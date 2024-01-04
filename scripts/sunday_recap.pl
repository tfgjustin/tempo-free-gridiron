#!/usr/bin/perl 

use TempoFree;
use strict;
use warnings;

sub print_prediction($$$);
sub print_game_info($$$);
sub print_table_line($$$$$);
sub print_table($$$);
sub actual_expected($);
sub print_stats($$$);
sub analyze_game($$$$);
sub analyze_results($$$$$);
sub usage($);

my %TAG_TO_NAME = (
    "GOTW" => "Game of the Week",
    "UFIO" => "Unstoppable Force/Immovable Object Game",
    "SHOOT" => "Shootout of the Week",
    "COIN" => "Coin Toss Game of the Week"
  );

my %TAG_TO_FOOTER = (
    # No entry for game of the week or shootout of the week
    "UFIO" => "<b>Unstoppable Force X, Immovable Object Y</b>",
    "COIN" => "<b>Coin Toss Record:</b> TFG X, RBA Y."
);

my $weeknum = shift(@ARGV);
my $start_date = shift(@ARGV);
my $end_date = shift(@ARGV);
my $tfg_predict = shift(@ARGV);
my $tfg_ranking = shift(@ARGV);
my $rba_predict = shift(@ARGV);
my $rba_ranking = shift(@ARGV);
# Comma-separated (GOTW, UFIO, SHOOT, COIN)
my $games_of_the_week = shift(@ARGV);

usage($0) if (!defined($games_of_the_week));

$start_date =~ s/-//g;
$end_date =~ s/-//g;

my $this_year = substr($start_date, 0, 4);
my $next_year = $this_year + 1;

my $start_year_date = sprintf "%d0801", $this_year;
my $end_year_date = sprintf "%d1214", $this_year;

my %id2name;
my %id2conf;
LoadConferences(\%id2name, \%id2conf, undef, undef);

my %names;
LoadPrintableNames(\%names);

my %full_names;
LoadFullNames(\%full_names);

my %results;
LoadResults(\%results);
#printf STDERR "Found %d results\n", scalar(keys %results);

my %tfg_predictions;
LoadPredictions($tfg_predict, 1, \%tfg_predictions);
#printf STDERR "Found %d predictions for TFG\n", scalar(keys %tfg_predictions);

my %tfg_rankings;
my %tfg_wpcts;
LoadCurrentRankings($tfg_ranking, \%id2conf, \%tfg_wpcts, \%tfg_rankings);

my %rba_predictions;
LoadPredictions($rba_predict, 1, \%rba_predictions);
#printf STDERR "Found %d predictions for RBA\n", scalar(keys %rba_predictions);

my %rba_rankings;
my %rba_wpcts;
LoadCurrentRankings($rba_ranking, \%id2conf, \%rba_wpcts, \%rba_rankings);

my %tfg_week_stats;
analyze_results(\%results, \%tfg_predictions, $start_date, $end_date, \%tfg_week_stats);
my %tfg_year_stats;
analyze_results(\%results, \%tfg_predictions, $start_year_date, $end_year_date, \%tfg_year_stats);

my %rba_week_stats;
analyze_results(\%results, \%rba_predictions, $start_date, $end_date, \%rba_week_stats);
my %rba_year_stats;
analyze_results(\%results, \%rba_predictions, $start_year_date, $end_year_date, \%rba_year_stats);

print "<link rel=\"stylesheet\" type=\"text/css\" href=\"ncaa.css\" />\n";
print "<!-- POSTTITLE|Week $weeknum: Saturday Recap| -->\n";
print_table("Week $weeknum", \%tfg_week_stats, \%rba_week_stats);
my @last_games = split(/,/, $games_of_the_week);
my %team_ids;
foreach my $game (@last_games) {
  my ($game_code, $gid) = split(/:/, $game);
  my $game_title = $TAG_TO_NAME{$game_code};
  if (!defined($game_title)) {
    warn "No title for game code $game_code";
    next;
  }
  my $footer = $TAG_TO_FOOTER{$game_code};
  print_game_info($game_title, $gid, $footer);
  if ($gid =~ /\d{8}-(\d{4})-(\d{4})/) {
    $team_ids{$1} = 1;
    $team_ids{$2} = 1;
  } else {
    warn "Invalid game ID for matchup: $gid";
    next;
  }
}
my @tag_teams;
foreach my $tid (keys %team_ids) {
  my $n = $names{$id2name{$tid}};
  $n =~ s/St\./State/g;
  $n =~ s/\&/+/g;
  push(@tag_teams, $n);
}
printf "<!-- POSTTAGS|recap,%s| -->\n", join(',', @tag_teams);
print_table("$this_year - $next_year Season", \%tfg_year_stats, \%rba_year_stats);
print "<div><i>Follow us on Twitter at "
      . "<a href=\"http://twitter.com/TFGridiron\">\@TFGridiron</a> "
      . "and <a href=\"http://twitter.com/TFGLiveOdds\">\@TFGLiveOdds</a>.</i></div>\n";

