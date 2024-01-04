#!/usr/bin/perl -w

use POSIX;
use TempoFree;
use strict;

sub print_header();
sub stats_cell($$);
sub team_name($);
sub usage($);
sub last_week($);
sub next_week($);

usage($0) if (scalar(@ARGV) != 6);

my $under_the_hood_url = "/2009/10/under-hood.html";
my $full_rankings = 1;
my $topX = undef;
my $header_repeats_after = 25;
my $post_name = "Full Rankings";
if ($0 =~ /top_25/) {
  $topX = 25;
  $post_name = "Top 25";
  $full_rankings = 0;
}

my $current_rankfile = shift(@ARGV);
my $last_rankfile = shift(@ARGV);
my $season_week_number = shift(@ARGV);
my $curr_date = shift(@ARGV);
my $post_date_time = shift(@ARGV);
my $pred_system = shift(@ARGV);

if (($pred_system ne "tfg") and ($pred_system ne "rba") and ($pred_system ne "all")) {
  usage($0);
}

my ($season, $month, $day) = split(/-/, $curr_date);
if (!defined($day)) {
  usage($0);
}

if ($month eq "01") {
  --$season;
}

my %id2name;
my %id2conf;
LoadConferences(\%id2name, \%id2conf, undef, undef);
my %names;
LoadPrintableNames(\%names);
my %results;
LoadResults(\%results);
# 1) team ID -> short name
# 2) team ID -> Conference
# 3) (conference, subconference) -> set of team IDs
# 4) team ID -> isBcs

my %all_wpct;
my %all_sos;
my %all_oeff;
my %all_deff;
my %all_pace;
my $rc = LoadRanksAndStats($current_rankfile, \%all_wpct, \%all_sos, \%all_oeff,
                      \%all_deff, \%all_pace);
if ($rc) {
  warn "Error loading current rankings from $current_rankfile";
  exit 1;
}
my %curr_wpct;
my %curr_sos;
my %curr_oeff;
my %curr_deff;
my %curr_pace;
$rc = FetchWeekRankings(\%all_wpct, \%all_sos, \%all_oeff, \%all_deff, \%all_pace, -1,
                        \%curr_wpct, \%curr_sos, \%curr_oeff, \%curr_deff, \%curr_pace);
if ($rc) {
  warn "Error fetching current rankings from $current_rankfile";
  exit 1;
}

if (!defined($topX)) { $topX = scalar(keys %curr_wpct); }
my %wpct_rank;
my %sos_rank;
my %off_rank;
my %def_rank;
my %pace_rank;
RankValues(\%curr_wpct, \%wpct_rank, 1, \%id2conf);
RankValues(\%curr_sos, \%sos_rank, 1, \%id2conf);
RankValues(\%curr_oeff, \%off_rank, 1, \%id2conf);
RankValues(\%curr_deff, \%def_rank, 0, \%id2conf);
RankValues(\%curr_pace, \%pace_rank, 1, \%id2conf);

%all_wpct = ();
%all_sos = ();
%all_oeff = ();
%all_deff = ();
%all_pace = ();
$rc = LoadRanksAndStats($last_rankfile, \%all_wpct, \%all_sos, \%all_oeff,
                   \%all_deff, \%all_pace);
if ($rc) {
  warn "Error loading last rankings from $last_rankfile";
  exit 1;
}
my %last_wpct;
$rc = FetchWeekRankings(\%all_wpct, \%all_sos, \%all_oeff, \%all_deff, \%all_pace, -1,
                        \%last_wpct, undef, undef, undef, undef);
if ($rc) {
  warn "Error fetching last rankings from $last_rankfile";
  exit 1;
}
my %last_rank;
RankValues(\%last_wpct, \%last_rank, 1, \%id2conf);

my %wins;
my %losses;
GetAllTeamRecords(\%results, undef, \%wins, undef, \%losses, undef);

