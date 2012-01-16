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

plan tests => 19;

use IO::HTML;
use File::Temp;

#---------------------------------------------------------------------
my $tested_open_method;

sub test
{
  my ($expected, $out, $data, $name) = @_;

  local $Test::Builder::Level = $Test::Builder::Level + 1;

  my $tmp = File::Temp->new(UNLINK => 1);

  if ($out) {
    $out = ":encoding($out)" unless $out =~ /^:/;
    binmode $tmp, $out;
  }

  print $tmp $data;
  $tmp->close;

  my $fh = html_file("$tmp");

  $expected = "encoding($expected)";
  my @layers = PerlIO::get_layers($fh);

  ok((grep { $_ eq $expected } @layers), $name)
      or diag(map { "$_\n" } "Expected $expected, but got", @layers);

  like(<$fh>, qr/^<html/i);

  close $fh;

  # Just try the open method once:
  unless ($tested_open_method) {
    $tested_open_method = 1;

    my $fh = IO::HTML->open("$tmp");
    like(<$fh>, qr/^<html/i);
  } # end unless $tested_open_method
} # end test

#---------------------------------------------------------------------
test 'utf-8-strict' => '' => <<'';
<html><meta charset="UTF-8">

test 'utf-8-strict' => ':utf8' => <<"";
<html><head><title>Foo\xA0Bar</title>

test cp1252 => latin1 => <<"";
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
