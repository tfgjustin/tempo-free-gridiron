#!/usr/bin/perl

use POSIX;
use TempoFree;
use warnings;
use strict;

sub gamesort;

my $directory = shift(@ARGV);

exit 1 if (!defined($directory));

my %id2name;
LoadIdToName(\%id2name);

my %names;
LoadPrintableNames(\%names);

my %gametime;

# {gid}{time}[line]
my %tfg_stats;
my $tfg_t = LoadInGamePredictions($directory, "tfg", \%tfg_stats, \%gametime);
my %rba_stats;
my $rba_t = LoadInGamePredictions($directory, "rba", \%rba_stats, \%gametime);

my $last_time = ($rba_t > $tfg_t) ? $rba_t : $tfg_t;

foreach my $gid (sort gamesort keys %tfg_stats) {
  my ($d, $hid, $aid) = split(/-/, $gid);
  my $hname = $id2name{$hid};
  next if(!defined($hname));
  my $home = $names{$hname};
  next if(!defined($home));
  $home =~ s/&/%26/g;
  my $aname = $id2name{$aid};
  next if(!defined($aname));
  my $away = $names{$aname};
  next if(!defined($away));
  $away =~ s/&/%26/g;

  my $tfg_game_href = $tfg_stats{$gid};
  my $rba_game_href = $rba_stats{$gid};
  if (!defined($tfg_game_href) or !defined($rba_game_href)) {
    warn "Missing either TFG or RBA data for $gid";
    next;
  }
  my @times = sort { $a <=> $b } keys %$tfg_game_href;
  printf "<!-- GID %s %3d -->\n", $gid, scalar(@times);
  foreach my $t (@times) {
    my $tfg_l = $$tfg_game_href{$t};
    my $rba_l = $$rba_game_href{$t};
    print "<!-- TFG " . $tfg_l . " -->\n";
    print "<!-- RBA " . $rba_l . " -->\n";
  }
  print "\n\n";
}

sub gamesort {
  my $at = $gametime{$a};
  my $bt = $gametime{$b};
  if (!defined($at)) {
    if (!defined($at)) {
      return $a cmp $b;
    } else {
      return 1;
    }
  } else {
    if (!defined($bt)) {
      return -1;
    }
  }
  # If we got here, both $at and $bt are defined.
  if ($at == 3600) {
    if ($bt == 3600) {
      return $a cmp $b;
    } else {
      return 1;
    }
  } else {
    if ($bt == 3600) {
      return -1;
    } else {
      return $bt <=> $at;
    }
  }
}
