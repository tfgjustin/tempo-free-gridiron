#!/usr/bin/perl 
#===============================================================================
#
#         FILE: merge_tfg_boxscore.pl
#
#        USAGE: ./merge_tfg_boxscore.pl  
#
#  DESCRIPTION: Merge TFG boxscore summaries.
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 03/01/2013 12:45:48 PM
#     REVISION: ---
#===============================================================================

use TempoFree;
use strict;
use warnings;

my %team_plays;
my %team_tds;
my %team_fgs;
my %team_downs;

exit 1 if (!@ARGV);

foreach my $boxfile (@ARGV) {
  open my $boxf, "<", $boxfile or die "Can't open $boxfile for reading: $!";
  while(<$boxf>) {
    chomp;
    my ($team_id, $plays, $tds, $fgs, @downs) = split;
    if (scalar(@downs) != 4) {
      warn "Only found counts of " . scalar(@downs) . " downs";
      next;
    }
    $team_plays{$team_id} += $plays;
    $team_tds{$team_id} += $tds;
    $team_fgs{$team_id} += $fgs;
    my $aref = $team_downs{$team_id};
    if (!defined($aref)) {
      $team_downs{$team_id} = \@downs;
    } else {
      foreach my $d (0..$#downs) {
        $$aref[$d] += $downs[$d];
      }
    }
  }
  close $boxf;
}

my %id2name;
my %id2conf;
my %conf2teams;
my %team2bcs;
LoadConferences(\%id2name, \%id2conf, \%conf2teams, \%team2bcs);

my @teams = sort { $a <=> $b } keys %team_plays;
foreach my $tid (@teams) {
  my $c = $id2conf{$tid};
  next if (!defined($c) or ($c eq "FCS"));
  my $p = $team_plays{$tid};
  my $tds = $team_tds{$tid};
  my $fgs = $team_fgs{$tid};
  my $non_tds_p = $p - $tds;
  my $non_score_p = $non_tds_p - $fgs;
  my $aref = $team_downs{$tid};
  my $n = $id2name{$tid};
  $n =~ s/\ /_/g;
  printf "%-20s %4d %4d %4d %4d %.4f %.4f %.4f %.4f\n", $n, $p, $tds, $fgs, $tds + $fgs,
         $tds / $p, $fgs / $non_tds_p, ($tds + $fgs) / $p, $$aref[0] / $non_score_p;
}