sub print_prediction($$$) {
  my $gid = shift;
  my $pred_href = shift;
  my $rank_href = shift;

  my ($home_id, $away_id);
  if ($gid =~ /\d{8}-(\d{4})-(\d{4})/) {
    $home_id = $1;
    $away_id = $2;
  } else {
    warn "Invalid game ID for matchup: $gid";
    return;
  }

  my $home_shortname = $names{$id2name{$home_id}};
  my $away_shortname = $names{$id2name{$away_id}};
  if (!defined($home_shortname)) {
    warn "No name found for $home_id";
    return;
  }
  if (!defined($away_shortname)) {
    warn "No name found for $away_id";
    return;
  }
  my $home_rank = $$rank_href{$home_id};
  my $away_rank = $$rank_href{$away_id};
  if (!defined($home_rank)) {
    warn "No ranking found for $home_id";
    return;
  }
  if (!defined($away_rank)) {
    warn "No ranking found for $away_id";
    return;
  }

  my $pred_aref = $$pred_href{$gid};
  if (!defined($pred_aref)) {
    warn "No prediction available for $gid";
    return;
  }
  if ($$pred_aref[2] > $$pred_aref[4]) {
    printf "<div>(%d) %s %d, (%d) %s %d (%4.1f%%); %d plays</div>\n", $home_rank, $home_shortname,
           $$pred_aref[2], $away_rank, $away_shortname, $$pred_aref[4], $$pred_aref[5] * 100,
           $$pred_aref[6];
  } else {
    printf "<div>(%d) %s %d, (%d) %s %d (%4.1f%%); %d plays</div>\n", $away_rank, $away_shortname,
           $$pred_aref[4], $home_rank, $home_shortname, $$pred_aref[2], $$pred_aref[5] * 100,
           $$pred_aref[6];
  }
}

my $which_first = 0;
sub print_game_info($$$) {
  my $game_title = shift;
  my $gid = shift;
  my $post_game_tags = shift;
  my ($home_id, $away_id);
  if ($gid =~ /\d{8}-(\d{4})-(\d{4})/) {
    $home_id = $1;
    $away_id = $2;
  } else {
    warn "Invalid game ID for matchup: $gid";
    return;
  }
  my $home_shortname = $id2name{$home_id};
  if (!defined($home_shortname)) {
    warn "No short name for team $home_id";
    return;
  }
  my $home_name = $full_names{$home_shortname};
  if (!defined($home_name)) {
    warn "No full name for team $home_id ($home_shortname)";
    return;
  }
  my $away_shortname = $id2name{$away_id};
  if (!defined($away_shortname)) {
    warn "No short name for team $away_id";
    return;
  }
  my $away_name = $full_names{$away_shortname};
  if (!defined($away_name)) {
    warn "No full name for team $away_id ($away_shortname)";
    return;
  }

  my $result_aref = $results{$gid};
  if (!defined($result_aref)) {
    warn "No results data for game $gid";
    return;
  }
  my $num_plays = $$result_aref[4];
  my $home_score = $$result_aref[7];
  my $away_score = $$result_aref[10];
  if (!$home_score and !$away_score) {
    warn "No score data for game $gid";
    return;
  }
  print "<div><b>$game_title</b></div>\n";
  if ($home_score > $away_score) {
    print "<div>$home_name $home_score, $away_name $away_score; $num_plays plays</div>\n";
  } else {
    print "<div>$away_name $away_score, $home_name $home_score; $num_plays plays</div>\n";
  }

  if ($which_first) {
    print "<br>\n<div><b>Eddie</b></div>\n";
    print_prediction($gid, \%rba_predictions, \%rba_rankings);
    print "<br>\n<div>Text goes here</div>\n";
    print "<br>\n<div><b>Justin</b></div>\n";
    print_prediction($gid, \%tfg_predictions, \%tfg_rankings);
    print "<br>\n<div>Text goes here</div>\n";
  } else {
    print "<br>\n<div><b>Justin</b></div>";
    print_prediction($gid, \%tfg_predictions, \%tfg_rankings);
    print "<br>\n<div>Text goes here</div>\n";
    print "<br>\n<div><b>Eddie</b></div>\n";
    print_prediction($gid, \%rba_predictions, \%rba_rankings);
    print "<br>\n<div>Text goes here</div>\n";
  }
  if (defined($post_game_tags)) {
    print "<br />\n";
    print "<div>$post_game_tags</div>\n";
  }
  print "<br />\n<br />\n";
  $which_first = !$which_first;
}

sub print_table_line($$$$$) {
  my $row_type = shift;
  my $sys = shift;
  my $actual = shift;
  my $expected = shift;
  my $num_games = shift;

  my $actual_winloss = sprintf "%3d - %3d", $actual, $num_games - $actual;
  $actual_winloss =~ s/\s/&nbsp;/g;
  my $expected_winloss = sprintf "%5.1f - %5.1f", $expected, $num_games - $expected;
  $expected_winloss =~ s/\s/&nbsp;/g;

  printf "<tr class=\"$row_type\">\n";
  printf "  <td class=\"teamName\">$sys</td>\n";
  printf "  <td class=\"stats\">$expected_winloss</td>\n";
  printf "  <td class=\"stats\">%4.1f</td>\n", 100 * $expected / $num_games;
  printf "  <td class=\"stats\">$actual_winloss</td>\n";
  printf "  <td class=\"stats\">%4.1f</td>\n", 100 * $actual / $num_games;
  printf "</tr>\n";
}

