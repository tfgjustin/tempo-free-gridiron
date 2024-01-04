#!/usr/bin/perl -w
#
# Takes output from scripts/scoreMyResults.pl
#
# E.g.,
#
# ./scripts/scoreMyResults input/summaries.csv predict.out | \
#     ./scripts/odds_of_results.pl

use strict;

my %week_res;
my %week_games;

while(<STDIN>) {
  next unless (/^2/);
  s/-/\ /g;
  chomp;
  @_ = split;
  my $day = $_[0];
  my $odds = 1;
  if ($_[4] > $_[5]) {
    # Actual game: home team wins
    $odds = $_[13];
  } else {
    # Actual game: home team loses
    $odds = 1000 - $_[13];
  }
  $odds /= 1000;
  if (defined($week_res{$day})) {
    $week_res{$day} *= $odds;
  } else {
    $week_res{$day} = $odds;
  }
  $week_games{$day} += 1;
}
foreach my $d (sort keys %week_res) {
  my $n = $week_games{$d};
  my $res_odds = $week_res{$d};
  my $one_game_odds = $res_odds ** (1 / $n);
  printf "%d %2d %.20f %.20f\n", $d, $n, $res_odds, $one_game_odds;
}
