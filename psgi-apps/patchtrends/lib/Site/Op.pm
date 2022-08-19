package Site::Op;
use strict;

sub new {
    my $pkg = shift;
    ## flatten alike operations, i.e, "a+(b+c)" into "a+b+c"
    my @flat = @_;
    map { UNIVERSAL::isa( $_, $pkg ) ? $_->members : $_ } @_;

    bless \@flat, $pkg;
}

sub members {
    my $self = shift;
    wantarray ? @$self[ 0 .. $#$self ] : $self->[0];
}

#### operators / components

package Site::Op::atomic;
use base 'Site::Op';

our $search_column = 'tbl_tag_strings.tag_string';    # default

sub as_string {
    my $t = $_[0]->members;

    return "#" if not defined $t;

    # escape single quotes
    $t =~ s/'/\\'/g;

    return sprintf( "%s RLIKE '^%s | %s | %s\$|^%s\$'", $Site::Op::atomic::search_column, $t, $t, $t, $t );
}

sub from_parse {
    my ( $pkg, @item ) = @_;
    my $i = $item[1];

    return $pkg->new("")    if $i eq "[]";
    return $pkg->new(undef) if $i eq "#";

    $i =~ s/^\[|\]$//g;

    return $pkg->new($i);
}

package Site::Op::negate;
use base "Site::Op";
use Carp;

sub parse_spec { "'!' %s"; }
sub precedence {20}

sub as_string {
    my ( $self, $prec ) = @_;
    my $result = "NOT " . $self->members->as_string( $self->precedence );

    #my $result = " -" . $self->members->as_string($self->precedence);
    return $prec > $self->precedence ? "( $result )" : $result;
}

sub from_parse {
    my ( $pkg, @item ) = @_;
    $pkg->new( $item[2] );
}

package Site::Op::concat;
use base 'Site::Op';

sub parse_spec { "%s(2..)"; }
sub precedence {10}

sub as_string {
    my ( $self, $prec ) = @_;
    my $result = join " OR ",

        #my $result = join " ",
        map { $_->as_string( $self->precedence ) } $self->members;
    return $prec > $self->precedence ? "( $result )" : $result;
}

sub from_parse {
    my ( $pkg, @item ) = @_;
    $pkg->new( @{ $item[1] } );
}

package Site::Op::and;
use base 'Site::Op';

sub parse_spec {"%s(2.. /[&]/)"}
sub precedence {15}

sub as_string {
    my ( $self, $prec ) = @_;
    my $result = join " AND ",

        #my $result = join " +",
        map { $_->as_string( $self->precedence ) } $self->members;
    return $prec > $self->precedence ? "( $result )" : $result;
}

sub from_parse {
    my ( $pkg, @item ) = @_;
    $pkg->new( @{ $item[1] } );
}

1;
