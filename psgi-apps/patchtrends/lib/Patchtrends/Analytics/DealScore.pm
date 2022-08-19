package Patchtrends::Analytics::DealScore;

use strict;
use warnings;

use JSON::XS     ();
use Config::Tiny ();
use Sphinx::Search;
use Patchtrends::Analytics::ItemSemantics ();
use List::Util                            ();

use Set::Similarity::Jaccard ();
use Set::Similarity::Dice    ();
use Set::Similarity::Cosine  ();
use Set::Similarity::Overlap ();

my $HOME   = ( getpwuid $> )[7];
my $config = Config::Tiny->read(qq{$HOME/patchtrends.conf});
my $x      = Patchtrends::Analytics::ItemSemantics->new;

our $MAX_RESULTS        = 100;
our $MINIMUM_CONFIDENCE = .5;

# requires bidcount >= 1, thus ensuring it was an Auction item
sub _get_similar_auctions {

    my $config = shift;
    my $terms  = shift;

    my $sph = Sphinx::Search->new();
    $sph->SetServer( $config->{sphinx}->{host}, $config->{sphinx}->{port} );

    $sph->SetSortMode(SPH_SORT_RELEVANCE);

    $sph->SetFilter( 'itemsold', [1] );    #replaces: $sph->SetFilterRange( 'bidcount', 1, 500 );

    $sph->SetLimits( 0, $MAX_RESULTS );

    # if terms is a single space (%20), all the return of all results
    $terms = ( $terms eq q{ } ) ? undef : $terms;

    if ( $terms ne q{ } ) {
        $terms = $x->construct_terms($terms);

        # escape double quotes due to use of quorum syntax to emulate "any"
        $terms =~ s/[^\\]"/\\"/g;

        # emulates any using the quorum operator, "term1 term2 term3"/num_to_match
        $terms = qq{"$terms"/1};
    }

    $sph->SetRankingMode(SPH_RANK_WORDCOUNT);    #<--may be introducing error into clustering! ... test!
    my $results = $sph->Query( $terms, $config->{sphinx}->{indexes} );

    return $results->{matches};
}

# using a variety of "similarity" measures of the bag of words
sub compute_confidence {
    my $i_terms = shift;
    my $j_terms = shift;

    my $Ti = $x->construct_terms($i_terms);
    my $Tj = $x->construct_terms($j_terms);

    my @Ti = split / /, $Ti;
    my @Tj = split / /, $Tj;

    my $method1 = Set::Similarity::Jaccard->new;
    my $sim1 = $method1->similarity( \@Ti, \@Tj );

    my $method2 = Set::Similarity::Dice->new;
    my $sim2 = $method2->similarity( \@Ti, \@Tj );

    my $method3 = Set::Similarity::Cosine->new;
    my $sim3 = $method3->similarity( \@Ti, \@Tj );

    my $method4 = Set::Similarity::Overlap->new;
    my $sim4 = $method4->similarity( \@Ti, \@Tj );

    my $similarity = ( $sim1 + $sim2 + $sim3 + $sim4 ) / 4;

    # factor in specificity
    my $Si = compute_specificity($i_terms);
    my $Sj = compute_specificity($j_terms);

    # multiply average $similarity by the average specificity of both sets of terms
    my $confidence = $similarity * ( ( $Si + $Sj ) / 2 );

    return $confidence;
}

# assumes phrase has been "prepped"; factors in weight (importance) of $matched terms
# weight on not matched terms is based on word length
sub compute_specificity {
    my $prepped = shift;

    # number of words eligable for extraction
    my $prep_count = () = ( split ' ', $prepped, -1 );

    my ( $matched, @notmatched ) = $x->extract_keywords($prepped);

    # number of words not extracted, weight based on word length
    my $notmatched_weight = 0;
    foreach my $nm ( @{ $notmatched[0] } ) {
        $notmatched_weight += length $nm;
    }

    # weighted sum of extracted words
    my $weighted_sum = 0;
    foreach my $m ( keys %$matched ) {
        $weighted_sum += $x->weight($m);
    }

    # specificity is the ratio of unextracted words to all words, protected against divide by zero
    my $specificity = ( $notmatched_weight + $weighted_sum > 0 ) ? $notmatched_weight / ( $notmatched_weight + $weighted_sum ) : 0;

    return $specificity;
}

