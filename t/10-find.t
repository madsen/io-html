#! /usr/bin/perl
#---------------------------------------------------------------------
# 10-find.t
# Copyright 2012 Christopher J. Madsen
#
# Test the find_charset_in function
#---------------------------------------------------------------------

use strict;
use warnings;

use Test::More 0.88;            # done_testing

use IO::HTML 'find_charset_in';

plan tests => 10;

sub test
{
  my ($charset, $data, $name) = @_;

  local $Test::Builder::Level = $Test::Builder::Level + 1;

  is(scalar find_charset_in($data), $charset, $name);
} # end test

#---------------------------------------------------------------------
test 'utf-8-strict' => <<'';
<meta charset="UTF-8">

test 'utf-8-strict' => <<'';
<!-- UTF-16 is recognized only with a BOM -->
<meta charset="UTF-16BE">

test 'iso-8859-15' => <<'';
<meta charset ="ISO-8859-15">

test 'iso-8859-15' => <<'';
<meta charset= "ISO-8859-15">

test 'iso-8859-15' => <<'';
<meta charset =
 "ISO-8859-15">

test 'cp1252' => <<'';
<meta charset="Windows-1252">

test undef, <<'', 'misspelled charset';
<meta charseat="Windows-1252">

test 'utf-8-strict' => <<'';
<meta charset="UTF-8">
<meta charset="Windows-1252">
<meta charseat="Windows-1252">

test 'cp1252' => <<'';
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=ISO-8859-1" />
<title>Title</title>

test 'iso-8859-15' => <<'';
<html>
<head><!-- somebody forgot the quotes -->
<meta http-equiv=Content-Type content=text/html; charset=ISO-8859-15 />
<title>Title</title>

done_testing;
