#!/usr/bin/perl 

use TempoFree;
use strict;
use warnings;

sub log_one_data_point($$$);
sub odds_to_bin($);

my $MIN_DATA_POINTS = 20;
my $BIN_SIZE = 25;

my $directory = shift;
my $start_t = shift;
my $end_t = shift;

exit 1 if (!defined($directory));

$start_t = 0 if (!defined($start_t));
$end_t = 3600 if (!defined($end_t));

exit 2 if ($start_t >= $end_t);

my %gametimes;
my %tfg_preds;
my %rba_preds;
# {tag}{bin}[count]
my %pred_data;
my %right_data;
my %total_data;
# {tag}[sum_err,N]
my %brier_input;

LoadInGamePredictions($directory, "TFG", \%tfg_preds, \%gametimes);
LoadInGamePredictions($directory, "RBA", \%rba_preds, \%gametimes);

exit 1 if (!(keys %tfg_preds and keys %rba_preds));

foreach my $gid (keys %tfg_preds) {
  my $tfg_href = $tfg_preds{$gid};
  my $rba_href = $rba_preds{$gid};
  next unless (defined($tfg_href) and defined($rba_href));
  my @times = sort { $a <=> $b } keys %$tfg_href;
  next unless (scalar(@times) > $MIN_DATA_POINTS);
  my $last_t = $times[-1];
  my $last_l = $$tfg_href{$last_t};
  next if (!defined($last_l));
  my @wa = split(/,/, $last_l);
  my $w = int($wa[-1]);
  foreach my $t (@times) {
    next if (($t < $start_t) or ($t > $end_t));
    my @tfg_s = split(/,/, $$tfg_href{$t});
    my @rba_s = split(/,/, $$rba_href{$t});
    my $tfg_odds = $tfg_s[-1];
    my $rba_odds = $rba_s[-1];
    my $sum_odds = ($tfg_odds + $rba_odds) / 2;
    log_one_data_point("tfg", $tfg_odds, $w);
    log_one_data_point("rba", $rba_odds, $w);
    log_one_data_point("sum", $sum_odds, $w);
  }  
}

foreach my $tag (keys %total_data) {
  my $sum_href = $total_data{"sum"};
  print "\n=== $tag \n";
  my ($total_right, $total_pred, $total_total, $sos) = (0, 0, 0, 0);
  printf "Tag    Start    End  Total    Pred  PPct Right  RPct\n";
  foreach my $b (sort { $a <=> $b } keys %$sum_href) {
    my $total = $total_data{$tag}{$b};
    my $right = $right_data{$tag}{$b};
    my $pred  = $pred_data{$tag}{$b};
    $total = 0 if (!defined($total));
    $right = 0 if (!defined($right));
    $pred  = 0 if (!defined($pred));
    $total_total += $total;
    $total_right += $right;
    $total_pred += $pred;
    my $d = $total_right - $total_pred;
    $sos += ($d * $d);
    my $ppct = "0.000";
    my $rpct = "0.000";
    if ($total) {
      $rpct = sprintf "%.3f", $right / $total;
      $ppct = sprintf "%.3f", $pred / $total;
    }
    my $start_b = ($b * $BIN_SIZE) / 1000;
    my $end_b = 1;
    if ($start_b != 1) {
      $end_b = ((($b + 1) * $BIN_SIZE) - 1) / 1000;
    }
#    printf "$tag %s %.3f %.3f\n", $b, ($start_b + $end_b) / 2, $pct;
    printf "%s %s %.3f - %.3f %5d %7.1f %s %5d %s\n", $tag, $b, $start_b,
           $end_b, $total, $pred, $ppct, $right, $rpct;
  }
  my $ppct = "0.000";
  my $rpct = "0.000";
  if ($total_total) {
    $rpct = sprintf "%.3f", $total_right / $total_total;
    $ppct = sprintf "%.3f", $total_pred / $total_total;
  }
  my $baref = $brier_input{$tag};
  printf "%s %s %.3f - %.3f %5d %7.1f %s %5d %s %.4f %.4f\n", $tag, "XX", 0.5, 0.999,
         $total_total, $total_pred, $ppct, $total_right, $rpct,
         (sqrt($sos) / ($total_total - 1)), $$baref[0] / $$baref[1];
}

sub log_one_data_point($$$) {
  my $tag = shift;
  my $odds = shift;
  my $winner = shift;
  my $aref = $brier_input{$tag};
  if (!defined($aref)) {
    my @a = (0, 0);
    $brier_input{$tag} = $aref = \@a;
  }
  my $b = odds_to_bin($odds);
  $total_data{$tag}{$b} += 1;
  if ($odds < 0.5) {
    $pred_data{$tag}{$b} += (1 - $odds);
    $$aref[0] += ((1 - $odds) ** 2);
    if (!$winner) {
      $right_data{$tag}{$b} += 1;
    } else {
      $right_data{$tag}{$b} += 0;
    }
  } else {
    $pred_data{$tag}{$b} += $odds;
    $$aref[0] += ($odds ** 2);
    if ($winner) {
      $right_data{$tag}{$b} += 1;
    } else {
      $right_data{$tag}{$b} += 0;
    }
  }
  $$aref[1] += 1;
}

sub odds_to_bin($) {
  my $o = shift;
  if ($o < 0.5) {
    $o = 1 - $o;
  }
  $o *= 1000;
  return int($o / $BIN_SIZE);
}
