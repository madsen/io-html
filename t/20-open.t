#! /usr/bin/perl
#---------------------------------------------------------------------
# 20-open.t
# Copyright 2012 Christopher J. Madsen
#
# Actually open files and check the encoding
#---------------------------------------------------------------------

use strict;
use warnings;

use Test::More 0.88;

plan tests => 53;

use IO::HTML;
use File::Temp;
use Scalar::Util 'blessed';

#---------------------------------------------------------------------
sub test
{
  my ($expected, $out, $data, $name) = @_;

  local $Test::Builder::Level = $Test::Builder::Level + 1;

  unless ($name) {
    $name = 'test ' . ($expected || 'cp1252');
  }

  my $tmp = File::Temp->new(UNLINK => 1);
  open(my $mem, '>', \(my $buf)) or die;

  if ($out) {
    $out = ":encoding($out)" unless $out =~ /^:/;
    binmode $tmp, $out;
    binmode $mem, $out;
  }

  print $mem $data;
  print $tmp $data;
  close $mem;
  $tmp->close;

  my ($fh, $encoding, $bom) = IO::HTML::file_and_encoding("$tmp");

  is($encoding, $expected || 'cp1252', $name);

  my $firstLine = <$fh>;
  like($firstLine, qr/^<html/i);

  close $fh;

  $fh = html_file("$tmp");

  is(<$fh>, $firstLine);

  close $fh;

  # Test sniff_encoding:
  undef $mem;
  open($mem, '<:raw', \$buf) or die;

  ($encoding, $bom) = IO::HTML::sniff_encoding($mem);

  is($encoding, $expected);

  seek $mem, 0, 0;

  ($encoding, $bom) = IO::HTML::sniff_encoding($mem, undef, { encoding => 1 });

  if (defined $expected) {
    ok(blessed($encoding), 'encoding is an object');

    is(eval { $encoding->name }, $expected);
  } else {
    is($encoding, undef);
  }
} # end test

#---------------------------------------------------------------------
test 'utf-8-strict' => '' => <<'';
<html><meta charset="UTF-8">

test 'utf-8-strict' => ':utf8' => <<"";
<html><head><title>Foo\xA0Bar</title>

test undef, latin1 => <<"";
<html><head><title>Foo\xA0Bar</title>

test 'UTF-16BE' => 'UTF-16BE' => <<"";
\x{FeFF}<html><head><title>Foo\xA0Bar</title>

test 'utf-8-strict' => ':utf8' => <<"";
\x{FeFF}<html><meta charset="UTF-16">

test 'utf-8-strict' => ':utf8' => <<"";
<html><meta charset="UTF-16BE">

test 'UTF-16LE' => 'UTF-16LE' => <<"";
\x{FeFF}<html><meta charset="UTF-16">

test 'utf-8-strict' => ':utf8' =>
  "<html><title>Foo\xA0Bar" . ("\x{2014}" x 512) . "</title>\n",
  'UTF-8 character crosses boundary';

test 'utf-8-strict' => ':utf8' =>
  "<html><title>Foo Bar" . ("\x{2014}" x 512) . "</title>\n",
  'UTF-8 character crosses boundary 2';

done_testing;
