#!/usr/bin/perl -w

use POSIX;
use TempoFree;
use strict;

sub construct_treemap($$$);
sub print_game_info($$$$);
sub get_undefeated_odds_games($$$);
sub usage();

my %ODDS_TO_TAGS = ( 1.000 => "Legitimate Title Contenders",
                     0.850 => "Second-Tier Hopefuls",
                     0.750 => "Long Shots",
                     0.600 => "Absolute Phonies",
                     0.500 => "What are YOU doing here??",
                     0.000 => "ERROR"
                   );
my $MAX_WEEK = 16;

my $prediction_file = shift(@ARGV);
my $rankings_file = shift(@ARGV);
my $pred_system = shift(@ARGV);
my $week_number = shift(@ARGV);
my $current_date = shift(@ARGV);
my $post_time = shift(@ARGV);

usage() if (!defined($post_time));

my $tree_tag = $current_date;
$tree_tag =~ s/-//g;

if (($pred_system ne "rba") and ($pred_system ne "tfg")) {
  print STDERR "Invalid prediction system: \"$pred_system\"\n";
  usage();
}
my $pred_name = uc $pred_system;

if ($week_number == $MAX_WEEK) {
  print STDERR "Current week is max week ($MAX_WEEK)";
  exit 0;
}

$tree_tag .= $pred_system;

my %id2name;
my %id2conf;
my %confteams;
my %is_bcs;
LoadConferences(\%id2name, \%id2conf, \%confteams, \%is_bcs);

my %names;
LoadPrintableNames(\%names);

my %full_names;
LoadFullNames(\%full_names);

my %results;
LoadResults(\%results);

my %weeks;
DatesToWeek(\%results, \%weeks);

my %team_seasons;
ResultsToTeamSeasons(\%results, \%team_seasons);

# Parse the predictions for each team.
my %undefeated_predictions;
my %oneloss_predictions;
LoadPredictions($prediction_file, 0, \%undefeated_predictions);
LoadPredictions($prediction_file, 0, \%oneloss_predictions);

my %all_predictions;
LoadPredictions($prediction_file, 1, \%all_predictions);

my %all_wpcts;
my %all_sos;
my %all_oeff;
my %all_deff;
my %all_pace;
my $rc = LoadRanksAndStats($rankings_file, \%all_wpcts, \%all_sos, \%all_oeff, \%all_deff, \%all_pace);
if ($rc) {
  die "Error getting rankings and stats from $rankings_file";
}

my %all_data;
$all_data{"WPCTS"} = \%all_wpcts;
$all_data{"SOS"} = \%all_sos;
$all_data{"OEFF"} = \%all_oeff;
$all_data{"DEFF"} = \%all_deff;
$all_data{"PACE"} = \%all_pace;

# Go through the summary file and build the mappings of existing game results to
# teams on a per-year basis.
# Also keep track of the most recent year.
my $lastyear = 0;
my %per_year_wins;         # {team_id}{year}[wins]
my %per_year_losses;       # {team_id}{year}[losses]
foreach my $gameinfo (values %results) {
  my $week = $$gameinfo[0];
  # Since each year has 52w1d in it (leap years have 52w2d) and since week 0 is
  # the first week of the 2000-01 season, this next statement is good for about
  # 40 years' worth of football seasons.
  my $year = int($week / 52) + 2000;
  $lastyear = $year if ($year > $lastyear);
  my $homeid = $$gameinfo[5];
  my $homescore = $$gameinfo[7];
  my $awayid = $$gameinfo[8];
  my $awayscore = $$gameinfo[10];
  next if (!$homescore and !$awayscore);
  my ($hwin, $hloss, $awin, $aloss);
  if ($homescore > $awayscore) {
    $hwin = $aloss = 1;
    $hloss = $awin = 0;
  } else {
    $hwin = $aloss = 0;
    $hloss = $awin = 1;
  }
  $per_year_wins{$homeid}{$year} += $hwin;
  $per_year_losses{$homeid}{$year} += $hloss;
  $per_year_wins{$awayid}{$year} += $awin;
  $per_year_losses{$awayid}{$year} += $aloss;
}

# Go through and put a defined value in each per-team-per-year register.
foreach my $teamid (keys %id2name) {
  if (!defined($per_year_wins{$teamid}{$lastyear})) {
    $per_year_wins{$teamid}{$lastyear} = 0;
  }
  if (!defined($per_year_losses{$teamid}{$lastyear})) {
    $per_year_losses{$teamid}{$lastyear} = 0;
  }
}

