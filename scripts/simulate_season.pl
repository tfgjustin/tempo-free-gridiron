#!/usr/bin/perl 
#===============================================================================
#
#         FILE: simulate_season.pl
#
#        USAGE: ./simulate_season.pl  
#
#  DESCRIPTION: Load current conference data, simulate the rest of the season,
#               and then print conference standings.
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 09/06/2013 08:19:25 PM
#     REVISION: ---
#===============================================================================

use TempoFree;
use strict;
use warnings;

my $pred_file = shift(@ARGV);
exit 1 if (!defined($pred_file) or ! -f $pred_file);

my %predictions;
LoadPredictions($pred_file, 0, \%predictions);

my $YEAR = 2014;
my %conf;
my %names;
my %conf_teams;
my %is_bcs;
LoadConferencesForYear($YEAR, \%names, \%conf, \%conf_teams, \%is_bcs);

my %results;
LoadResults(\%results);

my %wins;
my %losses;
my %confwins;
my %conflosses;
GetAllTeamRecords(\%results, \%conf, \%wins, \%losses, \%confwins, \%conflosses);

# {conf}{subconf}{teamid}{pos}[count]
my %conf_standings;
# {conf}{teamid}[wincount]
my %conf_winners;
# {teamid}[undefcount]
my %undef_count;

foreach my $i (0..1000) {
  my %proj_wins;
  my %proj_losses;
  my %proj_confwins;
  my %proj_conflosses;
  foreach my $gid (sort keys %predictions) {
    my $aref = $predictions{$gid};
    my ($is_neutral, $home_id, $home_pts, $away_id, $away_pts, $odds) = @$aref;
    my $homeconf = $conf{$home_id};
    my $awayconf = $conf{$away_id};
    next if (!defined($awayconf) or !defined($homeconf));
    my $pred_odds = rand 1000;
    my ($away_win, $home_win) = (0, 0);
    if ($pred_odds <= $odds) {
      # Favorite wins
      if ($away_pts > $home_pts) {
        $away_win = 1;
      } else {
        $home_win = 1;
      }
    } else {
      # Upset
      if ($away_pts < $home_pts) {
        # Expected loser actually wins
        $away_win = 1;
      } else {
        $home_win = 1;
      }
    }
    $proj_wins{$home_id} += $home_win;
    $proj_wins{$away_id} += $away_win;
    $proj_losses{$home_id} += !$home_win;
    $proj_losses{$away_id} += !$away_win;
    if ($homeconf eq $awayconf) {
      $proj_confwins{$home_id} += $home_win;
      $proj_confwins{$away_id} += $away_win;
      $proj_conflosses{$home_id} += !$home_win;
      $proj_conflosses{$away_id} += !$away_win;
    }
  }
}
