#!/usr/bin/perl 
#===============================================================================
#
#         FILE: parse_octave.pl
#
#        USAGE: ./parse_octave.pl  
#
#  DESCRIPTION: Parse the fit from octave.
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 04/14/2013 11:49:59 AM
#     REVISION: ---
#===============================================================================

use TempoFree;
use strict;
use warnings;

sub pythag($$$);
sub parse_file($$);

my $baserank = shift(@ARGV);
my $exponent = shift(@ARGV);

exit 1 if (!@ARGV);

my %id2name;
my %id2conf;
my %conf2team;
my %isbcs;
LoadConferences(\%id2name, \%id2conf, \%conf2team, \%isbcs);
my @teams;
foreach my $tid (keys %id2conf) {
  my $c = $id2conf{$tid};
  if (defined($c) and $c ne "FCS") {
    push(@teams, $tid);
  }
}

my %basewpct;
my %baseranking;
LoadCurrentRankings($baserank, \%id2conf, \%basewpct, \%baseranking);

foreach my $in (@ARGV) {
  my @a;
  parse_file($in, \@a);
}

sub parse_file($$) {
  my $infile = shift;
  my $winaref = shift;
  my $off = undef;
  open my $inf, "<", $infile or die "Can't open $infile for reading: $!";
  while (<$inf>) {
    next if (/^#/ or !/[0-9]/);
    if (!defined($off)) {
      $off = $_;
    } else {
      push(@$winaref, sprintf "%.5f", pythag($off, $_, $exponent));
      $off = undef;
    }
  }
  close $inf;

  if (scalar(@teams) != scalar(@$winaref)) {
    die "Number of teams " . scalar(@teams) . " != number of winpcts " . scalar(@$winaref);
  }

  my $i = 0;
  foreach my $t (sort {$a <=> $b } @teams) {
    my $n = $id2name{$t};
    my $w = $basewpct{$t};
    next if (!defined($n) or !defined($w));
    $n =~ s/\ /_/g;
    printf "%-20s %s %.5f %8.5f\n", $n, $$winaref[$i], $w, $$winaref[$i] - $w;
    ++$i;
  }
}

sub pythag($$$) {
  my $pf = shift;
  my $pa = shift;
  my $e = shift;
  return 0 if ($pf < 0.0001);
  return 1 / (1 + (($pa / $pf)**$e));
}
