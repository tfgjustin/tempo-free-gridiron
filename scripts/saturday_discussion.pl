#!/usr/bin/perl 

use TempoFree;
use strict;
use warnings;

sub print_game_info($$$);
sub print_system_matchup($$$$$$$$);
sub print_matchup_stats($$);
sub unstoppable_immovable($);
sub shootout($);
sub coin_toss($);
sub expected();
sub usage($);

my $TFG = "TFG";
my $RBA = "RBA";

my $MIN_GUGS = 40;
my $GUGS_URL = "http://blog.tempo-free-gridiron.com/2010/12/whats-gugs.html";

usage($0) if (scalar(@ARGV) != 6);

my $week_number = shift(@ARGV);
my $target_date = shift(@ARGV);
my $tfg_predict = shift(@ARGV);
my $tfg_ranking = shift(@ARGV);
my $rba_predict = shift(@ARGV);
my $rba_ranking = shift(@ARGV);

my %id2name;
LoadIdToName(\%id2name);

my %names;
LoadPrintableNames(\%names);

my %full_names;
LoadFullNames(\%full_names);

$target_date =~ s/-//g;

my %tfg_predictions;
my $rc = LoadPredictions($tfg_predict, 0, \%tfg_predictions);
if ($rc) {
  die "Error loading TFG predictions from $tfg_predict";
}

my $WPCT = "wpct";
my $OEFF = "oeff";
my $DEFF = "deff";

my %tfg_wpct;
my %tfg_sos;
my %tfg_oeff;
my %tfg_deff;
my %tfg_pace;
LoadCurrentRanksAndStats($tfg_ranking, \%tfg_wpct, \%tfg_sos, \%tfg_oeff, \%tfg_deff, \%tfg_pace);

my %rba_predictions;
$rc = LoadPredictions($rba_predict, 0, \%rba_predictions);
if ($rc) {
  die "Error loading RBA predictions from $rba_predict";
}

my %rba_wpct;
my %rba_sos;
my %rba_oeff;
my %rba_deff;
my %rba_pace;
LoadCurrentRanksAndStats($rba_ranking, \%rba_wpct, \%rba_sos, \%rba_oeff, \%rba_deff, \%rba_pace);

foreach my $gid (sort keys %tfg_predictions) {
  next if ($gid =~ /^$target_date/);
  delete $tfg_predictions{$gid};
  delete $rba_predictions{$gid};
}

my $num_tfg = scalar(keys %tfg_predictions);
my $num_rba = scalar(keys %rba_predictions);
exit if (!$num_tfg or !$num_rba);

my %expected_stats;
my ($tfg_sum, $tfg_games, $rba_sum, $rba_games) = (0, 0, 0, 0);
expected();
if ($rba_games) {
  printf "<!-- RBA %5.2f - %5.2f @ %5.2f%% -->\n", $rba_sum, $rba_games - $rba_sum, 100 * $rba_sum / $rba_games;
}
if ($tfg_games) {
  printf "<!-- TFG %5.2f - %5.2f @ %5.2f%% -->\n", $tfg_sum, $tfg_games - $tfg_sum, 100 * $tfg_sum / $tfg_games;
}

exit if (!$rba_games or !$tfg_games);

my $tfg_wl = sprintf "%5.2f - %5.2f", $tfg_sum, $tfg_games - $tfg_sum;
$tfg_wl =~ s/\s/&nbsp;/g;
my $tfg_wp = sprintf "%5.2f%%", 100 * $tfg_sum / $tfg_games;
$tfg_wp =~ s/\s/&nbsp;/g;
my $rba_wl = sprintf "%5.2f - %5.2f", $rba_sum, $rba_games - $rba_sum;
$rba_wl =~ s/\s/&nbsp;/g;
my $rba_wp = sprintf "%5.2f%%", 100 * $rba_sum / $rba_games;
$rba_wp =~ s/\s/&nbsp;/g;

my %games_taken;
my $this_game;

print "<html><head>\n";
print "<link rel=\"stylesheet\" type=\"text/css\" href=\"ncaa.css\" />\n";
print "</head><body>\n";

