package patchtrends::ItemBucket;

use strict;
use warnings;
use parent q{Site::Object};
use patchtrends::eBayItem ();
use Sphinx::Search ();

use Exception::Class (
    'X::Fatal',
    'X::DBError'          => { isa => 'X::Fatal' },
    'X::InvalidParameter' => { isa => 'X::Fatal', fields => [qw/missing invalid/] },
    'X::RecordNotFound'   => { isa => 'X::Fatal' },
    'X::Unauthorized'     => { isa => 'X::Fatal' },
);

# mirrors table tbl_item_buckets + attributes related to tbl_item_bucket_to_ebay_item_rel
our @DB            = (qw/bucket_id fk_owner_id name description primary_item_id url_key patchvault_uuid visibility created updated archived/);
our @RELATED_ITEMS = (qw/items/);

# used to strip out unwanted fields when converted to a pure hashref (see as_hashref)
our @strip_fields = [qw/dbh fk_userid validator/];

__PACKAGE__->attributes( @DB, @RELATED_ITEMS );

sub new {
    my $pkg        = shift;
    my $params_ref = shift;

    my $self = $pkg->SUPER::new($params_ref);

    return $self;
}

sub create {
    my $self = shift;
    my %params = @_;

    my $dbh         = $params{dbh};
    my $fk_owner_id = $params{ownerid};
    my $name        = $params{name};
    my $description = $params{description};

    my $iSQL = q{INSERT INTO tbl_item_buckets (fk_owner_id, name, description, visibility, url_key, created, updated ) VALUES ( ?, ?, ?, 'private', LEFT(MD5(RAND()),16), now(), now() )}; 

    $dbh->do($iSQL, undef, $fk_owner_id, $name, $description )
      and $dbh->commit();

    my $insert_info = $dbh->selectrow_hashref(q{SELECT LAST_INSERT_ID() AS id});

   return $self->read( dbh => $dbh, ownerid => $fk_owner_id, id => $insert_info->{id} );
}


sub read_all {
    my $self       = shift;
    my %params     = @_;
    my $dbh = $params{dbh};

    # get all items owned by ownerid, except items that have been archived
    my $sSQL = q{SELECT
                   bucket_id as id, name, description, url_key, patchvault_uuid, visibility
                 FROM
                   tbl_item_buckets
                 WHERE fk_owner_id = ? AND visibility != 'archived'};

    my $buckets = $dbh->selectall_arrayref( $sSQL, { Slice => {} }, $params{ownerid} );

    return $buckets // [];
}

sub read {
    my $self       = shift;
    my %params     = @_;

    my $dbh = $params{dbh};
    my $fk_owner_id = $params{ownerid};
    my $bucket_id   = $params{id};

    # get all items owned by ownerid, except items that have been archived
    my $sSQL = q{SELECT
                   bucket_id as id, name, description, url_key, patchvault_uuid, visibility
                 FROM
                   tbl_item_buckets
                 WHERE fk_owner_id = ? AND visibility != 'archived' AND bucket_id=?};

    my $bucket = $dbh->selectrow_hashref( $sSQL, undef, $fk_owner_id, $bucket_id );

    return $bucket;
}

sub update {
    my $self = shift;
    my %params = @_;

    my $dbh             = $params{dbh};
    my $fk_owner_id     = $params{ownerid};
    my $bucket_id       = $params{id};
    my $name            = $params{name};
    my $description     = $params{description};
    my $visibility      = $params{visibility};
    my $patchvault_uuid = $params{patchvault_uuid};

    my $uSQL = q{UPDATE
                   tbl_item_buckets
                 SET
                   name = ?, description = ?, visibility = ?, patchvault_uuid =?
                 WHERE fk_owner_id = ? AND bucket_id = ? LIMIT 1};

    $dbh->do( $uSQL, undef, $name, $description, $visibility, $patchvault_uuid, $fk_owner_id, $bucket_id )
      and $dbh->commit();

    return $self->read( dbh => $dbh, ownerid => $fk_owner_id, id => $bucket_id );
}

sub delete {
    my $self       = shift;
    my %params     = @_;

    my $dbh = $params{dbh};
    my $fk_owner_id = $params{ownerid};
    my $bucket_id   = $params{id};

    # get to return upon delete
    my $bucket = $self->read( dbh => $dbh, ownerid => $fk_owner_id, id => $bucket_id );

    # get all items owned by ownerid, except items that have been archived
    #my $dSQL = q{DELETE
    #             FROM
    #               tbl_item_buckets
    #             WHERE fk_owner_id = ? AND bucket_id=? LIMIT 1};
    #
    my $dSQL  = q{UPDATE
                    tbl_item_buckets
                 SET
                   visibility='archived', archived=now()
                 WHERE fk_owner_id = ? AND bucket_id=? LIMIT 1};
                      

    $dbh->do( $dSQL, undef, $fk_owner_id, $bucket_id )
      and $dbh->commit();

   return $bucket;
}

