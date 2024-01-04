#!/usr/bin/perl -w

use POSIX;
use TempoFree;
use strict;

if (scalar(@ARGV) != 2) {
  print STDERR "\n";
  print STDERR "Usage: $0 <current_rankfile> <season_week_number>\n";
  print STDERR "\n";
  exit 1;
}

my $current_rankfile = shift(@ARGV);
my $season_week_number = shift(@ARGV);

my %id2name;
my %id2conf;
LoadConferences(\%id2name, \%id2conf, undef, undef);
my %names;
LoadPrintableNames(\%names);

my %wpcts;
my %ranks;
my $rc = LoadCurrentRankings($current_rankfile, \%id2conf, \%wpcts, \%ranks);
if ($rc) {
  warn "Error loading current rankings from $current_rankfile";
  exit 1;
}

my $t = localtime();
print  "# Rankings for Week $season_week_number\n";
printf "# Generated on %s\n", $t;
printf "# Rank,Power,TeamName\n";
foreach my $team_id (sort { $ranks{$a} <=> $ranks{$b} } keys %ranks) {
  my $wpct = $wpcts{$team_id};
  if (!defined($wpct)) {
    warn "Could not find winning percent for team $team_id";
    next;
  }
  my $short_name = $id2name{$team_id};
  if (!defined($short_name)) {
    warn "Could not get short name for team $team_id";
    next;
  }
  my $name = $names{$short_name};
  if (!defined($name)) {
    warn "Could not get printable name for team $short_name";
    next;
  }
  printf "%d,%.3f,%s\n", $ranks{$team_id}, $wpct, $name;
}
