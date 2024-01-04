#!/usr/bin/perl -w

use TempoFree;
use strict;

sub get_projected_record($$$$$$);
sub print_team_line($$$);
sub get_raw_projected_wins($$);
sub get_raw_projected_losses($$);
sub get_projected_wins($$$);
sub get_projected_losses($$$);
sub get_projected_conf_wins($$$);
sub get_projected_conf_losses($$$);
sub print_game_info($);
sub full_lookup_team($);   # ID->full name
sub printable_name($);        # name->full name
sub get_rank($$);
sub winpct($$);
sub usage();

my $summary_file = shift(@ARGV);
my $tfg_prediction_file = shift(@ARGV);
my $tfg_rankings_file = shift(@ARGV);
my $rba_prediction_file = shift(@ARGV);
my $rba_rankings_file = shift(@ARGV);
my $week_number = shift(@ARGV);
my $two_saturdays = shift(@ARGV);
my $last_saturday = shift(@ARGV);
my $this_saturday = shift(@ARGV);
my $current_date = shift(@ARGV);
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

my %allgames;
LoadResults(\%allgames);

my %per_year_wins;         # {team_id}{year}[wins]
my %per_year_conf_wins;    # {team_id}{year}[wins]
my %per_year_losses;       # {team_id}{year}[losses]
my %per_year_conf_losses;  # {team_id}{year}[losses]
GetAllTeamRecords(\%allgames, \%team_confs, \%per_year_wins, \%per_year_conf_wins,
                  \%per_year_losses, \%per_year_conf_losses);
my %per_year_wpct;         # {team_id}{year}[wpct]
my %per_year_conf_wpct;    # {team_id}{year}[wpct]

# Go through the summary file and build the mappings of existing game results to
# teams on a per-year basis.
my @last_week;
my @this_week;
foreach my $gid (keys %allgames) {
  my $href = $allgames{$gid};
  my $game_date = $$href[1];
  next if ($game_date > $this_saturday);
  if (($game_date > $two_saturdays) and ($game_date <= $last_saturday)) {
    push(@last_week, $gid);
  } elsif (($game_date > $last_saturday) and ($game_date <= $this_saturday)) {
    push(@this_week, $gid);
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

# Parse the predictions for each team (TFG)
my %tfg_proj_wins;         # {team}[wins]
my %tfg_proj_losses;       # {team}[losses]
my %tfg_proj_conf_wins;    # {team}[wins]
my %tfg_proj_conf_losses;  # {team}[losses]
get_projected_record($tfg_prediction_file, \%conf_href, \%tfg_proj_wins,
                     \%tfg_proj_losses, \%tfg_proj_conf_wins, \%tfg_proj_conf_losses);

# Parse the predictions for each team (RBA)
my %rba_proj_wins;         # {team}[wins]
my %rba_proj_losses;       # {team}[losses]
my %rba_proj_conf_wins;    # {team}[wins]
my %rba_proj_conf_losses;  # {team}[losses]
get_projected_record($rba_prediction_file, \%conf_href, \%rba_proj_wins,
                    \%rba_proj_losses, \%rba_proj_conf_wins, \%rba_proj_conf_losses);

my %tfg_teamwpct;
my %tfg_teamoff;
my %tfg_teamdef;
my %tfg_teampace;
my $rc = LoadCurrentRanksAndStats($tfg_rankings_file, \%tfg_teamwpct, undef,
                                  \%tfg_teamoff, \%tfg_teamdef, \%tfg_teampace);
if ($rc) {
  die "Error getting current rankings and stats from $tfg_rankings_file";
}
my %tfg_teamrank;
RankValues(\%tfg_teamwpct, \%tfg_teamrank, 1, \%team_confs);

my %rba_teamwpct;
my %rba_teamoff;
my %rba_teamdef;
my %rba_teampace;
my $rc = LoadCurrentRanksAndStats($rba_rankings_file, \%rba_teamwpct, undef,
                                  \%rba_teamoff, \%rba_teamdef, \%rba_teampace);
if ($rc) {
  die "Error getting current rankings and stats from $rba_rankings_file";
}
my %rba_teamrank;
RankValues(\%rba_teamwpct, \%rba_teamrank, 1, \%team_confs);

# We sort based on 7 criteria:
# 1) Projected conference winpct
# 2) Most projected conference wins
# 3) Fewest projected conference losses
# 4) Projected total winpct
# 5) Most projected total wins
# 6) Fewest projected conference losses
# 7) Highest current rank
sub tfg_standings_sort {
  my $a_conf_wins = get_projected_conf_wins($a, $spec_year, \%tfg_proj_conf_wins);
  my $a_conf_losses = get_projected_conf_losses($a, $spec_year, \%tfg_proj_conf_losses);
  my $a_total_wins = get_projected_wins($a, $spec_year, \%tfg_proj_wins);
  my $a_total_losses = get_projected_losses($a, $spec_year, \%tfg_proj_losses);
  my $b_conf_wins = get_projected_conf_wins($b, $spec_year, \%tfg_proj_conf_wins);
  my $b_conf_losses = get_projected_conf_losses($b, $spec_year, \%tfg_proj_conf_losses);
  my $b_total_wins = get_projected_wins($b, $spec_year, \%tfg_proj_wins);
  my $b_total_losses = get_projected_losses($b, $spec_year, \%tfg_proj_losses);
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
  my $a_rank = get_rank($a, \%tfg_teamrank);
  my $b_rank = get_rank($b, \%tfg_teamrank);
  return ( ($b_conf_wpct <=> $a_conf_wpct) or ($b_conf_wins <=> $a_conf_wins) or
           ($a_conf_losses <=> $b_conf_losses) or ($b_wpct <=> $a_wpct) or
           ($b_total_wins <=> $a_total_wins) or
           ($a_total_losses <=> $b_total_losses) or ($a_rank <=> $b_rank)
         );
}
sub rba_standings_sort {
  my $a_conf_wins = get_projected_conf_wins($a, $spec_year, \%rba_proj_conf_wins);
  my $a_conf_losses = get_projected_conf_losses($a, $spec_year, \%rba_proj_conf_losses);
  my $a_total_wins = get_projected_wins($a, $spec_year, \%rba_proj_wins);
  my $a_total_losses = get_projected_losses($a, $spec_year, \%rba_proj_losses);
  my $b_conf_wins = get_projected_conf_wins($b, $spec_year, \%rba_proj_conf_wins);
  my $b_conf_losses = get_projected_conf_losses($b, $spec_year, \%rba_proj_conf_losses);
  my $b_total_wins = get_projected_wins($b, $spec_year, \%rba_proj_wins);
  my $b_total_losses = get_projected_losses($b, $spec_year, \%rba_proj_losses);
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
  my $a_rank = get_rank($a, \%rba_teamrank);
  my $b_rank = get_rank($b, \%rba_teamrank);
  return ( ($b_conf_wpct <=> $a_conf_wpct) or ($b_conf_wins <=> $a_conf_wins) or
           ($a_conf_losses <=> $b_conf_losses) or ($b_wpct <=> $a_wpct) or
           ($b_total_wins <=> $a_total_wins) or
           ($a_total_losses <=> $b_total_losses) or ($a_rank <=> $b_rank)
         );
}
my $output = "";

# Dump all this to an HTML page.
$output .= sprintf "<link rel=\"stylesheet\" type=\"text/css\" href=\"ncaa.css\" />\n";
$output .= sprintf "<!-- POSTTITLE|Week $week_number Projections: $conference_list| -->\n";
$output .= sprintf "<!-- POSTTAGS|projections, $conference_list| -->\n";
my %tfg_conference_champions;
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
      print_team_line($tid, ++$cnt, ($sys eq "tfg"));
    }
    push(@these_champs, $first_team);
  }
  my @sorted_champs = sort { $teamwpct{$b} <=> $teamwpct{$a} } @these_champs;
  $tfg_conference_champions{$conference} = $sorted_champs[0];
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
foreach my $conf (sort keys %tfg_conference_champions) {
  printf "  <li><b>%s</b>: %s</li>\n", $conf, full_lookup_team($tfg_conference_champions{$conf});
}
print "</ul>\n";
print "<div>Full projected conference standings after the jump.</div>\n<br />\n";
print "<!--more-->\n";
print "$output\n";

