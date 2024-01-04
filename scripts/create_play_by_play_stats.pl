#!/usr/bin/perl 
#===============================================================================
#
#         FILE: create_play_by_play_stats.pl
#
#        USAGE: ./create_play_by_play_stats.pl  
#
#  DESCRIPTION: Parses the CFBStats play-by-play and game (drive?) data to come
#               up play-by-play data in a format we can use.
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 02/16/2015 10:46:55 AM
#     REVISION: ---
#===============================================================================

use Clone qw(clone);
use Data::Printer { multiline => 0 };
use TempoFree;
use strict;
use warnings;

sub parse_play_file($$);
sub parse_drive_file($$);
sub print_tfg_play_file($$$);
sub print_game($$$$);
sub get_points($$);
sub ncaa_gid_to_tfg_gid($);
sub ncaa_tid_to_tfg_tid($);
sub calc_time_left($$);
sub get_yards_gained($$);
sub fill_drive_entries($$$$);
sub smooth_clock($);

my %results;
LoadResults(\%results);

my $pbpfile = shift(@ARGV);
my $drivefile = shift(@ARGV);
my $outfile = shift(@ARGV);

if (!defined($outfile)) {
  print STDERR "\n";
  print STDERR "Usage: $0 <pbpfile> <drivefile> <outfile>\n";
  print STDERR "\n";
  exit 1;
}

if (! -f $pbpfile or ! -f $drivefile) {
  print STDERR "Missing an input file\n\n";
  print STDERR "Usage: $0 <pbpfile> <drivefile> <outfile>\n";
  print STDERR "\n";
  exit 1;
}

my %plays;
parse_play_file($pbpfile, \%plays);

my %drives;
parse_drive_file($drivefile, \%drives);

print_tfg_play_file(\%plays, \%drives, $outfile);

# Play-by-play input:
# 1) Game Code
# 2) Play Number
# 3) Period Number
# 4) Clock
# 5) Offense Team Code
# 6) Defense Team Code
# 7) Offense Points
# 8) Defense Points
# 9) Down
# 10) Distance
# 11) Spot
# 12) Play Type
# 13) Drive Number
# 14) Drive Play
sub parse_play_file($$) {
  my $fname = shift;
  my $href = shift;
  my $num_plays = 0;
  open my $inf, "<", $fname or die "Can't open $fname: $!";
  while (<$inf>) {
    chomp;
    my @parts = split(/,/);
    if (scalar(@parts) != 14) {
      print STDERR "Invalid line size: " . scalar(@parts) . "\n";
      print "\"$_\"\n";
      next;
    }
    my $gid = $parts[0];
    if (!($gid =~ /^\d{16}$/)) {
#      print STDERR "Invalid game ID: $gid\n";
      next;
    }
    $$href{$parts[0]}{$parts[1]} = \@parts;
    ++$num_plays;
  }
  close ($inf);
  print "Loaded $num_plays plays\n";
}

# Drive input:
# 1) Game Code
# 2) Drive Number
# 3) Team Code
# 4) Start Period
# 5) Start Clock
# 6) Start Spot
# 7) Start Reason
# 8) End Period
# 9) End Clock
# 10) End Spot
# 11) End Reason
# 12) Plays
# 13) Yards
# 14) Time Of Possession
# 15) Red Zone Attempt
sub parse_drive_file($$) {
  my $fname = shift;
  my $href = shift;
  my $num_drives = 0;
  open my $inf, "<", $fname or die "Can't open $fname: $!";
  while (<$inf>) {
    chomp;
    my @parts = split(/,/);
    if (scalar(@parts) != 15) {
      print STDERR "Invalid line size: " . scalar(@parts) . "\n";
      next;
    }
    my $gid = $parts[0];
    if (!($gid =~ /^\d{16}$/)) {
#      print STDERR "Invalid game ID: $gid\n";
      next;
    }
    $$href{$parts[0]}{$parts[1]} = \@parts;
    ++$num_drives;
  }
  close ($inf);
  print "Loaded $num_drives drives\n";
}

