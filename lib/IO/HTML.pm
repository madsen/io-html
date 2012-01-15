#---------------------------------------------------------------------
package IO::HTML;
#
# Copyright 2012 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 14 Jan 2012
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Open an HTML file with automatic charset detection
#---------------------------------------------------------------------

use 5.008;
use strict;
use warnings;

use Carp 'croak';
use Encode 'find_encoding';
use Exporter 5.57 'import';
use IO::File ();

our $VERSION = '0.01';
# This file is part of {{$dist}} {{$dist_version}} ({{$date}})

our $default_encoding ||= 'cp1252';

our @EXPORT    = qw(html_file);
our @EXPORT_OK = qw(find_charset_in sniff_encoding);
#=====================================================================

=sub html_file

  $filehandle = html_file($filename);

This function (exported by default) is the primary entry point.  It
opens the file specified by C<$filename> for reading and uses
C<sniff_encoding> to apply a suitable encoding layer.

If C<sniff_encoding> is unable to determine the encoding, it defaults
to C<$IO::HTML::default_encoding>, which is set to C<cp1252>
(a.k.a. Windows-1252) by default.  According to the standard, the
default should be locale dependent, but that is not currently
implemented.

It dies if the file cannot be opened.

=cut

sub html_file
{
  my ($filename) = @_;

  open(my $in, '<:raw', $filename) or croak "Failed to open $filename: $!";

=diag C<< Failed to open %s: %s >>

The specified file could not be opened for reading for the reason
specified by C<$!>.

=diag C<< No default encoding specified >>

The C<sniff_encoding> algorithm didn't find an encoding to use, and
you set C<$IO::HTML::default_encoding> to C<undef>.

=cut

  my $encoding = sniff_encoding($in, $filename);

  if (not defined $encoding) {
    croak "No default encoding specified"
        unless defined($encoding = $default_encoding);
  } # end if we didn't find an encoding

  binmode $in, ":encoding($encoding):crlf";

  return $in;
} # end html_file
#---------------------------------------------------------------------

=sub sniff_encoding

  $encoding = sniff_encoding($filehandle, $filename);

This function (exported only by request) runs the HTML5 encoding
sniffing algorithm on C<$filehandle> (which must be seekable, and
should have been opened in C<:raw> mode).  C<$filename> is used only
for error messages (if there's a problem using the filehandle), and
defaults to "file" if omitted.

It returns Perl's canonical name for the encoding, which is not
necessarily the same as the MIME or IANA charset name.  It returns
C<undef> if the encoding cannot be determined.

=cut

sub sniff_encoding
{
  my ($in, $filename) = @_;

  $filename = 'file' unless defined $filename;

  croak "Could not read $filename: $!" unless defined read $in, my $buf, 1024;

  seek $in, 0, 0 or croak "Could not seek $filename: $!"; # return to beginning

=diag C<< Could not read %s: %s >>

The specified file could not be read from for the reason specified by C<$!>.

=diag C<< Could not seek %s: %s >>

The specified file could not be rewound for the reason specified by C<$!>.

=cut

  # Check for BOM:
  my $encoding = do {
    if ($buf =~ /^\xFe\xFF/) {
      seek $in, 2, 0;
      'UTF-16BE';
    } elsif ($buf =~ /^\xFF\xFe/) {
      seek $in, 2, 0;
      'UTF-16LE';
    } elsif ($buf =~ /^\xEF\xBB\xBF/) {
      seek $in, 3, 0;
      'utf-8-strict';
    } else {
      find_charset_in($buf);    # check for <meta charset>
    }
  }; # end $encoding

  if (not defined $encoding and $buf =~ /[\x80-\xFF]/ and utf8::decode($buf)) {
    $encoding = 'utf-8-strict';
  } # end if valid UTF-8 with at least one multi-byte character:

  return $encoding;
} # end sniff_encoding

#=====================================================================
# Based on HTML5 8.2.2.1 Determining the character encoding:

# Get attribute from current position of $_
sub _get_attribute
{
  /\G[\x09\x0A\x0C\x0D\x20\x2F]+/gc; # skip whitespace or /

  return if /\G>/gc or /\G\z/gc;

  /\G(=?[^\x09\x0A\x0C\x0D\x20=]*)/gc;

  my ($name, $value) = (lc $1, '');

  if (/\G[\x09\x0A\x0C\x0D\x20]*=/gc
      and (/\G"([^"]*)"?/gc or
           /\G'([^']*)'?/gc or
           /\G([^\x09\x0A\x0C\x0D\x20>]*)/gc)) {
    $value = lc $1;
  }

  return wantarray ? ($name, $value) : 1;
} # end _get_attribute