my %undefeated_odds;
my %undefeated_games;
my %oneloss_odds;
my %oneloss_games;
foreach my $teamid (keys %per_year_losses) {
  next if ($id2conf{$teamid} eq "FCS");
  if ($per_year_losses{$teamid}{$lastyear} == 0) {
    my @a;
    $undefeated_games{$teamid} = \@a;
    $undefeated_odds{$teamid} = 1;
  } elsif ($per_year_losses{$teamid}{$lastyear} == 1) {
    my @a;
    $oneloss_games{$teamid} = \@a;
    $oneloss_odds{$teamid} = 1;
  }
}

print STDERR "UD\n";
get_undefeated_odds_games(\%undefeated_predictions, \%undefeated_odds, \%undefeated_games);

my @teams = sort { $undefeated_odds{$b} <=> $undefeated_odds{$a} } keys %undefeated_odds;
my $min_odds = $undefeated_odds{$teams[-1]};
printf "<!-- Min odds = $min_odds -->\n";
my $output = construct_treemap(\%undefeated_odds, $min_odds, "undefeated");

sub game_sorter {
  return $$a[-1] <=> $$b[-1];
}

print "$output\n";
my $current_tag = -1;
my @all_odds = sort { $b <=> $a } keys %ODDS_TO_TAGS;
my @blogtags = ( "undefeated" );
my @curryear = ( $lastyear );
my $bcs_count = 0;
foreach my $tid (@teams) {
  my $bcs = $is_bcs{$tid};
  $bcs_count += $bcs if(defined($bcs));
  my $aref = $undefeated_games{$tid};
  my $per_game_odds = $undefeated_odds{$tid} ** (1. / ($MAX_WEEK - $week_number));
  printf "<!-- Team %s PGO %.3f -->\n", $tid, $per_game_odds;
  my $print_header = 0;
  while (($current_tag < 0) || ($per_game_odds <= $all_odds[$current_tag])) {
    $current_tag++;
    $print_header++;
  }
  print "<div><b>$ODDS_TO_TAGS{$all_odds[$current_tag-1]}</b></div><br />" if ($print_header);
  PrintTeamHeaders(\%id2name, \%full_names, \%all_data, $tid,
                   \@curryear, $pred_system);
  my $weeks_href = shift;
  my $id2name_href = shift;
  my $names_href = shift;
  my $seasons_aref = shift;
  my $team_id = shift;
  my $team_seasons_href = shift;
  my $results_href = shift;
  my $predictions_href = shift;
  my $all_wpcts_href = shift;
  my $pred_system = shift;


  PrintSeasons(\%weeks, \%id2name, \%names, \@curryear, $tid, \%team_seasons,
               \%results, \%all_predictions, \%all_wpcts, $pred_system);
  my $odds = undef;
  if ($undefeated_odds{$tid} > 0.1) {
    $odds = sprintf "%.1f%%", 100 * $undefeated_odds{$tid};
  } else {
    $odds = sprintf "1-in-%.1f", 1 / $undefeated_odds{$tid};
  }
  printf "<div>Odds of finishing undefeated: %s<br />\n", $odds;
  push(@blogtags, $names{$id2name{$tid}});
  my @games = sort game_sorter @$aref;
  next if (scalar(@games) == 0);
  my $game_aref = $games[0];
  printf "Most difficult game left: %s<br />\n", print_game_info(\%undefeated_predictions, $tid, $$game_aref[0], $$game_aref[-1]);
  print "</div>\n";
  print "<br />\n<br />\n";
}

