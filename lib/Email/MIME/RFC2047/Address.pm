package Email::MIME::RFC2047::Address;
our $VERSION = '0.90';

use strict;
use base qw(Email::MIME::RFC2047::Parser);

use Email::MIME::RFC2047::Decoder;
use Email::MIME::RFC2047::Group;
use Email::MIME::RFC2047::Mailbox;
use Email::MIME::RFC2047::MailboxList;

my $domain_part_re = qr/[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?/;
my $addr_spec_re = qr/[\w+.-]+\@$domain_part_re(?:\.$domain_part_re)+/;

sub parse {
    my ($class, $string, $decoder) = @_;
    my $string_ref = ref($string) ? $string : \$string;

    my $address;

    if($$string_ref =~ /\G\s*($addr_spec_re)\s*/cg) {
        $address = Email::MIME::RFC2047::Mailbox->new($1);
    }
    else {
        $decoder ||= Email::MIME::RFC2047::Decoder->new();
        my $name = $decoder->decode_phrase($string_ref);

        if($$string_ref =~ /\G<\s*($addr_spec_re)\s*>\s*/cg) {
            my $addr_spec = $1;

            $address = Email::MIME::RFC2047::Mailbox->new(
                address => $addr_spec,
            );

            $address->name($name) if $name ne '';
        }
        elsif($$string_ref =~ /\G:/cg) {
            return $class->_parse_error($string_ref, 'group name')
                if $name eq '';

            my $mailbox_list;

            if($$string_ref =~ /\G\s*;\s*/cg) {
                $mailbox_list = Email::MIME::RFC2047::MailboxList->new();
            }
            else {
                $mailbox_list = Email::MIME::RFC2047::MailboxList->parse(
                    $string_ref, $decoder
                );

                $$string_ref =~ /\G;\s*/cg
                    or return $class->_parse_error($string_ref, 'group');
            }

            $address = Email::MIME::RFC2047::Group->new(
                name         => $name,
                mailbox_list => $mailbox_list,
            );
        }
        else {
            return $class->_parse_error($string_ref, 'address');
        }
    }

    if(!ref($string) && pos($string) < length($string)) {
        return $class->_parse_error($string_ref);
    }

    return $address;
}

1;

__END__

=head1 NAME

Email::MIME::RFC2047::Address - Handling of MIME encoded addresses

=head1 SYNOPSIS

 use Email::MIME::RFC2047::Address;

 my $address = Email::MIME::RFC2047::Address->parse($string);

 if($address->isa('Email::MIME::RFC2047::Mailbox')) {
    print $address->name(), "\n";
    print $address->address(), "\n";
 }

=head1 DESCRIPTION

This is the superclass for L<Email::MIME::RFC2047::Mailbox> and
L<Email::MIME::RFC2047::Group>.

=head1 CLASS METHODS

=head2 parse

 my $address = Email::MIME::RFC2047::Address->parse($string, [$decoder])

Parses a RFC 2822 'address'. Returns either a L<Email::MIME::RFC2047::Mailbox>
or a L<Email::MIME::RFC2047::Group> object.

=head1 AUTHOR

Nick Wellnhofer <wellnhofer@aevum.de>

=head1 COPYRIGHT AND LICENSE

Copyright (C) Nick Wellnhofer, 2009

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.

=cut

