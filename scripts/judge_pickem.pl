#!/usr/bin/perl 
#===============================================================================
#
#         FILE: judge_pickem.pl
#
#        USAGE: ./judge_pickem.pl  
#
#  DESCRIPTION: Figure out which pick'em games I do well at and which ones I
#  don't.
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 09/01/2014 09:44:22 PM
#     REVISION: ---
#===============================================================================

use TempoFree;
use strict;
use warnings;

my $predfile = shift(@ARGV);
my $gamefile = shift(@ARGV);

my %is_bcs;
foreach my $yr (2011..2013) {
  my %bcs;
  LoadConferences(undef, undef, undef, \%bcs);
  $is_bcs{$yr} = \%bcs;
}

my %results;
LoadResults(\%results);

my %predict;
LoadPredictions($predfile, 1, \%predict);
print "Loaded " . scalar(keys %predict) . " games\n";

my %expected;
my %actual;
my %games;
open(GAMES, "$gamefile") or die "Can't open gamefile $gamefile: $!";
while(<GAMES>) {
  chomp;
  my $p_aref = $predict{$_};
  my $r_aref = $results{$_};
  if (!defined($p_aref)) {
    warn "Missing! $_";
    next;
  }
  if (!defined($r_aref)) {
    warn "Missing! $_";
    next;
  }
  @_ = split(/-/);
  my $t1 = $_[1];
  my $t2 = $_[2];
  my $yr = substr($_[0], 0, 4);
  my $href = $is_bcs{$yr};
  my $bcs1 = $$href{$t1};
  my $bcs2 = $$href{$t2};
  if (!defined($bcs1) or !defined($bcs2)) {
    warn "Whuh? $_";
    next;
  }
  my $t = $bcs1 + $bcs2;
  my $e = $$p_aref[5];
  $expected{$t} += $e;
  $games{$t} += 1;
  if ($$p_aref[2] > $$p_aref[4]) {
    # Predict home win
    if ($$r_aref[7] > $$r_aref[10]) {
      $actual{$t} += 1;
    }
  } else {
    # Predict away win
    if ($$r_aref[10] > $$r_aref[7]) {
      $actual{$t} += 1;
    }
  }
}
close(GAMES);

foreach my $t (0..2) {
  printf "%d %4d %5.1f %.3f %5.1f %.3f\n", $t, $games{$t}, $expected{$t}, $expected{$t} / $games{$t}, $actual{$t}, $actual{$t} / $games{$t};
}
