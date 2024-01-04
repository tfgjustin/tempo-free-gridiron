#!/usr/bin/perl -w

use POSIX;
use strict;

my $FIRST_DAY = POSIX::mktime(0, 0, 0, 23, 7, 100);

sub parse_line($);
sub create_summary_line($$$$$$$$);
sub date_to_week($);
sub usage($);

my %offense_summary;
my %gamelog;

my $offense_filename = shift(@ARGV);
my $gamelog_filename = shift(@ARGV);

usage($0) if (!defined($offense_filename) or !defined($gamelog_filename));

if (! -f $offense_filename) {
  print STDERR "Could not find offense data: $offense_filename\n";
  usage($0);
}

if (! -f $gamelog_filename) {
  print STDERR "Could not find gamelog data: $gamelog_filename\n";
  usage($0);
}

my %offense_data;
open(OFF, "$offense_filename") or die "Cannot open offense data: $!";
while(<OFF>) {
  chomp;
  my @d = split(/,/);
  my $off_id = shift(@d);
  $offense_data{$off_id} = \@d;
}
close(OFF);

print "#Week,Date,GameID,Site,NumPoss,HomeID,HomeName,HomeScore,"
      . "AwayID,AwayName,AwayScore,HomeYards,AwayYards,HomePass,AwayPass,"
      . "HomeRush,AwayRush,HomeTOs,AwayTOs,HomePen,AwayPen,HomePassPlays,"
      . "AwayPassPlays,HomeRunPlays,AwayRunPlays,HomeFirstDowns,AwayFirstDowns,"
      . "HomeScores,AwayScores\n";
open(GAME, "$gamelog_filename") or die "Cannot open gamelog data: $!";
while(<GAME>) {
  parse_line($_);
}
close(GAME);

############################### Helper functions ###############################

sub parse_line($) {
  my $l = shift;
  chomp($l);
  @_ = split(/,/, $l);
  # Div,Team ID,Team,Opp ID,Opp,Date,Location
  my $date = $_[0];
  my $site = $_[1];
  my $team1 = $_[2];
  my $team2 = $_[3];
  my $t1name = $_[4];
  my $t2name = $_[5];
  my $off1id = "$date-$team1";
  my $off2id = "$date-$team2";
  my $t1aref = $offense_data{$off1id};
  if (!defined($t1aref)) {
    my @empty = ( 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 );
    $t1aref = \@empty;
    warn "Could not find data for $off1id\n";
  }
  my $t2aref = $offense_data{$off2id};
  if (!defined($t2aref)) {
    my @empty = ( 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 );
    $t2aref = \@empty;
    warn "Could not find data for $off2id\n";
  }
  my $output = create_summary_line($date, $site, $team1, $t1name, $t1aref, 
    $team2, $t2name, $t2aref);
  print "$output\n" if (defined($output));
}

# Summary:
# Week,Date,GameID,Site,NumPoss,HomeID,HomeName,HomeScore,
#   AwayID,AwayName,AwayScore,HomeYards,AwayYards,HomePass,AwayPass,
#   HomeRush,AwayRush,HomeTOs,AwayTOs,HomePen,AwayPen,
#   HomePassPlays,AwayPassPlays,HomeRunPlays,AwayRunPlays
sub create_summary_line($$$$$$$$) {
  my ($date, $site, $t1id, $t1n, $aref1, $t2id, $t2n, $aref2) = @_;
  my ($homeid, $homename, $homearef);
  my ($awayid, $awayname, $awayaref);
  if ($site eq "NEUTRAL") {
    # Neutral site
    $homeid = $t1id;
    $homename = $t1n;
    $homearef = $aref1;
    $awayid = $t2id;
    $awayname = $t2n;
    $awayaref = $aref2;
  } elsif ($site eq $t1n) {
    $site = $t1n;
    $homeid = $t1id;
    $homename = $t1n;
    $homearef = $aref1;
    $awayid = $t2id;
    $awayname = $t2n;
    $awayaref = $aref2;
  } elsif ($site eq $t2n) {
    $homeid = $t2id;
    $homename = $t2n;
    $homearef = $aref2;
    $awayid = $t1id;
    $awayname = $t1n;
    $awayaref = $aref1;
  } else {
    warn "Not sure where $date-$t1id-$t2id was held: ($site, $t1n, $t2n)";
    return undef;
  }
  my $homepts = $$homearef[0];
  my $awaypts = $$awayaref[0];
  my $numposs = $$homearef[1] + $$awayaref[1];
  my $homeyards = $$homearef[2];
  my $awayyards = $$awayaref[2];
  my $homepassy = $$homearef[3];
  my $awaypassy = $$awayaref[3];
  my $homerushy = $$homearef[4];
  my $awayrushy = $$awayaref[4];
  # Item 5 is the number of interceptions made by that team and item 6 is the
  # number of fumbles lost by that team.  Therefore the total number of
  # turnovers is the number of INTs made by your opponent (item 5) plus the
  # number of fumbles you lost (item 6).
  my $home_tos = $$awayaref[5] + $$homearef[6];
  my $away_tos = $$homearef[5] + $$awayaref[6];
  my $home_pen = $$homearef[7];
  my $away_pen = $$awayaref[7];
  my $home_np = $$homearef[8];
  my $away_np = $$awayaref[8];
  my $home_nr = $$homearef[9];
  my $away_nr = $$awayaref[9];
  my $home_nfd = $$homearef[10];
  my $away_nfd = $$awayaref[10];
  my $home_ns = $$homearef[11];
  my $away_ns = $$awayaref[11];
#  return undef if (!$numposs);
  my $week = date_to_week($date);
  $week = "-1" if (!defined($week));
  my $gid = sprintf "%d,%s,%s-%d-%d", $week, $date, $date, $homeid, $awayid;
  my $summary = sprintf "%s,%d,%d,%s,%d,%d,%s,%d", $site, $numposs, $homeid,
                        $homename, $homepts, $awayid, $awayname, $awaypts;
  my $yardage = sprintf "%d,%d,%d,%d,%d,%d", $homeyards, $awayyards, $homepassy,
                        $awaypassy, $homerushy, $awayrushy;
  my $misc = sprintf "%d,%s,%d,%d", $home_tos, $away_tos, $home_pen, $away_pen;
  my $plays = sprintf "%d,%d,%d,%d,%d,%d,%d,%d", $home_np, $away_np, $home_nr,
                       $away_nr, $home_nfd, $away_nfd, $home_ns, $away_ns;
  my $l = sprintf "%s,%s,%s,%s,%s", $gid, $summary, $yardage, $misc, $plays;
                  
  return $l;
}

sub date_to_week($) {
  my $date = shift;
  if ($date =~ /(\d{4})(\d{2})(\d{2})/) {
    my $year = $1 - 1900;
    my $month = $2 - 1;
    my $day = $3;
    my $t = POSIX::mktime(0, 0, 12, $day, $month, $year);
    $t -= $FIRST_DAY;
    my $week = int($t / (7 * 24 * 3600));
    return $week;
  } else {
    warn "Invalid date format: $date";
    return undef;
  }
}

sub usage($) {
  my $p = shift;
  print STDERR "\n";
  print STDERR "Usage: $p <offense_summary> <gamelog>\n";
  print STDERR "\n";
  exit 1;
}
