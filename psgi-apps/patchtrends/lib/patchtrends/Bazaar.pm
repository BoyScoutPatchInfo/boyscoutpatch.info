package patchtrends::Bazaar;

use strict;
use warnings;
use JSON::XS;
use URI::Escape  ();
use Config::Tiny;
use Sphinx::Search;
use Digest::SHA qw(hmac_sha512_hex);
use Time::HiRes qw(gettimeofday);
use HTTP::Tiny ();
use String::CRC32  ();

# for use with listingtype_crc32
our $crc32s = { 
  'AuctionWithBIN' => String::CRC32::crc32('AuctionWithBin'),
  'FixedPrice'     => String::CRC32::crc32('FixedPrice'),
  'StoreInventory' => String::CRC32::crc32('StoreInventory'),
};

sub new {
  my $pkg = shift;
  my $self = {};
  bless $self, $pkg;
  return $self;
}

sub _set_per_page {
    my $self = shift;
    my $sph  = shift;

    my $cgi = $self->query;

    # results per page
    my $perPage = $cgi->param('perPage');
    $perPage = ( int $perPage > 0 ) ? $perPage : 2000;

    eval { $sph->SetLimits( 0, $perPage ); };
    warn $@ if $@;
    return;
}

sub _set_bidcount_range {
    my $self = shift;
    my $sph  = shift;

    my $cgi = $self->query;

    my $minBidCount = ( int $cgi->param('minBidCount') >= 0 ) ? $cgi->param('minBidCount') : 0;
    my $maxBidCount =
      ( int $cgi->param('maxBidCount') >= 0 )
      ? $cgi->param('maxBidCount')
      : 100000;

    eval { $sph->SetFilterRange( 'bidcount', $minBidCount, $maxBidCount ); };
    warn $@ if $@;
    return;
}

sub _set_bidamount_range {
    my $self = shift;
    my $sph  = shift;

    my $cgi = $self->query;

    my $minBidAmount =
      ( $cgi->param('minBidAmount') ) ? $cgi->param('minBidAmount') : 0.00;
    my $maxBidAmount =
      ( $cgi->param('maxBidAmount') ) ? $cgi->param('maxBidAmount') : 100000.00;

    $minBidAmount = sprintf "%.2f", $minBidAmount;
    $maxBidAmount = sprintf "%.2f", $maxBidAmount;

    eval {
        $sph->SetFilterFloatRange( 'currentprice', $minBidAmount, $maxBidAmount );
    };
    warn $@ if $@;
    return;
}

sub _set_order_by {
    my $self = shift;
    my $sph  = shift;

    my $cgi = $self->query;

    my $orderBy = $cgi->param('orderBy');

    my $attrs = {
        q{bids}        => q{bidCount},
        q{bid amount}  => q{currentPrice},
        q{end time}    => q{endtimeunix},
        q{start time}  => q{starttimeunix},
    };

    if ( !$orderBy or !exists $attrs->{$orderBy} ) {
        $orderBy = q{bid amount};
    }

    my $order = ( $cgi->param('descending') ) ? SPH_SORT_ATTR_DESC : SPH_SORT_ATTR_ASC;
    eval { $sph->SetSortMode( $order, $attrs->{$orderBy} ) };
    warn $@ if $@;
    return;
}