my %game_of_the_week;
CalculateGugs(\%tfg_predictions, \%rba_predictions, \%tfg_wpct, \%rba_wpct, \%game_of_the_week);
my @games = sort { $game_of_the_week{$b} <=> $game_of_the_week{$a} } keys %game_of_the_week;
$this_game = undef;
foreach my $i (0..$#games) {
  if (!defined($games_taken{$games[$i]})) {
    $this_game = $games[$i];
    last;
  }
}
if (!defined($this_game)) {
  $this_game = $games[0];
}
$games_taken{$this_game} = 1;
printf "<!-- GOTW  $this_game %s -->\n", $game_of_the_week{$this_game};
print_game_info("Game of the Week", $this_game, 1);

#my %ufio;
#unstoppable_immovable(\%ufio);
#@games = sort { $ufio{$b} <=> $ufio{$a} } keys %ufio;
#$this_game = undef;
#foreach my $i (0..$#games) {
#  my $this_gid = substr($games[$i], 0, 18);
#  my $this_gugs = $game_of_the_week{$this_gid};
#  next if (!defined($this_gugs) or ($this_gugs < $MIN_GUGS));
#  if (!defined($games_taken{$this_gid})) {
#    $this_game = $this_gid;
#    last;
#  }
#}
#if (!defined($this_game)) {
#  $this_game = $games[0];
#}
#$games_taken{$this_game} = 1;
#printf "<!-- UFIO  $this_game %s -->\n", $game_of_the_week{$this_game};
#print_game_info("Unstoppable Force/Immovable Object Game", $this_game);
#
#my %scores;
#shootout(\%scores);
#@games = sort { $scores{$b} <=> $scores{$a} } keys %scores;
#$this_game = undef;
#foreach my $i (0..$#games) {
#  my $this_gugs = $game_of_the_week{$games[$i]};
#  next if (!defined($this_gugs) or ($this_gugs < $MIN_GUGS));
#  if (!defined($games_taken{$games[$i]})) {
#    $this_game = $games[$i];
#    last;
#  }
#}
#if (!defined($this_game)) {
#  $this_game = $games[0];
#}
#$games_taken{$this_game} = 1;
#printf "<!-- SHOOT $this_game %s -->\n", $game_of_the_week{$this_game};
#print_game_info("Shootout of the Week", $this_game);

my %disagree;
coin_toss(\%disagree);
@games = sort { $disagree{$b} <=> $disagree{$a} } keys %disagree;
printf "<!-- Disagree on %d games -->\n", scalar(@games);
$this_game = undef;
foreach my $i (0..$#games) {
  my $this_gugs = $game_of_the_week{$games[$i]};
  next if (!defined($this_gugs) or ($this_gugs < $MIN_GUGS));
  if (!defined($games_taken{$games[$i]})) {
    $this_game = $games[$i];
    last;
  }
}
if (!defined($this_game)) {
  foreach my $i (0..$#games) {
    my $this_gugs = $game_of_the_week{$games[$i]};
    next if (!defined($this_gugs));
    if (!defined($games_taken{$games[$i]})) {
      $this_game = $games[$i];
      last;
    }
  }
}
if (!defined($this_game)) {
  $this_game = $games[0];
}
$games_taken{$this_game} = 1;
printf "<!-- COIN  $this_game %s -->\n", $game_of_the_week{$this_game};
print_game_info("Coin Toss Game of the Week", $this_game, 0);

my %team_ids;
foreach my $g (keys %games_taken) {
  if ($g =~ /\d-(\d{4})-(\d{4})/) {
    $team_ids{$1} = 1;
    $team_ids{$2} = 1;
  }
}

my %tag_names;
foreach my $tid (keys %team_ids) {
  my $shortname = $id2name{$tid};
  my $tagname = $names{$shortname};
  if (defined($tagname)) {
    $tag_names{$tagname} = 1;
  }
}

$tag_names{"matchups"} = 1;

my $tags = join(',', keys %tag_names);
$tags =~ s/\&/+/g;
$tags =~ s/St\./State/g;

print "<!-- POSTTITLE|Week $week_number: Saturday Matchups| -->\n";
print "<!-- POSTTAGS|$tags| -->\n";

