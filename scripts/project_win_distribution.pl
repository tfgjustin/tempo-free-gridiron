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

my %windist;
my $NUM_GAMES = 100000;
foreach my $i (1..$NUM_GAMES) {
  my $s = 0;
  foreach my $p (@ARGV) {
    my $v = rand 1;
    if ($v < $p) {
      ++$s;
    }
  }
  $windist{$s} += 1;
}
foreach my $c (sort { $a <=> $b } keys %windist) {
  printf "%2d %.6f\n", $c, $windist{$c} / $NUM_GAMES;
}
