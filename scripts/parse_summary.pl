#!/usr/bin/perl -w

use TempoFree;
use strict;

my %gamelog;
my %id2name;

my %teamconf_peryear;
foreach my $y (2000..2014) {
  my %c_id2name;
  my %c_team2conf;
  my %c_conf2team;
  my %c_isbcs;
  LoadConferencesForYear($y, \%c_id2name, \%c_team2conf, \%c_conf2team, \%c_isbcs);
  $teamconf_peryear{$y} = \%c_team2conf;
}

my $pre2013_format = undef;
while(<STDIN>) {
  chomp;
  if (!defined($pre2013_format)) {
    if (/INSTITUTION/) {
      $pre2013_format = 1;
    } elsif (/^DIV/) {
      $pre2013_format = 0;
    } else {
      die "Can't determine format from header: \"$_\"";
    }
    next;
  }
  $_ =~ s/\r|\n//g;
  @_ = split(/,/);
  my ($date, $team_one_id, $team_one_name, $team_two_id, $team_two_name);
  if ($pre2013_format) {
    $date = $_[2];
    $team_one_id   = $_[0];
    $team_one_name = $_[1];
    $team_two_id   = $_[3];
    $team_two_name = $_[4];
  } else {
    $date = $_[5];
    $team_one_id   = $_[1];
    $team_one_name = $_[2];
    $team_two_id   = $_[3];
    $team_two_name = $_[4];
  }
  if (!length($date) or !length($team_one_id) or !length($team_one_name)
      or !length($team_two_id) or !length($team_two_name)) {
    warn "Missing data: \"$_\"";
    next;
  }
  my ($t1id, $t1n, $t2id, $t2n);
  my $loc = $_[-1];
  my $curr_loc = undef;
  if ($loc eq "HOME") {
    $curr_loc = "H";
  } elsif ($loc eq "AWAY") {
    $curr_loc = "A";
  } elsif ($loc =~ /NEUTRAL/) {
    $curr_loc = "N";
  } else {
    $curr_loc = "U";
  }
  if (!defined($curr_loc)) {
    warn "Unknown location: $loc ($_)";
    next;
  }

  if ($team_one_id < $team_two_id) {
    $t1id = $team_one_id;
    $t1n  = $team_one_name;
    $t2id = $team_two_id;
    $t2n  = $team_two_name;
  } else {
    $t1id = $team_two_id;
    $t1n  = $team_two_name;
    $t2id = $team_one_id;
    $t2n  = $team_one_name;
  }
  my $gameid;
  if ($date =~ /^(\d{2})\/(\d{2})\/(\d{2})$/ or $date =~ /^(\d{1,2})\/(\d{1,2})\/20(\d{2})$/) {
    if (!defined($curr_loc)) {
      warn "No L";
      next;
    }
    if (!defined($t1n)) {
      warn "No t1n";
      next;
    }
    if (!defined($t2n)) {
      warn "No t1n";
      next;
    }
    if (!defined($t1id)) {
      warn "No t1id";
      next;
    }
    if (!defined($t2id)) {
      warn "No t2id";
      next;
    }
    if (!defined($1) or !defined($2) or !defined($3)) {
      warn "No match (WTF)";
      next;
    }

    $date = sprintf "20%02d%02d%02d", $3, $1, $2;
    my $season = DateToSeason($date);
    next if (!defined($season) or ($season < 0));
    my $t1fid = 1000 + $t1id;
    my $t2fid = 1000 + $t2id;
    my $t1conf = $teamconf_peryear{$season}{$t1fid};
    my $t2conf = $teamconf_peryear{$season}{$t2fid};
    if (!defined($t1conf) or ($t1conf eq "FCS")) {
#      warn "Year $season Team $t1fid $t1n NOT FBS";
      next;
    }
    if (!defined($t2conf) or ($t2conf eq "FCS")) {
#      warn "Year $season Team $t2fid $t2n NOT FBS";
      next;
    }

    $id2name{$t1id} = $t1n;
    $id2name{$t2id} = $t2n;
    # Note that we preprend all team IDs with a 1 to make sure they're
    # always interpreted as base 10 (otherwise teams starting with a 0
    # would be interpreted as octal).
    my $gameid = sprintf "%s-%04d-1%04d", $date, 1000 + $t1id, 1000 + $t2id;
    my $game_loc = undef;
    if (defined($gamelog{$gameid})) {
      my $first_loc = $gamelog{$gameid};
      if ($first_loc eq "N" or $curr_loc eq "N") {
        $game_loc = "NEUTRAL";
      } elsif ($first_loc eq "U") {
        if ($curr_loc eq "H") {
          $game_loc = $team_one_name;
        } elsif ($curr_loc eq "A") {
          $game_loc = $team_two_name;
        } elsif ($curr_loc eq "U") {
          $game_loc = "NEUTRAL";
        } else {
          warn "No one know where game $gameid happened?";
          next;
        }
      } elsif ($curr_loc eq "U") {
        if ($first_loc eq "H") {
          $game_loc = $team_two_name;
        } elsif ($first_loc eq "A") {
          $game_loc = $team_one_name;
        } else {
          warn "No one know where game $gameid happened?";
          next;
        }
      } elsif ($first_loc eq "H") {
        if ($curr_loc eq "A") {
          $game_loc = $team_two_name;
        } else {
          warn "Unknown location for $gameid (1)";
          next;
        }
      } elsif ($first_loc eq "A") {
        if ($curr_loc eq "H") {
          $game_loc = $team_one_name;
        } else {
          warn "Unknown location for $gameid (2)";
          next;
        }
      } else {
        warn "Unknown location for $gameid (3)";
        next;
      }
      delete $gamelog{$gameid};
    } else {
      $gamelog{$gameid} = $curr_loc;
      next;
    }
    if (!defined($game_loc)) {
      warn "Unknown location for $gameid (4)";
      next;
    }
    printf "%s,%s,1%03d,1%03d,%s,%s\n", $date, $game_loc, $t1id, $t2id, $t1n, $t2n;
  } else {
    warn "Invalid date: $date";
  }
}