printf "<br> <br>\n";
printf "<table class=\"rank-table\">\n";
printf "<tr align=\"center\" valign=\"bottom\">\n";
printf "  <th>System</th><th>Expected<br>W - L</th><th>Expected<br>%% Correct</th>\n";
printf "</tr>\n";
printf "<tr class=\"oddRow\">\n";
printf "  <td class=\"teamName\">RBA</td>\n";
printf "  <td class=\"stats\">%s</td>\n", $rba_wl;
printf "  <td class=\"stats\">%s</td>\n", $rba_wp;
printf "</tr>\n";
printf "<tr class=\"evenRow\">\n";
printf "  <td class=\"teamName\">TFG</td>\n";
printf "  <td class=\"stats\">%s</td>\n", $tfg_wl;
printf "  <td class=\"stats\">%s</td>\n", $tfg_wp;
printf "</tr>\n";
printf "</table>\n";

print "</body></html>\n";

sub print_system_matchup($$$$$$$$) {
  my $pred_sys = shift;
  my $home_id = shift;
  my $away_id = shift;
  my $wpct_href = shift;
  my $sos_href = shift;
  my $oeff_href = shift;
  my $deff_href = shift;
  my $pace_href = shift;
  my $home_shortname = $id2name{$home_id};
  if (!defined($home_shortname)) {
    warn "No short name for team $home_id";
    return;
  }
  my $home_name = $names{$home_shortname};
  if (!defined($home_name)) {
    warn "No printable name for team $home_id ($home_shortname)";
    return;
  }
  my $away_shortname = $id2name{$away_id};
  if (!defined($away_shortname)) {
    warn "No short name for team $away_id";
    return;
  }
  my $away_name = $names{$away_shortname};
  if (!defined($away_name)) {
    warn "No printable name for team $away_id ($away_shortname)";
    return;
  }

  my %wpct_rank;
  my %sos_rank;
  my %oeff_rank;
  my %deff_rank;
  my %pace_rank;
  RankValues(\%$wpct_href, \%wpct_rank, 1, undef);
  RankValues(\%$sos_href,  \%sos_rank, 1, undef);
  RankValues(\%$oeff_href, \%oeff_rank, 1, undef);
  RankValues(\%$deff_href, \%deff_rank, 0, undef);
  RankValues(\%$pace_href, \%pace_rank, 1, undef);
  my $home_wpct_rank = $wpct_rank{$home_id};
  my $home_sos_rank = $sos_rank{$home_id};
  my $home_oeff_rank = $oeff_rank{$home_id};
  my $home_deff_rank = $deff_rank{$home_id};
  my $home_pace_rank = $pace_rank{$home_id};
  if (!defined($home_wpct_rank) or !defined($home_sos_rank) or !defined($home_oeff_rank)
      or !defined($home_deff_rank) or !defined($home_pace_rank)) {
    warn "Missing stats for home team $home_name ($home_id)";
    return;
  }
  my $away_wpct_rank = $wpct_rank{$away_id};
  my $away_sos_rank = $sos_rank{$away_id};
  my $away_oeff_rank = $oeff_rank{$away_id};
  my $away_deff_rank = $deff_rank{$away_id};
  my $away_pace_rank = $pace_rank{$away_id};
  if (!defined($away_wpct_rank) or !defined($away_sos_rank) or !defined($away_oeff_rank)
      or !defined($away_deff_rank) or !defined($away_pace_rank)) {
    warn "Missing stats for away team $away_name ($away_id)";
    return;
  }
  printf "<table class=\"rank-table\">\n  <tbody>\n";
  printf "  <tr class=\"$pred_sys\">\n";
  printf "    <th colspan=\"2\">Team</th>\n";
  printf "    <th>WinPct</th>\n";
  printf "    <th colspan=\"2\">SoS</th>\n";
  printf "    <th colspan=\"2\">Off.</th>\n";
  printf "    <th colspan=\"2\">Def.</th>\n";
  printf "    <th colspan=\"2\">Pace</th>\n";
  printf "  </tr>\n";
  printf "  <tr class=\"oddRow\">\n";
  printf "    <td class=\"bigrank\">$home_wpct_rank</td>\n";
  printf "    <td class=\"teamName\">$home_name</td>\n";
  printf "    <td class=\"stats\">%.3f</td>\n", $$wpct_href{$home_id};
  printf "    <td class=\"stats\">%.3f</td>\n", $$sos_href{$home_id};
  printf "    <td class=\"subRank\">$home_sos_rank</td>\n";
  printf "    <td class=\"stats\">$$oeff_href{$home_id}</td>\n";
  printf "    <td class=\"subRank\">$home_oeff_rank</td>\n";
  printf "    <td class=\"stats\">$$deff_href{$home_id}</td>\n";
  printf "    <td class=\"subRank\">$home_deff_rank</td>\n";
  printf "    <td class=\"stats\">$$pace_href{$home_id}</td>\n";
  printf "    <td class=\"subRank\">$home_pace_rank</td>\n";
  printf "  </tr>\n";
  printf "  <tr class=\"evenRow\">\n";
  printf "    <td class=\"bigrank\">$away_wpct_rank</td>\n";
  printf "    <td class=\"teamName\">$away_name</td>\n";
  printf "    <td class=\"stats\">%.3f</td>\n", $$wpct_href{$away_id};
  printf "    <td class=\"stats\">%.3f</td>\n", $$sos_href{$away_id};
  printf "    <td class=\"subRank\">$away_sos_rank</td>\n";
  printf "    <td class=\"stats\">$$oeff_href{$away_id}</td>\n";
  printf "    <td class=\"subRank\">$away_oeff_rank</td>\n";
  printf "    <td class=\"stats\">$$deff_href{$away_id}</td>\n";
  printf "    <td class=\"subRank\">$away_deff_rank</td>\n";
  printf "    <td class=\"stats\">$$pace_href{$away_id}</td>\n";
  printf "    <td class=\"subRank\">$away_pace_rank</td>\n";
  printf "  </tr>\n";
  printf "  </tbody>\n";
  printf "</table>\n";
}

