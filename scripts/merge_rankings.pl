#!/usr/bin/perl 
#===============================================================================
#
#         FILE: merge_rankings.pl
#
#        USAGE: ./merge_rankings.pl  
#
#  DESCRIPTION: Merge the TFG and RBA ranking systems together.
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 10/11/2015 04:25:48 PM
#     REVISION: ---
#===============================================================================

use TempoFree;
use strict;
use warnings;

sub avg($$);

# Sample input:
# RANKING,6,1327,0.95251,0.08791,34.0,13.7,163.5
my $tfg_filename = shift(@ARGV);
my $rba_filename = shift(@ARGV);

exit 1 if (!defined($rba_filename));

if (! -f $tfg_filename or ! -f $rba_filename) {
  exit 1;
}

my (%tfg_wpct, %tfg_sos, %tfg_oeff, %tfg_deff, %tfg_pace);
LoadRanksAndStats($tfg_filename, \%tfg_wpct, \%tfg_sos, \%tfg_oeff, \%tfg_deff, \%tfg_pace);
my (%rba_wpct, %rba_sos, %rba_oeff, %rba_deff, %rba_pace);
LoadRanksAndStats($rba_filename, \%rba_wpct, \%rba_sos, \%rba_oeff, \%rba_deff, \%rba_pace);

for my $week (sort { $a <=> $b } keys %tfg_wpct) {
  my $tfg_w_wpct_href = $tfg_wpct{$week};
  my $tfg_w_sos_href = $tfg_sos{$week};
  my $tfg_w_oeff_href = $tfg_oeff{$week};
  my $tfg_w_deff_href = $tfg_deff{$week};
  my $tfg_w_pace_href = $tfg_pace{$week};
  my $rba_w_wpct_href = $rba_wpct{$week};
  my $rba_w_sos_href = $rba_sos{$week};
  my $rba_w_oeff_href = $rba_oeff{$week};
  my $rba_w_deff_href = $rba_deff{$week};
  my $rba_w_pace_href = $rba_pace{$week};
  next if (!defined($rba_w_wpct_href));
  for my $team_id (sort { $a <=> $b } keys %$tfg_w_wpct_href) {
    my $tfg_t_wpct = $$tfg_w_wpct_href{$team_id};
    my $tfg_t_sos = $$tfg_w_sos_href{$team_id};
    my $tfg_t_oeff = $$tfg_w_oeff_href{$team_id};
    my $tfg_t_deff = $$tfg_w_deff_href{$team_id};
    my $tfg_t_pace = $$tfg_w_pace_href{$team_id};
    my $rba_t_wpct = $$rba_w_wpct_href{$team_id};
    my $rba_t_sos = $$rba_w_sos_href{$team_id};
    my $rba_t_oeff = $$rba_w_oeff_href{$team_id};
    my $rba_t_deff = $$rba_w_deff_href{$team_id};
    my $rba_t_pace = $$rba_w_pace_href{$team_id};
    # RANKING,6,1327,0.95251,0.08791,34.0,13.7,163.5
    printf "RANKING,%d,%d,%.5f,%.5f,%.1f,%.1f,%.1f\n", $week, $team_id,
      avg($tfg_t_wpct, $rba_t_wpct), avg($tfg_t_sos, $rba_t_sos),
      avg($tfg_t_oeff, $rba_t_oeff), avg($tfg_t_deff, $rba_t_deff),
      avg($tfg_t_pace, $rba_t_pace);
  }
}

sub avg($$) {
  my $v1 = shift;
  my $v2 = shift;
  if (defined($v1)) {
    if (defined($v2)) {
      return ($v1 + $v2) / 2;
    }
    return $v1;
  } elsif (defined($v2)) {
    return $v2;
  } else {
    return undef;
  }
}
