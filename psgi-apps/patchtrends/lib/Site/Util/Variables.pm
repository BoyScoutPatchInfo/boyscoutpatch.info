package Site::Util::Variables;

use strict;
use warnings;

sub is_hashref {
    my $var_ref = shift;
    return ((defined $var_ref && ref $var_ref eq 'HASH') ? $var_ref : undef);
}

sub is_arrayref {
    my $var_ref = shift;
    return ((defined $var_ref && ref $var_ref eq 'ARRAY') ? $var_ref : undef);
}

sub is_blessed_ref {
    my $var_ref = shift;
    return ((defined $var_ref && ref $var_ref && UNIVERSAL::can($var_ref, 'can')) ? $var_ref : undef);
}

1;