sub print_matchup_stats($$) {
  my $gid = shift;
  my $pred_sys = shift;
  my ($home_id, $away_id);
  if ($gid =~ /\d{8}-(\d{4})-(\d{4})/) {
    $home_id = $1;
    $away_id = $2;
  } else {
    warn "Invalid game ID for matchup: $gid";
    return;
  }
  if ($pred_sys eq "tfg") {
    print_system_matchup($pred_sys, $home_id, $away_id, \%tfg_wpct, \%tfg_sos,
                         \%tfg_oeff, \%tfg_deff, \%tfg_pace);
  } elsif ($pred_sys eq "rba") {
    print_system_matchup($pred_sys, $home_id, $away_id, \%rba_wpct, \%rba_sos,
                         \%rba_oeff, \%rba_deff, \%rba_pace);
  }
}

my $which_first = 0;
sub print_game_info($$$) {
  my $game_title = shift;
  my $gid = shift;
  my $gugs_link = shift;
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

  my $tfg_aref = $tfg_predictions{$gid};
  my $at_vs = "at";
  if ($$tfg_aref[0]) {
    $at_vs = "vs";
  }
  my $gugs = $game_of_the_week{$gid};
  if (!defined($gugs)) {
    warn "No GUGS score for game $gid";
    return;
  }
  my $gugs_line;
  if (defined($gugs_link) and $gugs_link) {
    $gugs_line = sprintf "<div><a href=\"%s\">GUGS Score:</a> %s</div>\n",
                         $GUGS_URL, $gugs;
  } else {
    $gugs_line = "<div>GUGS Score: $gugs</div>\n";
  }
  print "<div><b>$game_title</b></div>\n";
  print "<div>$away_name $at_vs $home_name</div>\n";
  print $gugs_line;
  if ($which_first) {
    print "<br>\n<div><b>Eddie</b></div><br>\n";
    print_matchup_stats($gid, "rba");
    printf "<br>\n<div>%s\n</div><br>\n",
            print_prediction($gid, $home_shortname, $away_shortname, \%rba_predictions);
    print "<br>\n<div><b>Justin</b></div>\n<br>\n";
    print_matchup_stats($gid, "tfg");
    printf "<br>\n<div>%s</div><br>\n",
           print_prediction($gid, $home_shortname, $away_shortname, \%tfg_predictions);
    print "<br>\n";
  } else {
    print "<br>\n<div><b>Justin</b></div><br>\n";
    print_matchup_stats($gid, "tfg");
    printf "<br>\n<div>%s</div>\n",
            print_prediction($gid, $home_shortname, $away_shortname, \%tfg_predictions);
    print "<br>\n<div><b>Eddie</b></div>\n<br>\n";
    print_matchup_stats($gid, "rba");
    printf "<br>\n<div>%s\n</div><br>\n",
            print_prediction($gid, $home_shortname, $away_shortname, \%rba_predictions);
    print "<br>\n";
  }
  $which_first = !$which_first;
}