sub _compute_auction_score {
    my $self = shift;

    my $original_terms        = shift;
    my $original_bidcount     = shift;
    my $original_currentprice = shift;
    my $original_endtimeunix  = shift;

    # time left
    my $now           = time + 3 * 3600;                # bad bc server is cst, time is pst
    my $time_left_sec = $original_endtimeunix - $now;

    my $x = Patchtrends::Analytics::ItemSemantics->new;

    my $results = _get_similar_auctions( $config, $original_terms );

    # add confidence of match for each result returned
    my @confident_results = ();
    my $confidence_sum    = 0;
  COMPUTE_CONFIDENCE_SPECIFICITY:
    foreach my $r (@$results) {
        my $terms = $r->{title};

        # confidence of match with original title, includes specificities
        $r->{confidence} = compute_confidence( $original_terms, $terms );
        if ( $r->{confidence} >= $MINIMUM_CONFIDENCE ) {
            $confidence_sum += $r->{confidence};
            push @confident_results, $r;
        }
    }

    my $item_count = scalar @confident_results;
    $item_count = ($item_count) ? $item_count : 1;

    my $bid_sum   = 0;
    my $price_sum = 0;
    my $conf_sum  = 0;

    # sorted by highest confidence first - for no good reason atm, maybe later degrading weight
    foreach my $r ( sort { $b->{confidence} <=> $a->{confidence} } @confident_results ) {
        $bid_sum   += $r->{bidcount} || 1;# since we are using all sold items, assume bidcount is at least 1 even if it wasn't an auction
        $price_sum += $r->{finalprice}->[0] // $r->{finalprice}->[0];
        $conf_sum  += $r->{confidence};
    }

    # averages from selected sold items
    my $A_b = $bid_sum / $item_count;
    my $A_p = $price_sum / $item_count;
    my $C   = $conf_sum / $item_count;

    # default for when auction is < 2 days from ending
    my $T = 1;

    # 172800 sec is 48 hours
    my $window = 172800;
    if ( $window > $time_left_sec ) {
        $T = $time_left_sec / $window;
    }

    my $div_b = List::Util::max $A_b, $original_bidcount;
    $div_b = ( $div_b > 0 ) ? $div_b : 1;    # no divide by 0

    my $div_p = List::Util::max $A_p, $original_currentprice;
    $div_p = ( $div_p > 0 ) ? $div_p : 1;    # no divide by 0

    my $X_b = ( $C * ( $A_b - $original_bidcount ) / $div_b ) / $T;
    my $X_p = ( $C * ( $A_p - $original_currentprice ) / $div_p ) / $T;

    return ( $X_b, $X_p );
}

sub _compute_bin_score {
    my $self = shift;

    my $original_terms        = shift;
    my $original_currentprice = shift;
    my $original_endtimeunix  = shift;

    # time left
    my $now           = time + 3 * 3600;                # bad bc server is cst, time is pst
    my $time_left_sec = $original_endtimeunix - $now;

    my $x = Patchtrends::Analytics::ItemSemantics->new;

    my $results = _get_similar_auctions( $config, $original_terms );

    # add confidence of match for each result returned
    my @confident_results = ();
    my $confidence_sum    = 0;
  COMPUTE_CONFIDENCE_SPECIFICITY:
    foreach my $r (@$results) {
        my $terms = $r->{title};

        # confidence of match with original title, includes specificities
        $r->{confidence} = compute_confidence( $original_terms, $terms );
        if ( $r->{confidence} >= $MINIMUM_CONFIDENCE ) {
            $confidence_sum += $r->{confidence};
            push @confident_results, $r;
        }
    }

    my $item_count = scalar @confident_results;
    $item_count = ($item_count) ? $item_count : 1;

    my $price_sum = 0;
    my $conf_sum  = 0;

    # sorted by highest confidence first - for no good reason atm, maybe later degrading weight
    foreach my $r ( sort { $b->{confidence} <=> $a->{confidence} } @confident_results ) {
        $price_sum += $r->{currentprice}->[0];
        $conf_sum  += $r->{confidence};
    }

    # averages from selected sold items
    my $A_p = $price_sum / $item_count;
    my $C   = $conf_sum / $item_count;

    # default for when auction is < 2 days from ending
    my $T = 1;

    # 172800 sec is 48 hours
    my $window = 172800;
    if ( $window > $time_left_sec ) {
        $T = $time_left_sec / $window;
    }

    my $div_p = List::Util::max $A_p, $original_currentprice;
    $div_p = ( $div_p > 0 ) ? $div_p : 1;    # no divide by 0

    my $X_p = ( $C * ( $A_p - $original_currentprice ) / $div_p ) / $T;

    return $X_p;
}

1;

__END__
