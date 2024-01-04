#!/usr/bin/perl -w

use strict;

my $PARSEHTML = "w3m -dump -cols 300 -T text/html";

sub parse_one_file($);
sub extract_metadata($);
sub parse_stats($$$$$$);
sub parse_summary($$$$$);
sub print_summary($$$$$$$);

my @filelist = <STDIN>;
chomp (@filelist);
if (!@filelist) {
  die "No named files provided on STDIN";
}

foreach my $fname (@filelist) {
  parse_one_file($fname);
  print STDERR ".";
}
print STDERR "\n";

############################### Helper Functions ###############################
sub parse_one_file($) {
  my $filename = shift;
  my $teamid = extract_metadata($filename);
  if (!defined($teamid)) {
    warn "Error extracting metadata from $filename";
    return;
  }
  my $cmd = "cat $filename | sed -e 's/\&nbsp/0/g' | $PARSEHTML";
  open(CMD, "$cmd|") or do {
    warn "Could not execute \"$cmd\": $!";
    return;
  };
  my %game_plays;
  my %game_penalties;
  my %game_points;
  my %game_yards;
  my %game_int;
  my %game_fumbles;
  my %game_downs;
  while(<CMD>) {
    chomp;
#    print "CMD: $_\n";
    if (/\/0[0-9]\ \w/ or /\/1[0123]\ \w/) {
      @_ = split;
      if (scalar(@_) > 30) {
        parse_stats($teamid, \@_, \%game_plays, \%game_points, \%game_yards,
                    \%game_int);
      } else {
        parse_summary($teamid, \@_, \%game_penalties, \%game_fumbles, \%game_downs);
      }
    }
  }
  close(CMD);
  print_summary(\%game_plays, \%game_points, \%game_penalties, \%game_yards,
                \%game_int, \%game_fumbles, \%game_downs);
}

sub extract_metadata($) {
  my $filename = shift;
  my @path = split(/\//, $filename);
  $filename = pop(@path);
  if ($filename =~ /(\d{4})\d{6}(\d{3})teamoff.html/) {
    return "1" . $2;
  } else {
    return undef;
  }
}

sub parse_stats($$$$$$) {
  my ($teamid, $aref, $plays_href, $points_href, $yards_href, $int_href) = @_;
  my $date = $$aref[0];
  my $pts  = $$aref[-1];
  my $fgm  = $$aref[-3];  # There's a kickoff after each FGM
  my $fga  = $$aref[-4];
  my $tds  = $$aref[-13]; # A kickoff after each TD
  my $ko_ret_yds = $$aref[-15];
  my $pt_ret_yds = $$aref[-18];
  my $punt = $$aref[-21];
  my $fum_ret_yds = $$aref[-23];
  my $int_ret_yds = $$aref[-26];
  my $int_count = $$aref[-27];
  my $line = $$aref[-32];
  my $pass_yds = $$aref[-35];
  my $pass_plays = $$aref[-38];
  my $rush_yds = $$aref[-40];
  my $rush_plays = $$aref[-43];
  my $score_plays = $fgm + $tds;
  my $tplays = $fga + $punt + $line + $tds + 1;  # One KO to start each half
  my $yards = $ko_ret_yds + $pt_ret_yds + $fum_ret_yds + $int_ret_yds;
  $yards += $pass_yds + $rush_yds;
  my ($yr, $mo, $day);
  if ($date =~ /(\d{2})\/(\d{2})\/(\d{2})/) {
    $yr  = "20" . $3;
    $mo  = $1;
    $day = $2;
  } else {
    warn "Invalid date format: $date";
    return;
  }
  my @per_yards = ( $yards , $pass_yds, $rush_yds );
  my $gameid = sprintf "%4d%02d%02d-%s", $yr, $mo, $day, $teamid;
#  print "$gameid,$pts,$tplays,$line,$punt,$tds,$fga,$fgm\n";
  my @plays = ( $tplays, $pass_plays, $rush_plays, $score_plays );
  $$plays_href{$gameid} = \@plays;
  $$points_href{$gameid} = $pts;
  $$yards_href{$gameid} = \@per_yards;
  $$int_href{$gameid} = $int_count;
}

sub parse_summary($$$$$) {
  my ($teamid, $aref, $penalties_href, $fumbles_href, $downs_href) = @_;
  my $date = $$aref[0];
  my $fumbles = $$aref[-3];
  my $pen  = $$aref[-6];
  my $downs = $$aref[-10] + $$aref[-9] + $$aref[-8];
  my ($yr, $mo, $day);
  if ($date =~ /(\d{2})\/(\d{2})\/(\d{2})/) {
    $yr  = "20" . $3;
    $mo  = $1;
    $day = $2;
  } else {
    warn "Invalid date format: $date";
    return;
  }
  my $gameid = sprintf "%4d%02d%02d-%s", $yr, $mo, $day, $teamid;
  $$penalties_href{$gameid} = $pen;
  $$fumbles_href{$gameid} = $fumbles;
  $$downs_href{$gameid} = $downs;
}

sub print_summary($$$$$$$) {
  my ($plays_href, $points_href, $penalties_href, $yards_href, $int_href,
      $fumbles_href, $downs_href) = @_;
  foreach my $gameid (sort keys %$plays_href) {
    my $numplays_aref = $$plays_href{$gameid};
    my $numplays = $$numplays_aref[0];
    my $pplays = $$numplays_aref[1];
    my $rplays = $$numplays_aref[2];
    my $splays = $$numplays_aref[3];
    my $numpoints = $$points_href{$gameid};
    my $numpenalties = $$penalties_href{$gameid};
    $numplays += int($numpenalties / 2);
    my $yards_aref = $$yards_href{$gameid};
    my $tyards = $$yards_aref[0];
    my $pyards = $$yards_aref[1];
    my $ryards = $$yards_aref[2];
    my $int_num = $$int_href{$gameid};
    my $fumbles = $$fumbles_href{$gameid};
    my $downs = $$downs_href{$gameid};
    print "$gameid,$numpoints,$numplays,$tyards,$pyards,$ryards,$int_num,"
          . "$fumbles,$numpenalties,$pplays,$rplays,$downs,$splays\n";
  }
}
