#!/usr/bin/perl 

use TempoFree;
use Text::CSV;
use strict;
use warnings;

my %pos_points; # [off|def][position] = points
my %pos_counts; # [off|def][position] = counts
my %down_distance_pos_points; # [off|def][down][distance][position] = points
my %down_distance_pos_counts; # [off|def][down][distance][position] = counts

my $prediction_file = shift(@ARGV);
my $odds_cutoff = shift(@ARGV);
my $logfile = shift(@ARGV);
if (!defined($prediction_file) or ! -f $prediction_file or
    !defined($odds_cutoff) or !defined($logfile) or !@ARGV) {
  die "Usage: $0 <prediction_file> <odds_cutoff> <logfile> [pbp0] ... [pbpN]";
}
my $csv = Text::CSV->new() or die "Cannot use CSV: " . Text::CSV->error_diag();
open my $logf, ">", $logfile or die "Cannot open logfile $logfile: $!";

my %predictions;
LoadPredictions($prediction_file, 1, \%predictions);
if (!scalar(keys %predictions)) {
  die "No predictions found in $prediction_file";
}

sub parse_play($) {
  my $aref = shift;
  my $off_id = $aref->[6];
  my $field_id = $aref->[7];
  my $position = $aref->[8];
  if ($off_id == $field_id) {
    # If a team is on their half of the field then it's 100 yards minus field
    # position (e.g., a team on their own 1 is 99 yards from scoring).
    $position = 100 - $position;
  }
#  $position = int($position / 3) * 3 + 1;
  return ($aref->[9], $aref->[10], $position);
}

sub parse_drive($$$$$) {
  my ($t1id, $t2id, $init_t1s, $init_t2s, $aref) = @_;
  my $last_play = $$aref[-1];
  my $t1s = $last_play->[4];
  my $t2s = $last_play->[5];
  my $t1pts = $t1s - $init_t1s;
  my $t2pts = $t2s - $init_t2s;
  my $off_id = $last_play->[6];
  if ($t1pts and $t2pts) {
    printf $logf "T1Pts %2d T2Pts NumPlays %2d\n", $t1pts, $t2pts, scalar(@$aref);
  }
  my ($off_pts, $def_pts) = (0, 0);
  if ($off_id == $t1id) {
    # Team 1 is on offense.
    $off_pts = $t1pts;
    $def_pts = $t2pts;
  } else {
    # Team 2 is on offense.
    $off_pts = $t2pts;
    $def_pts = $t1pts;
  }

  print $logf "OffPts $off_pts DefPts $def_pts OffTeam $off_id\n";
  if ($last_play->[1] == 0) {
    # Don't account for kickoffs just yet.
    return ($t1s, $t2s);
  }
  foreach my $play_row (@$aref) {
    my ($down, $distance, $position) = parse_play($play_row);
    $pos_points{"off"}{$position} += $off_pts;
    $pos_points{"def"}{$position} += $def_pts;
    $pos_counts{"off"}{$position} += 1;
    $pos_counts{"def"}{$position} += 1;
    $down_distance_pos_points{"off"}{$down}{$distance}{$position} += $off_pts;
    $down_distance_pos_points{"def"}{$down}{$distance}{$position} += $def_pts;
    $down_distance_pos_counts{"off"}{$down}{$distance}{$position} += 1;
    $down_distance_pos_counts{"def"}{$down}{$distance}{$position} += 1;
  }
  return ($t1s, $t2s);
}

sub parse_file($) {
  my $fname = shift;
  my @drive_plays;
  my $drive_id = undef;
  my ($t1id, $t2id) = (undef, undef);
  my $curr_t1s = 0;
  my $curr_t2s = 0;
  my $curr_drive_id = -1;
  my $curr_team_id = 0;

  open my $fh, "<", $fname or do die "Can't open $fname: $!";
  while (my $row = $csv->getline($fh)) {
    if (!defined($t1id) or !defined($t2id)) {
      if ($row->[0] =~ /^\d{8}-(\d{4})-(\d{4})$/) {
        $t1id = $1;
        $t2id = $2;
      } else {
        warn "Invalid game ID: $row->[0]";
        close $fh;
        return;
      }
    }
    my $pred_aref = $predictions{$row->[0]};
    if (!defined($pred_aref)) {
      print $logf "Skipping $fname because GID $row->[0] not in prediction file\n";
      close $fh;
      return;
    }
    if (abs($$pred_aref[5] - 0.5) > $odds_cutoff) {
      printf $logf "GID %s has favorite odds of %.3f; greater than "
                   . "cutoff of %.3f\n", $row->[0], $$pred_aref[5],
                   0.5 + $odds_cutoff;
      close $fh;
      return;
    }
    my $drive_id = $row->[1];
    my $team_id = $row->[6];
    if ($drive_id == $curr_drive_id) {
      push(@drive_plays, $row);
      printf $logf "Drive %2d Play %3d DrivePlay %2d\n", $drive_id, $row->[2],
             scalar(@drive_plays);
    } else {
      if ($curr_drive_id >= 0) {
        printf $logf "Parsing drive %2d NumPlays %2d\n", $curr_drive_id, scalar(@drive_plays);
        ($curr_t1s, $curr_t2s) = parse_drive($t1id, $t2id, $curr_t1s, $curr_t2s,
                                             \@drive_plays);
      } else {
        print $logf "Skipping drive ID $curr_drive_id\n";
      }
      @drive_plays = ( $row );
      $curr_drive_id = $drive_id;
      $curr_team_id = $team_id;
      printf $logf "Drive %2d Play %3d DrivePlay %2d\n", $drive_id, $row->[2], scalar(@drive_plays);
    }
  }
  close $fh;
}

foreach my $fname (@ARGV) {
  parse_file($fname);
}
close $logf;

foreach my $offdef (keys %pos_points) {
  my $href = $pos_points{$offdef};
  foreach my $pos (sort { $a <=> $b } keys %$href) {
    my $pts = $$href{$pos};
    my $cnt = $pos_counts{$offdef}{$pos};
    if (!defined($cnt) or !$cnt) {
      warn "Missing or 0-sized count for $offdef|$pos";
      next;
    }
    printf "%s %3d %6d %4d %5.3f\n", $offdef, $pos, $pts, $cnt, $pts / $cnt;
  }
}
#my %down_distance_pos_points; # [off|def][down][distance][position] = points
foreach my $offdef (keys %down_distance_pos_points) {
  my $offdef_pts_href = $down_distance_pos_points{$offdef};
  my $offdef_cnt_href = $down_distance_pos_counts{$offdef};
  next if (!defined($offdef_cnt_href));
  foreach my $down (sort { $a <=> $b } keys %$offdef_pts_href) {
    my $down_pts_href = $$offdef_pts_href{$down};
    my $down_cnt_href = $$offdef_cnt_href{$down};
    next if (!defined($down_cnt_href));
    foreach my $distance (sort { $a <=> $b } keys %$down_pts_href) {
      my $distance_pts_href = $$down_pts_href{$distance};
      my $distance_cnt_href = $$down_cnt_href{$distance};
      next if (!defined($distance_cnt_href));
      foreach my $pos (sort { $a <=> $b } keys %$distance_pts_href) {
        my $pos_pts = $$distance_pts_href{$pos};
        my $pos_cnt = $$distance_cnt_href{$pos};
        next if (!defined($pos_cnt) or !$pos_cnt);
        printf "%s %1d %2d %3d %4d %4d %5.3f\n", $offdef, $down, $distance,
               $pos, $pos_pts, $pos_cnt, $pos_pts / $pos_cnt;
      }
    }
  }
}
