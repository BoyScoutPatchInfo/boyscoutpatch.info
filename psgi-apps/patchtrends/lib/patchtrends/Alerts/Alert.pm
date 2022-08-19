package patchtrends::Alerts::Alert;

use strict;
use warnings;

use parent q{Site::Object};
use Site::Passwords     ();
use DateTime            ();
use Data::FormValidator ();

use Exception::Class (
    'X::Fatal',
    'X::DBError'          => { isa => 'X::Fatal' },
    'X::RecordNotFound'   => { isa => 'X::Fatal' },
    'X::InvalidParameter' => { isa => 'X::Fatal', fields => [qw/missing invalid/] },
);

# match tbl_saved_search + dbh
__PACKAGE__->attributes( qw/id fk_userid search frequency max_results active last_update search_type sortby minbid maxbid minprice maxprice minrating report_window_days description search_target day hour alt_email dbh/);

# just DB fields
our @fields = qw/id fk_userid search frequency max_results active last_update search_type sortby minbid maxbid minprice maxprice minrating report_window_days description search_target day hour alt_email/;

# used to strip out unwanted fields when converted to a pure hashref (see as_hashref)
our @strip_fields = [qw/dbh fk_userid validator/];

our $_validator = Data::FormValidator->new(
    {
        all_fields => {
            required => [qw/fk_userid/],
            optional => [
                qw/day alt_email frequency max_results active search_type sortby minbid maxbid minprice maxprice minrating report_window_days description search_target day hour/
            ],
            constraint_methods => {
                maxbid   => sub { my $v = int shift->get_current_constraint_value(); ( defined $v && $v >= 0 ) ? 1 : 0 },
                maxprice => sub { my $v = int shift->get_current_constraint_value(); ( defined $v && $v >= 0 ) ? 1 : 0 },
                minbid   => sub { my $v = int shift->get_current_constraint_value(); ( defined $v && $v >= 0 ) ? 1 : 0 },
                minprice => sub { my $v = int shift->get_current_constraint_value(); ( defined $v && $v >= 0 ) ? 1 : 0 },
                hour => sub { my $v = int shift->get_current_constraint_value(); ( defined $v && $v >= 0 && $v <= 23 ) ? 1 : undef },
                report_window_days => qr/^[\d]+$/,                                                     # default value?
                search_type        => qr/^(?:all|any|phrase|boolean|extended|extended2|fullscan)$/,    # boolean, etc; default value?
                search_target => qr/^(?:completed|active|completed_and_active)$/,    # completed_and_active, completed, active; default value?
                frequency     => qr/^(?:daily|weekly)$/,                             # daily, weekly; 'weekly' requires a valid hour; default value?
                sortby => qr/^(?:newest|endingsoonest|highbid|lowbid|highprice|lowprice)$/,    # newest, etc
                day   => qr/^[0-6]$/,    # (optional if frequency is 'weekly') range: 0-6; default value?
                email => qr/\@/,         # check for email address
            }
        },
    }
);

sub new {
    my $pkg        = shift;
    my $params_ref = shift;

    my $self = $pkg->SUPER::new($params_ref);

    return $self;
}

# constructs an unblessed hashref based on what is in @__PACKAGE__::fields,
# strips what is in @__PACKAGE__::strip_fields; used mainly to pass to JSON::XS::encode_json
sub as_hashref {
    my $self    = shift;
    my $ref     = {};
    my %strip   = map { $_ => 1 } @strip_fields;
    my @include = grep { not $strip{$_} } @fields;
    foreach my $f (@include) {
        $ref->{$f} = $self->{$f} if exists $self->{$f};
    }
    return $ref;
}

