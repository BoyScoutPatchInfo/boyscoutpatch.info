package patchtrends::Search;

use strict;
use warnings;
use Sphinx::Search             ();
use DateTime                   ();
use String::CRC32              ();
use patchtrends::ItemSemantics ();

our $crc32s = {
    'Auction'        => String::CRC32::crc32('Auction'),
    'AuctionWithBIN' => String::CRC32::crc32('AuctionWithBin'),
    'FixedPrice'     => String::CRC32::crc32('FixedPrice'),
    'StoreInventory' => String::CRC32::crc32('StoreInventory'),
};

sub new {
    my $pkg  = shift;
    my $self = {};
    bless $self, $pkg;
    return $self;
}

sub _set_date_range {
    my $self   = shift;
    my $sph    = shift;
    my $params = shift;

    my $now = time;

    my $beginEpoch = $params->{beginDate} // 0;
    my $endEpoch   = $params->{endDate}   // $now;

    $beginEpoch = ( int $beginEpoch ) ? int $beginEpoch : 0;
    $endEpoch   = ( int $endEpoch )   ? int $endEpoch   : $now;

    #-- filtering on "endtime" only
    if ( $beginEpoch and $endEpoch ) {
        my $beginDT = DateTime->from_epoch( epoch => $beginEpoch );
        $beginDT->set_hour('0');
        $beginDT->set_minute('0');
        $beginDT->set_second('0');
        my $beginDate = $beginDT->epoch();

        my $endDT = DateTime->from_epoch( epoch => $endEpoch );
        $endDT->set_hour('23');
        $endDT->set_minute('59');
        $endDT->set_second('59');
        my $endDate = $endDT->epoch();

        eval { $sph->SetFilterRange( 'endtime', $beginDate, $endDate ); };
        warn $@ if $@;
    }
    return;
}

sub _set_per_page {
    my $self   = shift;
    my $sph    = shift;
    my $params = shift;

    my $large_limit   = 150000;
    my $default_limit = 150;

    # results per page
    my $perPage = $params->{perPage} // $default_limit;

    $perPage = ( defined $perPage and $perPage eq 'forplot' ) ? $large_limit : ( int $perPage > 0 ) ? int $perPage : $default_limit;

    eval { $sph->SetLimits( 0, $perPage, $large_limit ); };
    warn $@ if $@;
    return;
}

sub _set_bidcount_range {
    my $self   = shift;
    my $sph    = shift;
    my $params = shift;

    # bid count is not useful when we want to filter by bestOffer or BIN
    my $minBidCount = ( defined $params->{minBidCount} and int $params->{minBidCount} >= 0 ) ? int $params->{minBidCount} : 1;
    my $maxBidCount = ( defined $params->{maxBidCount} and int $params->{maxBidCount} >= 0 ) ? int $params->{maxBidCount} : 100000;

    eval { $sph->SetFilterRange( 'bidcount', $minBidCount, $maxBidCount ); };
    warn $@ if $@;
    return;
}

sub _set_bidamount_range {
    my $self   = shift;
    my $sph    = shift;
    my $params = shift;

    my $minBidAmount = $params->{minBidAmount} // 0.01;
    my $maxBidAmount = $params->{maxBidAmount} // 100000.00;

    $minBidAmount = ( 0.01 <= $minBidAmount ) ? $minBidAmount : 0.01;
    $maxBidAmount = ( 0.01 < $maxBidAmount )  ? $maxBidAmount : 100000.00;

    $minBidAmount = sprintf "%.2f", $minBidAmount;
    $maxBidAmount = sprintf "%.2f", $maxBidAmount;

    eval { $sph->SetFilterFloatRange( 'currentprice', $minBidAmount, $maxBidAmount ); };
    warn $@ if $@;
    return;
}

sub _set_category {
    my $self   = shift;
    my $sph    = shift;
    my $params = shift;

    my @categories = ( q{Council & Shoulder Patches}, q{Order of the Arrow Patches}, q{Neckerchiefs & Slides}, q{Postcards & Cards}, q{Badges & Patches}, q{Jamboree Patches}, q{Posters & Prints}, q{Flags & Pennants}, q{Books & Manuals}, q{Camp Patches}, q{Mugs & Cups}, q{Pins}, q{Mixed Lots}, q{Equipment}, q{Insignia Patches}, q{Philmont & High Adventure}, q{International Patches}, q{Other}, );

    my $crc32 = undef;
    my $cat   = $params->{primaryCategory};
    if ( $cat and grep { /$cat/ } @categories ) {
        $crc32 = String::CRC32::crc32($cat);
        eval { $sph->SetFilter( 'primarycategory_crc32', [$crc32] ); };
    }
    warn $@ if $@;
    return;
}

sub _set_seller {
    my $self   = shift;
    my $sph    = shift;
    my $params = shift;

    return if not $params->{seller};

    my $crc32s      = [];
    my $seller_list = $params->{seller};
    if ($seller_list) {
        $seller_list =~ s/, /,/g;    # remove spaces after commas
        $seller_list =~ s/ /,/g;     # convert spaces to commas
        my @sellers = split /,/, $seller_list;
        foreach my $seller (@sellers) {
            push @$crc32s, String::CRC32::crc32($seller);
        }
        eval { $sph->SetFilter( 'seller_crc32', $crc32s ); } if @$crc32s;
    }

    warn $@ if $@;
    return;
}

