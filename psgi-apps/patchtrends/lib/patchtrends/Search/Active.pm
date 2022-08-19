package patchtrends::Search::Active;
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

sub search {
    my $self   = shift;
    my %params = @_;

    my $sph = Sphinx::Search->new();

    # prepare search terms
    my $terms = ( $params{terms} and $params{terms} =~ m/^\s*$/ ) ? q{} : $params{terms};

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

    # TODO Update Active item UI to use same scheme as Completed items
    # TODO reuse code - vv literally the only diff between search method between Active.pm and Completed.pm
    # don't show items that expired before $now
    my $now = time;
    $sph->SetFilterRange( 'endtimeunix', $now, 2424893481 );

    # TODO reuse code - ^^ literally the only diff between search method between Active.pm and Completed.pm

    my $matchMode = $params{query}->{matchMode} // q{bool};
    if ( $terms and $matchMode eq q{any} and $terms !~ m/^\s+$/ ) {

        # escape double quotes due to use of quorum syntax to emulate "any"
        $terms =~ s/[^\\]"/\\"/g;

        # emulate "any"
        $terms = qq{"$terms"/1};
     }
    
    my $results = $sph->Query( $terms, $params{sphinx}->{indexes} );

    return $results->{matches};
}

1;