# loads the database record once the id and fk_userid fields are in place
sub load {
    my $self = shift;

    if ( not $self->dbh() ) {
        throw X::InvalidParameter(q{dbh handle required});
    }

    if ( not defined $self->id() or not defined $self->fk_userid() ) {
        throw X::InvalidParameter(q{'id' and 'fk_userid' required to saved search record from DB});
    }

    my $dbh = $self->dbh();

    my $sSQL = qq{SELECT * FROM tbl_saved_search WHERE id=? AND fk_userid=?};

    my @results = eval { return $dbh->selectall_arrayref( $sSQL, { Slice => {} }, $self->id, $self->fk_userid ) };
    if ( $dbh->errstr ) {
        my $errmsg = ( $dbh->errstr ) ? qq{Error on update: } . $dbh->errstr : q{Unknown error on update};
        throw X::DBError($errmsg);
    }
    elsif ( not $results[0][0] ) {
        my $id = $self->id();
        throw X::RecordNotFound(qq{Can't local member record for id $id});
    }
    my $results_ref = $results[0][0];

    # update $self's fields
    foreach my $field ( grep { !/^id|^fk_userid/ } keys %$results_ref ) {
        $self->$field( $results_ref->{$field} );
    }

    return $self->id();
}

# replace current instances fields with provided hash, doesn't save to DB though
sub replace {
    my $self = shift;
    my $vars = shift;

    # update all unrestricted fields in object
    foreach my $field ( grep { !/^id|^fk_userid|^last_update/ } @fields ) {
        if ( exists $vars->{$field} and defined $vars->{$field} ) {
            $self->$field( $vars->{$field} );
        }
    }

    return 1;
}

# dispatches to _do_create or _do_update, depending on if an id value has been set
sub save {
    my $self = shift;
    if ( not $self->dbh() ) {
        throw X::InvalidParameter(q{dbh handle required});
    }

    if ( defined $self->id() and defined $self->fk_userid() ) {
        return $self->_do_update(@_);
    }
    elsif ( defined $self->fk_userid() ) {
        eval { $self->_do_create(@_); };
        if ( my $e = Exception::Class->caught() ) {
            warn $e->message;
            rethrow $e;
        }
    }
    else {
        throw X::InvalidParameter(q{at least fk_userid required for new saved searches});
    }
}

# validates fields for create and update,
# throws X::InvalidParameter if assertion fails
sub assert_validation {
    my $self    = shift;
    my $profile = shift;    # do_create or do_update

    my $results = $_validator->check( $self->as_hashref, $profile );

    if ( $results->has_invalid or $results->has_missing ) {
        my @missing = $results->missing;
        my @invalid = $results->invalid;
        X::InvalidParameter->throw( error => qq{Error saving/updating saved search.}, missing => \@missing, invalid => \@invalid );
    }

    return;
}

# INSERTs a record in the DB that reflects the current state of the instance object
sub _do_create {
    my $self = shift;

    $self->assert_validation('all_fields');

    if ( not $self->dbh() ) {
        throw X::InvalidParameter(q{dbh handle required});
    }

    if ( not defined $self->fk_userid() ) {
        throw X::InvalidParameter(q{'fk_userid' required to saved search record from DB});
    }
    my $dbh = $self->dbh();

    # update only fields that are returned as hashref, use table defaults optional fields aren't included
    my @_fields = grep { !/last_update/ } keys %{ $self->as_hashref };

    my @bind_values   = ();
    my @place_holders = ();

  BIND:
    foreach my $field (@_fields) {
        push @bind_values,   $self->$field();
        push @place_holders, q{?};
    }

    # the fields we want for this table
    my $iSQL = sprintf( "INSERT INTO tbl_saved_search (%s,last_update) VALUE (%s,now())", join( ',', @_fields ), join( ',', @place_holders ) );

    my $ok = eval { $dbh->do( $iSQL, undef, @bind_values ) }
      and $dbh->commit();
    if ( $dbh->errstr or not $ok ) {
        my $errmsg = ( $dbh->errstr ) ? qq{Error on insert: } . $dbh->errstr : q{Unknown error on insert};
        throw X::DBError($errmsg);
    }

    # get last insert id, in scalar context w/ 1 row and 1 col it returns that 1 value
    my $last_insert = eval { $dbh->selectrow_array(q{SELECT LAST_INSERT_ID()}) };

    $self->id($last_insert);

    return $self->load();
}

# saves the state of the insance to the db record with the matching id
sub _do_update {
    my $self = shift;

    $self->assert_validation('all_fields');

    if ( not $self->dbh() ) {
        throw X::InvalidParameter(q{dbh handle required});
    }

    if ( not defined $self->id() or not defined $self->fk_userid() ) {
        throw X::InvalidParameter(q{'id' and 'fk_userid' required to saved search record from DB});
    }

    my $dbh = $self->dbh();

    # update all fields as they are in the instance
    my @_fields = grep { !/^fk_userid|^last_update/ } keys %{ $self->as_hashref };

    my @bind_values = ();
    my @field_set   = ();

  BIND:
    foreach my $field (@_fields) {
        push @bind_values, $self->$field();
        push @field_set,   qq{$field=?};
    }

    my $uSQL = sprintf( "UPDATE tbl_saved_search SET %s, last_update=now() WHERE id=? AND fk_userid=?", join( ',', @field_set ) );
    my $ok = eval { $dbh->do( $uSQL, undef, @bind_values, $self->id, $self->fk_userid ) }
      and $dbh->commit();
    if ( $@ or not $ok ) {
        my $errmsg = ( $dbh->errstr ) ? qq{Error on update: } . $dbh->errstr : q{Unknown error on update};
        throw X::DB::Error($errmsg);
    }
    return 1;
}

# deletes in the DB the record of the given id
sub delete {
    my $self = shift;

    if ( not $self->dbh() ) {
        throw X::InvalidParameter(q{dbh handle required});
    }

    if ( not defined $self->id() or not defined $self->fk_userid() ) {
        throw X::InvalidParameter(q{'id' and 'fk_userid' required to saved search record from DB});
    }

    my $dbh  = $self->dbh();
    my $dSQL = q{DELETE from tbl_saved_search WHERE id=? AND fk_userid=?};
    my $ok   = eval { $dbh->do( $dSQL, undef, $self->id(), $self->fk_userid() ) }
      and $dbh->commit();
    if ( $@ or not $ok ) {
        my $errmsg = ( $dbh->errstr ) ? qq{Error on insert: } . $dbh->errstr : q{Unknown error on insert};
        throw X::DBError($errmsg);
    }

    return 1;
}

1;

__END__
