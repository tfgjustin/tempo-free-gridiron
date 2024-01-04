#!/usr/bin/perl 

use TempoFree;
use strict;
use warnings;

sub usage($) {
  my $p = shift;
  print STDERR "\n";
  print STDERR "Usage: $p <cfbstats_gamecsv>\n";
  print STDERR "\n";
  exit 1;
}

my %id2name;
my %id2conf;
my %conf2teams;
my %is_bcs;

LoadConferences(\%id2name, \%id2conf, \%conf2teams, \%is_bcs);

my $cfbstatsfile = shift(@ARGV);
usage($0) if (!defined($cfbstatsfile));
if (! -f $cfbstatsfile) {
  warn "No such file: $cfbstatsfile";
  usage($0);
}

open my $fh, "<", $cfbstatsfile or die "Can't open $cfbstatsfile for reading: $!";
while(<$fh>) {
  next if (/Team Code/);
  @_ = split(/,/);
  my $team_id = undef;
  if ($_[0] =~ /^0*(\d+)$/) {
    $team_id = 1000 + $1;
  } else {
    next;
  }
  if (!defined($team_id)) {
    warn "Invalid team ID: $team_id";
    next;
  }
  my $conf = $id2conf{$team_id};
  next if (!defined($conf));
  next if ($conf eq "FCS");
  my $game_date = undef;
  if ($_[1] =~ /^\d{8}(20\d{6})$/) {
    $game_date = $1;
  }
  if (!defined($game_date)) {
    warn "Invalid game ID: $_[1]";
    next;
  }
# Need to get:
# - FGA
# - FGM
# - KORetYards
# - PassPlays
# - PassYards
# - PuntRetYards
# - Punts
# - RushPlays
# - RushYards
# - TDs
# - NumPoints
# - Fumbles
# - IntRetYards
# - Num1stDowns
# - NumIntercept
# - NumPenalties
  my $fga = $_[26];
  my $fgm = $_[27];
  my $ko_ret_yards = $_[12];
  my $num_pass = $_[5];
  my $pass_yards = $_[7];
  my $punt_ret_yards = $_[15];
  my $num_punts = $_[36];
  my $num_rush = $_[2];
  my $rush_yards = $_[3];
  my $tds = $_[4] + $_[8] + $_[13] + $_[16] + $_[19] + $_[22] + $_[25];
  my $points = $_[35];
  my $fumbles = $_[44];
  my $fumble_ret_yards = $_[18];
  my $int_ret_yards = $_[21];
  my $num_first = $_[55] + $_[56] + $_[57];
  my $num_int = $_[20];
  my $num_penalties = $_[59];
# Output:
# GameID,NumPoints,NumPlays,TotalYards,PassYards,RushYards,NumIntercept,Fumbles\
# ,NumPenalties,PassPlays,RushPlays,Num1stDowns,ScorePlays
# GameID: YYYYMMDD-TFGID
# NumPlays: FGA + Punts + TDs + 1 + PassPlays + RushPlays + (NumPenalties / 2)
# TotalYards: KORetYards + PuntRetYards + FumRetYards + IntRetYards + PassYards + RushYards
# ScorePlays: FGM + TDs
  my $score_plays = $fgm + $tds;
  my $total_yards = $ko_ret_yards + $punt_ret_yards + $fumble_ret_yards;
  $total_yards += $int_ret_yards + $pass_yards + $rush_yards;
  my $num_plays = $fga + $num_punts + $tds + 1 + $num_pass + $num_rush;
  $num_plays += ($num_penalties / 2);
  printf "%d-%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n", $game_date, $team_id,
         $points, $num_plays, $total_yards, $pass_yards, $rush_yards, $num_int,
         $fumbles, $num_penalties, $num_pass, $num_rush, $num_first, $tds + $fgm;
}
close($fh);
