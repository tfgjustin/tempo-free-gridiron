#!/usr/bin/perl 
#===============================================================================
#
#         FILE: project_win_distribution.pl
#
#        USAGE: ./project_win_distribution.pl  
#
#  DESCRIPTION: Given a set of win probabilities, run 10000 simulations and
#               figure out how many they'll win.
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 09/10/2013 01:35:37 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;

my %games;
my $i = 1;
foreach my $p (sort {$a <=> $b} @ARGV) {
  $games{$i++} = $p;
}

my %windist;
my $NUM_GAMES = 100000;
foreach my $i (1..$NUM_GAMES) {
  my $s = 0;
  foreach my $pts (keys %games) {
    my $prob = $games{$pts};
    my $v = rand 1;
    if ($v < $prob) {
      $s += $pts;
    }
  }
  $windist{$s} += 1;
}
my $cdf = 0;
foreach my $c (sort { $a <=> $b } keys %windist) {
  $cdf += $windist{$c};
  printf "%2d %.6f %.6f\n", $c, $windist{$c} / $NUM_GAMES, $cdf / $NUM_GAMES;
}