my $upper_system = uc $pred_system;
my $output = "<!-- POSTTITLE|Week $season_week_number: $post_name &mdash; $upper_system|-->\n";
$output .= sprintf "<div><i>Mouse over column headers for definitions, or see <a href=\"%s\">this page</a></i></div>\n", $under_the_hood_url;
$output .= sprintf "<!-- POSTTIME|%s| -->\n", $post_date_time;
$output .= sprintf "<table class=\"rank-table\">\n";
$output .= print_header();
my $r = 1;
my @new_arrivals;
my %in_team_list;
my %wpct_delta;
my $next_header = $header_repeats_after;
foreach my $team_id (sort { $curr_wpct{$b} <=> $curr_wpct{$a} } keys %curr_wpct) {
  my $team_c = $id2conf{$team_id};
  next if (!defined($team_c) or ($team_c eq "FCS"));
  my $wpct = $curr_wpct{$team_id};
  my $sos = $curr_sos{$team_id};
  my $off = $curr_oeff{$team_id};
  my $def = $curr_deff{$team_id};
  my $pace = $curr_pace{$team_id};
  my $teamname = team_name($id2name{$team_id});
  if (!defined($wpct) or !defined($sos) or !defined($off) or !defined($def) or !defined($pace)) {
    next;
  }
  if ($r > $next_header) {
    $output .= print_header();
    $next_header += $header_repeats_after;
  }

  $wpct_delta{$team_id} = $wpct - $last_wpct{$team_id};
  $in_team_list{$team_id} = 1;

  my $changeclass = "changeNone";
  my $change = "--";
  my $last_r = $last_rank{$team_id};
  if (defined($last_r)) {
    if ($last_r < $r) {
      $changeclass = "changeBad";
      $change = $last_r - $r;
    } elsif ($last_r > $r) {
      $changeclass = "changeGood";
      if ($last_r <= $topX) {
        $change = "+" . ($last_r - $r);
      } else {
	    $change = "NA";
	    push(@new_arrivals, $teamname);
      }
    }
  }
  my $rowtype = undef;
  if ($r % 2) {
    $rowtype = "oddRow";
  } else {
    $rowtype = "evenRow";
  }
  $output .= sprintf "<tr class=\"%s\">\n  <td class=\"bigrank\">%s</td>\n"
                     . "  <td class=\"%s bigrank\">%s</td>\n",
                     $rowtype, $r++, $changeclass, $change;
  $output .= sprintf "  <td class=\"teamName\">%s", $teamname;
  $output .= sprintf "<span class=\"rank\">&nbsp;&nbsp;( %d - %d )</span></td>\n",
             $wins{$team_id}{$season}, $losses{$team_id}{$season};
  $output .= sprintf "%s", stats_cell("%.3f", $wpct);
  $output .= sprintf "%s", stats_cell("%.3f", $sos);
  $output .= sprintf "  <td class=\"subRank\">%d</td>\n", $sos_rank{$team_id};
  $output .= sprintf "%s", stats_cell("%.1f", $off);
  $output .= sprintf "  <td class=\"subRank\">%d</td>\n", $off_rank{$team_id};
  $output .= sprintf "%s", stats_cell("%.1f", $def);
  $output .= sprintf "  <td class=\"subRank\">%d</td>\n", $def_rank{$team_id};
  $output .= sprintf "%s", stats_cell("%3.1f", $pace);
  $output .= sprintf "  <td class=\"subRank\">%d</td>\n", $pace_rank{$team_id};
  $output .= sprintf "</tr>\n";
  last if ($r > $topX);
}
$output .= sprintf "</table>\n";
$output .= sprintf "<div><i>Rankings through games of $curr_date</i><br/>\n";

