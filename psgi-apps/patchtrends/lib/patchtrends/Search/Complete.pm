package patchtrends::Search::Complete;
use parent q{patchtrends::Search};

sub item_details {
    my $self   = shift;
    my %params = @_;

    my $sph = Sphinx::Search->new();

    my $itemid = $params{query}->{itemid};

    $sph->SetServer( $params{sphinx}->{host}, $params{sphinx}->{port} );

    # default result list
    $sph->SetLimits( 0, 1, 1 );

    # add "is_bin"
    my $crc32s = $patchtrends::Search::crc32s;
    $sph->SetSelect(qq/*, buyitnow=1 or ( listingtype_crc32=$crc32s->{FixedPrice} and bestoffer=0 ) or ( listingType_crc32=$crc32s->{StoreInventory} and bestoffer=0 ) as is_bin/);

    $sph->SetFilter( 'itemid', [$itemid] );

    $sph->SetRankingMode( Sphinx::Search->SPH_RANK_NONE );

    my $results = $sph->Query( q{}, $params{sphinx}->{indexes} );

    return $results->{matches}->[0];
}

sub _set_sold_status {
    my $self   = shift;
    my $sph    = shift;
    my $params = shift;

    my $status_map = {
        'sold'    => [1],
        'unsold'  => [0],
        'known'   => [ 0, 1 ],
        'unknown' => [-1],
    };

    if ( $params->{soldStatus} and defined $status_map->{ $params->{soldStatus} } ) {
        $sph->SetFilter( 'itemsold', $status_map->{ $params->{soldStatus} } );
    }

    return;
}

sub search {
    my $self   = shift;
    my %params = @_;

    my $sph = Sphinx::Search->new();

    # prepare search terms
    my $terms = ( $params{terms} and $params{terms} =~ m/^\s*$/ ) ? q{} : $params{terms};

    # if an array ref of fields to include is passed, create SelectSet string; otherwise, pass
    # in a wildcard (*) that returns all like in an SQL SELECT
    my $select_fields = (q{ARRAY} eq ref $params{fields}) ? join(q{,}, @{$params{fields}}) : q{*};

    $sph->SetServer( $params{sphinx}->{host}, $params{sphinx}->{port} );


    $self->_mark_is_bin( $sph, $params{query} );
    $self->_set_order_by( $sph, $params{query} );
    $self->_set_match_mode( $sph, $params{query} );
    $self->_set_date_range( $sph, $params{query} );
    $self->_set_per_page( $sph, $params{query} );
    $self->_set_category( $sph, $params{query} );

    # don't apply bid count to StoreInventory or FixedPrice; do apply if Auction or AuctionWithBIN
    my $listingType = $params{query}->{listingType};
    if ( grep { /$listingType/ } (qw/Auction AuctionWithBIN/) ) {
        $self->_set_bidcount_range( $sph, $params{query} );
    }

    $self->_set_bidamount_range( $sph, $params{query} );
    $self->_set_seller( $sph, $params{query} );
    $self->_set_listing_type( $sph, $params{query} );
    $self->_set_itemid( $sph, $params{query} );
    $self->_set_sold_status( $sph, $params{query} );

    my $matchMode = $params{query}->{matchMode} // q{bool};
    if ( $terms and $matchMode eq q{any} and $terms !~ m/^\s+$/ ) {

        # escape double quotes due to use of quorum syntax to emulate "any"
        $terms =~ s/[^\\]"/\\"/g;

        # emulate "any"
        $terms = qq{"$terms"/1};
    }

    $sph->SetSelect($select_fields);

    my $results = $sph->Query( $terms, $params{sphinx}->{indexes} );

    return $results->{matches};
}

1;