# gets all things that have a "buy it now" button, but not "best offer" 
sub _set_buy_it_now {
    my $self = shift;
    my $sph  = shift;

    my $cgi = $self->query;

    my $buyItNow = $cgi->param('buyItNow');
    if ( $buyItNow ) {
      # gets results matching all criteria that make it a "buy it now"
      eval {
          # added "is_bin" attr 
          $sph->SetSelect(qq/*, buyitnow=1 or ( listingtype_crc32=$crc32s->{FixedPrice} and bestoffer=0 ) or ( listingType_crc32=$crc32s->{StoreInventory} and bestoffer=0 ) as is_bin/); 
          # shows only if 'is_bin' is 1
          $sph->SetFilter('is_bin', [ 1 ]);
      };
    }

    return;
}

# gets all things with a "best offer" enabled, even if it's also a "buy it now"
sub _set_best_offer {
    my $self = shift;
    my $sph  = shift;

    my $cgi = $self->query;
    
    my $bestOffer = $cgi->param('bestOffer');
    if ( $bestOffer ) {
      eval {
          $sph->SetFilter( 'bestoffer', [ $bestOffer ] );
      };
    }

    return;
}

sub _set_listing_type {
    my $self = shift;
    my $sph  = shift;

    my $cgi = $self->query;

    my $listingType = $cgi->param('listingType');

    if ( defined $listingType ) {
      my $crc32 = String::CRC32::crc32($cgi->param('listingType'));
      eval {
          $sph->SetFilter( 'listingtype_crc32', [ $crc32 ] );
      };
    }

    return;
}

sub sphinx_search {
    my $self = shift;

    my $cgi    = $self->query();
    my $config = $self->param('config');

    my $terms = $self->param('terms');
    $terms = URI::Escape::uri_unescape($terms);
    $terms = ( $terms eq q{ } ) ? undef : $terms;

    my $sph = Sphinx::Search->new();
    $sph->SetServer( $config->{sphinx}->{host}, $config->{sphinx}->{port} );

    # default result list
    $sph->SetLimits( 0, 1500, 1500 );

    # Results
    $self->_set_per_page($sph);
    $self->_set_order_by($sph);

    # Filters
    $self->_set_bidcount_range($sph);
    $self->_set_bidamount_range($sph);
    $self->_set_buy_it_now($sph);
    $self->_set_best_offer($sph);
    $self->_set_listing_type($sph);

    #TODO: tempory fix to only return items that have not ended
    my $now = time;
    $sph->SetFilterRange( 'endtimeunix', $now, 2424893481 );

    my @indexes = ();

    # just using combined MariaDB 
    foreach my $search ( keys %{ $config->{combined} } ) {
        push @indexes, qq{$search};
    }

    # emulate deprecated BOOLEAN match mode - no need to escape quotes (would if using emulating ANY with quorum operator)
    $sph->SetRankingMode(SPH_RANK_NONE);
    my $results = $sph->Query( qq{$terms}, join( ' ', @indexes ) );

    #-- add search logging and session logging back at some point

    return JSON::XS::encode_json $results->{matches};
}

sub details {
    my $self = shift;

    my $cgi    = shift // $self->query();
    my $config = shift // $self->param('config');
    my $itemid = shift // $self->param('itemid');

    my $sph = Sphinx::Search->new();
    $sph->SetServer( $config->{sphinx}->{host}, $config->{sphinx}->{port} );

    # default result list
    $sph->SetLimits( 0, 1, 1 );

    # add "is_bin"
    $sph->SetSelect(qq/*, buyitnow=1 or ( listingtype_crc32=$crc32s->{FixedPrice} and bestoffer=0 ) or ( listingType_crc32=$crc32s->{StoreInventory} and bestoffer=0 ) as is_bin/); 

    my @indexes = ();

    # just using combined MariaDB 
    foreach my $search ( keys %{ $config->{combined} } ) {
        push @indexes, qq{$search};
    }

    $sph->SetFilter( 'itemid', [$itemid] );

    # emulate deprecated BOOLEAN match mode
    $sph->SetRankingMode(SPH_RANK_NONE);
    my $results = $sph->Query( undef, join( ' ', @indexes ) );
    if ( not @{ $results->{matches} } ) {
        $self->header_props( -type => 'application/json', -status => 404 );
        return q/{"status":"404", msg:"Item not found."}/;
    }

    my $JSON = eval { JSON::XS::encode_json $results->{matches} };
    if ( not $JSON or $@ ) {
        $self->header_add( -type => 'application/json', -status => 500 );
        return q/{"status":"500", msg:"Item details currently not available"}/;
    }
    return $JSON;
}

sub _sign_request {
    my $self = shift;
    my $config = shift;
    my $message = shift;

    # build up request to Patchtrends
    my $key    = $config->{patchtrends}->{key};
    my $secret = $config->{patchtrends}->{secret};
    my $nonce  = $self->microtime();

    # sign $terms unescaped
    my $signature = hmac_sha512_hex( $nonce, $message, $secret );
    my $attributes = {
        default_headers => {
            q{PATCHTRENDS-KEY}     => $key,
            q{PATCHTRENDS-NONCE}   => $nonce,
            q{PATCHTRENDS-REQ-SIG} => $signature,
        }
    };

    return $attributes;
}

sub patchtrends_search {
    my $self = shift;

    my $cgi    = shift // $self->query();
    my $config = shift // $self->param('config');
    my $terms  = shift // $self->param('terms');

    # $terms here is the data we're sending via the request
    $terms =~ s/[^\w\.\-]/ /g;    # remove non-word characters
    $terms =~ s/\s+/ /g;          # compact spaces

    my $attributes = $self->_sign_request($config, $terms);

    # escape for inclusion in URI
    $terms = URI::Escape::uri_escape($terms);
    my $uri = qq{http://www.patchtrends.com/cgi-bin/rest/client/similar/$terms};

    my $response = eval { return HTTP::Tiny->new(%$attributes)->get($uri) };

    if ( not $response ) {
        $self->header_props( -type => 'application/json', -status => 404 );
        return q/{"status":"404", msg:"Item not found."}/;
    }
    elsif ( not $response->{success} ) {
        $self->header_props( type => 'application/json', -status => 500 );
        return q/{"status":"500", msg:"Patchtrends data currently not available"}/;
    }
    else {
        my $JSON = $response->{content} // q{[]};
        return $JSON;
    }
}

sub patchtrends_deal_score {
    my $self   = shift;
    my $cgi    = shift // $self->query();
    my $config = shift // $self->param('config');
    my $itemid = shift // int $self->param('itemid');

    my $attributes = $self->_sign_request($config, $itemid);
    my $uri = qq{http://www.patchtrends.com/cgi-bin/rest/client/dealscore/$itemid};
    my $response = eval { return HTTP::Tiny->new(%$attributes)->get($uri) };
    return Data::Dumper::Dumper($response); 
}

sub microtime {
    my $self = shift;
    return sprintf "%d%06d", gettimeofday;
}

1;