my $tags = "";
if ($full_rankings) {
  my $count = 0;
  my @jumps;
  my @drops;
  my @high_to_low = sort { $wpct_delta{$b} <=> $wpct_delta{$a} } keys %wpct_delta;
  foreach my $i (0..5) {
    my $team_id = $high_to_low[$i];
    if (abs($wpct_delta{$team_id}) > 0.001) {
      my $team = $id2name{$team_id};
      my $teamname = team_name($team);
      push(@jumps, sprintf "%s (%.3f)", $teamname, $wpct_delta{$team_id});
    }
    $team_id = $high_to_low[-($i+1)];
    if (abs($wpct_delta{$team_id}) > 0.001) {
      my $team = $id2name{$team_id};
      my $teamname = team_name($team);
      push(@drops, sprintf "%s (%.3f)", $teamname, $wpct_delta{$team_id});
    }
    last if (++$count >= 5);
  }
  $output = sprintf "Biggest jumps: %s<br />\n<br />\n"
                    . "Biggest drops: %s<br />\n<br />\n"
                    . "Full rankings after the jump.<br />\n"
                    . "<!--more--><br />\n%s",
                    join('; ', @jumps),  join('; ', @drops), $output;
  if (@jumps) {
    foreach my $t (@jumps) {
      my ($team, $data) = split(/\(/, $t);
      $team =~ s/St\./State/g;
      $team =~ s/\&/+/g;
      $tags .= sprintf "%s,", $team;
    }
  }
  if (@drops) {
    foreach my $t (@drops) {
      my ($team, $data) = split(/\(/, $t);
      $team =~ s/St\./State/g;
      $team =~ s/\&/+/g;
      $tags .= sprintf "%s,", $team;
    }
  }
  $tags .= " rankings";
} else {
  my $arrivals = "none";
  if (@new_arrivals) {
    $arrivals = join(', ', @new_arrivals);
    foreach my $t (@new_arrivals) {
      my ($team, $data) = split(/\(/, $t);
      $team =~ s/St\./State/g;
      $team =~ s/\&/+/g;
      $tags .= sprintf "%s,", $team;
    }
  }
  $output .= sprintf "<br />\nNew entries: %s.<br />\n<br />\n",
             $arrivals;
  my @dropped_out;
  foreach my $team_id (sort { $last_rank{$a} <=> $last_rank{$b} } keys %last_rank) {
    last if ($last_rank{$team_id} > $topX);
    my $team = $id2name{$team_id};
    my $teamname = team_name($team);
    if (!defined($in_team_list{$team_id})) {
      push(@dropped_out, $teamname);
    }
  }
  my $dropped = "none";
  if (@dropped_out) {
    $dropped = join(', ', @dropped_out);
    foreach my $t (@dropped_out) {
      my ($team, $data) = split(/\(/, $t);
      $team =~ s/St\./State/g;
      $team =~ s/\&/+/g;
      $tags .= sprintf "%s,", $team;
    }
  }
  $output .= sprintf "Dropped out: %s.<br />\n", $dropped;
  $tags .= " top25";
}

$tags =~ s/\&/+/g;
$output .= "<!-- POSTTAGS|$tags| -->\n";
$output .= "<br />\n<br />\n";
$output .= sprintf "<i>Follow us on Twitter at "
        . "<a href=\"http://twitter.com/TFGridiron\">\@TFGridiron</a> "
        . "and <a href=\"http://twitter.com/TFGLiveOdds\">\@TFGLiveOdds</a>.</i>\n"
        . "</div>\n";

print "<link rel=\"stylesheet\" type=\"text/css\" href=\"ncaa.css\" />\n";
print $output;

sub print_header() {
  return sprintf "<tr class=\"$pred_system\">
  <th valign=\"bottom\" rowspan=\"2\">Rank</th>
  <th valign=\"bottom\" rowspan=\"2\">+/-</th>
  <th valign=\"bottom\" rowspan=\"2\">Team</th>
  <th valign=\"bottom\" rowspan=\"2\"><span title=\"Expected winning percent if they were to play a schedule of 0.500 opponents.\">WinPct</span></th>
  <th valign=\"bottom\" rowspan=\"2\" colspan=\"2\"><span title=\"Average expected winning percentage of the opponents this team has played.\">SoS</span></th>
  <th colspan=\"6\">Adjusted</th>
</tr>
<tr class=\"$pred_system\">
  <th colspan=\"2\"><span title=\"Points per 100 plays this team has scored, adjusted for strength of their opponents. Includes points from all sources, including offense, defense (e.g., pick-6s), and special teams.\">Off.</span></th>
  <th colspan=\"2\"><span title=\"Points per 100 plays this team has allowed, adjusted for strength of their opponents. Includes points from all sources, including offense, defense (e.g., pick-6s), and special teams.\">Def.</span></th>
  <th colspan=\"2\"><span title=\"Average number of plays per game, adjusted for pace of opponent. Includes all plays: e.g., offense, defense, kickoffs, extra points, etc, etc.\">Pace</span></th>
</tr>\n";
}

sub stats_cell($$) {
  my $fmt = shift;
  my $currval = shift;

  return sprintf "  <td class=\"stats\">$fmt</td>\n", $currval;
}

sub team_name($) {
  my $team = shift;
  my $teamname = $names{$team};
  if (!defined($teamname)) {
    $teamname = $team;
  }
  return $teamname;
}

sub usage($) {
  my $p = shift;
  my @parts = split(/\//, $p);
  $p = pop(@parts);
  print STDERR "\n";
  print STDERR "Usage: $p <current_rankfile> <last_rankfile> "
               . "<season_week_number> <curr_date> <post_date_time> <rba|tfg|all>\n";
  print STDERR "\n";
  exit 1;
}
