#!/usr/bin/perl 

use strict;
use warnings;

my $minpts = shift(@ARGV);

$minpts = 10 if (!defined($minpts));

# {min}{lead}
my %counts;
my %wins;
while(<STDIN>) {
  chomp;
  my ($sec, $lead, $won) = split(/,/);
  my $min = int($sec / 60);
  $counts{$min}{$lead} += 1;
  $wins{$min}{$lead} += $won;
}
foreach my $minpass (sort { $a <=> $b } keys %counts) {
#  print "Minute $minpass\n";
  my $href = $counts{$minpass};
  my $print_top = 0;
  foreach my $lead (sort { $a <=> $b } keys %$href) {
    next if (!$lead);
    my $c = $$href{$lead};
    next if ($c < $minpts);
    my $w = $wins{$minpass}{$lead};
    if ($print_top) {
      next if ($c < 15);
    } else {
      if ($c == $w) {
        $print_top = 1;
      } elsif ($c < 15) {
        next;
      }
    }
    printf "%2d,%2d,%.3f,%4d,%4d\n", $minpass, $lead, $w / $c, $c, $w;
  }
}
