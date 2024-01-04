#!/usr/bin/perl -w

use strict;

my %num_seen;  # {gid}[num_played]
my %expected;  # {num_played}[expected_right]
my %per_num_seen; # {num_played}[count]
my %actual_right; # {num_played}[right]

while(<STDIN>) {
  next if(/^WK/ or /^YR/);
  next if(/G  0  0  /);
  s/\-/\ /g;
  @_ = split;
  my @g = ( $_[1] , $_[2] );
  @g = sort @g;
  my $gid = join(':', @g);
  $num_seen{$gid} += 1;
  my $ns = $num_seen{$gid};
  if ($_[13] < 500) {
    $_[13] = 1000 - $_[13];
  }
  $expected{$ns} += ($_[13] / 1000);
  $per_num_seen{$ns} += 1;
#  print STDERR "10 = $_[10]\n";
  $actual_right{$ns} += $_[10];
}

foreach my $ns (sort { $a <=> $b } keys %per_num_seen) {
  my $exp = $expected{$ns};
  my $act = $actual_right{$ns};
  my $cnt = $per_num_seen{$ns};
  my $d = $act - $exp;
  $d /= $cnt;
  $d *= 100;
  printf "%6.1f %6.1f %5d %5.1f\n", $exp, $act, $cnt, $d;
}