sub get_projected_record($$$$$$) {
  my $pred_file = shift;
  my $conf_href = shift;
  my $proj_wins_href = shift;
  my $proj_losses_href = shift;
  my $proj_conf_wins_href = shift;
  my $proj_conf_losses_href = shift;
  my %predictions;
  LoadPredictions($pred_file, 0, \%predictions);
  foreach my $gid (keys %predictions) {
    my $aref = $predictions{$gid};
    my $d = substr($gid, 0, 8);
    my $game_year = substr($d, 0, 4);
    # If this game isn't the same year as the one we're examining, skip it.
    next if ($game_year != $spec_year);
    # If the date is prior to the date we're examining, skip the prediction.
    next if ($d < $numeric_date);
    my $monthday = substr($d, 4, 4);
    # If this is before October or after mid-December, skip the prediction.
    #  next if ($monthday < 1000 or $monthday > 1215);
    my $t1id = $$aref[1];
    my $t2id = $$aref[3];
    my $t1c = $team_confs{$t1id};
    my $t2c = $team_confs{$t2id};
    my ($hwin, $hloss, $awin, $aloss);
    my $wpct = $$aref[5];
    my $t1wp = $wpct;
    if ($$aref[2] < $$aref[4]) {
      # Away team actually winning.
      $t1wp = 1 - $wpct;
    }
    $hwin = $aloss = $t1wp;
    $awin = $hloss = 1 - $t1wp;
    $$proj_wins_href{$t1id} += $hwin;
    $$proj_losses_href{$t1id} += $hloss;
    $$proj_wins_href{$t2id} += $awin;
    $$proj_losses_href{$t2id} += $aloss;
    if (defined($t1c) and defined($t2c) and ($t1c eq $t2c)) {
      $$proj_conf_wins_href{$t1id} += $hwin;
      $$proj_conf_losses_href{$t1id} += $hloss;
      $$proj_conf_wins_href{$t2id} += $awin;
      $$proj_conf_losses_href{$t2id} += $aloss;
    }
  }
  foreach my $teamid (keys %id2name) {
    if (!defined($$proj_wins_href{$teamid})) {
      $$proj_wins_href{$teamid} = 0;
    }
    if (!defined($$proj_losses_href{$teamid})) {
      $$proj_losses_href{$teamid} = 0;
    }
    if (!defined($$proj_conf_wins_href{$teamid})) {
      $$proj_conf_wins_href{$teamid} = 0;
    }
    if (!defined($$proj_conf_losses_href{$teamid})) {
      $$proj_conf_losses_href{$teamid} = 0;
    }
  }
}

