#!/usr/bin/perl -w

use POSIX;
use TempoFree;
use strict;

my @ROMAN = qw( I II III IV V VI VII VIII IX X XI XII XIII XIV XV XVI XVII );
my $CURRYEAR = 2013;

sub print_day_page($$$$$);
sub print_prediction($$$$);
sub parse_bowl_groups($$);
sub parse_bowl_csv($$$);
sub usage();

my $bowl_csv_file = shift(@ARGV);
my $bowl_group_file = shift(@ARGV);
my $prediction_file_a = shift(@ARGV);
my $rankings_file_a = shift(@ARGV);
my $prediction_file_b = shift(@ARGV);
my $rankings_file_b = shift(@ARGV);
my $output_directory = shift(@ARGV);

usage() if (!defined($output_directory));

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

my %per_year_wins;         # {team_id}{year}[wins]
my %per_year_conf_wins;    # {team_id}{year}[wins]
my %per_year_losses;       # {team_id}{year}[losses]
my %per_year_conf_losses;  # {team_id}{year}[losses]
GetAllTeamRecords(\%results, \%id2conf, \%per_year_wins, \%per_year_conf_wins,
                  \%per_year_losses, \%per_year_conf_losses);

# Parse the predictions for each team.
my %upcoming_predictions_a;
LoadPredictions($prediction_file_a, 0, \%upcoming_predictions_a);
my %all_predictions_a;
LoadPredictions($prediction_file_a, 1, \%all_predictions_a);

my %upcoming_predictions_b;
LoadPredictions($prediction_file_b, 0, \%upcoming_predictions_b);
my %all_predictions_b;
LoadPredictions($prediction_file_b, 1, \%all_predictions_b);

# {mangled_gid}[title,time]
my %bowl_info;
parse_bowl_csv(\%results, $bowl_csv_file, \%bowl_info);

# {date}{gid}
my %bowl_dates;
parse_bowl_groups($bowl_group_file, \%bowl_dates);

# First one (probably TFG)
my %all_wpcts_a;
my %all_sos_a;
my %all_oeff_a;
my %all_deff_a;
my %all_pace_a;
my $rc = LoadRanksAndStats($rankings_file_a, \%all_wpcts_a, \%all_sos_a, \%all_oeff_a, \%all_deff_a, \%all_pace_a);
if ($rc) {
  die "Error getting rankings and stats from $rankings_file_a";
}
my %all_data_a;
$all_data_a{"WPCTS"} = \%all_wpcts_a;
$all_data_a{"SOS"} = \%all_sos_a;
$all_data_a{"OEFF"} = \%all_oeff_a;
$all_data_a{"DEFF"} = \%all_deff_a;
$all_data_a{"PACE"} = \%all_pace_a;

my %wpcts_a;
$rc = FetchWeekRankings(\%all_wpcts_a, undef, undef, undef, undef, -1,
                        \%wpcts_a, undef, undef, undef, undef);
if ($rc) {
  die "Error fetching most recent rankings from $rankings_file_a";
}

# Second one (probably RBA)
my %all_wpcts_b;
my %all_sos_b;
my %all_oeff_b;
my %all_deff_b;
my %all_pace_b;
$rc = LoadRanksAndStats($rankings_file_b, \%all_wpcts_b, \%all_sos_b, \%all_oeff_b, \%all_deff_b, \%all_pace_b);
if ($rc) {
  die "Error getting rankings and stats from $rankings_file_b";
}
my %all_data_b;
$all_data_b{"WPCTS"} = \%all_wpcts_b;
$all_data_b{"SOS"} = \%all_sos_b;
$all_data_b{"OEFF"} = \%all_oeff_b;
$all_data_b{"DEFF"} = \%all_deff_b;
$all_data_b{"PACE"} = \%all_pace_b;

my %wpcts_b;
$rc = FetchWeekRankings(\%all_wpcts_b, undef, undef, undef, undef, -1,
                        \%wpcts_b, undef, undef, undef, undef);
if ($rc) {
  die "Error fetching most recent rankings from $rankings_file_b";
}

my %gugs;
CalculateGugs(\%upcoming_predictions_a, \%upcoming_predictions_b, \%wpcts_a, \%wpcts_b, \%gugs);
# TODO: Fix rankings since it returns an aref now
my %gugs_ranks;
RankValues(\%gugs, \%gugs_ranks, 1, \%id2conf);