sub print_tfg_play_file($$$) {
  my $play_href = shift;
  my $drive_href = shift;
  my $outfname = shift;

  open my $outf, ">", $outfname or die "Can't open $outfname for writing: $!";
  print_header($outf);
  # Iterate over all the games
  foreach my $ncaa_gid (keys %$play_href) {
    my $game_plays_href = $$play_href{$ncaa_gid};
    my $game_drives_href = $$drive_href{$ncaa_gid};
    if (!defined($game_drives_href)) {
      warn "No drive data for game $ncaa_gid";
      next;
    }
    my $tfg_gid = ncaa_gid_to_tfg_gid($ncaa_gid);
    next if (!defined($tfg_gid));
#    printf "Game: %s Plays: %3d Drives: %2d\n", $tfg_gid,
#      scalar(keys %$game_plays_href), scalar(keys %$game_drives_href);
    print_game($tfg_gid, $game_plays_href, $game_drives_href, $outf);
  }
  close ($outf);
}

sub print_header($) {
  my $outf = shift;
  my @PARTS = ("Game ID", "Time Left", "Off ID", "Def ID", "Off Pts",
    "Def Pts", "Down", "Distance", "Spot", "Off Drive Pts", "Def Drive Pts",
    "Play Type", "Play Yards", "Off Play Pts", "Def Play Pts");
  print $outf "\"" . join('","', @PARTS) . "\"\n";
}

