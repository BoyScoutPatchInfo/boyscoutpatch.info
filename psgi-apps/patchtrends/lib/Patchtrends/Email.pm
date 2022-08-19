package Patchtrends::Email;

use strict;
use warnings;

use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP::TLS ();
use Email::Simple                       ();
use Email::Simple::Creator              ();
use Email::MIME::CreateHTML;

sub send_report {

    my ( $config, $email, $html, $body, $subject ) = @_;

    my $transport = Email::Sender::Transport::SMTP::TLS->new(
        port     => $config->{notify}->{sender_port},
        host     => $config->{notify}->{sender_host},
        username => $config->{notify}->{sender_username},
        password => $config->{notify}->{sender_password},
    );

    my $message = Email::MIME->create_html(
        header => [
            To      => $email,
            From    => q{patchtrends@gmail.com},
            Subject => $subject,
        ],
        body      => $html,
        text_body => $body,
    );

    sendmail( $message, { transport => $transport } );
    return;
}


1;
