#!/usr/bin/perl -w

use TempoFree;
use strict;

sub print_team_line($$);
sub get_raw_projected_wins($$);
sub get_raw_projected_losses($$);
sub get_projected_wins($$);
sub get_projected_losses($$);
sub get_projected_conf_wins($$);
sub get_projected_conf_losses($$);
sub print_game_info($);
sub full_lookup_team($);   # ID->full name
sub printable_name($);        # name->full name
sub get_rank($);
sub winpct($$);
sub usage();

my $summary_file = shift(@ARGV);
my $prediction_file = shift(@ARGV);
my $rankings_file = shift(@ARGV);
my $pred_system = shift(@ARGV);
my $week_number = shift(@ARGV);
my $two_saturdays = shift(@ARGV);
my $last_saturday = shift(@ARGV);
my $this_saturday = shift(@ARGV);
my $current_date = shift(@ARGV);
my $post_time = shift(@ARGV);
my $conference_list = shift(@ARGV);

usage() if (!defined($pred_system));

if (($pred_system ne "rba") and ($pred_system ne "tfg")) {
  print STDERR "Invalid prediction system: \"$pred_system\"\n";
  usage();
}
my $pred_name = uc $pred_system;

my $numeric_date = $current_date;
$numeric_date =~ s/-//g;
my $spec_year = substr($numeric_date, 0, 4);

# Create the mappings of
# 1) team ID -> short name
# 2) team ID -> Conference
# 3) (conference, subconference) -> set of team IDs
my %id2name;               # {team_id}[name]
my %conf_teams;            # {conf}{subconf}{team_id}
my %team_confs;            # {team_id}[conf]
my %is_bcs;                # {team_id}[is_bcs]
LoadConferencesForYear($spec_year, \%id2name, \%team_confs, \%conf_teams, \%is_bcs);

# By default print all the conferences. If the user has specified a subset of
# them to print, put that in the array.
my @conferences = sort keys %conf_teams;
if (defined($conference_list) and length($conference_list)) {
  @conferences = split(/,/, $conference_list);
} else {
  $conference_list = "All Conferences";
}

# Create the mapping of
# 1) short name -> printable name
my %names;
LoadPrintableNames(\%names);

my %per_year_wins;         # {team_id}{year}[wins]
my %per_year_conf_wins;    # {team_id}{year}[wins]
my %per_year_losses;       # {team_id}{year}[losses]
my %per_year_conf_losses;  # {team_id}{year}[losses]
my %per_year_wpct;         # {team_id}{year}[wpct]
my %per_year_conf_wpct;    # {team_id}{year}[wpct]

