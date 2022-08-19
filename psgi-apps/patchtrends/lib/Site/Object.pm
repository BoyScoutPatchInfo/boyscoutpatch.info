package Site::Object;

use strict;
use warnings;

use Site::Util::Variables ();

sub new {
    my ($class, $params_hash_ref) = @_;

    my $self = bless {}, $class;

    # Import any arguments passed in via the params hash reference
    if (Site::Util::Variables::is_hashref($params_hash_ref)) {
        @$self{keys %{$params_hash_ref}} = values %{$params_hash_ref};
    }

    return $self;
}

sub attributes {
    my ($class, @attributes) = @_;

    # define setters and getters for each attribute
    foreach my $attr (@attributes) {
        my $code   = $class->_setter_code($attr);
        my $method = "${class}::${attr}";
        {no strict 'refs'; *$method = $code;}
    }
}

sub _setter_code {
    my ($class, $attr) = @_;
    return sub {
        my ($self, $value) = @_;
        if (@_ == 1) {
            return $self->{$attr};
        }
        else {
            return $self->{$attr} = $value;
        }
    };
}

1;

=head1 NAME

Site::Object

=head1 DESCRIPTION

This is intended to be used as a base class for other basic objects

For example:

package Foo::Bar;

use base qw(Store::Object);

# Define basic get/sets for this package
__PACKAGE__->attributes(qw{name phone address});

1;
