#!/usr/bin/perl -w
#
# Takes output from scoreMyResults.pl and bins them into 5% probability windows.

use strict;

my $window = 50;
my %games;
my %right;
my %expect;
my $tg = 0;
my $tr = 0;
my $te = 0;
while(<STDIN>) {
  next if (/^WK/ or /^200[2-9]/ or /^YR/);
  next if (/G  0  0  /);
  next unless (/^20/);
  chomp;
  @_ = split;
  my $o = $_[11];
  if ($o < 500) { $o = 1000 - $o; }
  my $b = $o - ($o % $window);
  $games{$b} += 1;
  $right{$b} += $_[8];
  $expect{$b} += ($o / 1000);
  $te += ($o / 1000);
  $tr += $_[8];
  $tg++;
}

exit if (!$tg);

foreach my $o (sort { $a <=> $b } keys %games) {
  my $g = $games{$o};
  my $r = $right{$o};
  my $e = $expect{$o};
  printf "+ %5.3f %4.3f %4.3f %6.3f %4d %6.1f %6.1f\n", $o / 1000, $e / $g, $r / $g, ($r - $e) / $g, $g, $r, $e;
}
printf "= %5.3f %4.3f %4d %6.1f %6.1f\n", $te / $tg, $tr / $tg, $tg, $tr, $te;
