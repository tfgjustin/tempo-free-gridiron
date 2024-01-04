#!/usr/bin/perl -w

use Data::Dumper;
use strict;

sub LoadConferences($$);
sub LoadTeams($$);
sub LoadGames($$);
sub usage();

my $team_game_stats_file = shift(@ARGV);
my $team_file = shift(@ARGV);
my $conf_file = shift(@ARGV);

usage() if (!defined($conf_file));
usage() if (! -f $team_game_stats_file);
usage() if (! -f $team_file);
usage() if (! -f $conf_file);

my %confs;
LoadConferences($conf_file, \%confs);

my %teams;
LoadTeams($team_file, \%teams);

my %games;
LoadGames($team_game_stats_file, \%games);

my %fcs_losses;
foreach my $gid (keys %games) {
  my $ghref = $games{$gid};
  my @teams = keys %$ghref;
  my $fcs_id = undef;
  my $fbs_id = undef;
  foreach my $tid (@teams) {
    my $conf_id = $teams{$tid};
    next if (!defined($conf_id));
    my $div = $confs{$conf_id};
    next if (!defined($div));
    if ($div eq "FCS") {
      next if (defined($fcs_id));
      $fcs_id = $tid;
    } elsif ($div eq "FBS") {
      next if (defined($fbs_id));
      $fbs_id = $tid;
    }
  }
  next unless (defined($fbs_id) and ($fcs_id));
  if ($$ghref{$fbs_id} < $$ghref{$fcs_id}) {
    if (defined($fcs_losses{$fbs_id})) {
      $fcs_losses{$fbs_id} += 1;
    } else {
      $fcs_losses{$fbs_id} = 1;
    }
  }
}

foreach my $fbs_id (sort keys %fcs_losses) {
  printf "%d,%d\n", $fbs_id + 1000, $fcs_losses{$fbs_id};
}

sub usage() {
  print STDERR "\n";
  print STDERR "$0 <team_game_stats_file> <team_file> <conf_file>\n";
  print STDERR "\n";
  exit 1;
}

sub LoadConferences($$) {
  my $fname = shift;
  my $href = shift;
  open(CONF, "$fname") or die "Can't open conference file: $!";
  while(<CONF>) {
    s///g;
    s/\"//g;
    next if (/^Conference/);
    chomp;
    @_ = split(/,/);
    $$href{$_[0]} = $_[2];
  }
  close(CONF);
}

sub LoadTeams($$) {
  my $fname = shift;
  my $href = shift;
  open(TEAMS, "$fname") or die "Can't open teams file: $!";
  while(<TEAMS>) {
    s///g;
    s/\"//g;
    chomp;
    @_ = split(/,/);
    $$href{$_[0]} = $_[2];
  }
  close(TEAMS);
}

sub LoadGames($$) {
  my $fname = shift;
  my $href = shift;
  open(GAMES, "$fname") or die "Can't open games file: $!";
  while(<GAMES>) {
    s///g;
    chomp;
    @_ = split(/,/);
    my $gid = $_[1];
    my $tid = $_[0];
    my $pts = $_[35];
    my $ghref = $$href{$gid};
    if (!defined($ghref)) {
      my %h;
      $$href{$gid} = $ghref = \%h;
    }
    $$ghref{$tid} = $pts;
  }
  close(GAMES);
}