# Go through the summary file and build the mappings of existing game results to
# teams on a per-year basis.
my %allyears;
my %allgames;
my @last_week;
my @this_week;
open(SUMMARY, "$summary_file") or die "Cannot open $summary_file: $!";
while(<SUMMARY>) {
  next if (/^#/);
  my @g = split(/,/);
  $allgames{$g[2]} = \@g;
  my $week = $g[0];
  my $game_date = $g[1];
  next if ($game_date > $this_saturday);
  if (($game_date > $two_saturdays) and ($game_date <= $last_saturday)) {
    push(@last_week, $g[2]);
  } elsif (($game_date > $last_saturday) and ($game_date <= $this_saturday)) {
    push(@this_week, $g[2]);
  }
  # Since each year has 52w1d in it (leap years have 52w2d) and since week 0 is
  # the first week of the 2000-01 season, this next statement is good for about
  # 40 years' worth of football seasons.
  my $year = int($week / 52) + 2000;
  $allyears{$year} = 1;
  my $homeid = $g[5];
  my $homescore = $g[7];
  my $awayid = $g[8];
  my $awayscore = $g[10];
  my $homeconf = $team_confs{$homeid};
  my $awayconf = $team_confs{$awayid};
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
  # If we know the conference of both teams and they're the same, add this to
  # the conference standings.
  if (defined($homeconf) and defined($awayconf) and ($homeconf eq $awayconf)) {
    $per_year_conf_wins{$homeid}{$year} += $hwin;
    $per_year_conf_losses{$homeid}{$year} += $hloss;
    $per_year_conf_wins{$awayid}{$year} += $awin;
    $per_year_conf_losses{$awayid}{$year} += $aloss;
  }
}
close(SUMMARY);

# Go through and put a defined value in each per-team-per-year register.
foreach my $teamid (keys %id2name) {
  if (!defined($per_year_wins{$teamid}{$spec_year})) {
    $per_year_wins{$teamid}{$spec_year} = 0;
  }
  if (!defined($per_year_losses{$teamid}{$spec_year})) {
    $per_year_losses{$teamid}{$spec_year} = 0;
  }
  if (!defined($per_year_conf_wins{$teamid}{$spec_year})) {
    $per_year_conf_wins{$teamid}{$spec_year} = 0;
  }
  if (!defined($per_year_conf_losses{$teamid}{$spec_year})) {
    $per_year_conf_losses{$teamid}{$spec_year} = 0;
  }
}

# Now that we have the (current) overall and conference wins and losses,
# calculate the winning percentage for each team.
foreach my $teamid (keys %per_year_wins) {
  my $year_win_href = $per_year_wins{$teamid};
  my $year_loss_href = $per_year_losses{$teamid};
  my $year_conf_win_href = $per_year_conf_wins{$teamid};
  my $year_conf_loss_href = $per_year_conf_losses{$teamid};
  if (!defined($year_win_href)) {
    warn "No win data for team $teamid";
    next;
  }
  if (!defined($year_loss_href)) {
    warn "No loss data for team $teamid";
    next;
  }
  $per_year_wpct{$teamid}{$spec_year} = winpct($$year_win_href{$spec_year},
                                              $$year_loss_href{$spec_year});
  $per_year_conf_wpct{$teamid}{$spec_year} = winpct($$year_conf_win_href{$spec_year},
                                                   $$year_conf_loss_href{$spec_year});
}

# Parse the predictions for each team.
my %proj_wins;         # {team}[wins]
my %proj_losses;       # {team}[losses]
my %proj_conf_wins;    # {team}[wins]
my %proj_conf_losses;  # {team}[losses]
my %gids;
open(GAMES, "$prediction_file") or die "Cannot open $prediction_file for reading: $!";
while(<GAMES>) {
  next unless(/^PREDICT,/);
  chomp;
  s/\ //g;
  @_ = split(/,/);
  next if (scalar(@_) < 9);
  my $gid = $_[2];
  next if (defined($gids{$gid}));
  $gids{$gid} = 1;
  my $d = substr($gid, 0, 8);
  # If the date is prior to the date we're examining, skip the prediction.
  next if ($d < $numeric_date);
  my $monthday = substr($d, 4, 4);
  # If this is before October or after mid-December, skip the prediction.
#  next if ($monthday < 1000 or $monthday > 1215);
  my $game_year = substr($d, 0, 4);
  # If this game isn't the same year as the one we're examining, skip it.
  next if ($game_year != $spec_year);
  my $t1id = $_[4];
  my $t2id = $_[6];
  my $t1c = $team_confs{$t1id};
  my $t2c = $team_confs{$t2id};
  my ($hwin, $hloss, $awin, $aloss);
  my $wpct = $_[8];
  if ($wpct < 500) {
    $wpct = 1000 - $wpct;
  }
  my $t1wp = $wpct;
  if ($_[5] < $_[7]) {
    # Away team actually winning.
    $t1wp = 1000 - $wpct;
  }
  $hwin = $aloss = ($t1wp / 1000);
  $awin = $hloss = 1 - ($t1wp / 1000);
  $proj_wins{$t1id} += $hwin;
  $proj_losses{$t1id} += $hloss;
  $proj_wins{$t2id} += $awin;
  $proj_losses{$t2id} += $aloss;
  if (defined($t1c) and defined($t2c) and ($t1c eq $t2c)) {
    $proj_conf_wins{$t1id} += $hwin;
    $proj_conf_losses{$t1id} += $hloss;
    $proj_conf_wins{$t2id} += $awin;
    $proj_conf_losses{$t2id} += $aloss;
  }
}
close(GAMES);

# Go through and put a defined value in each per-team-projection register.
foreach my $teamid (keys %id2name) {
  if (!defined($proj_wins{$teamid})) {
    $proj_wins{$teamid} = 0;
  }
  if (!defined($proj_losses{$teamid})) {
    $proj_losses{$teamid} = 0;
  }
  if (!defined($proj_conf_wins{$teamid})) {
    $proj_conf_wins{$teamid} = 0;
  }
  if (!defined($proj_conf_losses{$teamid})) {
    $proj_conf_losses{$teamid} = 0;
  }
}

my %teamwpct;
my %teamoff;
my %teamdef;
my %teampace;
my $rc = LoadCurrentRanksAndStats($rankings_file, \%teamwpct, undef, \%teamoff,
                                  \%teamdef, \%teampace);
if ($rc) {
  die "Error getting current rankings and stats from $rankings_file";
}

my %teamrank;
RankValues(\%teamwpct, \%teamrank, 1, \%team_confs);

# We sort based on 7 criteria:
# 1) Projected conference winpct
# 2) Most projected conference wins
# 3) Fewest projected conference losses
# 4) Projected total winpct
# 5) Most projected total wins
# 6) Fewest projected conference losses
# 7) Highest current rank
sub standings_sort {
  my $a_conf_wins = get_projected_conf_wins($a, $spec_year);
  my $a_conf_losses = get_projected_conf_losses($a, $spec_year);
  my $a_total_wins = get_projected_wins($a, $spec_year);
  my $a_total_losses = get_projected_losses($a, $spec_year);
  my $b_conf_wins = get_projected_conf_wins($b, $spec_year);
  my $b_conf_losses = get_projected_conf_losses($b, $spec_year);
  my $b_total_wins = get_projected_wins($b, $spec_year);
  my $b_total_losses = get_projected_losses($b, $spec_year);
  my $a_conf_wpct = 0;
  if ($a_conf_wins) {
    $a_conf_wpct = $a_conf_wins / ($a_conf_wins + $a_conf_losses);
  }
  my $a_wpct = 0;
  if ($a_total_wins) {
    $a_wpct = $a_total_wins / ($a_total_wins + $a_total_losses);
  }
  my $b_conf_wpct = 0;
  if ($b_conf_wins) {
    $b_conf_wpct = $b_conf_wins / ($b_conf_wins + $b_conf_losses);
  }
  my $b_wpct = 0;
  if ($b_total_wins) {
    $b_wpct = $b_total_wins / ($b_total_wins + $b_total_losses);
  }
  my $a_rank = get_rank($a);
  my $b_rank = get_rank($b);
  # We sort based on 7 criteria:
  # 1) Projected conference winpct
  # 2) Most projected conference wins
  # 3) Fewest projected conference losses
  # 4) Projected total winpct
  # 5) Most projected total wins
  # 6) Fewest projected conference losses
  # 7) Highest current rank
  return ( ($b_conf_wpct <=> $a_conf_wpct) or ($b_conf_wins <=> $a_conf_wins) or
           ($a_conf_losses <=> $b_conf_losses) or ($b_wpct <=> $a_wpct) or
           ($b_total_wins <=> $a_total_wins) or
           ($a_total_losses <=> $b_total_losses) or ($a_rank <=> $b_rank)
         );
}
my $output = "";

# Dump all this to an HTML page.
$output .= sprintf "<link rel=\"stylesheet\" type=\"text/css\" href=\"ncaa.css\" />\n";
$output .= sprintf "<!-- POSTTITLE|Week $week_number $pred_name Projections: $conference_list| -->\n";
$output .= sprintf "<!-- POSTTAGS|projections, $conference_list| -->\n";
$output .= sprintf "<!-- POSTTIME|$post_time| -->\n";
my %conference_champions;
foreach my $conference (@conferences) {
  next if ($conference eq "FCS");
  if (!defined($conf_teams{$conference})) {
    warn "Invalid conference name: \"$conference\"";
    next;
  }
  $output .= sprintf "<table class=\"conf-table\">\n";
  $output .= sprintf "  <tr class=\"$pred_system\"><th colspan=9 class=\"confName\">$conference</th></tr>\n";
  my $href = $conf_teams{$conference};
  my @these_champs;
  foreach my $subconf (sort keys %$href) {
    if (length($subconf)) {
      $output .= sprintf "  <tr class=\"$pred_system\"><th colspan=9 class=\"subConfName\">$subconf</th></tr>\n";
    }
    my $subconf_href = $$href{$subconf};
    $output .= sprintf "<tr><th valign=\"bottom\" rowspan=2 colspan=2>Team</th>";
    $output .= sprintf "<th class=\"divide\" colspan=2>Conference</th>";
    $output .= sprintf "<th class=\"divide\" colspan=2>Overall</th>";
    $output .= sprintf "<th class=\"divide\" colspan=3>Adjusted</th></tr>\n";
    $output .= sprintf "<tr><th class=\"divide\">Now</th><th class=\"divide\">Projected</th>";
    $output .= sprintf "<th class=\"divide\">Now</th><th class=\"divide\">Projected</th>";
    $output .= sprintf "<th class=\"divide\">Off.</th><th class=\"divide\">Def.</th>";
    $output .= sprintf "<th class=\"divide\">Pace</th></tr>\n";
    my $cnt = 0;
    # Sort the standings by existing conference win percentage.
    my $first_team = undef;
    foreach my $tid (sort standings_sort keys %$subconf_href) {
      if (!defined($first_team)) {
        $first_team = $tid;
      }
      print_team_line($tid, ++$cnt);
    }
    push(@these_champs, $first_team);
  }
  my @sorted_champs = sort { $teamwpct{$b} <=> $teamwpct{$a} } @these_champs;
  $conference_champions{$conference} = $sorted_champs[0];
  $output .= sprintf "<tr><td class=\"disclaimer\" colspan=9>Projected records may not "
        . "sum to total number of actual games due to rounding errors.</td></tr>\n";
  # Print upcoming games here.
  $output .= sprintf "<tr><td colspan=9><b>Last Week</b><br />\n";
  foreach my $gid (@last_week) {
    my ($h, $a);
    if ($gid =~ /\d{8}-(\d{4})-(\d{4})/) {
      $h = $1;
      $a = $2;
    } else { next; }
    next unless ($team_confs{$h} eq $conference or $team_confs{$a} eq $conference);
    $output .= print_game_info($gid);
  }
  $output .= sprintf "<br />\n";
  $output .= sprintf "<b>This Week</b><br />\n";
  foreach my $gid (@this_week) {
    my ($h, $a);
    if ($gid =~ /\d{8}-(\d{4})-(\d{4})/) {
      $h = $1;
      $a = $2;
    } else { next; }
    next unless ($team_confs{$h} eq $conference or $team_confs{$a} eq $conference);
    $output .= print_game_info($gid);
  }
  $output .= sprintf "</td></tr>\n";
  $output .= sprintf "</table>\n";
  $output .= sprintf "<br/>\n";
}
$output .= sprintf "<div><i>All records through games of $current_date</i><br />\n";
$output .= sprintf "<i>Follow us on Twitter at "
        . "<a href=\"http://twitter.com/TFGridiron\">\@TFGridiron</a> "
        . "and <a href=\"http://twitter.com/TFGLiveOdds\">\@TFGLiveOdds</a>.</i></div>\n";
# Now actually print things out.
print "<b>Projected conference champions</b>\n";
print "<ul>\n";
foreach my $conf (sort keys %conference_champions) {
  printf "  <li><b>%s</b>: %s</li>\n", $conf, full_lookup_team($conference_champions{$conf});
}
print "</ul>\n";
print "<div>Full projected conference standings after the jump.</div>\n<br />\n";
print "<!--more-->\n";
print "$output\n";

sub print_team_line($$) {
  my $tid = shift;
  my $is_odd = shift;
  my $rowclass = "evenRow";
  if ($is_odd % 2) {
    $rowclass = "oddRow";
  }
  my $p_wins = get_projected_wins($tid, $spec_year);
  my $p_losses = get_projected_losses($tid, $spec_year);
  my $p_conf_wins = get_projected_conf_wins($tid, $spec_year);
  my $p_conf_losses = get_projected_conf_losses($tid, $spec_year);
  my $remain_wpct = winpct(get_raw_projected_wins($tid, $spec_year),
                           get_raw_projected_losses($tid, $spec_year));
  my $ronzook = "nz";
  if ((6 == ($per_year_wins{$tid}{$spec_year} + $per_year_losses{$tid}{$spec_year}))
      and ($per_year_losses{$tid}{$spec_year} <= 1)) {
    if ($remain_wpct < 0.5) {
      $ronzook = "RZ";
    } elsif ($remain_wpct < 0.55) {
      $ronzook = "rz";
    }
  }
  $output .= sprintf "<!-- Team $tid -->\n";
  $output .= sprintf "<!-- PROJECTED,%s,%d,%d,%d,%.3f,%.2f,%.2f,%.3f,%.3f -->\n",
         $ronzook, $tid, $per_year_wins{$tid}{$spec_year}, $per_year_losses{$tid}{$spec_year},
         $per_year_wpct{$tid}{$spec_year}, get_raw_projected_wins($tid, $spec_year),
         get_raw_projected_losses($tid, $spec_year), $remain_wpct,
         $remain_wpct - $per_year_wpct{$tid}{$spec_year};

  $output .= sprintf "<tr class=\"$rowclass\">";
  $output .= sprintf "  <td><span class=\"rank\">%d</span></td>\n", get_rank($tid);
  $output .= sprintf "  <td class=\"teamName\">%s</td>\n", full_lookup_team($tid);
  $output .= sprintf "  <td class=\"stats\">%2d&nbsp;-&nbsp;%2d&nbsp;&nbsp;&nbsp;%.3f</td>\n",
    $per_year_conf_wins{$tid}{$spec_year}, $per_year_conf_losses{$tid}{$spec_year},
    $per_year_conf_wpct{$tid}{$spec_year};
  $output .= sprintf "  <td class=\"stats\">%2d&nbsp;-&nbsp;%2d&nbsp;&nbsp;&nbsp;%.3f</td>\n",
     $p_conf_wins, $p_conf_losses, winpct($p_conf_wins, $p_conf_losses);
  $output .= sprintf "  <td class=\"stats\">%2d&nbsp;-&nbsp;%2d&nbsp;&nbsp;&nbsp;%.3f</td>\n",
    $per_year_wins{$tid}{$spec_year}, $per_year_losses{$tid}{$spec_year},
    $per_year_wpct{$tid}{$spec_year};
  $output .= sprintf "  <td class=\"stats\">%2d&nbsp;-&nbsp;%2d&nbsp;&nbsp;&nbsp;%.3f</td>\n",
         $p_wins, $p_losses, winpct($p_wins, $p_losses);
  $output .= sprintf "  <td class=\"stats\">%4.1f</td>\n", get_offense($tid);
  $output .= sprintf "  <td class=\"stats\">%4.1f</td>\n", get_defense($tid);
  $output .= sprintf "  <td class=\"stats\">%5.1f</td>\n", get_pace($tid);
  $output .= sprintf "</tr>\n";
}

sub get_raw_projected_wins($$) {
  my $tid = shift;
  my $year = shift;
  my $p_wins = $proj_wins{$tid};
  $p_wins = 0 if (!defined($p_wins));
  return $p_wins;
}

sub get_raw_projected_losses($$) {
  my $tid = shift;
  my $year = shift;
  my $p_losses = $proj_losses{$tid};
  $p_losses = 0 if (!defined($p_losses));
  return $p_losses;
}

sub get_projected_wins($$) {
  my $tid = shift;
  my $year = shift;
  my $p_wins = get_raw_projected_wins($tid, $year);
  my $a_wins = $per_year_wins{$tid}{$year};
  $a_wins = 0 if (!defined($a_wins));
  return sprintf "%d", int($p_wins + $a_wins + 0.5);
}

sub get_projected_losses($$) {
  my $tid = shift;
  my $year = shift;
  my $p_losses = get_raw_projected_losses($tid, $year);
  my $a_losses = $per_year_losses{$tid}{$year};
  $a_losses = 0 if (!defined($a_losses));
  return sprintf "%d", int($p_losses + $a_losses + 0.5);
}

sub get_projected_conf_wins($$) {
  my $tid = shift;
  my $year = shift;
  my $p_wins = $proj_conf_wins{$tid};
  $p_wins = 0 if (!defined($p_wins));
  my $a_wins = $per_year_conf_wins{$tid}{$year};
  $a_wins = 0 if (!defined($a_wins));
  return sprintf "%d", int($p_wins + $a_wins + 0.5);
}

sub get_projected_conf_losses($$) {
  my $tid = shift;
  my $year = shift;
  my $p_losses = $proj_conf_losses{$tid};
  $p_losses = 0 if (!defined($p_losses));
  my $a_losses = $per_year_conf_losses{$tid}{$year};
  $a_losses = 0 if (!defined($a_losses));
  return sprintf "%d", int($p_losses + $a_losses + 0.5);
}

sub get_rank($) {
  my $tid = shift;
  return -1 if (!defined($teamrank{$tid}));
  return $teamrank{$tid};
}

sub get_offense($) {
  my $tid = shift;
  return -2 if (!defined($teamoff{$tid}));
  return $teamoff{$tid};
}

sub get_defense($) {
  my $tid = shift;
  return -2 if (!defined($teamdef{$tid}));
  return $teamdef{$tid};
}

sub get_pace($) {
  my $tid = shift;
  return -2 if (!defined($teampace{$tid}));
  return $teampace{$tid};
}

sub lookup_team($) {
  my $id = shift;
  return undef if (!defined($id));
  return undef if (!defined($id2name{$id}));
  return $id2name{$id};
}

sub print_game_info($) {
  my $gid = shift;
  my $aref = $allgames{$gid};
  return "" if (!defined($aref));
  my $home_id = $$aref[5];
  my $home_rk = $teamrank{$home_id};
  my $home_pt = $$aref[7];
  my $away_id = $$aref[8];
  my $away_rk = $teamrank{$away_id};
  my $away_pt = $$aref[10];
  my $home_name = full_lookup_team($home_id);
  my $away_name = full_lookup_team($away_id);
  my $is_neutral = ($$aref[3] eq "NEUTRAL");
  if ($home_pt or $away_pt) {
    if ($home_pt > $away_pt) {
      return "($home_rk) $home_name $home_pt, ($away_rk) $away_name $away_pt<br />\n";
    } else {
      return "($away_rk) $away_name $away_pt, ($home_rk) $home_name $home_pt<br />\n";
    }
  } else {
    my $at_vs = "at";
    if ($is_neutral) { $at_vs = "vs"; }
    return "($away_rk) $away_name $at_vs ($home_rk) $home_name<br />\n";
  }
  return "";
}

# ID->full name
sub full_lookup_team($) {
  my $id = shift;
  my $name = lookup_team($id);
  return printable_name($name);
}

# name->full name
sub printable_name($) {
  my $n = shift;
  return "(unknown)" if (!defined($n));
  return $n if (!defined($names{$n}));
  return $names{$n};
}

sub winpct($$) {
  my $wins = shift;
  my $losses = shift;
  return 0 if (!defined($wins) or !defined($losses));
  return 0 unless ($wins or $losses);
  return $wins / ($wins + $losses);
}

sub usage() {
  print STDERR "\n";
  print STDERR "Usage: $0 <summary> <predictions> <rankings> <rba|tfg> "
               . "<week_number> <current_date> [conference_list]\n";
  print STDERR "\n";
  exit 1;
}
