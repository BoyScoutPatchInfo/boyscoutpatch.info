package patchtrends::Email;

use strict;
use warnings;

use Email::Sender::Simple qw(sendmail);
use Email::Sender::Transport::SMTP::TLS ();
use Email::Simple                       ();
use Email::Simple::Creator              ();
use Email::MIME::CreateHTML;

sub send_report {

    my ( $sender_username, $sender_password, $email, $html, $body, $subject ) = @_;

    my $transport = Email::Sender::Transport::SMTP::TLS->new(
        host     => q{smtp.gmail.com},
        port     => 587,
        username => $sender_username,
        password => $sender_password,
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