# Desired output:
# 1) TFG GID
# 2) Time Left (until end of regulation)
# 3) Offense ID
# 4) Defense ID
# 5) Current Offense Pts
# 6) Current Defense Pts
# 7) Down
# 8) Distance
# 9) Spot
# 10) Offense Points This Drive
# 11) Defense Points This Drive
# 12) Play Type
# 13) Play Yards
# 14) Offense Points This Play
# 15) Defense Points This Play
sub print_game($$$$) {
  my $gid = shift;
  my $play_href = shift;
  my $drive_href = shift;
  my $outf = shift;

  my $num_plays = scalar(keys %$play_href);
  my @game_plays;
  my $curr_drive_num = undef;
  my $drive_start_idx = undef;
  my %drive_start_pts = ();
  foreach my $playnum (1..$num_plays) {
    my $play_aref = $$play_href{$playnum};
    die "No such play num: $playnum" if (!defined($play_aref));
    # If we're past the 4th Quarter, just bail for now
    if ($$play_aref[2] > 4) {
#      print STDERR "Overtime: $gid\n";
      last;
    }
    my @play_data = ("") x 15;
    # TFG game ID
    $play_data[0] = $gid;
    # Amount of time left (or blank if initially not known)
    $play_data[1] = calc_time_left($$play_aref[2], $$play_aref[3]);
    my $off_tid = ncaa_tid_to_tfg_tid($$play_aref[4]);
    my $def_tid = ncaa_tid_to_tfg_tid($$play_aref[5]);
    $play_data[2] = $off_tid;
    $play_data[3] = $def_tid;
    # Points at the start of the play
    my %this_pts;
    get_points($play_aref, \%this_pts);
    $play_data[4] = $this_pts{$off_tid};
    $play_data[5] = $this_pts{$def_tid};
    # Down, distance, and spot
    $play_data[6] = $$play_aref[8];
    $play_data[7] = $$play_aref[9];
    $play_data[8] = $$play_aref[10];
    # For now we leave the offense and defense points blank.
    # Fill in the play type
    $play_data[11] = $$play_aref[11];
    # If this is not the last play of the game, figure out the number of yards
    # gained this play, as well as the number of points.
    if ($playnum != $num_plays) {
      my $next_playnum = $playnum + 1;
      my $next_play_aref = $$play_href{$next_playnum};
      if (!defined($next_play_aref)) {
        warn "We shouldn't be at the end of the game yet!";
        next;
      }
      my %next_pts;
      get_points($next_play_aref, \%next_pts);
      # Fill in the number of offense points and defense points
      $play_data[13] = $next_pts{$off_tid} - $this_pts{$off_tid};
      $play_data[14] = $next_pts{$def_tid} - $this_pts{$def_tid};
      # If it's not a kickoff or kick attempt, get the number of yards gained.
      $play_data[12] = get_yards_gained($play_aref, $next_play_aref);
    } else {
      # This is the last play of the game.
    }
    my $this_drive_num = $$play_aref[12];
    if (!length($this_drive_num)) {
      # This play is not part of a drive. Is it an XP/2PT attempt?
      if ($play_data[11] ne "ATTEMPT" and $play_data[11] ne "TIMEOUT" and $play_data[11] ne "PENALTY") {
#        print "\nPlay type means end of previous drive: $play_data[11] ($curr_drive_num)\n";
        # No, it's not. Fill in the previous drive info.
        fill_drive_entries($drive_start_idx, \%drive_start_pts, \%this_pts, \@game_plays);
        $curr_drive_num = undef;
        $drive_start_idx = undef;
        %drive_start_pts = ();
      }
    } elsif (defined($curr_drive_num) and ($curr_drive_num != $this_drive_num)) {
#      print "\nFound new drive ($this_drive_num) is not current drive ($curr_drive_num)\n";
      # Fill the previous drive data.
      fill_drive_entries($drive_start_idx, \%drive_start_pts, \%this_pts, \@game_plays);
      $curr_drive_num = $this_drive_num;
      $drive_start_idx = $playnum - 1;
      %drive_start_pts = %{ clone (\%this_pts) };
    } elsif (!defined($curr_drive_num)) {
#      print "\nStart of new drive ($this_drive_num)\n";
      $curr_drive_num = $this_drive_num;
      $drive_start_idx = $playnum - 1;
      %drive_start_pts = %{ clone (\%this_pts) };
    }
    push(@game_plays, \@play_data);
    if ($playnum == $num_plays) {
      # This is the last play of the game. Get the number of points in the final
      # and fill in the last drive.
      my %final_pts;
      my $game_aref = $results{$gid};
      $final_pts{$$game_aref[5]} = $$game_aref[7];
      $final_pts{$$game_aref[8]} = $$game_aref[10];
      # Play points
      $play_data[13] = $final_pts{$off_tid} - $this_pts{$off_tid};
      $play_data[14] = $final_pts{$def_tid} - $this_pts{$def_tid};
      # Drive points
      fill_drive_entries($drive_start_idx, \%drive_start_pts, \%final_pts, \@game_plays);
    }
  }
  smooth_clock(\@game_plays);
  foreach my $aref (@game_plays) {
    print $outf join(',', @$aref) . "\n";
  }
}

sub get_points($$) {
  my $aref = shift;
  my $href = shift;
  $$href{ncaa_tid_to_tfg_tid($$aref[4])} = $$aref[6];
  $$href{ncaa_tid_to_tfg_tid($$aref[5])} = $$aref[7];
}

sub ncaa_gid_to_tfg_gid($) {
  my $ncaa_gid = shift;
  my ($t1, $t2, $date);
  if ($ncaa_gid =~ /^(\d{4})(\d{4})(\d{8})$/) {
    $t1 = $1;
    $t2 = $2;
    $date = $3;
  }
  $t1 = ncaa_tid_to_tfg_tid($t1);
  $t2 = ncaa_tid_to_tfg_tid($t2);
  my $tfg_gid = sprintf "%s-%d-%d", $date, $t1, $t2;
  return $tfg_gid if (defined($results{$tfg_gid}));
  $tfg_gid = sprintf "%s-%d-%d", $date, $t2, $t1;
  return $tfg_gid if (defined($results{$tfg_gid}));
#  warn "No such TFG game: $ncaa_gid ($date, $t1, $t2)";
  return undef;
}

