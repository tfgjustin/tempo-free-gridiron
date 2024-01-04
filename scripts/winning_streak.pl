#!/usr/bin/perl 

use POSIX;
use TempoFree;
use strict;
use warnings;

sub per_team_seasons($);
sub date_to_season($);

my $predictfile = shift(@ARGV);
if (!defined($predictfile)) {
  print STDERR "\n";
  print STDERR "Usage: $0 <predictfile>\n";
  print STDERR "\n";
  exit 1;
}

my %results;
LoadResults(\%results);

my %predictions;
LoadPredictions($predictfile, 1, \%predictions);

# {team}{year}{gid}[win/loss,odds]
my %per_team_results;
per_team_seasons(\%per_team_results);

foreach my $team_id (keys %per_team_results) {
  my $seasons_href = $per_team_results{$team_id};
  foreach my $season (sort keys %$seasons_href) {
    my $current_odds = 1;
    my @gids;
    my $gids_href = $$seasons_href{$season};
    foreach my $gid (sort keys %$gids_href) {
      my $aref = $$gids_href{$gid};
      if ($$aref[0]) {
        push(@gids, $gid);
        $current_odds *= $$aref[1];
      } else {
        if (@gids) {
          my $num_gids = scalar(@gids);
          printf "%d,%d,%d,%.10f,%.5f,%s\n", $team_id, $season, $num_gids, $current_odds, $current_odds ** (1. / $num_gids), join(',', @gids);
          @gids = ( );
          $current_odds = 1;
        }
      }
    }
    if (@gids) {
      my $num_gids = scalar(@gids);
      printf "%d,%d,%d,%.10f,%.5f,%s\n", $team_id, $season, $num_gids, $current_odds, $current_odds ** (1. / $num_gids), join(',', @gids);
    }
  }
}


sub per_team_seasons($) {
  my $per_team_results_href = shift;
  foreach my $gid (sort keys %results) {
    my $season = date_to_season($gid);
    if (!defined($season)) {
      warn "Could not get season from $gid";
      next;
    }
    if ($season < 1) {
      # A sign we should skip this since it's too early in the predictions or too early in the season.
      next;
    }
    my $pred_aref = $predictions{$gid};
    if (!defined($pred_aref)) {
      warn "Missing prediction for game $gid";
      next;
    }
    my $result_aref = $results{$gid};
    my $home_id = $$result_aref[5];
    my $home_score = $$result_aref[7];
    my $away_id = $$result_aref[8];
    my $away_score = $$result_aref[10];
    # If there's no score, then this hasn't been played. Skip it.
    next if (!$home_score and !$away_score);
    my $home_odds = $$pred_aref[5];
    if ($$pred_aref[2] < $$pred_aref[4]) {
      $home_odds = 1 - $home_odds;
    }
#    $home_odds /= 1000;
    # $home_odds now has the odds that the home team won.
    my @home_data;
    my @away_data;
    if ($home_score > $away_score) {
      # The home team won.
      push(@home_data, 1, $home_odds);
      push(@away_data, 0, 1 - $home_odds);
    } else {
      # The away team won..
      push(@home_data, 0, $home_odds);
      push(@away_data, 1, 1 - $home_odds);
    }
    $$per_team_results_href{$home_id}{$season}{$gid} = \@home_data;
    $$per_team_results_href{$away_id}{$season}{$gid} = \@away_data;
  }
}

sub date_to_season($) {
  my $date = shift;
  if ($date =~ /(\d{4})(\d{2})\d{2}/) {
    my $year = $1;
    my $month = $2 - 1;
    return -1 if ($year <= 2003);
    return -1 if ($month and $month <= 8);
    my $season = $year - ($month ? 0 : 1);
    return $season;
  } else {
    warn "Invalid date format: $date";
    return undef;
  }
}
