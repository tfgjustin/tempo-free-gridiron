#!/usr/bin/perl -w

use strict;

my $pf = shift(@ARGV);
my $pa = shift(@ARGV);
my $exp = shift(@ARGV);

$exp = 2.66 if (!defined($exp));

if (!defined($pf) or !defined($pa)) {
  print "Usage: $0 <points_for> <points_against> [exp]\n";
  exit;
}

printf "%5.3f\n", 1 / (1 + (($pa / $pf)**$exp));