sub ncaa_tid_to_tfg_tid($) {
  my $tfg_tid = shift;
  $tfg_tid =~ s/^0*//g;
  return $tfg_tid + 1000;
}

sub calc_time_left($$) {
  my $q_num = shift;
  my $q_left = shift;
  return '' if (!defined($q_num) or !defined($q_left));
  return '' if (!length($q_num) or !length($q_left));
  return (900 * (4 - $q_num)) + $q_left;
}

sub get_yards_gained($$) {
  my $play_aref = shift;
  my $next_play_aref = shift;
  return 0 if (!defined($play_aref) or !defined($next_play_aref));
  return 0 if ($$play_aref[11] eq "ATTEMPT");
  # Note: we may change this to account for onsides kicks
  return 0 if ($$play_aref[11] eq "KICKOFF");
  # We don't handle field goals well right now.
  return 0 if ($$play_aref[11] eq "FIELD_GOAL");
  # We don't handle punts well right now.
  return 0 if ($$play_aref[11] eq "PUNT");
  # If this crosses the halftime or end-of-regulation boundary, return 0.
  return 0 if ($$play_aref[2] == 2 and $$next_play_aref[2] == 3);
  return 0 if ($$play_aref[2] == 4 and $$next_play_aref[2] == 5);
  # If the offense is the same for each play, then possession has been
  # maintained.
  if ($$play_aref[4] == $$next_play_aref[4]) {
    # Same team has the ball. Unless they scored a TD, we can do some simple
    # math.
    if ($$next_play_aref[11] eq "ATTEMPT") {
      # They scored. They gained ALL THE YARDS.
      return $$play_aref[10];
    }
    # They didn't score. Do the math.
    if (length($$play_aref[10]) and length($$next_play_aref[10])) {
      return $$play_aref[10] - $$next_play_aref[10];
    }
  } else {
    # There was a turnover.
    return "TURNOVER";
  }
  warn "Unknown number of yards gained:\nThisPlay\n" . join(',', @$play_aref)
    . "\nNextPlay\n" . join(',', @$next_play_aref) . "\n";
  return 0; # Catch-all.
}

sub fill_drive_entries($$$$) {
  my $start_idx = shift;
  my $start_pts_href = shift;
  my $this_pts_href = shift;
  my $plays_aref = shift;
  return if (!defined($start_idx));
  my %drive_pts;
  foreach my $tid (keys %$this_pts_href) {
    $drive_pts{$tid} = $$this_pts_href{$tid} - $$start_pts_href{$tid};
  }
#  print "StartIDX: $start_idx EndIDX: " . $#$plays_aref . "\n";
#  print "\tStart: " . p($start_pts_href) . " This: " . p($this_pts_href) . " DrivePts: " . p(%drive_pts) . "\n";
  foreach my $idx ($start_idx..$#$plays_aref) {
    my $aref = $$plays_aref[$idx];
    my $off_tid = $$aref[2];
    my $def_tid = $$aref[3];
    $$aref[9] = $drive_pts{$off_tid};
    $$aref[10] = $drive_pts{$def_tid};
  }
}

sub smooth_clock($) {
  my $plays_aref = shift;
  my $last_seen_idx = 0;
  my $last_seen_value = 3600;
  foreach my $idx (0..$#$plays_aref) {
    my $aref = $$plays_aref[$idx];
    if (length($$aref[1])) {
      # The clock was seen at this index
      my $clock_diff = $last_seen_value - $$aref[1];
      my $num_plays = $idx - $last_seen_idx;
      if ($num_plays > 1) {
        my $per_play_delta = $clock_diff / $num_plays;
        foreach my $adj_idx (1..($num_plays - 1)) {
          my $updated_idx = $last_seen_idx + $adj_idx;
          my $updated_clock = $last_seen_value - ($adj_idx * $per_play_delta);
          $$plays_aref[$updated_idx][1] = sprintf "%.1f", $updated_clock;
        }
      }
      $last_seen_value = $$aref[1];
      $last_seen_idx = $idx;
    }
  }
}
