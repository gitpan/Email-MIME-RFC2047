package Email::MIME::RFC2047::Encoder;
BEGIN {
  $Email::MIME::RFC2047::Encoder::VERSION = '0.91';
}

use strict;

use Encode ();
use MIME::Base64 ();

my $rfc_specials = '()<>\[\]:;\@\\,."';

sub new {
    my $package = shift;
    my $options = ref($_[0]) ? $_[0] : { @_ };

    my ($encoding, $method) = ($options->{encoding}, $options->{method});

    if(!defined($encoding)) {
        $encoding = 'utf-8';
        $method = 'Q' if !defined($method);
    }
    else {
        $method = 'B' if !defined($method);
    }

    my $encoder = Encode::find_encoding($encoding)
        or die("encoding '$encoding' not found");

    my $self = {
        encoding => $encoding,
        encoder  => $encoder,
        method   => uc($method),
    };

    return bless($self, $package);
}

sub encode_text {
    my ($self, $string) = @_;

    return $self->_encode('text', $string);
}

sub encode_phrase {
    my ($self, $string) = @_;

    return $self->_encode('phrase', $string);
}

sub _encode {
    my ($self, $mode, $string) = @_;

    my $encoder = $self->{encoder};
    my $result = '';

    # $string is split on whitespace. Each $word is categorized into
    # 'mime', 'quoted' or 'text'. The intermediate result of the conversion of
    # consecutive words of the same types is accumulated in $buffer.
    # The type of the buffer is tracked in $buffer_type.
    # The method _finish_buffer is called to finish the encoding of the
    # buffered content and append to the result.
    my $buffer = '';
    my $buffer_type;

    for my $word (split(/\s+/, $string)) {
        next if $word eq ''; # ignore leading white space

        $word =~ s/[\x00-\x1f\x7f]//g; # better remove control chars

        my $word_type;

        if($word =~ /[\x80-\x{ffff}]|(^=\?.*\?=\z)/s) {
            # also encode any word that starts with '=?' and ends with '?='
            $word_type = 'mime';
        }
        elsif($mode eq 'phrase') {
            $word_type = 'quoted';
        }
        else {
            $word_type = 'text';
        }
        
        $self->_finish_buffer(\$result, $buffer_type, \$buffer)
            if $buffer ne '' && $buffer_type ne $word_type;
        $buffer_type = $word_type;

        if($word_type eq 'text') {
            $result .= ' ' if $result ne '';
            $result .= $word;
        }
        elsif($word_type eq 'quoted') {
            $buffer .= ' ' if $buffer ne '';
            $buffer .= $word;
        }
        else {
            my $max_len = 75 - 7 - length($self->{encoding});
            $max_len = 3 * ($max_len >> 2) if $self->{method} eq 'B';

            my @chars;
            push(@chars, ' ') if $buffer ne '';
            push(@chars, split(//, $word));

            for my $char (@chars) {
                my $chunk;
                
                if($self->{method} eq 'B') {
                    $chunk = $encoder->encode($char);
                }
                elsif($char =~ /[()<>@,;:\\".\[\]=?_]/) {
                    # special character
                    $chunk = sprintf('=%02x', ord($char));
                }
                elsif($char =~ /[\x80-\x{ffff}]/) {
                    # non-ASCII character

                    my $enc_char = $encoder->encode($char);
                    $chunk = '';
                    
                    for my $byte (unpack('C*', $enc_char)) {
                        $chunk .= sprintf('=%02x', $byte);
                    }
                }
                elsif($char eq ' ') {
                    $chunk = '_';
                }
                else {
                    $chunk = $char;
                }

                if(length($buffer) + length($chunk) <= $max_len) {
                    $buffer .= $chunk;
                }
                else {
                    $self->_finish_buffer(\$result, 'mime', \$buffer);
                    $buffer = $chunk;
                }
            }
        }
    }

    $self->_finish_buffer(\$result, $buffer_type, \$buffer)
        if $buffer ne '';

    return $result;
}

sub _finish_buffer {
    my ($self, $result, $buffer_type, $buffer) = @_;

    $$result .= ' ' if $$result ne '';

    if($buffer_type eq 'quoted') {
        if($$buffer =~ /[$rfc_specials]/) {
            # use quoted string if buffer contains special chars
            $$buffer =~ s/[\\"]/\\$&/g;
            
            $$result .= qq("$$buffer");
        }
        else {
            $$result .= $$buffer;
        }
    }
    elsif($buffer_type eq 'mime') {
        $$result .= "=?$self->{encoding}?$self->{method}?";

        if($self->{method} eq 'B') {
            $$result .= MIME::Base64::encode_base64($$buffer, '');
        }
        else {
            $$result .= $$buffer;
        }

        $$result .= '?=';
    }

    $$buffer = '';

    return;
}

1;

__END__

=head1 NAME

Email::MIME::RFC2047::Encoder - Encoding of non-ASCII MIME headers

=head1 SYNOPSIS

 use Email::MIME::RFC2047::Encoder;
 
 my $encoder = Email::MIME::RFC2047::Encoder->new(
     encoding => 'utf-8',
     method   => 'Q',
 );
 
 my $encoded_text   = $encoder->encode_text($string);
 my $encoded_phrase = $encoder->encode_phrase($string);

=head1 DESCRIPTION

This module encodes non-ASCII text for MIME email message headers according to
RFC 2047.

=head1 CONSTRUCTOR

=head2 new

 my $encoder = Email::MIME::RFC2047::Encoder->new(
     encoding => $encoding,
     method   => $method,
 );

Creates a new encoder object.

I<encoding> specifies the encoding ("character set" in the RFC) to use. This is
passed to the L<Encode> module. See L<Encode::Supported> for supported
encodings.

I<method> specifies the encoding method ("encoding" in the RFC). Must be either
'B' or 'Q'.

If both I<encoding> and I<method> are omitted, encoding defaults to 'utf-8'
and method to 'Q'. If only I<encoding> is omitted it defaults to 'utf-8'.
If only I<method> is omitted it defaults to 'B'.

=head1 METHODS

=head2 encode_text

 my $encoded_text = $encoder->encode_text($string);

Encodes a string that may replace a sequence of 'text' tokens (as defined by
RFC 822) in any Subject or Comments header field, any extension message header
field, or any MIME body part field for which the field body is defined as
'*text'. $string is expected to be an unencoded perl string.

This method tries to use the MIME encoding for as few characters of the
input string as possible. So the result may consist of a mix of
'encoded-words' and '*text'.

The source string is trimmed and any whitespace is collapsed. The words in the
result are separated by single space characters without folding of long lines.

=head2 encode_phrase

 my $encoded_phrase = $encoder->encode_phrase($string);

Encodes a string that may replace a 'phrase' token (as defined by RFC 822),
for example, one that precedes an address in a From, To, or Cc header.

This method works like I<encode_text> but additionally converts remaining
text that contains special characters to 'quoted-strings'.

=head1 AUTHOR

Nick Wellnhofer <wellnhofer@aevum.de>

=head1 COPYRIGHT AND LICENSE

Copyright (C) Nick Wellnhofer, 2009

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.0 or,
at your option, any later version of Perl 5 you may have available.

=cut