if ($bcs_count <= 3) {
  # If we only have two undefeated teams from within the BCS, then include the one-loss teams.
  print STDERR "1L\n";
  get_undefeated_odds_games(\%oneloss_predictions, \%oneloss_odds, \%oneloss_games);
  
  my @ol_teams = sort { $oneloss_odds{$b} <=> $oneloss_odds{$a} } keys %oneloss_odds;
  my $min_ol_odds = $oneloss_odds{$ol_teams[-1]};
  printf "<!-- Min 1-loss odds = $min_ol_odds -->\n";
  print "<br/><div><b>One-Loss Hopefuls</b></div>\n";
  $output = construct_treemap(\%oneloss_odds, $min_ol_odds, "oneloss");
  print "$output\n";
  $current_tag = 0;
  foreach my $tid (@ol_teams) {
    my $bcs = $is_bcs{$tid};
    next if (!defined($bcs) or !$bcs);
    my $aref = $oneloss_games{$tid};
    my $per_game_odds = $oneloss_odds{$tid} ** (1. / ($MAX_WEEK - $week_number));
    printf "<!-- Team %s PGO %.3f -->\n", $tid, $per_game_odds;
    PrintTeamHeaders(\%id2name, \%full_names, \%all_data, $tid,
                     \@curryear, $pred_system);
    PrintSeasons(\%weeks, \%id2name, \%names, \@curryear, $tid, \%team_seasons,
                 \%results, \%all_predictions, \%all_wpcts, $pred_system);
    my $odds = undef;
    if ($oneloss_odds{$tid} > 0.1) {
      $odds = sprintf "%.1f%%", 100 * $oneloss_odds{$tid};
    } else {
      $odds = sprintf "1-in-%.1f", 1 / $oneloss_odds{$tid};
    }
    printf "<div>Odds of finishing with one loss: %s<br/>\n", $odds;
    push(@blogtags, $names{$id2name{$tid}});
    my @games = sort game_sorter @$aref;
    next if (scalar(@games) == 0);
    my $game_aref = $games[0];
    printf "Most difficult game left: %s</div>\n", print_game_info(\%oneloss_predictions, $tid, $$game_aref[0], $$game_aref[-1]);
    print "<br />\n<br />\n";
  }
}
print "<i>Follow us on Twitter at "
      . "<a href=\"http://twitter.com/TFGridiron\">\@TFGridiron</a> "
      . "and <a href=\"http://twitter.com/TFGLiveOdds\">\@TFGLiveOdds</a>.</i>\n";

my $tags = join(',', @blogtags);
$tags =~ s/St\./State/g;
$tags =~ s/\&/+/g;
print "<!-- POSTTAGS|$tags| -->\n";
print "<!-- POSTTITLE|Week $week_number: Undefeated ... but for how long? &mdash; $pred_name| -->\n";
print "<!-- POSTTIME|$post_time| --\n";

