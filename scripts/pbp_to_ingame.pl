#!/usr/bin/perl 

use TempoFree;
use Text::CSV;
use strict;
use warnings;

my $infile = shift(@ARGV);
my $outfile = shift(@ARGV);

if (!defined($infile) or !defined($outfile)) {
  die "Usage: $0 <infile> <outfile>";
}

if (! -f $infile) {
  die "Missing input file $infile";
}

my %id2name;
LoadIdToName(\%id2name);

# Input format
# 20130107-1008-1513,7,46,1005,21,0,1008,1008,37,3,12,"bama committed 10 yard penalty"
# GID,DriveId,PlayId,GameClock,HomeScore,AwayScore,OffId,FieldId,Yard,Down,Dist,Play

# Output format:
# 0,Date,GID,Field,TimeLeft,HomeId,HomeName,HomeScore,AwayId,AwayName,AwayScore
# 0,20121227,20121227-1140-1193,CINCINNATI,0,1140,CINCINNATI,48,1193,DUKE,34

my $csv = Text::CSV->new() or die "Cannot use CSV: " . Text::CSV->error_diag();

open my $inf, "<", $infile or die "Cannot open input file $infile: $!";
open my $outf, ">", $outfile or die "Cannot open output file $outfile: $!";
my $last_home_score = 0;
my $last_away_score = 0;
my ($gid, $date, $home_id, $away_id);
my ($home_name, $away_name);
while(my $row = $csv->getline($inf)) {
  $gid = $row->[0];
  ($date, $home_id, $away_id) = split(/-/, $gid);
  next if (!defined($away_id));
  my $time_left = 3600 - $row->[3];
  $time_left = 1 if ($time_left < 0);  # Overtime
  my $home_score = $row->[4];
  my $away_score = $row->[5];
  my $off_id = $row->[6];
  my $field_side = $row->[7];
  my $yard = $row->[8];
  if ($field_side eq $off_id) {
    $yard = 100 - $yard;
  }
  my ($off_exp_pts, $def_exp_pts) = FieldPositionPoints($yard);
  $off_exp_pts = 0 if ($off_exp_pts < 0);
  $def_exp_pts = 0 if ($def_exp_pts < 0);
  my ($home_exp_pts, $away_exp_pts) = ( 0, 0 );
  if ($row->[11] !~ /kicked off/ and ($home_score == $last_home_score) and
      ($away_score == $last_away_score)) {
    if ($off_id eq $home_id) {
      $home_exp_pts = $off_exp_pts;
      $away_exp_pts = $def_exp_pts;
    } elsif ($off_id eq $away_id) {
      $home_exp_pts = $def_exp_pts;
      $away_exp_pts = $off_exp_pts;
    } else {
      die "Offense ID $off_id is not home $home_id or away $away_id";
    }
  }
  $home_name = $id2name{$home_id};
  $away_name = $id2name{$away_id};
  die "Unknown home ID: $home_id" if (!defined($home_name));
  die "Unknown away ID: $away_id" if (!defined($away_name));
  printf $outf "0,%d,%s,%s,%d,%d,%s,%d,%d,%s,%d,%.2f,%.2f\n",
               $date, $gid, $home_name, $time_left, $home_id, $home_name,
               $home_score, $away_id, $away_name, $away_score,
               $home_score + $home_exp_pts, $away_score + $away_exp_pts;
  $last_home_score = $home_score;
  $last_away_score = $away_score;
}
printf $outf "0,%d,%s,%s,%d,%d,%s,%d,%d,%s,%d,%d,%d\n",
             $date, $gid, $home_name, 0, $home_id, $home_name,
             $last_home_score, $away_id, $away_name, $last_away_score,
             $last_home_score, $last_away_score;
close $inf;
close $outf;
