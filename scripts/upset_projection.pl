#!/usr/bin/perl 

use TempoFree;
use strict;
use warnings;

sub print_ingame_odds($$$);
sub usage($);

sub usage($) {
  my $p = shift;
  my @parts = split(/\//, $p);
  $p = pop(@parts);
  print STDERR "\n";
  print STDERR "Usage: $p <prediction_file> <results0> ... <resultsN>\n";
  print STDERR "\n";
  exit 1;
}

my $pred_file = shift(@ARGV);

usage($0) if(!@ARGV);

my %predictions;
LoadPredictions($pred_file, 1, \%predictions);

foreach my $results_file (@ARGV) {
  my %results;
  LoadPartialResults($results_file, \%results);

  foreach my $gid (sort keys %results) {
    my $result_aref = $results{$gid};
    my $pred_aref = $predictions{$gid};
    print_ingame_odds($gid, $result_aref, $pred_aref);
  }
}

sub print_ingame_odds($$$) {
  my $gid = shift;
  my $result_aref = shift;
  my $pred_aref = shift;
  my $time_left = $$result_aref[4];
  my $odds = undef;
  if (!$time_left) {
    # $time_left == 0 -> game is over
    if ($$result_aref[7] > $$result_aref[10]) {
      $odds = 1.0;
    } else {
      $odds = 0.0;
    }
    printf "%s,%s,%d,%s,%d,3600,%.1f\n", $gid, $$result_aref[5], $$result_aref[7],
           $$result_aref[8], $$result_aref[10], $odds;
    return;
  } elsif ($time_left < 0) { # Overtime
    printf "%s,%s,%d,%s,%d,3599,0.5\n", $gid, $$result_aref[5], $$result_aref[7],
           $$result_aref[8], $$result_aref[10];
    return;
  } else {
    # At this point, $p is actually the % of the game remaining.
    my $p = $time_left / 3600;
    my $second_mark = 3600 - $time_left;
    # At this point, $p is the % that has been played.
    # After this line, it will be the % of the game played.
    $p = 1 - $p;
    # TODO: See if this is actually better.
#    $p = $p ** 0.5;
#    my $projected_plays = $$pred_aref[-1];
#    if (!$projected_plays) {
#      return;
#    }
    # We use the effective score instead of the actual score to calculate odds.
    # The effective score will be at the [11] position for the home team and the
    # [12] position for the away team. If these are not present, then fall back
    # on using the [7] and [10] points.
    my $home_eff_pts = $$result_aref[11];
    my $away_eff_pts = $$result_aref[12];
    $home_eff_pts = $$result_aref[7] if (!defined($home_eff_pts));
    $away_eff_pts = $$result_aref[10] if (!defined($away_eff_pts));
    $home_eff_pts = 0 if ($home_eff_pts < 0);
    $away_eff_pts = 0 if ($away_eff_pts < 0);
    $p = 0.001 if (!$p);
    my $lead = abs($home_eff_pts - $away_eff_pts);
    my $lead_odds = LeadOdds($second_mark, $lead);
    $lead_odds = ($home_eff_pts > $away_eff_pts) ? $lead_odds : 1 - $lead_odds;
#    printf STDERR "Second %4d Lead %4.1f Odds %.3f\n", $second_mark, $lead, $lead_odds;
    my $home_off = $home_eff_pts / $p;
    my $home_def = $away_eff_pts / $p;
    $home_off = 0.001 if (!$home_off);
    $home_def = 0.001 if (!$home_def);
    my $home_wpct = 1 / (1 + (($home_def / $home_off) ** 2.7));
 
    my $away_off = $home_def;
    my $away_def = $home_off;
    my $away_wpct = 1 / (1 + (($away_def / $away_off) ** 2.7));

    my $num = $home_wpct - ($home_wpct * $away_wpct);
    my $den = $home_wpct + $away_wpct - (2 * $home_wpct * $away_wpct);
    my $in_game_log5 = $num / $den;
    my $pred_odds = ($$pred_aref[2] > $$pred_aref[4]) ? $$pred_aref[5] : 1 - $$pred_aref[5];
    # This assumes $p is the % of the game that's been played
    $odds = combine_odds($gid, $pred_odds, $in_game_log5, $lead_odds, $p, $second_mark, $lead);
#    printf STDERR "GID %s HID %d HS %2d AID %d AS %2d HWP %.3f AWP %.3f LG5 %.3f\n",
#                  $gid, $$result_aref[5], $$result_aref[7], $$result_aref[8],
#                  $$result_aref[10], $home_wpct, $away_wpct, $in_game_log5;
#    printf STDERR "    %18s TL %4d PP %.3f PWP %.3f ODDS %.3f\n", "", $time_left,
#                  $p, $pred_odds, $odds;
#    printf STDERR "DEBUGP GID %s PHS %2d PAS %2d PNP %4d PHE %5.2f PAE %5.2f FO %.3f\n",
#           $gid, $$pred_aref[2], $$pred_aref[4], $$pred_aref[-1], 100 * $proj_home_oeff,
#           100 * $proj_away_oeff, $$pred_aref[-2];
#    printf STDERR "DEBUGA GID %s AHS %2d AAS %2d TTL %4d PHS %5.2f PAS %5.2f PO %.3f\n\n",
#           $gid, $$result_aref[7], $$result_aref[10], $time_left,
#           $home_off, $away_off, $num / $den;
    printf "%s,%s,%d,%s,%d,%d,%.3f\n", $gid, $$result_aref[5], $$result_aref[7],
           $$result_aref[8], $$result_aref[10], 3600 - $time_left, $odds;
  }
}

sub combine_odds($$$$$$$) {
  my $gid = shift;
  my $init_log5 = shift;
  my $curr_perf = shift;
  my $lead_odds = shift;
  my $pct_played = shift;
  my $second_mark = shift;
  my $lead = shift;
  my $init_weight = 1 - $pct_played;
  my $lead_weight = $pct_played ** 0.5;
  my $perf_weight = 2 * (0.5 - abs(0.5 - $pct_played));
  $perf_weight = $perf_weight ** 2;
#  my $dist_from_half = 2 * abs(0.5 - $pct_played);
#  my $perf_weight = (1 - $dist_from_half) ** 2;
  my $weight_sum = $init_weight + $perf_weight + $lead_weight;
  my $hwin = (($init_log5 * $init_weight) + ($curr_perf * $perf_weight) + ($lead_odds * $lead_weight)) / $weight_sum;
#  printf STDERR "Combine %s SecMark %4d %%Play %.3f Init %.3f IW %.3f Perf %.3f "
#                . "PW %.3f LPts %2d Lead %.3f LW %.3f Sum %.3f HWin %.3f\n",
#                $gid, $second_mark, $pct_played, $init_log5, $init_weight, $curr_perf,
#                $perf_weight, $lead, $lead_odds, $lead_weight, $weight_sum, $hwin;
  return $hwin;
}
