#!/usr/bin/perl 

use TempoFree;
use strict;
use warnings;

sub test_prediction($$$);
sub usage($);

my $predict_file = shift(@ARGV);
my $ranking_file = shift(@ARGV);
my $year = shift(@ARGV);

usage($0) if (!defined($year));

my %id2name;
LoadIdToName(\%id2name);

my %names;
LoadPrintableNames(\%names);

my %results;
LoadResults(\%results);

my %team_seasons;
ResultsToTeamSeasons(\%results, \%team_seasons);

my %dates2week;
DatesToWeek(\%results, \%dates2week);

my $min_week = 10000;
my $max_week = -1;
my $max_week_played = -1;

my %team_weeks;
foreach my $tid (keys %team_seasons) {
  my $aref = $team_seasons{$tid}{$year};
  next if (!defined($aref));
  my %weeks;
  foreach my $gid (sort @$aref) {
    my $date = substr($gid, 0, 8);
    my $week = $dates2week{$date};
    if (!defined($week)) {
      warn "No week for $date";
      next;
    }
    $min_week = $week if ($week < $min_week);
    $max_week = $week if ($week > $max_week);
    $weeks{$week} = $gid;
    my $res_aref = $results{$gid};
    if ($$res_aref[7] or $$res_aref[10]) {
      $max_week_played = $week if ($week > $max_week_played);
    }
  }
  $team_weeks{$tid} = \%weeks;
}

exit if ($min_week >= $max_week);

my $num_weeks = $max_week - $min_week + 1;

print "<!-- Year = $year Min = $min_week Max = $max_week Num = $num_weeks -->\n";

my %predictions;
LoadPredictions($predict_file, 1, \%predictions);

my %wpcts;
my %ranks;
LoadCurrentRankings($ranking_file, undef, \%wpcts, \%ranks);


my %all_wpcts;
LoadRanksAndStats($ranking_file, \%all_wpcts, undef, undef, undef, undef);

my $this_week = (sort { $a <=> $b } keys %all_wpcts)[-1];
my $year_week = $this_week - 53;

my %old_wpcts;
FetchWeekRankings(\%all_wpcts, undef, undef, undef, undef, $year_week, \%old_wpcts, undef, undef, undef, undef);

print "<link rel=\"stylesheet\" type=\"text/css\" href=\"ncaa.css\" />\n";
print "<table class=\"win-loss\">\n";
print "<tr align=\"center\"><th rowspan=\"2\">Team</th><th colspan=$num_weeks>Week</th>";
print "<th rowspan=\"2\">Pred<br />Diff</th></tr>\n";
print "<th rowspan=\"2\">EWP<br />Diff</th></tr>\n";
print "<tr align=\"center\">\n";
foreach my $i (1..$num_weeks) {
  print "  <th>$i</th>\n";
}
print "</tr>\n";

sub compare_teams {
  if (defined($ranks{$a})) {
    if (defined($ranks{$b})) {
      return $ranks{$a} <=> $ranks{$b};
    } else {
      return -1;
    }
  } else {
    if (defined($ranks{$b})) {
      return 1;
    } else {
      return 0;
    }
  }
}

foreach my $tid (sort compare_teams keys %id2name) {
  my $short_name = $id2name{$tid};
  my $print_name = PrintableName(\%names, $short_name);
  my $weeks_href = $team_weeks{$tid};
  if (!defined($weeks_href)) {
#    warn "No per-week data for $print_name";
    next;
  }
  print "<tr>\n  <td class=\"teamName\">$print_name</td>\n";
  my $exp = 0;
  my $act = 0;
  foreach my $w ($min_week..$max_week) {
    my $class = "future";
    my $gid = $$weeks_href{$w};
    my $odds = 0;
    my $good = 0;
    if (defined($gid)) {
      ($class, $odds, $good) = test_prediction(\%results, \%predictions, $gid);
    } elsif ($w <= $max_week_played) {
      $class = "byeWeek";
    }
    $exp += $odds;
    $act += $good;
    print "  <td class=\"$class\">&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>\n";
  }
  my $c = "future";
  my $diff = $act - $exp;
  if ($diff > 1.0)     { $c = "bigWin";  }
  elsif ($diff > 0)    { $c = "win";     }
  elsif ($diff < -1.0) { $c = "bigLoss"; }
  else                 { $c = "loss";    }
  printf "  <td class=\"$c\" align=\"right\">&nbsp;%5.2f</td>\n", $diff;
  my $curr_wpct = $wpcts{$tid};
  my $prev_wpct = $old_wpcts{$tid};
  $c = "future";
  $diff = $curr_wpct - $prev_wpct;
  if ($diff > 0.15)     { $c = "bigWin";  }
  elsif ($diff > 0)     { $c = "win";     }
  elsif ($diff < -0.15) { $c = "bigLoss"; }
  else                  { $c = "loss";    }
  printf "  <td class=\"$c\" align=\"right\">&nbsp;%5.2f</td>\n", $diff;
  print "</tr>\n";
}
print "</table>\n";

sub test_prediction($$$) {
  my $results_href = shift;
  my $predict_href = shift;
  my $gid = shift;
  my $results_aref = $$results_href{$gid};
  my $predict_aref = $$predict_href{$gid};
  return ("future", 0, 0) if (!defined($results_aref) or !defined($predict_aref));
  return ("future", 0, 0) if (!($$results_aref[7] or $$results_aref[10]));
  my $odds = $$predict_aref[5];
  if ($$results_aref[7] > $$results_aref[10]) {
    # Home team actually beat the away team. What did we predict?
    if ($$predict_aref[2] > $$predict_aref[4]) {
      # Correct
      return ("win", $odds, 1);
    } else {
      return ("loss", $odds, 0);
    }
  } else {
    # Away team won. What did we predict?
    if ($$predict_aref[4] > $$predict_aref[2]) {
      # Correct
      return ("win", $odds, 1);
    } else {
      return ("loss", $odds, 0);
    }
  }
  # Should never get here.
  warn "Whuh?";
  return "future";
}

sub usage($) {
  my $p = shift;
  my @parts = split(/\//, $p);
  $p = pop(@parts);
  print STDERR "\n";
  print STDERR "Usage: $p <predict_file> <ranking_file> <year>\n";
  print STDERR "\n";
  exit 1;
}