sub construct_treemap($$$) {
  my $undefeated_odds_href = shift;
  my $min_odds = shift;
  my $extra = shift;
  $min_odds /= 100;
  my $full_tag = $tree_tag . $extra;
  my $tree_out = "<script src=\"https://www.google.com/jsapi\" type=\"text/javascript\"></script>\n";
  $tree_out .= "
     <script type=\"text/javascript\">
        google.load(\"visualization\", \"1\", {packages:[\"treemap\"]});
        google.setOnLoadCallback(drawChart);
        function drawChart() {
            // Create and populate the projected table.
            var projected$full_tag = new google.visualization.DataTable();
            projected$full_tag.addColumn('string', 'Team');
            projected$full_tag.addColumn('string', 'Parent');
            projected$full_tag.addColumn('number', 'Number of Projected Wins');
            projected$full_tag.addRows([
              [\"Odds of remaining undefeated\",null,0],\n";
  foreach my $tid (keys %$undefeated_odds_href) {
    $tree_out .= sprintf "  [\"%s\",\"Odds of remaining undefeated\",%d],\n",
                       $names{$id2name{$tid}}, $$undefeated_odds_href{$tid} / $min_odds;
  }
  # Remove the last trailing ",\n"
  chop($tree_out);
  chop($tree_out);

  $tree_out .= "          ]);

          // Create and draw the projectedvisualization.
          var tree = new google.visualization.TreeMap(document.getElementById('projected$full_tag" . "visualization'));
          tree.draw(projected$full_tag, {
            minColor: '#f00',
            midColor: '#ddd',
            maxColor: '#0d0',
            headerHeight: 15,
            fontColor: 'black',
            fontFamily: 'Verdana',
            showScale: false});
      }
</script>
<div id=\"projected$full_tag" . "visualization\" style=\"height: 252px; width: 625px;\"></div>
<i>Odds as of games through $current_date</i><br /><br />
<!--more-->\n";
  return $tree_out;
}

sub print_game_info($$$$) {
  my $pred_href = shift;
  my $tid = shift;
  my $gid = shift;
  my $odds = shift;
  my ($year, $month, $day, $home, $away);
  if ($gid =~ /(\d{4})(\d{2})(\d{2})-(\d{4})-(\d{4})/) {
    $year = $1;
    $month = $2;
    $day = $3;
    $home = $4;
    $away = $5;
  } else {
    return "(unknown)";
  }
  my $pred_aref = $$pred_href{$gid};
  if (!defined($pred_aref)) {
    return "(unknown)";
  }
  $year -= 1900;
  --$month;
  my $at_vs = "vs";
  my $opponent = undef;
  if ($$pred_aref[1]) {
    # Neutral site
    if ($tid == $$pred_aref[4]) {
      $opponent = $$pred_aref[2];
    } else {
      $opponent = $$pred_aref[4];
    }
  } elsif ($tid == $$pred_aref[4]) {
    # Not a neutral site, and we're the visitors
    $at_vs = "at";
    $opponent = $$pred_aref[2];
  } else {
    $opponent = $$pred_aref[4];
  }
  my $t = POSIX::mktime(0, 0, 12, $day, $month, $year);
  my $game_str = strftime "%B %e", localtime($t);
  return sprintf "$game_str, $at_vs %s, %.1f%%", $full_names{$id2name{$opponent}}, 100 * $odds;
}

sub get_undefeated_odds_games($$$) {
  my $predictions_href = shift;
  my $undefeated_odds_href = shift;
  my $undefeated_games_href = shift;
  foreach my $tid (keys %$undefeated_odds_href) {
    print STDERR "  TEAM $tid\n";
  }
  foreach my $gid (sort keys %$predictions_href) {
    my $predinfo = $$predictions_href{$gid};
    my $t1id = $$predinfo[1];
    my $t1s  = $$predinfo[2];
    my $t2id = $$predinfo[3];
    my $t2s  = $$predinfo[4];
    print STDERR "   T1 $t1id T2 $t2id\n";
    if (!(defined($$undefeated_odds_href{$t1id}) or defined($$undefeated_odds_href{$t2id}))) {
      print STDERR "    Skipping GID $gid\n";
      next;
    }
    my $favor_wp = $$predinfo[5];
    if ($favor_wp < 0.500) {
      $favor_wp = 1 - $favor_wp;
    }
    unshift(@$predinfo, $gid) if ($$predinfo[0] ne $gid);
    my ($hwin, $hloss, $awin, $aloss);
    if ($t1s > $t2s) {
      # Home team is the favorite
      if (defined($$undefeated_odds_href{$t1id})) {
        # Home team currently undefeated.
        my $aref = $$undefeated_games_href{$t1id};
        $$undefeated_odds_href{$t1id} *= $favor_wp;
        my @a = @$predinfo;
        push(@a, $favor_wp);
        push(@$aref, \@a);
        printf STDERR "GID %s HH %.3f\n", $gid, $favor_wp;
      }
      if (defined($$undefeated_odds_href{$t2id})) {
        # Away team currently undefeated.
        my $aref = $$undefeated_games_href{$t2id};
        $$undefeated_odds_href{$t2id} *= (1 - $favor_wp);
        my @a = @$predinfo;
        push(@a, 1 - $favor_wp);
        push(@$aref, \@a);
        printf STDERR "GID %s HA %.3f\n", $gid, 1 - $favor_wp;
      }
    } else {
      # Away team is the favorite
      if (defined($$undefeated_odds_href{$t1id})) {
        # Home team currently undefeated.
        my $aref = $$undefeated_games_href{$t1id};
        $$undefeated_odds_href{$t1id} *= (1 - $favor_wp);
        my @a = @$predinfo;
        push(@a, 1 - $favor_wp);
        push(@$aref, \@a);
        printf STDERR "GID %s AH %.3f\n", $gid, 1 - $favor_wp;
      }
      if (defined($$undefeated_odds_href{$t2id})) {
        # Away team currently undefeated.
        my $aref = $$undefeated_games_href{$t2id};
        $$undefeated_odds_href{$t2id} *= $favor_wp;
        my @a = @$predinfo;
        push(@a, $favor_wp);
        push(@$aref, \@a);
        printf STDERR "GID %s AA %.3f\n", $gid, $favor_wp;
      }
    }
  }
}

sub usage() {
  print STDERR "\n";
  print STDERR "Usage: $0 <predictions> <rankings> <rba|tfg> <week_number> <current_date>\n";
  print STDERR "\n";
  exit 1;
}
