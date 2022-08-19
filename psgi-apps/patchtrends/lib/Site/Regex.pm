package Site::Regex;
use strict;
use Carp;

use Site::Parser;
use Site::Op;

my $PARSER = Site::Parser->new(qw[ and concat negate ]);

#### TODO: error checking in the parse

sub _parser {$PARSER}

sub new {
    my ( $pkg, $string ) = @_;
    my $result = $pkg->_parser->parse($string)
        or undef;    #croak qq[``$string'' is not a valid regular expression];
    if ($result) {
       my $self = $pkg->_from_op($result);
       return $self;
    }
    else {
        return undef;
    }
}

sub _from_op {
    my ( $proto, $op ) = @_;
    $proto = ref $proto || $proto;    ## I really do want this
    bless [$op], $proto;
}

sub op {
    $_[0][0];
}

use overload '""' => 'as_string';

sub as_string {
    my $self          = shift;
    my $search_column = shift;
    my $dbh           = shift;
    if ($search_column) {
        $Site::Op::atomic::search_column = $search_column;
    }
    if ($dbh) {
        $Site::Op::atomic::dbh = $dbh;
    }
    $self->op->as_string(0);
}

1;
