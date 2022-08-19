package patchtrends::API::v1::ItemBucket;

use strict;
use warnings;
use patchtrends::ItemBucket;
use Exception::Class ( 'X::BadRequest' );

# creates a new bucket
sub create {
    my ( $dbh, $config, $member_info, $body_params, $query_params, $route_params ) = @_;
    my $name        = $body_params->{name};
    my $description = $body_params->{description};
    my $bucket = patchtrends::ItemBucket->create( dbh => $dbh, ownerid => $member_info->id, name => $name, description => $description );
    return $bucket;
}

# get all, no pagination
sub read_all {
    my ( $dbh, $config, $member_info, $body_params, $query_params, $route_params ) = @_;
    my $buckets = patchtrends::ItemBucket->read_all( dbh => $dbh, ownerid => $member_info->id );
    return $buckets // [];
}

# get bucket with id
sub read {
    my ( $dbh, $config, $member_info, $body_params, $query_params, $route_params ) = @_;
    my $bucket_id = int $route_params->{id} // 0;
    return {} if $bucket_id < 1;
    my $bucket = patchtrends::ItemBucket->read( dbh => $dbh, ownerid => $member_info->id, id => $bucket_id );
    return $bucket;
}

sub update {
    my ( $dbh, $config, $member_info, $body_params, $query_params, $route_params ) = @_;
    my $bucket_id = int $route_params->{id} // -1;
    my $bucket = patchtrends::ItemBucket->update( dbh => $dbh, ownerid => $member_info->id, id => $bucket_id, name => $body_params->{name}, description => $body_params->{description}, visibility => $body_params->{visibility}, patchvault_uuid => $body_params->{patchvault_uuid} );
    return $bucket;
}

sub delete {
    my ( $dbh, $config, $member_info, $body_params, $query_params, $route_params ) = @_;
    my $bucket_id = int $route_params->{id} // -1;
    my $bucket = patchtrends::ItemBucket->delete( dbh => $dbh, ownerid => $member_info->id, id => $bucket_id );
    return $bucket;
}

sub add_items {
    my ( $dbh, $config, $member_info, $body_params, $query_params, $route_params ) = @_;
    my $bucket   = patchtrends::ItemBucket->new;
    my $bucket_id = int $route_params->{id} // -1;

    my $num_added = $bucket->add_items( dbh => $dbh, ownerid => $member_info->id, bucket_id => $bucket_id, items => $body_params->{items} );

    # throw error so caller can do something with it via the server response 
    if (not defined $num_added) {
      # generally means the call was made outside of normal conditions and the
      # userid doesn't have permission to view the list
      X::BadRequest->throw(q{Bad request.});
    }

    # returns number of items
    return { ok => $num_added };
}

sub read_items {
    my ( $dbh, $config, $member_info, $body_params, $query_params, $route_params ) = @_;
    my $bucket   = patchtrends::ItemBucket->new;
    my $bucket_id = int $route_params->{id} // -1;
    my $items = $bucket->read_items( dbh => $dbh, config => $config, ownerid => $member_info->id, bucket_id => $bucket_id );

    # returns all items in list
    return $items; 
}

sub update_items {
    # this call is not currently supported
    X::BadRequest->throw(q{Bad request.});
}

sub delete_items {
    my ( $dbh, $config, $member_info, $body_params, $query_params, $route_params ) = @_;
    my $bucket   = patchtrends::ItemBucket->new;
    my $bucket_id = int $route_params->{id} // -1;
    my $items = $bucket->delete_items( dbh => $dbh, config => $config, ownerid => $member_info->id, bucket_id => $bucket_id, items => $body_params->{items} );
    # returns items that were deleted via the original request
    return $items; 
}

1;
