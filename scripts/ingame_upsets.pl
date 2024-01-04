#!/usr/bin/perl 
#===============================================================================
#
#         FILE: ingame_upsets.pl
#
#        USAGE: ./ingame_upsets.pl  
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
#      CREATED: 03/08/2013 09:54:05 AM
#     REVISION: ---
#===============================================================================

use TempoFree;
use strict;
use warnings;


my $directory = shift(@ARGV);

exit 1 if (!defined($directory) or ! -d $directory);

my %pergame;
my %gametime;
LoadInGamePredictions($directory, "COM", \%pergame, \%gametime);

# 20111122-1519-1414,TFG,1519,21,1414,14,3600,1.0
my %upsets;  # {gid}[line]
my %diffs;   # {gid}[value]
foreach my $gid (keys %pergame) {
  my $href = $pergame{$gid};
  my $last_line = $$href{3600};
  if (!defined($last_line)) {
    warn "No last line for game $gid";
    next;
  }
  my @p = split(/,/, $last_line);
  my $last_prob = $p[-1];
  my $max_diff = 0;
  foreach my $t (keys %$href) {
    my $l = $$href{$t};
    @p = split(/,/, $l);
    my $prob = $p[-1];
    my $d = abs($last_prob - $prob);
    if ($d > $max_diff) {
      $upsets{$gid} = $l;
      $max_diff = $d;
    }
  }
  $diffs{$gid} = $max_diff;
}

my $cnt = 0;
foreach my $gid (sort { $diffs{$b} <=> $diffs{$a} } keys %upsets) {
  last if ($cnt++ == 5);
  printf "%s,%s\n", $gid, $upsets{$gid};
}