my $i = 0;
foreach my $date (sort keys %bowl_dates) {
  my $games_href = $bowl_dates{$date};
  my $part = $ROMAN[$i];
  print_day_page($games_href, $i, $part, \%upcoming_predictions_a, \%upcoming_predictions_b);
  ++$i;
}

sub print_day_page($$$$$) {
  my $games_href = shift;
  my $count = shift;
  my $roman = shift;
  my $pred_a = shift;
  my $pred_b = shift;

  my $outpath = sprintf "%s/bowls.%d.%d.html", $output_directory, $CURRYEAR, $count;
  open(OUTFILE, ">$outpath") or die "Can't open $outpath for writing: $!";
  select OUTFILE;

  my $title = sprintf "%d - %d Bowl Previews: Part %s", $CURRYEAR, $CURRYEAR + 1, $roman;
  print "<!-- POSTTITLE|$title| -->\n";
  print "<link rel=\"stylesheet\" type=\"text/css\" href=\"ncaa.css\" />\n";
  printf "<div>Today is Part %s of our %d - %d bowl preview series. Today we'll examine the </div>\n",
         $roman, $CURRYEAR, $CURRYEAR + 1;
  print "<ul>\n";
  foreach my $gid (sort { $gugs{$a}[3] <=> $gugs{$b}[3] } keys %$games_href) { 
    my $r = $gugs_ranks{$gid};
    my $bowl_aref = $bowl_info{$gid};
    my ($date, $t1, $t2) = split(/-/, $gid);
    my $full_t1 = $full_names{$id2name{$t1}};
    my $full_t2 = $full_names{$id2name{$t2}};
    print "<li><b>$$bowl_aref[0]</b><br />$full_t1 vs $full_t2</li>\n";
  }
  print "</ul>\n";
  print "<div>Full previews after the jump ....</div>\n<br />\n";

  my @blogtags = ( "bowl previews" );
  my @years = ( $CURRYEAR );
  my $v = $count;
  foreach my $gid (sort { $gugs{$a}[3] <=> $gugs{$b}[3] } keys %$games_href) {
    my $g_gugs = $gugs{$gid}[3];
    my $r = $gugs_ranks{$gid};
    my $bowl_aref = $bowl_info{$gid};
    my ($date, $t1, $t2) = split(/-/, $gid);
    my $hour  = substr($$bowl_aref[1], 0, 2);
    my $min   = substr($$bowl_aref[1], 2, 2);
    my ($y, $m, $d);
    if ($gid =~ /(\d{4})(\d{2})(\d{2})-.*/) {
      $y = $1 - 1900;
      $m = $2 - 1;
      $d = $3;
    } else {
      warn "Invalid GID: $gid";
      next;
    }
    my $full_t1 = $full_names{$id2name{$t1}};
    my $full_t2 = $full_names{$id2name{$t2}};
    my $conf_t1 = $id2conf{$t1};
    my $conf_t2 = $id2conf{$t2};
    my $record_t1 = sprintf "%d - %d; %d - %d %s", $per_year_wins{$t1}{$CURRYEAR},
                            $per_year_losses{$t1}{$CURRYEAR},
                            $per_year_conf_wins{$t1}{$CURRYEAR},
                            $per_year_conf_losses{$t1}{$CURRYEAR}, $conf_t1;
    my $record_t2 = sprintf "%d - %d; %d - %d %s", $per_year_wins{$t2}{$CURRYEAR},
                            $per_year_losses{$t2}{$CURRYEAR},
                            $per_year_conf_wins{$t2}{$CURRYEAR},
                            $per_year_conf_losses{$t2}{$CURRYEAR}, $conf_t2;
    my $game_time = POSIX::mktime(0, $min, $hour, $d, $m, $y);
    my $time_name = strftime "%A, %B %e at %l:%M %p", localtime($game_time);
    print "<h3>$r. $$bowl_aref[0]</h3>\n";
    print "<h4>$time_name</h4>\n";
    print "<div>$full_t1 ($record_t1)<br />vs<br />$full_t2 ($record_t2)</div>\n";
    print "<div>GUGS Score: $g_gugs</div><br />\n";
    my $pred_sys_a = ($v % 2) ? "tfg" : "rba";
    my $pred_sys_b = ($v % 2) ? "rba" : "tfg";
    my $person_a = ($v % 2) ? "Justin" : "Eddie";
    my $person_b = ($v % 2) ? "Eddie" : "Justin";
    my $pred_data_a = ($v % 2) ? $pred_a : $pred_b;
    my $pred_data_b = ($v % 2) ? $pred_b : $pred_a;
    my $all_data_a_href = ($v % 2) ? \%all_data_a : \%all_data_b;
    my $all_data_b_href = ($v % 2) ? \%all_data_b : \%all_data_a;

    print "<div><b>$person_a</b></div><br />\n";
    foreach my $tid ( $t1, $t2 ) {
      PrintTeamHeaders(\%id2name, \%full_names, $all_data_a_href, $tid, \@years, $pred_sys_a);
    }
    printf "<br /><div>%s</div><br />\n", print_prediction($gid, $id2name{$t1}, $id2name{$t2}, $pred_data_a);

    print "<div><b>$person_b</b></div><br />\n";
    foreach my $tid ( $t1, $t2 ) {
      PrintTeamHeaders(\%id2name, \%full_names, $all_data_b_href, $tid, \@years, $pred_sys_b);
    }
    printf "<br /><div>%s</div><br />\n", print_prediction($gid, $id2name{$t1}, $id2name{$t2}, $pred_data_b);
    print  "<br />\n";

    foreach my $tid ( $t1, $t2 ) {
      print "<div><b>$full_names{$id2name{$tid}} Season Summary</b></div>\n";
      PrintComparisonSeasons(\%weeks, \%id2name, \%names, \@years, $tid,
                             \%team_seasons, \%results, \%all_predictions_a, \%all_wpcts_a,
                             \%all_predictions_b, \%all_wpcts_b);
      push(@blogtags, $names{$id2name{$tid}});
    }
    ++$v;
  }

  print "<i>Follow us on Twitter at "
        . "<a href=\"http://twitter.com/TFGridiron\">\@TFGridiron</a> "
        . "and <a href=\"http://twitter.com/TFGLiveOdds\">\@TFGLiveOdds</a>.</i>\n";
  my $tags = join(',', @blogtags);
  $tags =~ s/St\./State/g;
  $tags =~ s/\&/+/g;
  print "<!-- POSTTAGS|$tags| -->\n";
  select STDOUT;
  close(OUTFILE);
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
    return sprintf "%s %d, %s %d (%.1f%%); %d plays.", $home_print_name, $$pred_aref[2],
           $away_print_name, $$pred_aref[4], 100 * $$pred_aref[5], $$pred_aref[6];
  } else {
    return sprintf "%s %d, %s %d (%.1f%%); %d plays.", $away_print_name, $$pred_aref[4],
           $home_print_name, $$pred_aref[2], 100 * $$pred_aref[5], $$pred_aref[6];
  }
}

