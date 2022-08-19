package patchtrends::eBayItem;

use strict;
use warnings;
use parent q{Site::Object};

use Exception::Class (
    'X::Fatal',
    'X::DBError'          => { isa => 'X::Fatal' },
    'X::RecordNotFound'   => { isa => 'X::Fatal' },
    'X::InvalidParameter' => { isa => 'X::Fatal', fields => [qw/missing invalid/] },
);

# mirrors data structure return by Sphinx Search of a specific eBay item
our @SPHINX = (qw/bestoffer bidcount buyitnow conditiondisplayname currentprice doc endtime endtimeunix finalprice groupby_all imageurl is_bin itemid itemsold listingtype listingtype_crc32 postalcode primarycategory primarycategory_crc32 searchcatagory seller seller_crc32 starttime starttimeunix store title url weight/);

# used to strip out unwanted fields when converted to a pure hashref (see as_hashref)
our @strip_fields = [qw/sph/];

__PACKAGE__->attributes(@SPHINX);

sub new {
    my $pkg        = shift;
    my $params_ref = shift;

    my $self = $pkg->SUPER::new($params_ref);

    return $self;
}

sub load {
    my $self = shift;
    $self->_assert_sph();
}

sub _assert_sph {
    my $self = shift;
    if ( not $self->sph() ) {
        throw X::InvalidParameter(q{Sphinx handle required (sph)});
    }
    return;
}

sub TO_JSON {

}

1;

__END__
