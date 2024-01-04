#!/usr/bin/perl 

use TempoFree;
use strict;
use warnings;

my $predict_file = shift(@ARGV);
my $min_diff = shift(@ARGV);
my $max_diff = shift(@ARGV);
my $bet_amount = shift(@ARGV);

exit 1 if (!defined($predict_file) or ! -f $predict_file);

if (!defined($min_diff)) {
  $min_diff = 0.05;
}
if (!defined($max_diff)) {
  $max_diff = 0.09;
}

if (!defined($bet_amount)) {
  $bet_amount = 500;
}

my $DONBEST_TEAMS = "data/donbest/teams.csv";
my %don_teams;
open(DON, "$DONBEST_TEAMS") or die "Can't open $DONBEST_TEAMS for reading: $!";
while (<DON>) {
  chomp;
  @_ = split(/,/);
  $don_teams{$_[0]} = $_[1];
}
close(DON);

my %all_predictions;
if (LoadPredictions($predict_file, 1, \%all_predictions)) {
  die "Can't load predictions from $predict_file";
}

my %results;
if (LoadResults(\%results)) {
  die "Can't load results file";
}

sub get_odds($) {
  my $aref = shift;
  return (undef, undef) if (scalar(@$aref) < 7);
  if ($$aref[2] > $$aref[4]) {
    return (($$aref[5] / 1), 1 - ($$aref[5] / 1));
  } else {
    return (1 - ($$aref[5] / 1), ($$aref[5] / 1));
  }
}

sub who_won($) {
  my $res_aref = shift;
  if ($$res_aref[7] > $$res_aref[10]) {
    return 1;
  } else { return 2; }
}

sub money_back($$$) {
  my $did_win = shift;
  my $money = shift;
  my $ratio = shift;
  return 0 if (!$did_win);
  if ($money < 100) {
    $money = -$money;
    return $ratio * $bet_amount * (100 + $money) / $money;
  } elsif ($money >= 100) {
    return $ratio * $bet_amount * (100 + $money) / 100;
  } else {
    warn "Invalid money: $money";
    return -1;
  }
}

sub handle_one_house($$$$$$$$$) {
  my $gid = shift;
  my $house = shift;
  my $pred_t1 = shift;
  my $pred_t2 = shift;
  my $odds_t1 = shift;
  my $odds_t2 = shift;
  my $money_t1 = shift;
  my $money_t2 = shift;
  my $winner = shift;
  if ($pred_t1 - $odds_t1 >= $min_diff and $pred_t1 - $odds_t1 < $max_diff) {
    my $ratio = 1; # $pred_t1 / $odds_t1;
    # We think t1 is a good bet.
    printf "%s %-18s %.3f %.3f %.3f %5.2f %5d %5d %5d\n", $gid, $house,
           $pred_t1, $odds_t1,
           $pred_t1 - $odds_t1, $ratio, $money_t1, $bet_amount * $ratio,
           money_back($winner == 1, $money_t1, $ratio);
  }
  if ($pred_t2 - $odds_t2 >= $min_diff and $pred_t2 - $odds_t2 < $max_diff) {
    my $ratio = 1; # $pred_t2 / $odds_t2;
    # We think t2 is a good bet.
    printf "%s %-18s %.3f %.3f %.3f %5.2f %5d %5d %5d\n", $gid, $house,
           $pred_t2, $odds_t2,
           $pred_t2 - $odds_t2, $ratio, $money_t2, $bet_amount * $ratio,
           money_back($winner == 2, $money_t2, $ratio);
  }
}

sub handle_prediction($$$) {
  my $gid = shift;
  my $flip = shift;
  my $aref = shift;
  my $pred_aref = $all_predictions{$gid};
  return if (!defined($pred_aref));
  my $res_aref = $results{$gid};
  return if (!defined($res_aref));
  my ($pred_t1_odds, $pred_t2_odds) = get_odds($pred_aref);
  my $winner = who_won($res_aref);
  while (@$aref) {
    my $house = shift(@$aref);
    my $t1_money = shift(@$aref);
    my $t1_odds = shift(@$aref);
    my $t2_money = shift(@$aref);
    my $t2_odds = shift(@$aref);
    next if ($t1_odds < 0 or $t2_odds < 0);
    if ($flip) {
      my $tl = $t1_money;
      my $to = $t1_odds;
      $t1_money = $t2_money;
      $t1_odds = $t2_odds;
      $t2_money = $tl;
      $t2_odds = $to;
    }
    handle_one_house($gid, $house, $pred_t1_odds, $pred_t2_odds, $t1_odds, $t2_odds,
                     $t1_money, $t2_money, $winner);
  }
}

while(<STDIN>) {
  next if (/Open,-,-1.000,-,-1.000$/);
  next if (/^DUP/);
  @_ = split(/,/);
  my $date = shift(@_);
  my $t1 = shift(@_);
  my $t2 = shift(@_);
  if (!defined($don_teams{$t1})) {
    next;
  }
  if (!defined($don_teams{$t2})) {
    next;
  }
  my $t = 0;
  foreach my $i (0..2) {
    my $d = $date + $i;
    my $gid = sprintf "%s-%d-%d", $d, $don_teams{$t1}, $don_teams{$t2};
    if (defined($all_predictions{$gid})) {
      handle_prediction($gid, 0, \@_);
      $t = 1;
      last;
    } else {
      $gid = sprintf "%s-%d-%d", $d, $don_teams{$t2}, $don_teams{$t1};
      if (defined($all_predictions{$gid})) {
        handle_prediction($gid, 1, \@_);
        $t = 1;
        last;
      }
    }
  }
  if (!$t) {
    print STDERR "No prediction for $don_teams{$t1} ($t1) vs $don_teams{$t2} ($t2) on $_[0]\n";
  }
}
