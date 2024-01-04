#!/usr/bin/perl 
#===============================================================================
#
#         FILE: tfg_boxscore.pl
#
#        USAGE: ./tfg_boxscore.pl  
#
#  DESCRIPTION: Calculate the TD percentage, the FG percentage, first down
#               percentage, and turnover percentage.
#
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 03/01/2013 09:22:15 AM
#     REVISION: ---
#===============================================================================

use Text::CSV;
use TempoFree;
use strict;
use warnings;

if (!@ARGV) {
  die "Usage: $0 <playfile0> ... <playfileN>";
}

my $csv = Text::CSV->new() or die "Cannot use CSV: " . Text::CSV->error_diag();
foreach my $playfile (@ARGV) {
  open my $pf, "<", $playfile or die "Can't open $playfile: $!";
  my ($last_hs, $last_as) = (0, 0);
  my ($home_plays, $away_plays) = (0, 0);
  my ($home_tds, $away_tds) = (0, 0);
  my ($home_fgs, $away_fgs) = (0, 0);
  my %home_downs;
  my %away_downs;
  my ($home_id, $away_id) = (undef, undef);
  my $last_drive_id = 0;
  while (my $row = $csv->getline($pf)) {
    # First, figure out if this was a kickoff. If so, remember the score
    # and move on.
    if (!$row->[0]) {
      $last_hs = $row->[4];
      $last_as = $row->[5];
      next;
    }
    if (!defined($home_id) and !defined($away_id) and
        ($row->[0] =~ /\d{8}-(\d{4})-(\d{4})/)) {
      $home_id = $1;
      $away_id = $2;
    }
    # Who has the ball?
    my $off_id = $row->[6];
    my $drive_id = $row->[1];
    my $down = $row->[9];
    if ($off_id == $home_id) {
      ++$home_plays;
      if ($row->[4] >= ($last_hs + 6)) {
        ++$home_tds;
      } elsif ($row->[4] == ($last_hs + 3)) {
        ++$home_fgs;
      }
      if ($drive_id and $drive_id != $last_drive_id) {
        # First play of a new drive.
        $last_drive_id = $drive_id;
      } else {
        $home_downs{$down} += 1;
      }
    } elsif ($off_id == $away_id) {
      ++$away_plays;
      if ($row->[5] >= ($last_as + 6)) {
        ++$away_tds;
      } elsif ($row->[5] == ($last_as + 3)) {
        ++$away_fgs;
      }
      if ($drive_id and $drive_id != $last_drive_id) {
        $last_drive_id = $drive_id;
      } else {
        $away_downs{$down} += 1;
      }
    } else {
      warn "Team with ball $off_id is not home $home_id or away $away_id";
      next;
    }
    $last_hs = $row->[4];
    $last_as = $row->[5];
  }
  close $pf;
  next if (!$home_plays or !$away_plays);
  
  foreach my $d (1..4) {
    $home_downs{$d} = 0 if (!defined($home_downs{$d}));
    $away_downs{$d} = 0 if (!defined($away_downs{$d}));
  }
  
  # TeamId Plays TD% FG% 1D 2D 3D 4D
  printf "%4d %3d %2d %2d", $home_id, $home_plays, $home_tds, $home_fgs;
  foreach my $d (1..4) {
    printf " %3d", $home_downs{$d};
  }
  print "\n";
  
  printf "%4d %3d %2d %2d", $away_id, $away_plays, $away_tds, $away_fgs;
  foreach my $d (1..4) {
    printf " %3d", $away_downs{$d};
  }
  print "\n";
}
