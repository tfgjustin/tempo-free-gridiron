#!/usr/bin/perl 
#===============================================================================
#
#         FILE: remove_garbage_time.pl
#
#        USAGE: ./remove_garbage_time.pl  
#
#  DESCRIPTION: Create a CSV of the summaries which has garbage time removed and
#  the length of the game (and its score) adjusted for time.
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 10/18/2015 06:42:13 PM
#     REVISION: ---
#===============================================================================

use TempoFree;
use strict;
use warnings;

*STDERR = *STDOUT;

my %MARGINS = (1 => 35, 2 => 28, 3 => 24, 4 => 21);

sub parse_plays($$);
sub percent_played($$);

my $play_filename = shift(@ARGV);
if (!defined($play_filename) or ! -f $play_filename) {
  print STDERR "No play-by-play file named\n";
  exit 1;
}

my %results;
LoadResults(\%results);
printf "Found %d games\n", scalar(keys %results);

my %plays;
parse_plays($play_filename, \%plays);
printf "Loaded %d play-by-play games\n", scalar(keys %plays);

my %adjust_games;
my $skip = 0;
foreach my $ncaa_gid (keys %plays) {
  my ($date, $t1id, $t2id);
  if ($ncaa_gid =~ /(\d{4})(\d{4})(\d{8})/) {
    $t1id = $1;
    $t2id = $2;
    $date = $3;
  } else {
    next;
  }
  my $gid = sprintf "%d-%d-%d", $date, 1000 + $t1id, 1000 + $t2id;
  my $aref = $results{$gid};
  if (!defined($aref)) {
    $gid = sprintf "%d-%d-%d", $date, 1000 + $t2id, 1000 + $t1id;
    $aref = $results{$gid};
    if (!defined($aref)) {
      ++$skip;
      next;
    }
  }
  my $play_aref = $plays{$ncaa_gid};
  foreach my $play (sort @$play_aref) {
    my @parts = split(/,/, $play);
    if (scalar(@parts) < 8) {
      print "Invalid line: \"$play\"\n";
      next;
    }
    next if (!defined($parts[6]) or !defined($parts[7]));
    my $ptdiff = abs($parts[6] - $parts[7]);
    if ($ptdiff >= $MARGINS{$parts[2]}) {
      my $pp = percent_played($parts[2], $parts[3]);
      $adjust_games{$gid} = $play;
#      printf "ADJUST %.3f %s %s\n", $pp, $gid, $play;
      last;
    }
  }
}

printf "Skipped %d play-by-play games\n", $skip;
printf "Adjusting %d games\n", scalar(keys %adjust_games);

sub parse_plays($$) {
  my $fname = shift;
  my $href = shift;
  open(PLAYS, "$fname") or die "Can't open $fname for reading: $!";
  while (<PLAYS>) {
    chomp;
    my $line = $_;
    @_ = split(/,/);
    next unless ($_[11] eq "KICKOFF");
    my $aref = $$href{$_[0]};
    if (!defined($aref)) {
      my @a;
      $aref = \@a;
      $$href{$_[0]} = $aref;
    }
    push(@$aref, $line);
#    print "LINE $line\n";
  }
  close(PLAYS);
}

sub percent_played($$) {
  my $qtr = shift;
  my $sec = shift;
  my $total_time = 3600 - (4 - $qtr);
  return ($total_time - $sec) / 3600;
}
