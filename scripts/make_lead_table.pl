#!/usr/bin/perl 

use strict;
use warnings;

my $infile = shift(@ARGV);
exit 1 if (!defined($infile) or ! -f $infile);

open my $inf, "<", $infile or die "Can't open $infile: $!";
my @lines = <$inf>;
close $inf;
chomp @lines;

exit 1 if (!@lines);

my $last_line = $lines[-1];
my @p = split(/,/, $last_line);
my $final_hs = $p[7];
my $final_as = $p[10];

my $curr_minute = 0;
my $last_hs = 0;
my $last_as = 0;
foreach my $line (@lines) {
  @p = split(/,/, $line);
  my $t = 3600 - $p[4];
  my $hs = $p[7];
  my $as = $p[10];
  if ($t < $curr_minute) {
    $last_hs = $hs;
    $last_as = $as;
    next;
  }
  if ($final_hs > $final_as) {
    # Home team won
    printf "%d,%d,%d\n", $curr_minute, abs($last_hs - $last_as), ($last_hs > $last_as) ? 1 : 0;
  } elsif ($final_hs < $final_as) {
    # Away team won
    printf "%d,%d,%d\n", $curr_minute, abs($last_hs - $last_as), ($last_as > $last_hs) ? 1 : 0;
  }
  $last_hs = $hs;
  $last_as = $as;
  $curr_minute += 60;
}