sub print_prediction($$$$) {
  my $gid = shift;
  my $home_shortname = shift;
  my $away_shortname = shift;
  my $pred_href = shift;

  my $home_print_name = $names{$home_shortname};
  my $away_print_name = $names{$away_shortname};
  my $pred_aref = $$pred_href{$gid};
  if (!defined($pred_aref)) {
    return "--";
  }
  if ($$pred_aref[2] > $$pred_aref[4]) {
    return sprintf "%s %d, %s %d (%.1f%%); %d plays", $home_print_name, $$pred_aref[2],
           $away_print_name, $$pred_aref[4], 100 * $$pred_aref[5], $$pred_aref[6];
  } else {
    return sprintf "%s %d, %s %d (%.1f%%); %d plays", $away_print_name, $$pred_aref[4],
           $home_print_name, $$pred_aref[2], 100 * $$pred_aref[5], $$pred_aref[6];
  }
}

sub calculate_gugs($$$) {
  my $closeness = shift;
  my $goodness = shift;
  my $excitement = shift;
  my @weights = ( 2, 3, 1 );
  my $denominator = 0;
  foreach my $w (@weights) {
    $denominator += ($w * $w);
  }
  $closeness *= $weights[0];
  $goodness *= $weights[1];
  $excitement *= $weights[2];
  my $score = $closeness * $closeness;
  $score += ($goodness * $goodness);
  $score += ($excitement * $excitement);
  return 100 * ($score / $denominator);
}

sub get_game_components($) {
  my $gid = shift;
  my ($closeness, $goodness, $excitement) = (0, 0, 0);
  my ($home_id, $away_id);
  if ($gid =~ /\d{8}-(\d{4})-(\d{4})/) {
    $home_id = $1;
    $away_id = $2;
  } else {
    warn "Malformed GID: $gid";
    return ($closeness, $goodness, $excitement);
  }
  # There are three elements:
  # 1) Closeness (close to 0.500)
  # 2) Goodness (winning percent of the teams)
  # 3) Excitement (high scoring)
  # First, get the prediction for each system.
  my $tfg_aref = $tfg_predictions{$gid};
  my $rba_aref = $rba_predictions{$gid};
  if (!defined($rba_aref) or !defined($tfg_aref)) {
    warn "Missing prediction for game $gid";
    return ($closeness, $goodness, $excitement);
  }
  # Base it on the odds of the home team winning
  my $tfg_home_win = $$tfg_aref[5];
  if ($$tfg_aref[4] > $$tfg_aref[2]) {
    $tfg_home_win = 1 - $tfg_home_win;
  }
  my $rba_home_win = $$rba_aref[5];
  if ($$rba_aref[4] > $$rba_aref[2]) {
    $rba_home_win = 1 - $rba_home_win;
  }
  # $avg_home_win will be in the range [0,1]
  my $avg_home_win = ($tfg_home_win + $rba_home_win) / 2;
  # Now in the range [0,0.5] (distance from a 0.500 game)
  $avg_home_win = abs(0.5 - $avg_home_win);
  # Now in the range [0,1] (2x distance from a 0.500 game)
  $avg_home_win *= 2;
  # Closeness is now how close it is to 0.500
  $closeness = 1 - $avg_home_win;
  # Goodness is the combined winning percentage
  my $tfg_home_wpct = $tfg_wpct{$home_id};
  my $tfg_away_wpct = $tfg_wpct{$away_id};
  if (!defined($tfg_home_wpct) or !defined($tfg_away_wpct)) {
    warn "Missing winning percent for TFG for $home_id or $away_id";
    return ($closeness, $goodness, $excitement); 
  }
  my $rba_home_wpct = $rba_wpct{$home_id};
  my $rba_away_wpct = $rba_wpct{$away_id};
  if (!defined($rba_home_wpct) or !defined($tfg_away_wpct)) {
    warn "Missing winning percent for RBA for $home_id or $away_id";
    return ($closeness, $goodness, $excitement); 
  }
  $goodness  = ($tfg_home_wpct + $tfg_away_wpct);
  $goodness += ($rba_home_wpct + $rba_away_wpct);
  $goodness /= 4;
  # Excitement is the score
  # Combined game scores are in the range [0,80] for our purposes
  my $tfg_score = ($$tfg_aref[2] + $$tfg_aref[4]) / 80;
  my $rba_score = ($$rba_aref[2] + $$rba_aref[4]) / 80;
  $excitement = ($tfg_score + $rba_score) / 2;
  return ($closeness, $goodness, $excitement); 
}

