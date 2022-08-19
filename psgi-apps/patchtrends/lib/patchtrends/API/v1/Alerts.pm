package patchtrends::API::v1::Alerts;

use strict;
use warnings;
use patchtrends::Alerts ();

sub create {
    my ($dbh, $config, $member_info, $body_params, $query_params, $route_params) = @_;
    my $alerts      = patchtrends::Alerts->new;
    my $alert = $alerts->create( userid => $member_info->id, vars => $body_params, dbh => $dbh );
    return $alert;
};

sub read_all {
    my ($dbh, $config, $member_info, $body_params, $query_params, $route_params) = @_;
    my $alert      = patchtrends::Alerts->new;
    my $alerts     = $alert->read_all( userid => $member_info->id, dbh => $dbh );
    return $alerts;
};

sub read {
    my ($dbh, $config, $member_info, $body_params, $query_params, $route_params) = @_;
    my $alerts      = patchtrends::Alerts->new;
    my $alertid     = int $route_params->{id} // -1;
    my $alert = $alerts->read( userid => $member_info->id, alertid => $alertid, dbh => $dbh );
    return $alert;
};

sub update {
    my ($dbh, $config, $member_info, $body_params, $query_params, $route_params) = @_;
    my $alerts      = patchtrends::Alerts->new;
    my $alertid     = int $route_params->{id} // -1;
    my $alert       = $alerts->update( userid => $member_info->id, alertid => $alertid, vars => $body_params,$query_params,$route_params, dbh => $dbh );
    return $alert;
};

sub delete {
    my ($dbh, $config, $member_info, $body_params, $query_params, $route_params) = @_;
    my $alerts      = patchtrends::Alerts->new;
    my $alertid     = int $route_params->{id} // -1;
    my $alert       = $alerts->delete( userid => $member_info->id, alertid => $alertid, dbh => $dbh );
    return $alert;
};

1;

__END__
