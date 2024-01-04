#!/usr/bin/perl 
#===============================================================================
#
#         FILE: create_ingame_odds.pl
#
#        USAGE: ./create_ingame_odds.pl  
#
#  DESCRIPTION: Create in-game win odds based on parsed play-by-play data.
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 02/23/2015 11:52:17 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;

my %games;

while(<STDIN>){
  chomp;
  my @l = split(/,/);
  next if (!length($l[1]));
  $games{$l[0]}{$l[1]} = \@l;
}

foreach my $gid (keys %games) {
  my $href = $games{$gid};
  my @t = sort { $a <=> $b } keys %$href;
  my $fl_aref = $$href{$t[0]};
  my $w = undef;
  if ($$fl_aref[4] > $$fl_aref[5]) {
    $w = $$fl_aref[2];
  } elsif ($$fl_aref[5] > $$fl_aref[4]) {
    $w = $$fl_aref[3];
  }
  foreach my $i (1..$#t) {
    my $laref = $$href{$t[$i]};
    my $m = $$laref[4] - $$laref[5];
    if (!defined($w)) {
      # Tie game. Whoever has the lead ends up in a tie.
      printf "%d,%d,%d,0\n", $$laref[1], ($m >= 0) ? 1 : 0, abs($m);
    } elsif ($$laref[2] eq $w) {
      # The eventual winner has the ball. Do they have the lead.
      if ($m >= 0) {
        # They're not going to lose, at least.
        printf "%d,%d,%d,1\n", $$laref[1], 1, $m;
      } else {
        # No, they don't have the lead.
        # Do this from the POV of the eventual loser. They don't have the ball,
        # but they do have the lead.
        printf "%d,%d,%d,-1\n", $$laref[1], 0, -$m;
      }
    } else { 
      # The eventual loser has the ball. Do they have the lead?
      if ($m <= 0) {
        # The eventual loser does not have the lead. Do this from the winner's
        # POV: they don't have the ball, but they have the lead.
        # Use abs() to make sure we don't somehow get -0.
        printf "%d,%d,%d,1\n", $$laref[1], 0, abs(-$m);
      } else {
        # The eventual loser has the ball and the lead. Do this from their POV.
        printf "%d,%d,%d,-1\n", $$laref[1], 1, $m;
      }
    }
  }
}
