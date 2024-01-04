#!/usr/bin/perl -w

use POSIX;
use TempoFree;
use strict;

sub usage();

my $prediction_file = shift(@ARGV);
my $rankings_file = shift(@ARGV);
my $pred_system = shift(@ARGV);
my $team_tags = shift(@ARGV);

usage() if (!defined($team_tags));

if (($pred_system ne "rba") and ($pred_system ne "tfg")) {
  print STDERR "Invalid prediction system: \"$pred_system\"\n";
  usage();
}
my $pred_name = uc $pred_system;

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
my %upcoming_predictions;
LoadPredictions($prediction_file, 0, \%upcoming_predictions);

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

my @blogtags = ( );
my @teams = split(/:/, $team_tags);
foreach my $team_info (@teams) {
  my @years = split(/,/, $team_info);
  my $tid = shift(@years);
  PrintTeamHeaders(\%id2name, \%full_names, \%all_data, $tid, \@years, "tfg");
  PrintSeasons(\%weeks, \%id2name, \%names, \@years, $tid, \%team_seasons,
               \%results, \%all_predictions, \%all_wpcts, "tfg");
  push(@blogtags, $names{$id2name{$tid}});
}
print "<i>Follow us on Twitter at "
      . "<a href=\"http://twitter.com/TFGridiron\">\@TFGridiron</a> "
      . "and <a href=\"http://twitter.com/TFGLiveOdds\">\@TFGLiveOdds</a>.</i>\n";

my $tags = join(',', @blogtags);
$tags =~ s/St\./State/g;
$tags =~ s/\&/+/g;
print "<!-- POSTTAGS|$tags| -->\n";

sub usage() {
  print STDERR "\n";
  print STDERR "Usage: $0 <predictions> <rankings> <rba|tfg> <team_info>\n";
  print STDERR "\n";
  exit 1;
}