# operations to add/delete/edit items associated with lists 

sub _assert_bucket_owner {
  my $self = shift;
  my ($dbh, $fk_owner_id, $bucket_id) = @_;
  # check that fk_owner_id owns bucket_id
  my $sSQL = q{SELECT fk_owner_id FROM tbl_item_buckets WHERE fk_owner_id=? AND bucket_id=?};
  my $owner_checks_out = $dbh->selectrow_arrayref($sSQL, undef, $fk_owner_id, $bucket_id);
  if (not $owner_checks_out) {
    X::Unauthorized->throw;
  }
  return 1;
}

sub add_items {
  my $self = shift;
  my %params = @_;

  my $dbh = $params{dbh};
  my $fk_owner_id = $params{ownerid};
  my $bucket_id   = $params{bucket_id}; # should validate this <<<<<<<

  $self->_assert_bucket_owner($dbh, $fk_owner_id, $bucket_id);

  return undef if ref $params{items} ne q{ARRAY} or not @{$params{items}}; # for now, may end up returning a status indicating bad input

  my $iSQL = q{INSERT INTO tbl_item_bucket_to_ebay_item_rel (fk_item_bucket_id, fk_ebay_item_id) VALUES};
  my @_iSQL = ();
  for my $i (1 .. scalar @{$params{items}}) {
    push @_iSQL, qq{($bucket_id,?)}; 
  }
  $iSQL = sprintf("%s %s ON DUPLICATE KEY UPDATE fk_item_bucket_id=fk_item_bucket_id", $iSQL, join(q{, }, @_iSQL));
  $dbh->do( $iSQL, undef, @{$params{items}} )
    and $dbh->commit(); 

  # return number added
  return scalar @{$params{items}};
}

sub delete_items {
  my $self = shift;
  my %params = @_;

  my $dbh         = $params{dbh};
  my $config      = $params{config};
  my $fk_owner_id = $params{ownerid};
  my $bucket_id   = $params{bucket_id};

  $self->_assert_bucket_owner($dbh, $fk_owner_id, $bucket_id);

  return undef if ref $params{items} ne q{ARRAY} or not @{$params{items}}; # for now, may end up returning a status indicating bad input

  my $place_holders = join(q{,}, q{?} x @{$params{items}}); # creates "?,?,.....,?" based on number of items being deleted
  my $dSQL  = qq{DELETE FROM tbl_item_bucket_to_ebay_item_rel WHERE fk_item_bucket_id=? AND fk_ebay_item_id IN ($place_holders)};

  $dbh->do($dSQL, undef, $bucket_id, @{$params{items}})
    and $dbh->commit();

  return { items => $params{items} };
}

#$bucket->read_items( dbh => $dbh, ownerid => $member_info->id, bucket_id => $bucket_id );
sub read_items {
  my $self = shift;
  my %params = @_;

  my $dbh         = $params{dbh};
  my $config      = $params{config};
  my $fk_owner_id = $params{ownerid};
  my $bucket_id   = $params{bucket_id};

  # 1. get list from DB
  my $sSQL  = q{SELECT fk_ebay_item_id FROM tbl_item_bucket_to_ebay_item_rel WHERE fk_item_bucket_id=?};
  my $itemids = $dbh->selectcol_arrayref($sSQL, undef, $bucket_id); 

  # if no results, don't bother to hit sphinx
  return [] if not @$itemids;

  # 2. get item details from Sphinx, using list of itemids
  my $sph = Sphinx::Search->new();
  $sph->SetServer( $config->{sphinx}->{completed}->{host}, $config->{sphinx}->{completed}->{port} );
  $sph->SetLimits( 0, scalar @$itemids );
  $sph->SetFilter( 'itemid', $itemids );

  # send minimum information, use it for simple view and to generate a link to item details page
  $sph->SetSelect( q{title, itemsold, starttime, endtime, currentprice, bidcount, listingtype, seller} );
  my $results = $sph->Query( q{}, $config->{sphinx}->{completed}->{indexes} );

  return $results->{matches} // [];
}

# throws an exception if there is no dbh provided
sub _assert_dbh {
    my $self = shift;
    if ( not $self->dbh() ) {
        X::InvalidParameter->throw(q{dbh handle required});
    }
    return;
}

1;

__END__
