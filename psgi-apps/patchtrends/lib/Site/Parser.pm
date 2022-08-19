package Site::Parser;
use strict;
use lib '/usr/local/www/patchlodge';

#### Is this one level of abstraction too far? Parser generator generators..

#### TODO: try YAPP, since recursive descent is SLOOOW
use Parse::RecDescent;
use Site::Op;

use vars '$CHAR';
$CHAR = qr{ [a-zA-Z0-9'\-:_\.]+ }x;

sub new {
    my $pkg = shift;
    my @ops = sort { $a->{prec} <=> $b->{prec} }
        map {
        {   pkg   => "Site::Op::$_",
            prec  => "Site::Op::$_"->precedence,
            spec  => "Site::Op::$_"->parse_spec,
            short => $_
        }
        } @_;

    my $lowest  = shift @ops;
    my $grammar = qq!
            parse:
                $lowest->{short} /^\\Z/ { \$item[1] }
    !;

    my $prev = $lowest;
    for (@ops) {
        my $spec = sprintf $prev->{spec}, $_->{short};
        $grammar .= qq!
            $prev->{short}:
                $spec       { $prev->{pkg}\->from_parse(\@item) }
              | $_->{short} { \$item[1] }
        !;
        $prev = $_;
    }

    my $spec = sprintf $prev->{spec}, "atomic";
    $grammar .= qq!
            $prev->{short}:
                $spec  { $prev->{pkg}\->from_parse(\@item) }
              | atomic { \$item[1] }
            atomic: /\$Site::Parser::CHAR/ { Site::Op::atomic->from_parse(\@item) }
                  | '(' $lowest->{short} ')' { \$item[2] }
    !;

    Parse::RecDescent->new($grammar);
}

1;