sub _set_itemid {
    my $self   = shift;
    my $sph    = shift;
    my $params = shift;

    my $itemid_list = $params->{itemid};
    if ($itemid_list) {
        $itemid_list =~ s/, /,/g;    # remove spaces after commas
        $itemid_list =~ s/ /,/g;     # convert spaces to commas
        my @itemids = split /,/, $itemid_list;
        eval { $sph->SetFilter( 'itemid', \@itemids ); } if @itemids;
    }

    warn $@ if $@;
    return;
}

sub _set_order_by {
    my $self   = shift;
    my $sph    = shift;
    my $params = shift;

    my $attrs = {
        q{end time}   => q{endtimeunix},   # active items     - inconsistent with completed field
        q{date}       => q{endtime},       # completed items  - inconsistent with active field
        q{start time} => q{starttimeunix},
        q{bids}       => q{bidcount},
        q{bid amount} => q{currentprice},
        q{relevance}  => q{relevance},
        q{rating}     => q{rating},
    };

    my $orderBy = ( $params->{orderBy} ) ? $params->{orderBy} : undef;
    my $order = ( $params->{descending} and ( $params->{descending} eq q{1} or $params->{descending} eq q{true} ) ) ? Sphinx::Search->SPH_SORT_ATTR_DESC : Sphinx::Search->SPH_SORT_ATTR_ASC;

    if ( !$orderBy or $orderBy eq 'relevance' or not exists $attrs->{$orderBy} ) {
        eval { $sph->SetSortMode( Sphinx::Search->SPH_SORT_RELEVANCE ); };
    }
    else {
        eval { $sph->SetSortMode( $order, $attrs->{$orderBy} ) };
        if ( $orderBy eq 'rating' ) {
          eval { $sph->SetFilterRange( 'rating', 1, 3 ) };
        }
    }

    warn $@ if $@;
    return;
}

sub _set_match_mode {
    my $self   = shift;
    my $sph    = shift;
    my $params = shift;

    my $matchMode = $params->{matchMode} // q{bool};

    my $modes = {
        'any' => sub {
            $sph->SetRankingMode( Sphinx::Search->SPH_RANK_MATCHANY );
        },
        'all' => sub {
            $sph->SetRankingMode( Sphinx::Search->SPH_RANK_PROXIMITY_BM25 );
        },
        'bool' => sub {
            $sph->SetRankingMode( Sphinx::Search->SPH_RANK_NONE );
        },
    };

    $modes->{$matchMode}->();

    return;
}

# deprecated from patchtrends::Search::Completed, currently only used by patchtrends::Search::Active
sub _set_buy_it_now {
    my $self   = shift;
    my $sph    = shift;
    my $params = shift;

    if ( $params->{buyItNow} ) {
        eval { $sph->SetFilter( 'is_bin', [1] ); };
    }

    return;
}

sub _set_best_offer {
    my $self   = shift;
    my $sph    = shift;
    my $params = shift;

    if ( $params->{bestOffer} ) {
        eval { $sph->SetFilter( 'bestoffer', [1] ); };
    }

    return;
}

sub _set_listing_type {
    my $self   = shift;
    my $sph    = shift;
    my $params = shift;

    my $listingType = $params->{listingType};

    if ( defined $listingType and $listingType eq q{BuyItNow} ) {
        eval { $sph->SetFilter( 'is_bin', [1] ); };
    }
    elsif ( defined $listingType and $listingType eq q{BestOffer} ) {
        eval { $sph->SetFilter( 'bestoffer', [1] ); };
    }
    elsif ( defined $listingType and defined $crc32s->{$listingType} ) {
        my $crc32 = String::CRC32::crc32($listingType);
        eval { $sph->SetFilter( 'listingtype_crc32', [$crc32] ); };
    }

    return;
}

sub _mark_is_bin {
    my $self   = shift;
    my $sph    = shift;
    my $params = shift;

    $sph->SetSelect(qq/*, buyitnow=1 or ( listingtype_crc32=$patchtrends::Search::crc32s->{FixedPrice} and bestoffer=0 ) or ( listingType_crc32=$patchtrends::Search::crc32s->{StoreInventory} and bestoffer=0 ) as is_bin/);
    return;
}

sub search {
    die q{Need to implement search method in child class.};
}

sub similar_items {
    my $self   = shift;
    my %params = @_;

    my $sph = Sphinx::Search->new();

    my $terms = $params{query}->{label};

    $sph->SetServer( $params{sphinx}->{host}, $params{sphinx}->{port} );

    $sph->SetSortMode( Sphinx::Search->SPH_SORT_RELEVANCE );

    $sph->SetFilter( 'itemsold', [ 1 ] ); #replaces: $sph->SetFilterRange( 'bidcount', 1, 500 );

    $sph->SetLimits( 0, 100 );

    # if terms is a single space (%20), all the return of all results
    $terms = ( $terms eq q{ } ) ? q{} : $terms;

    if ( $terms ne q{ } ) {
        my $x = patchtrends::ItemSemantics->new;
        $terms = $x->construct_terms($terms);

        # escape double quotes due to use of quorum syntax to emulate "any"
        $terms =~ s/[^\\]"/\\"/g;

        # emulates any using the quorum operator, "term1 term2 term3"/num_to_match
        $terms = qq{"$terms"/1};
    }

    $sph->SetRankingMode( Sphinx::Search->SPH_RANK_WORDCOUNT );
    my $results = $sph->Query( $terms, $params{sphinx}->{indexes} );

    return $results->{matches};
}


1;
