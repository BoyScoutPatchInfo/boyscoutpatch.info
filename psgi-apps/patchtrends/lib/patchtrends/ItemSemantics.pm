package patchtrends::ItemSemantics;

use strict;
use warnings;
use Tie::Hash::Indexed;

binmode STDOUT, ":utf8";

our $NOTMATCHED_WEIGHT = 8;

our @stops = qw/
  boy bsa oa of scout scouts vintage america badge national the mint and
  set patches new community scouting official with county award
  rare used antique look only very good first last long great little own
  other old right big different large next early young important few public
  bad same able new scouting tough hot bsa slightly used in original scout
  extremely collectible estate order arrow orig original no reserve sale
  opportunity for item items mint is excellent inches width collection pile
  assorted by free shipping beauty order of the arrow
  /;

our $table = {
    nth    => { weight => 4, match => [qr/[\d]+th/] },
    first  => { weight => 4, match => [qw/1st first/], nomatch => [qw/class/] },
    second => { weight => 4, match => [qw/2nd second/], nomatch => [qw/class/] },
    issue  => { weight => 4, match => [qr/[a-z][ -]?[\d]+/] },
    years   => { weight => 4, match => [ qr/19\d\ds?/i, qr/2\d\d\ds?/i ] },
    numbers => { weight => 4, match => [qr/\d+/] },
    jewelry        => { weight => 2, match => [qw/jewelry ring watch necklace pin/], nomatch => [qr(centennial ring)] },
    commoration    => { weight => 2, match => [qw/reunion ann anniv anniversary centennial bicentennial memorial/] },
    oa_event       => { weight => 2, match => [qw/ordeal conclave noac fellowship/] },
    event          => { weight => 2, match => [qw/encampment conference camporee jamboree woodbadge campout/] },
    oa_division    => { weight => 2, match => [qw/chapter lodge section/] },
    division       => { weight => 2, match => [qw/contingent delegation trek patrol troop pack crew district council region/] },
    high_adventure => { weight => 2, match => [qw/philmont seabase sommers/] },
    ranks          => { weight => 2, match => [qw/eagle life star tenderfoot/] },
    colors         => {
        weight  => 2,
        match   => [qw/gold tan silver bronze red orange yellow green blue indigo violet black white gmy smy bkm bmy grm omy pmy rmy drd lrd dpk lpk mar dor org lor cop ror sam pchdyl yel lyl pyl dbr brn lbr rbr gbr tandgr fgr grn lgr pgr kak dkh lol olv doldtq btq lrq ltq ptq nbl dbl blu bbl lbl pbl dpr pur pbr lpr mar dvi vio lvi blk dgy gry lgy wht rwb gid/],
        nomatch => []
    },
    camp        => { weight => 1, match => [qw/camp camps reservation/] },
    shapes      => { weight => 1, match => [qw/dia diamond hex hexagon oct octagon pent pentagon rect rectangle  tri triangle/] },
    item        => { weight => 1, match => [qw/clasp clasps clip clamp tac slide hat hats slides tie bar rifle knive compass fob/] },
    maker       => { weight => 1, match => [qw/sterling/] },
    numberword  => { weight => 1, match => [qw/one two three four five six seven eight nine ten/] },
    patch       => { weight => 1, match => [qw/patch patches round flap/] },
    placement   => { weight => 1, match => [qw/shoulder pocket/] },
    neckerchief => { weight => 1, match => [qw/necker neckerchief/] },
    patch_type  => { weight => 1, match => [qw/csp jsp strip strips rws twill chenille woven bullion jacket round odd private fake forgery arrrowhead flap reject rejected/] },
    merged      => { weight => 1, match => [qw/merged merger/] },
    oa          => { weight => 1, match => [qw/oa/] },
    place       => { weight => 1, match => [qw/camp/] },

    #'' => { weight => 1, match => [ ], nomatch => [ ] },
    #'' => { weight => 1, match => [ ], nomatch => [ ] },
    #'' => { weight => 1, match => [ ], nomatch => [ ] },
};

sub new {
    my $pkg = shift;
    return bless {}, $pkg;
}

sub weight {
    my $self = shift;
    my $cat  = shift;
    return $table->{$cat}->{weight};
}

# uses $table to pick out relevent keywords
sub extract_keywords {
    my $self   = shift;
    my $string = shift;
    my @words  = split ' ', $string;

    my %words      = map { $_ => 1 } @words;
    my %notmatched = map { $_ => 1 } @words;
    my $found      = {};

  TYPES:
    foreach my $type ( keys %{$table} ) {

        # precondition - there must be no matches from the REs in 'nomatch' over the entire $string
      NO_MATCH:
        foreach my $re ( @{ $table->{$type}->{nomatch} } ) {
            next TYPES if $string =~ m/$re/i;
        }
      KEYWORD_MATCH:
        foreach my $re ( @{ $table->{$type}->{match} } ) {
            foreach my $w ( keys %words ) {
                if ( $w =~ m/^($re)$/ ) {
                    push @{ $found->{$type} }, $1;

                    # track what is is not matched thu deletion
                    delete $notmatched{$w} if exists $notmatched{$w};
                }
            }
        }
    }

    my @notmatched = keys %notmatched;

    return $found, \@notmatched;
}

# uses output of extract_keywords to build up a relevent search string
sub construct_terms {
    my $self   = shift;
    my $search = shift;

    # prepare string for keyword extraction
    my $prepared_search = $self->prepare($search);

    # extract keywords
    my ( $extracted, $notmatched ) = $self->extract_keywords($prepared_search);

    # build up search terms using extracted keywords and associated weights
    my $terms = q{ };
  NOTMATCHED:
    foreach my $m (@$notmatched) {
        $terms .= qq{$m } x int $NOTMATCHED_WEIGHT;
    }

  TYPES:
    foreach my $type ( keys %{$extracted} ) {
        my $weight = $self->weight($type);
        foreach my $keyword ( @{ $extracted->{$type} } ) {
            $terms .= qq{$keyword } x int $weight . qq{\n};
        }
    }

    return $terms;
}

# removes "stop" words, meaningless noise
sub strip_stopwords {
    my $self     = shift;
    my $string   = shift;
    my @words    = split / /, lc $string;
    my %in_bl    = map { $_ => 1 } @stops;
    my @newwords = grep { not $in_bl{$_} } @words;
    $string = join q{ }, sort @newwords;
    return $string;
}

sub unique {
    my $self   = shift;
    my $string = shift;
    my @words  = split / /, $string;
    tie my %words, 'Tie::Hash::Indexed';
    %words = map { $_ => 1 } @words;
    return join q{ }, sort keys %words;
}

# lowercase, remove garbage
sub prepare {
    my $self   = shift;
    my $string = shift;

    # force lowercase
    $string = lc $string;

    # with
    $string =~ s/ w\// with /g;

    # make bag of words unique, retain relative ordering
    $string = $self->unique($string);

    # regexes to further massage string
    $string =~ s/-//g;
    $string =~ s/([a-z]+)-([\d]+)/$1$2/gi;
    $string =~ s/[\/\\]/ /g;
    $string =~ s/[\+'";-]+//g;
    $string =~ s/[:#\+\?"'\*\]\[]+//g;
    $string =~ s/[_,\&!:)(]/ /g;
    $string =~ s/\'s//g;
    $string =~ s/ +/ /g;
    $string =~ s/\.//g;

    # remove stop words
    $string = $self->strip_stopwords($string);

    # removed works of size 3
    my @string = split / /, $string;
    @string = grep { !/^.{3}$/ } @string;

    $string = join " ", sort @string;
    return $string;
}

1;

__END__
