#!/usr/bin/perl -w

use POSIX;
use TempoFree;
use strict;

sub usage();

my $prediction_file_a = shift(@ARGV);
my $rankings_file_a = shift(@ARGV);
my $prediction_file_b = shift(@ARGV);
my $rankings_file_b = shift(@ARGV);
my $teamid = shift(@ARGV);
my $season = shift(@ARGV);

usage() if (!defined($season));

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
my %all_predictions_a;
LoadPredictions($prediction_file_a, 1, \%all_predictions_a);
my %all_predictions_b;
LoadPredictions($prediction_file_b, 1, \%all_predictions_b);

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

my @blogtags = ( "trivia" );
my @years = ( $season );
PrintComparisonSeasons(\%weeks, \%id2name, \%names, \@years, $teamid,
                       \%team_seasons, \%results, \%all_predictions_a, \%all_wpcts_a,
                       \%all_predictions_b, \%all_wpcts_b);

PrintTeamHeaders(\%id2name, \%full_names, \%all_data_a, $teamid, \@years, "tfg");
print "<div><b>Justin</b></div>\n<div>Text goes here</div>\n</br>\n";
PrintTeamHeaders(\%id2name, \%full_names, \%all_data_b, $teamid, \@years, "rba");
print "<div><b>Eddie</b></div>\n<div>Text goes here</div>\n</br>\n";

push(@blogtags, $names{$id2name{$teamid}});
print "<i>Follow us on Twitter at "
      . "<a href=\"http://twitter.com/TFGridiron\">\@TFGridiron</a> "
      . "and <a href=\"http://twitter.com/TFGLiveOdds\">\@TFGLiveOdds</a>.</i>\n";

my $tags = join(',', @blogtags);
$tags =~ s/St\./State/g;
$tags =~ s/\&/+/g;
print "<!-- POSTTAGS|$tags| -->\n";

sub usage() {
  print STDERR "\n";
  print STDERR "Usage: $0 <predictions_tfg> <rankings_tfg> <predictions_rba> <rankings_rba> "
               . "<team> <season>\n";
  print STDERR "\n";
  exit 1;
}
