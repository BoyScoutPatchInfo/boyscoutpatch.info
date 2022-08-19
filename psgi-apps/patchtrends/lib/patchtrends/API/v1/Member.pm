package patchtrends::API::v1::Member;

use strict;
use warnings;
use patchtrends::Member ();
use patchtrends::Email  ();
use Crypt::Passwd::XS ();

use Exception::Class (
    'X::Fatal',
    'X::InvalidParameter'     => {isa => 'X::Fatal'},
    'X::FailedAuthentication' => {isa => 'X::Fatal'},
);

sub update {
    my ($dbh, $config, $member_info, $body_params, $query_params, $route_params) = @_;

    my $current_password    = $body_params->{currentPassword};
    my $new_password        = $body_params->{newPassword1};
    my $new_password_repeat = $body_params->{newPassword2};

    my @length;
    my $length = @length = $new_password =~ /./g;

    throw X::InvalidParameter(q{passwords must be 7 or more characters in length}) if 6 > $length;
    throw X::InvalidParameter(q{passwords don't match}) if $new_password ne $new_password_repeat;
    throw X::FailedAuthentication(q{current password incorrect}) if !$member_info->verify_current_password( $dbh, $current_password );

    $member_info->load($dbh);
    $member_info->set_password($new_password);
    $member_info->save($dbh);

    return { ok => 1 };
};

sub reset_password {
    my ( $dbh, $config, $member_info, $body_params, $query_params, $route_params ) = @_;
    my $pp_subscr_id = $body_params->{subscriberId} // undef;
    my $_email       = $body_params->{email} // undef;
    my $_username    = $body_params->{username} // undef;

    throw X::InvalidParameter(q{bad parameters}) if not $pp_subscr_id and not $_email and not $_username;

    # 1. SQL - match on PayPal Id
    my $sSQL = q{SELECT id, username, email FROM tbl_users WHERE (subscr_id=? OR email=? OR username =?) AND status = 'active' AND now() < expires};

    # 2. there will be 0 or 1 results only because subscr_id is unique
    my $results = $dbh->selectall_arrayref( $sSQL, { Slice => {} }, $pp_subscr_id, $_email, $_username );

    # 3. modularize functionality of reset password script - resets all accounts returned from above query
    foreach my $account (@$results) {
        my $id = $account->{id};
        my $member = patchtrends::Member->new( { id => $id } );
        $member->load($dbh);
        if ( my $password = $member->set_password() ) {
            $member->save($dbh);

            # send email, one per reset
            my $username = $member->username();
            my $email    = $member->email();
            my $body     = qq{
Your password has been reset!

Below are your TEMPORARY login credentials:

username: $username 
password: $password 

Please change your password ASAP. If this does not solve your issue or if
you have additional questions, please let me know.

My goal is your satisfaction with this service, so please don't hesitate to 
contact me directly with questions, issues, or feedback. You may email me 
directly by replying to this email.

    https://boyscoutpatch.info

Thank you!
};

            patchtrends::Email::send_report( $config->{notify}->{sender_username}, $config->{notify}->{sender_password}, $email, qq{<font size=3><pre>$body</pre></font>}, $body, q{BoyScoutPatch.info Password Reset} );
        }
        return { ok => 2 };
    }

    return { ok => 1 };
}

1;

__END__