sub _get_charset_from_meta
{
  local $_ = shift;

  while (/charset[\x09\x0A\x0C\x0D\x20]*=[\x09\x0A\x0C\x0D\x20]*/ig) {
    return $1 if (/\G"([^"]*)"/gc or
                  /\G'([^']*)'/gc or
                  /\G(?!['"])([^\x09\x0A\x0C\x0D\x20;]+)/gc);
  }

  return undef;
} # end _get_charset_from_meta
#---------------------------------------------------------------------

=sub find_charset_in

  $encoding = find_charset_in($string_containing_HTML);

This function (exported only by request) looks for charset information
in a C<< <meta> >> tag in a possibly incomplete HTML document using
the "two step" algorithm specified by HTML5.  It does not look for a BOM.

It returns Perl's canonical name for the encoding, which is not
necessarily the same as the MIME or IANA charset name.  It returns
C<undef> if no charset is specified or if the specified charset is not
recognized by the Encode module.

=cut

sub find_charset_in
{
  local $_ = shift;

  while (not /\G\z/gc) {
    if (/\G<!--.*?(?<=--)>/sgc) {
      # Skip comment
    }
    elsif (/\G<meta(?=[\x09\x0A\x0C\x0D\x20\x2F])/gic) {
      my ($got_pragma, $need_pragma, $charset);

      while (my ($name, $value) = _get_attribute) {
        if ($name eq 'http-equiv' and $value eq 'content-type') {
          $got_pragma = 1;
        } elsif ($name eq 'content' and not defined $charset) {
          $need_pragma = 1 if defined($charset = _get_charset_from_meta($value));
        } elsif ($name eq 'charset') {
          $charset = $value;
          $need_pragma = 0;
        }
      } # end while more attributes

      if (defined $need_pragma and (not $need_pragma or $got_pragma)) {
        return 'utf-8-strict' if $charset =~ /^utf-?16/;
        return 'cp1252'       if $charset eq 'iso-8859-1'; # people lie
        my $encoding = find_encoding($charset);
        return $encoding->name if $encoding;
      } # end if found charset
    } # end elsif <meta
    elsif (m!\G</?[a-zA-Z][^\x09\x0A\x0C\x0D >]*!gc) {
      1 while _get_attribute;
    }
    elsif (m{\G<[!/?][^>]*}gc) {
      # skip unwanted things
    }
    elsif (m/\G</gc) {
      # skip < that doesn't open anything we recognize
    }

    # Advance to the next <:
    m/\G[^<]+/gc;
  } # end while not at end of string

  return undef;                 # Couldn't find a charset
} # end find_charset_in

#=====================================================================
# Methods:
#=====================================================================

=method open

  $filehandle = IO::HTML->open($filename);

This is just another way to write C<html_file($filename)> for people
who prefer an object-oriented interface.

=cut

sub open
{
  shift;                        # Discard class name
  goto &html_file;
} # end open

#=====================================================================
# Package Return Value:

1;

__END__

=head1 SYNOPSIS

  use IO::HTML;                 # exports html_file by default
  use HTML::TreeBuilder;

  my $tree = HTML::TreeBuilder->new_from_file(
               html_file('foo.html')
             );

  # Alternative interface:
  open(my $in, '<:raw', 'bar.html');
  my $encoding = IO::HTML::sniff_encoding($in, 'bar.html');

=head1 DESCRIPTION

IO::HTML provides an easy way to open a file containing HTML while
automatically determining its encoding.  It uses the HTML5 encoding
sniffing algorithm specified in section 8.2.2.1 of the draft standard.

=for Pod::Loom-insert_after
SUBROUTINES
METHODS