sub parse_bowl_groups($$) {
  my $fname = shift;
  my $bowl_href = shift;
  open(FILE, "$fname") or die "Can't open $fname for reading: $!";
  while(<FILE>) {
    # date,gid
    next if (/^#/);
    chomp;
    @_ = split(/,/);
    $$bowl_href{$_[0]}{$_[1]} = 1;
  }
  close(FILE);
}

sub parse_bowl_csv($$$) {
  my $result_href = shift;
  my $fname = shift;
  my $bowl_href = shift;
  open(FILE, "$fname") or die "Can't open bowl file $fname: $!";
  while(<FILE>) {
    next if (/^#/);
    chomp;
    @_ = split(/,/);
    my $title = $_[0];
    my $date  = $_[1];
    my $time_est = $_[2];
    my $t1id = $_[4];
    my $t2id = $_[6];
    my @a = ( $title, $time_est );
    my $gid = join('-', $date, $t1id, $t2id);
    if (defined($$result_href{$gid})) {
      $$bowl_href{$gid} = \@a;
    } else {
      $gid = join('-', $date, $t2id, $t1id);
      if (defined($$result_href{$gid})) {
        $$bowl_href{$gid} = \@a;
      } else {
        warn "Cannot find tag for $gid variants ($title)";
      }
    }
#    print "Game $gid: \"$title\" at $time_est\n";
  }
  close(FILE);
}

sub usage() {
  print STDERR "\n";
  print STDERR "Usage: $0 <bowl_csv> <bowl_post_dates> <predictions_tfg> <rankings_tfg> "
               . "<predictions_rba> <rankings_rba> <output_directory>\n";
  print STDERR "\n";
  exit 1;
}
