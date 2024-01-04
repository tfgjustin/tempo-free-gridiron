#!/usr/bin/perl 
#===============================================================================
#
#         FILE: parse_cfbstats_gamelog.pl
#
#        USAGE: ./parse_cfbstats_gamelog.pl  
#
#  DESCRIPTION: Parse the game.csv file found in the cfbstats zipfile.
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 10/27/2013 06:17:26 PM
#     REVISION: ---
#===============================================================================

use TempoFree;
use strict;
use warnings;

my $gamelog_filename = shift(@ARGV);
exit 1 if (!defined($gamelog_filename) or ! -f $gamelog_filename);

my %id2name;
my %id2conf;
LoadConferences(\%id2name, \%id2conf, undef, undef);

open(GAMELOG, "$gamelog_filename") or die "Can't open $gamelog_filename: $!";
while(<GAMELOG>) {
  next if (/Game Code/);
  chomp;
  s/\r//g;
  @_ = split(/,/);
  my $date = undef;
  if ($_[0] =~ /^\d{8}(20\d{6})$/) {
    $date = $1;
  } else {
    next;
  }
  my $hid = 1000 + $_[3];
  my $aid = 1000 + $_[2];
  my $hn = $id2name{$hid};
  my $an = $id2name{$aid};
  next if(!defined($hn) or !defined($an));
  my $hc = $id2conf{$hid};
  my $ac = $id2conf{$aid};
  next if(!defined($hc) or !defined($ac));
  next if (($hc eq "FCS") or ($ac eq "FCS"));
  my $site = "NEUTRAL";
  if ($_[5] eq "TEAM") {
    $site = $hn;
  }
  print "$date,$site,$hid,$aid,$hn,$an\n";
}
close(GAMELOG);
