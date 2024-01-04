#!/usr/bin/perl 

use strict;
use warnings;

sub parse_quarter_line($$);

my @aq;
my @hq;
my $as = undef;
my $hs = undef;
while(<STDIN>) {
  next unless (/Team[12]/);
  chomp;
  if (/Team1/) {
    $as = parse_quarter_line($_, \@aq);
  } elsif (/Team2/) {
    $hs = parse_quarter_line($_, \@hq);
  }
}
exit if (!@aq or !@hq or !defined($as) or !defined($hs));

my ($at, $ht) = (0, 0);
if ($as > $hs) {
  # Away team won
  foreach my $i (0..2) {
    $at += $aq[$i];
    $ht += $hq[$i];
    printf "%d,%d,%d\n", 900 * ($i + 1), abs($at - $ht), ($at > $ht) ? 1 : 0;
  }
} else {
  # Home team won
  foreach my $i (0..2) {
    $at += $aq[$i];
    $ht += $hq[$i];
    printf "%d,%d,%d\n", 900 * ($i + 1), abs($at - $ht), ($ht > $at) ? 1 : 0;
  }
}

sub parse_quarter_line($$) {
  my $l = shift;
  my $aref = shift;
  my @p = split(/:/, $l);
  return undef if (scalar(@p) != 4);
  if ($p[2] =~ /\s*(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+Final\s*/) {
    push(@$aref, $1);
    push(@$aref, $2);
    push(@$aref, $3);
    push(@$aref, $4);
    return ($1 + $2 + $3 + $4);
  } else {
    return undef;
  }
}
