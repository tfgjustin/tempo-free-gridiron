#!/usr/bin/perl 
#===============================================================================
#
#         FILE: create_lead_table.pl
#
#        USAGE: ./create_lead_table.pl  
#
#  DESCRIPTION: Given the number of seconds left, the current lead, and whether
#               or not you have the ball, calculate the odds of winning.
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 02/25/2015 09:36:29 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;

my $bin_size = shift(@ARGV);
my $min_bucket_size = shift(@ARGV);
$bin_size = 30 if (!defined($bin_size));
$min_bucket_size = 100 if (!defined($min_bucket_size));

# {time_left}{lead}{has_ball}
my %lead_counts;
my %win_counts;

while (<STDIN>) {
  chomp;
  @_ = split(/,/);
  my $bin = int($_[0] / $bin_size);
  $lead_counts{$bin}{$_[2]}{$_[1]} += 1;
  $win_counts{$bin}{$_[2]}{$_[1]} += ($_[3] > 0) ? 1 : 0;
}

foreach my $remain (sort { $b <=> $a } keys %lead_counts) {
  my $lead_count_href = $lead_counts{$remain};
  my $win_count_href = $win_counts{$remain};
  foreach my $lead (sort { $a <=> $b } keys %$lead_count_href) {
    next unless ($lead > 0);
    my $rl_count_href = $$lead_count_href{$lead};
    my $rw_count_href = $$win_count_href{$lead};
    foreach my $has (sort { $a <=> $b} keys %$rl_count_href) {
      my $num_games = $$rl_count_href{$has};
      next if ($num_games < $min_bucket_size);
      my $num_wins = $$rw_count_href{$has};
      printf "%4d - %4d %2d %1d %.3f %5d %5d\n",
             ($remain * $bin_size), (($remain + 1) * $bin_size) - 1,
             $lead, $has, $num_wins / $num_games, $num_wins, $num_games;
    }
  }
}
