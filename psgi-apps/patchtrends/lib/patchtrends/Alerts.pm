package patchtrends::Alerts;

use strict;
use warnings;

use patchtrends::Alerts::Alert ();

use JSON::XS              ();
use URI::Escape           ();
use HTML::Entities        ();
use Data::Structure::Util ();
use Util::H2O        qw/h2o/;

sub new {
    my $pkg  = shift;
    my $self = {};
    bless $self, $pkg;
    return $self;
}

sub create {
    my $self = shift;
    my %opts = @_;

    my $fk_userid = $opts{userid};
    my $dbh       = $opts{dbh};
    my $vars_ref  = $opts{vars};     # fields to update

    my $new_saved_search = patchtrends::Alerts::Alert->new($vars_ref);

    $new_saved_search->fk_userid($fk_userid);
    $new_saved_search->dbh($dbh);

    $new_saved_search->save;         # can throw exception

    return $new_saved_search->as_hashref;
}

# params:
#    read_all( userid => $userid, dbh => $dbh )
sub read_all {
    my $self = shift;
    my %opts = @_;

    my $fk_userid = $opts{userid};
    my $dbh       = $opts{dbh};

    my $sSQL = q{SELECT * FROM tbl_saved_search WHERE fk_userid=?};

    local $@;
    my $ret_ref = eval { $dbh->selectall_arrayref( $sSQL, { Slice => {} }, $fk_userid ) }
      || undef;

    $dbh->disconnect;

    return $ret_ref // [];
}

sub read {
    my $self = shift;
    my %opts = @_;

    my $fk_userid = $opts{userid};
    my $dbh       = $opts{dbh};
    my $alertid   = $opts{alertid};    # search id

    # initialize saved alert
    my $saved_search = patchtrends::Alerts::Alert->new( { id => $alertid, fk_userid => $fk_userid, dbh => $dbh } );

    # load alert
    $saved_search->load;               # can throw exception

    return $saved_search->as_hashref // {};
}

sub update {
    my $self = shift;
    my %opts = @_;

    my $fk_userid = $opts{userid};
    my $dbh       = $opts{dbh};
    my $alertid   = $opts{alertid};    # search id
    my $vars_ref  = $opts{vars};       # fields to update

    my $saved_search = patchtrends::Alerts::Alert->new( { id => $alertid, fk_userid => $fk_userid, dbh => $dbh } );

    $saved_search->load;               # can throw exception
    $saved_search->replace($vars_ref);
    $saved_search->save;

    return $saved_search->as_hashref // {};
}

sub delete {
    my $self = shift;
    my %opts = @_;

    my $fk_userid = $opts{userid};
    my $dbh       = $opts{dbh};
    my $alertid   = $opts{alertid};    # search id

    my $saved_search = patchtrends::Alerts::Alert->new( { id => $alertid, fk_userid => $fk_userid, dbh => $dbh } );

    $saved_search->load;               # can throw exception
    my $alert = $saved_search->as_hashref;
    $saved_search->delete;

    return $alert;
}

1;

__END__
