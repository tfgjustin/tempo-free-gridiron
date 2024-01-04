#!/usr/bin/perl -w

use strict;

sub log10($) {
  my $n = shift;
  return log($n) / log(10);
}

my %day_results;
my %day_predict;
my %day_games;
while(<STDIN>) {
  next unless(/^2/);
  next if (/ G  0  0/);
  chomp;
  @_ = split;
  my $day = $_[0];
  my $result_odds = 0;
  my $c = "";
  if ($_[7] > $_[8]) {
    $c .= "h";
    if ($_[4] > $_[5]) {
      $result_odds = $_[13];
      $c .= "H";
    } else {
      $result_odds = 1000 - $_[13];
      $c .= "A";
    }
  } else {
    $c .= "a";
    if ($_[4] < $_[5]) {
      $result_odds = 1000 - $_[13];
      $c .= "A";
    } else {
      $result_odds = $_[13];
      $c .= "H";
    }
  }
  my $predict_odds = $result_odds;
  if ($predict_odds < 500) {
    $predict_odds = 1000 - $predict_odds;
  }
#  printf "GAME $day-$_[1]-$_[2] $c $_[13] $predict_odds $result_odds\n";
  $result_odds /= 1000;
  $predict_odds /= 1000;
  if (defined($day_results{$day})) {
    $day_results{$day} += log10($result_odds);
    $day_predict{$day} += log10($predict_odds);
  } else {
    $day_results{$day} = log10($result_odds);
    $day_predict{$day} = log10($predict_odds);
  }
  $day_games{$day} += 1;
}

foreach my $d (sort keys %day_results) {
  my $res = $day_results{$d};
  my $pre = $day_predict{$d};
  printf "%d %2d %.10f %.10f %.10f\n", $d, $day_games{$d}, $res, $pre, $res - $pre;
}
