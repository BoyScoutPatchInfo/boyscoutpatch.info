package Patchtrends::Member;

use strict;
use warnings;

use parent q{Site::Object};
use Site::Passwords ();
use DateTime        ();

use Exception::Class (
    'X::Fatal',
    'X::DBError'              => {isa => 'X::Fatal'},
    'X::RecordNotFound'       => {isa => 'X::Fatal'},
    'X::PasswordNotSet'       => {isa => 'X::Fatal'},
    'X::InvalidAccessor'      => {isa => 'X::Fatal'},
    'X::InvalidParameter'     => {isa => 'X::Fatal'},
    'X::FailedAuthentication' => {isa => 'X::Fatal'},
);

# match tbl_users
__PACKAGE__->attributes(qw/id username phone email status create_date last_updated expires subscr_id payer_id type interval dbh/);

sub new {
    my $pkg        = shift;
    my $params_ref = shift;

    # do not want 'password' to be set outside of explicit accessors
    if (exists $params_ref->{password}) {
        throw X::InvalidParameter(q{'password' must be set outside of constructor});
    }

    my $self = $pkg->SUPER::new($params_ref);
    return $self;
}

sub authenticate {
    my $self          = shift;
    my $pass          = shift;
    my $passhash      = shift;
    my $authenticated = 0;
    if (Site::Passwords::match($pass, $passhash)) {
        $authenticated = 1;
    }
    else {
        throw X::FailedAuthentication(q{Password doesn't match});
    }
    return $authenticated;
}

# throw some X:: when validation fails (username, email, etc)
sub validate_params {
    return;
}

# if $self->id() or $self->subscr_id(), load from DB,
sub load {
    my $self = shift;
    if (not $self->dbh()) {
        throw X::InvalidParameter(q{dbh handle required});
    }
    if (not $self->id() and not $self->subscr_id() and not $self->username()) {
        throw X::InvalidParameter(q{id, subscr_id, username required to load record from DB});
    }
    my $dbh = $self->dbh();
    my $bv = q{};
    my $WHERE = q{WHERE };
    if ($bv = $self->id()) {
        $WHERE .= q{id=?};
    }
    elsif($bv = $self->username()) {
        $WHERE .= q{username=?};
    }
    elsif ($bv = $self->subscr_id()) {
        $WHERE .= q{subscr_id=?};
    }
    my $sSQL = qq{SELECT id,username,password,phone,email,status,create_date,last_updated,expires,subscr_id,payer_id,type FROM tbl_users $WHERE};
    my $results = eval { $dbh->selectall_arrayref($sSQL, {Slice => {}}, $bv) }
        and $dbh->commit();
    $results = pop @$results;
    if ($@) {
        throw X::DBError($@);
    }
    elsif (not $results) {
        my $id = $self->id();
        throw X::RecordNotFound(q{Can't local member record for id $id});
    }
    # set password directly
    $self->{password} = $results->{password};
    delete $results->{password};
    foreach my $field (keys %$results) {
        $self->$field($results->{$field});
    }
    return 1;
}

# only return password
sub password {
    my $self = shift;
    if (@_) {
        throw X::InvalidParameter(q{query only method, doesn't take paremeters});
    }
    return $self->{password} // throw X::InvalidAccessor(q{password not set, use 'set_password' first});
}

# returns the uncrypted password, required if one wishes to know the autogenerated password
sub set_password {
    my $self     = shift;
    my $new_pass = shift;
    if (not $new_pass) {
        # generate random password, return plain text for benefit of caller
        $new_pass = Site::Passwords::generate_password();
    }
    $self->{password} = Site::Passwords::cryptpass($new_pass);
    return $new_pass;
}

sub save {
    my $self = shift;
    if (not $self->dbh()) {
        throw X::InvalidParameter(q{dbh handle required});
    }
    if (not $self->password()) {
        throw X::PasswordNotSet(q{password not set, use 'set_password' method});
    }
    if ($self->id()) {
        return $self->_do_update(@_);
    }
    else {
        return $self->_do_create(@_);
    }
}

sub _do_update {
    my $self        = shift;
    my $dbh         = $self->dbh();
    my @bind_values = (
        $self->username(),  $self->phone(),       $self->email(),        $self->password(),
        $self->status(),    $self->create_date(), $self->last_updated(), $self->expires(),
        $self->subscr_id(), $self->payer_id(),    $self->type(),         $self->id()
    );
    my $uSQL =
        q{UPDATE tbl_users SET username=?,phone=?,email=?,password=?,status=?,create_date=?,last_updated=?,expires=?,subscr_id=?,payer_id=?,type=?,last_updated=now() WHERE id=?};
    my $ok = eval {$dbh->do($uSQL, undef, @bind_values)}
        and $dbh->commit();
    if ($@ or not $ok) {
        my $errmsg = ($@) ? qq{Error on update: $@} : q{Unknown error on update};
        throw X::DB::Error($errmsg);
    }
    return 1;
}

sub _ensure_username {
    my $self = shift;
    my $username = shift;
    my $dbh = $self->dbh();

    if (not $username) {
        # yes, this produces something close to a, too
        $username = Site::Passwords::generate_password();
        return $username;
    }
    # replace all non-word characters with underscore
    $username =~ s/[^\w]/_/xg;
    my $sSQL = q{SELECT id FROM tbl_users WHERE username=?};
    my $orig_username = $username;

    USERNAME:
    while (1) {
        my $ref = $dbh->selectall_arrayref($sSQL, undef, $username);
        last if (not @$ref);
        my $num = int rand (99);
        $username = $orig_username . $num;
    };
    # make sure that this username is unique
    return $username;
}

sub _do_create {
    my $self       = shift;
    my $params_ref = shift;
    my $interval   = $self->interval();
    if (not $interval or ($interval ne q{month} and $interval ne q{year})) {
        throw X::InvalidParameter(q{interval required - 'month' or 'year'});
    }
    my $INTERVAL = ($interval eq q{year}) ? q{INTERVAL 1 YEAR} : q{INTERVAL 1 MONTH};
    if (not $self->password()) {
        $self->password(Site::Passwords::cryptpass(Site::Passwords::generate_password()));
    }

    # ensure username is valid and unique
    $self->username($self->_ensure_username($self->username()));

    my $dbh = $self->dbh();
    my @bind_values =
        ($self->username(), $self->email(), $self->password(), $self->phone(), $self->subscr_id(), $self->type(),
        $self->status());
    my $iSQL = qq{INSERT INTO tbl_users (username,email,password,phone,subscr_id,type,status,create_date,last_updated,expires) VALUES (?,?,?,?,?,?,'active',now(),now(),DATE_ADD(now(),$INTERVAL))};
    my $ok = eval {$dbh->do($iSQL, undef, @bind_values)}
        and $dbh->commit();
    if ($DBI::errstr or not $ok) {
        my $errmsg = ($DBI::errstr) ? qq{Error on insert: $DBI::errstr} : q{Unknown error on insert};
        throw X::DBError($errmsg);
    }

    # get insert id, call 'load' to sync with what's now in the DB
    my $last_insert = eval {$dbh->selectcol_arrayref(q{SELECT LAST_INSERT_ID()}, {Columns => [1]})}
        and $dbh->commit();
    $last_insert = pop @$last_insert;
    # set $self->id()
    $self->id($last_insert);

    # put into consistent state using load()
    return $self->load();
}

# delete, mainly for test writing activities
sub delete {
    my $self = shift;
    if (not $self->id() or not $self->dbh()) {
        throw X::InvalidParameter(q{id and dbh handle required});
    }
    my $dbh  = $self->dbh();
    my $dSQL = q{DELETE from tbl_users WHERE id = ?};
    my $ok   = eval {$dbh->do($dSQL, undef, $self->id())} and $dbh->commit();
    if ($@ or not $ok) {
        my $errmsg = ($@) ? qq{Error on delete: $@} : q{Unknown error on delete};
        throw X::DBError($errmsg);
    }

    # unset $self->id() directly
    $self->id('0');

    return 1;
}

# higher level methods

sub update_expiration {
    my $self = shift;
    my $term = shift;

    # throw X
    if (not $term or not ($term eq q{year} or $term eq q{month})) {
        throw X::InvalidParameter(q{$term must be defined and be 'year' or 'month'});
    }

    my $month = 0;
    my $year  = 0;
    if ($term eq q{month}) {
        $month = 1;
    }
    elsif ($term eq q{year}) {
        $year = 1;
    }
    my ($sec,$min,$hour,$mday,$mon,$yr,$wday,$yday,$isdst) = localtime(); #now
    my $dt = DateTime->new(
        year      => $yr+1900,
        month     => $mon+1,
        day       => $mday,
        hour      => $hour,
        minute    => $min,
        second    => $sec,
        time_zone => 'America/Chicago',
    );
    # add year or month + 2 days for padding
    $dt->add( days => 2, months => $month, years => $year);
    my $dt_string = $dt->ymd(q{-}) . q{ } . $dt->hms(q{:}) ;
    $self->expires($dt_string);
    return $self->save();
}

sub deactivate {
    my $self = shift;
    if (not $self->id() or not $self->dbh()) {
        throw X::InvalidParameter(q{id and dbh handle required});
    }
    $self->status('inactive');
    return $self->save();
}

1;