sub unstoppable_immovable($) {
  my $game_href = shift;
  foreach my $gid (keys %tfg_predictions) {
    my $tfg_aref = $tfg_predictions{$gid};
    my $rba_aref = $rba_predictions{$gid};
    next if (!defined($rba_aref));
    my ($home_id, $away_id);
    if ($gid =~ /\d{8}-(\d{4})-(\d{4})/) {
      $home_id = $1;
      $away_id = $2;
    } else {
      warn "Invalid game ID: $gid";
      next;
    }
    my $tfg_home_off = $tfg_oeff{$home_id};
    my $tfg_home_def = $tfg_deff{$home_id};
    my $tfg_away_off = $tfg_oeff{$away_id};
    my $tfg_away_def = $tfg_deff{$away_id};
    my $rba_home_off = $rba_oeff{$home_id};
    my $rba_home_def = $rba_deff{$home_id};
    my $rba_away_off = $rba_oeff{$away_id};
    my $rba_away_def = $rba_deff{$away_id};
    next if (!defined($tfg_away_def) or !defined($rba_away_def));
    next if (!defined($tfg_home_def) or !defined($rba_home_def));
    next if ($tfg_away_def or $rba_away_def);
    next if ($tfg_home_def or $rba_home_def);
    my $home_diff = ($tfg_home_off / $tfg_away_def) + ($rba_home_off / $rba_away_def);
    my $away_diff = ($tfg_away_off / $tfg_home_def) + ($rba_away_off / $rba_home_def);
    $$game_href{$gid . "-H"} = ($home_diff / 2);
    $$game_href{$gid . "-A"} = ($away_diff / 2);
  }
}

sub shootout($) {
  my $game_href = shift;
  foreach my $gid (keys %tfg_predictions) {
    my $tfg_aref = $tfg_predictions{$gid};
    my $rba_aref = $rba_predictions{$gid};
    next if (!defined($rba_aref));
    my $sum = $$tfg_aref[2] + $$tfg_aref[4];
    $sum += $$rba_aref[2] + $$rba_aref[4];
    $$game_href{$gid} = $sum;
  }
}

sub coin_toss($) {
  my $game_href = shift;
  foreach my $gid (keys %tfg_predictions) {
    my $tfg_aref = $tfg_predictions{$gid};
    my $rba_aref = $rba_predictions{$gid};
    next if (!defined($rba_aref));
    if ($$tfg_aref[2] > $$tfg_aref[4]) {
      if ($$rba_aref[2] < $$rba_aref[4]) {
#        print "$gid TFG @$tfg_aref RBA @$rba_aref\n";
        $$game_href{$gid} = $$tfg_aref[5] + $$rba_aref[5];
      }
    } elsif ($$rba_aref[2] > $$rba_aref[4]) {
#      print "$gid TFG @$tfg_aref RBA @$rba_aref\n";
      $$game_href{$gid} = $$tfg_aref[5] + $$rba_aref[5];
    }
  }
}

sub expected() {
  foreach my $gid (keys %tfg_predictions) {
    my $tfg_aref = $tfg_predictions{$gid};
    $tfg_sum += $$tfg_aref[5];
    ++$tfg_games;
    my $rba_aref = $rba_predictions{$gid};
    next if (!defined($rba_aref));
    $rba_sum += $$rba_aref[5];
    ++$rba_games;
  }
}

sub usage($) {
  my $p = shift;
  my @parts = split(/\//, $p);
  $p = pop(@parts);
  print STDERR "\n";
  print STDERR "Usage: $p <week_number> <date> <tfg_predict> <tfg_ranking> <rba_predict> <rba_ranking>\n";
  print STDERR "\n";
  exit 1;
}
