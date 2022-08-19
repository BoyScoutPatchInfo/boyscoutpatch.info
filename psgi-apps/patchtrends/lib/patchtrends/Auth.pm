package patchtrends::Auth;

use strict;
use warnings;

use Crypt::Passwd::XS ();

sub new {
  my $pkg = shift;
  my %opt = @_;
  my $self = {
    dbh => $opt{dbh},
  };
  bless $self, $pkg;
  return $self;
}

sub _match {
    my $self = shift;
    my ($pass, $cryptpass) = @_;
    return 0 if !defined $cryptpass;
    # unix_md5_crypt extracts the salt from an encrypted pass
    return Crypt::Passwd::XS::unix_md5_crypt($pass, $cryptpass) eq $cryptpass;
}

# returns userid only if valid user is found
# returns undef otherwise
sub get_userid {
  my $self = shift;
  my ($username, $password) = @_;
  my $dbh = $self->{dbh};
  
  my $sSQL = q{SELECT id, password, email FROM tbl_users WHERE username = ? AND status = 'active' AND now() <= expires};
  my $results = eval {$dbh->selectall_arrayref($sSQL, {Slice => {}}, $username)};

  my $passhash = $results->[0]->{password} // undef;
  my $userid   = $results->[0]->{id} // undef;

  my $authenticated;
  if ($self->_match($password, $passhash)) {
    $authenticated = $userid;
  }

  return $authenticated;
}

1;