sub print_table($$$) {
  my $tag = shift;
  my $tfg_href = shift;
  my $rba_href = shift;
  my ($tfg_actual, $tfg_expected) = actual_expected($tfg_href);
  my ($rba_actual, $rba_expected) = actual_expected($rba_href);
  my $num_games = scalar(keys %$tfg_href);
  printf "<br />\n";
  printf "<table class=\"rank-table\">\n";
  printf "<tr align=\"center\"><th colspan=\"5\">$tag</th></tr>\n";
  printf "<tr align=\"center\" valign=\"bottom\">\n";
  printf "  <th rowspan=\"2\">System</th>\n";
  printf "  <th colspan=\"2\">Expected</th>\n";
  printf "  <th colspan=\"2\">Actual</th>\n";
  printf "</tr>\n";
  printf "<tr align=\"center\" valign=\"bottom\">\n";
  printf "  <th>W - L</th><th>Win %%</th>\n";  
  printf "  <th>W - L</th><th>Win %%</th>\n";  
  printf "</tr>\n";
  if ($rba_actual > $tfg_actual) {
    print_table_line("oddRow", "RBA", $rba_actual, $rba_expected, $num_games);
    print_table_line("evenRow", "TFG", $tfg_actual, $tfg_expected, $num_games);
  } else {
    print_table_line("oddRow", "TFG", $tfg_actual, $tfg_expected, $num_games);
    print_table_line("evenRow", "RBA", $rba_actual, $rba_expected, $num_games);
  }
  printf "</table>\n";
  printf "<br />\n";
}

sub actual_expected($) {
  my $stats_href = shift;
  my $expected_correct = 0;
  my $actual_correct = 0;
  foreach my $gid (keys %$stats_href) {
    my $aref = $$stats_href{$gid};
    $expected_correct += $$aref[2];
    $actual_correct   += $$aref[5];
  }
  return ($actual_correct, $expected_correct);
}

sub print_stats($$$) {
  my $tag = shift;
  my $range = shift;
  my $stats_href = shift;

  my ($actual_correct, $expected_correct) = actual_expected($stats_href);
  my $num_games = scalar(keys %$stats_href);
  return if (!$num_games);
  my $expected_pct = 100 * $expected_correct / $num_games;
  my $actual_pct = 100 * $actual_correct / $num_games;
  printf "%s %s: Expected %6.2f/%4d [ %5.2f%% ] | Actual %6.2f/%4d [ %5.2f%% ]\n",
         uc $tag, $range, $expected_correct, $num_games, $expected_pct,
         $actual_correct, $num_games, $actual_pct;
}

sub recap_game($$) {
  my $gid = shift;
  my $tag = shift;
}

# [predHS,predAS,expectedWin,actualHS,actualAS,actualWin]
sub analyze_game($$$$) {
  my $gid = shift;
  my $results_aref = shift;
  my $predict_aref = shift;
  my $stats_href = shift;
  my @stats;
#  printf STDERR "%s HS %2d AS %2d\n", $gid, $$results_aref[7], $$results_aref[10];
  if ($$results_aref[7] == 0 and $$results_aref[10] == 0) {
#    warn "Missing results for $gid";
    return;
  }
  push(@stats, $$predict_aref[2], $$predict_aref[4], $$predict_aref[5]);
  push(@stats, $$results_aref[7], $$results_aref[10]);
  my $is_right = 0;
  if ($$predict_aref[2] > $$predict_aref[4]) {
    if ($$results_aref[7] > $$results_aref[10]) {
      $is_right = 1;
    }
  } elsif ($$results_aref[7] < $$results_aref[10]) {
    $is_right = 1;
  }
  push(@stats, $is_right);
  $$stats_href{$gid} = \@stats;
}

sub analyze_results($$$$$) {
  my $results_href = shift;
  my $predict_href = shift;
  my $start_date = shift;
  my $end_date = shift;
  my $stats_href = shift;
  foreach my $gid (sort keys %$results_href) {
    my $game_date = substr($gid, 0, 8);
    last if ($game_date gt $end_date);
    next unless ($game_date ge $start_date);
    next if (!defined($$predict_href{$gid}));
    analyze_game($gid, $$results_href{$gid}, $$predict_href{$gid}, $stats_href);
  }
}

sub usage($) {
  my $p = shift;
  my @parts = split(/\//, $p);
  $p = pop(@parts);
  print STDERR "\n";
  print STDERR "Usage: $p <weeknum> <startdate> <enddate> <tfg_predict> <tfg_ranking> "
               . "<rba_predict> <rba_ranking>\n";
  print STDERR "\n";
  exit 1;
}
