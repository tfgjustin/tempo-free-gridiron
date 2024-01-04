#!/usr/bin/perl 
#===============================================================================
#
#         FILE: conference_round_robin.pl
#
#        USAGE: ./conference_round_robin.pl  
#
#  DESCRIPTION: 
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 11/27/2013 01:04:24 PM
#     REVISION: ---
#===============================================================================

use TempoFree;
use strict;
use warnings;

sub log5($$);

my $rank_file = shift(@ARGV);
if (!defined($rank_file) or ! -f $rank_file) {
  die "Usage: $0 <ranking_file>";
}

my %id2name;
my %conf_teams;
my %is_bcs;
LoadConferences(\%id2name, \%conf_teams, undef, \%is_bcs);

my %wpcts;
my %ranks;
LoadCurrentRankings($rank_file, \%conf_teams, \%wpcts, \%ranks);

my @teams;
foreach my $tid (keys %conf_teams) {
  my $c = $conf_teams{$tid};
  next if ($c eq "FCS");
  next if (!defined($wpcts{$tid}));
  push(@teams, $tid);
}

my %p5c_wins;
my %p5c_loss;
my %conf_wins;
my %team_wins;
my %conf_loss;
my %team_loss;
foreach my $t1 (@teams) {
  my $c1 = $conf_teams{$t1};
  my $t1pct = $wpcts{$t1};
  foreach my $t2 (@teams) {
    next if ($t1 == $t2);
    my $c2 = $conf_teams{$t2};
    next if ($c1 eq $c2);
    my $t2pct = $wpcts{$t2};
    my $t1w = log5($t1pct, $t2pct);
    $conf_wins{$c1} += $t1w;
    $conf_loss{$c2} += $t1w;
    $team_wins{$t1} += $t1w;
    $team_loss{$t2} += $t1w;
    my $t1b = $is_bcs{$t1};
    my $t2b = $is_bcs{$t2};
    if (!defined($t1b)) { $t1b = 0; }
    if (!defined($t2b)) { $t2b = 0; }
    if ($t1b and $t2b) {
      $p5c_wins{$c1} += $t1w;
      $p5c_loss{$c2} += $t1w;
    }
  }
}

my %conf_pcts;
foreach my $c (keys %conf_wins) {
  my $w = $conf_wins{$c};
  my $l = $conf_loss{$c};
  $conf_pcts{$c} = $w / ($w + $l);
}

foreach my $c (sort { $conf_pcts{$b} <=> $conf_pcts{$a} } keys %conf_pcts) {
  my $w = $conf_wins{$c};
  my $l = $conf_loss{$c};
  printf "CONF,%s,%.2f,%.2f,%.3f\n", $c, $w, $l, $conf_pcts{$c};
}

my %p5c_pcts;
foreach my $c (keys %p5c_wins) {
  my $w = $p5c_wins{$c};
  my $l = $p5c_loss{$c};
  $p5c_pcts{$c} = $w / ($w + $l);
}

foreach my $c (sort { $p5c_pcts{$b} <=> $p5c_pcts{$a} } keys %p5c_pcts) {
  my $w = $p5c_wins{$c};
  my $l = $p5c_loss{$c};
  printf "P5C,%s,%.2f,%.2f,%.3f\n", $c, $w, $l, $p5c_pcts{$c};
}

my %team_pcts;
foreach my $tid (keys %team_wins) {
  my $w = $team_wins{$tid};
  my $l = $team_loss{$tid};
  $team_pcts{$tid} = $w / ($w + $l);
}
foreach my $tid (sort { $team_pcts{$b} <=> $team_pcts{$a} } keys %team_pcts) {
  my $w = $team_wins{$tid};
  my $l = $team_loss{$tid};
  printf "TEAM,%d,%.2f,%.2f,%.3f\n", $tid, $w, $l, $team_pcts{$tid};
}
sub log5($$) {
  my $a = shift;
  my $b = shift;

  my $num = $a - ($a * $b);
  my $den = $a + $b - (2 * $a * $b);

  return 1.0 if (!$den);
  return $num / $den;
}
