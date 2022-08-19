package Site::Passwords;

use strict;
use warnings;
use Carp;

use Crypt::Passwd::XS;
use Digest::MD5 'md5_hex';
use Crypt::GeneratePassword qw(word);

sub generate_password {
    my $number = int rand(99);
    my $password = word(8,8) . $number;
    return $password; 
}

sub cryptpass {
    my ($pass) = @_;
    return Crypt::Passwd::XS::unix_md5_crypt( $pass, salt() );
}

sub match {
    my ( $pass, $cryptpass ) = @_;
    return 0 if !defined $cryptpass;
    # unix_md5_crypt extracts the salt from an encrypted pass
    return Crypt::Passwd::XS::unix_md5_crypt( $pass, $cryptpass ) eq $cryptpass;
}

sub salt {
    my $b64set =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789./";
    return join "", map substr( $b64set, devrand( length($b64set) ), 1 ),
      0 .. 8;
}

sub devrand {
    my ($n) = @_;
    $n ||= 1;
    open my $fh, "<", "/dev/urandom" or croak "unable to open /dev/urandom: $!";
    sysread $fh, my $buf, 4;
    close $fh;
    my $i = unpack( "N", $buf );
    return $i / 2**32 * $n;
}

1;
