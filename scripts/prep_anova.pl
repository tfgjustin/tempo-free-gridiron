#!/usr/bin/perl -w

use strict;

my $WIN_BIN_SIZE = 50;

#print "HAN NumMeet WinBin SosBin PredDiff\n";
print "HAN NumMeet WinBin Date PredDiff\n";
my %num_seen;
while(<STDIN>) {
  next if(/^WK/ or /G  0  0 /);
  chomp;
  s/\-/\ /g;
  @_ = split;
  my $monthday = substr($_[0], 4, 2) .  "" . int(substr($_[0], 6, 2) / 16);
  my $home = $_[1];
  my $away = $_[2];
  my $is_n = $_[12];
  my $home_wbin = int($_[13] / $WIN_BIN_SIZE);
  my $away_wbin = int((1000 - $_[13]) / $WIN_BIN_SIZE);
  my $home_pdiff = $_[18] / $_[21];
  my $away_pdiff = $_[19] / $_[22];
  my $home_sos = $_[15];
  my $away_sos = $_[16];
  my $home_sosbin = 1000 + int($home_sos - $away_sos);
  $home_sosbin = int($home_sosbin / $WIN_BIN_SIZE);
  my $away_sosbin = 1000 + int($away_sos - $home_sos);
  $away_sosbin = int($away_sosbin / $WIN_BIN_SIZE);
  my @g = ( $home , $away );
  @g = sort @g;
  my $gid = join(':', @g);
  $num_seen{$gid} += 1;
  my ( $h , $a ) = ( "H" , "A" );
  if ($is_n) {
    $h = "N";
    $a = "N";
  }
  printf "%s M%02d W%02d MD%03d %5.3f\n", $h, $num_seen{$gid}, $home_wbin,
         $monthday, $home_pdiff;
  printf "%s M%02d W%02d MD%03d %5.3f\n", $a, $num_seen{$gid}, $away_wbin,
         $monthday, $away_pdiff;
}