sub print_team_line($$$) {
  my $tid = shift;
  my $is_odd = shift;
  my $is_tfg = shift;
  my $rowclass = "evenRow";
  if ($is_odd % 2) {
    $rowclass = "oddRow";
  }
  my $p_wins = get_projected_wins($tid, $spec_year,
                $is_tfg ? \%tfg_proj_wins);
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

sub get_raw_projected_wins($$$) {
  my $tid = shift;
  my $year = shift;
  my $proj_wins_href = shift;
  my $p_wins = $$proj_wins_href{$tid};
  $p_wins = 0 if (!defined($p_wins));
  return $p_wins;
}

sub get_raw_projected_losses($$$) {
  my $tid = shift;
  my $year = shift;
  my $proj_losses_href = shift;
  my $p_losses = $$proj_losses_href{$tid};
  $p_losses = 0 if (!defined($p_losses));
  return $p_losses;
}

sub get_projected_wins($$$) {
  my $tid = shift;
  my $year = shift;
  my $proj_wins_href = shift;
  my $p_wins = get_raw_projected_wins($tid, $year, $proj_wins_href);
  my $a_wins = $per_year_wins{$tid}{$year};
  $a_wins = 0 if (!defined($a_wins));
  return sprintf "%d", int($p_wins + $a_wins + 0.5);
}

sub get_projected_losses($$$) {
  my $tid = shift;
  my $year = shift;
  my $proj_losses_href = shift;
  my $p_losses = get_raw_projected_losses($tid, $year, $proj_losses_href);
  my $a_losses = $per_year_losses{$tid}{$year};
  $a_losses = 0 if (!defined($a_losses));
  return sprintf "%d", int($p_losses + $a_losses + 0.5);
}

sub get_projected_conf_wins($$$) {
  my $tid = shift;
  my $year = shift;
  my $proj_conf_wins_href = shift;
  my $p_wins = $$proj_conf_wins_href{$tid};
  $p_wins = 0 if (!defined($p_wins));
  my $a_wins = $per_year_conf_wins{$tid}{$year};
  $a_wins = 0 if (!defined($a_wins));
  return sprintf "%d", int($p_wins + $a_wins + 0.5);
}

sub get_projected_conf_losses($$$) {
  my $tid = shift;
  my $year = shift;
  my $proj_conf_losses_href = shift;
  my $p_losses = $$proj_conf_losses_href{$tid};
  $p_losses = 0 if (!defined($p_losses));
  my $a_losses = $per_year_conf_losses{$tid}{$year};
  $a_losses = 0 if (!defined($a_losses));
  return sprintf "%d", int($p_losses + $a_losses + 0.5);
}

sub get_rank($$) {
  my $tid = shift;
  my $teamrank_href = shift;
  return -1 if (!defined($$teamrank_href{$tid}));
  return $$teamrank_href{$tid};
}

sub get_offense($$) {
  my $tid = shift;
  my $teamoff_href = shift;
  return -2 if (!defined($$teamoff_href{$tid}));
  return $$teamoff_href{$tid};
}

sub get_defense($$) {
  my $tid = shift;
  my $teamdef_href = shift;
  return -2 if (!defined($$teamdef_href{$tid}));
  return $$teamdef_href{$tid};
}

sub get_pace($$) {
  my $tid = shift;
  my $teampace_href = shift;
  return -2 if (!defined($$teampace_href{$tid}));
  return $$teampace_href{$tid};
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
  my $home_pt = $$aref[7];
  my $away_id = $$aref[8];
  my $away_pt = $$aref[10];
  my $home_name = full_lookup_team($home_id);
  my $away_name = full_lookup_team($away_id);
  my $is_neutral = ($$aref[3] eq "NEUTRAL");
  if ($home_pt or $away_pt) {
    if ($home_pt > $away_pt) {
      return "$home_name $home_pt, $away_name $away_pt<br />\n";
    } else {
      return "$away_name $away_pt, $home_name $home_pt<br />\n";
    }
  } else {
    my $at_vs = "at";
    if ($is_neutral) { $at_vs = "vs"; }
    return "$away_name $at_vs $home_name<br />\n";
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
