#!/usr/bin/perl -w

use TempoFree;
use strict;

sub load_rankings($$$);
sub load_games($$);
sub print_prediction($$);
sub usage($);

my $BASEDIR = ".";
my $PRETTYPRINT = "$BASEDIR/scripts/prettyprint.pl";

if (scalar(@ARGV) != 4) {
  printf STDERR "Only had %d parameters instead of 4.", scalar(@ARGV);
  usage($0);
}

my $start_date = shift(@ARGV);
my $end_date = shift(@ARGV);
if (!($start_date =~ /20[01][0-9][01][0-9][0-3][0-9]/)) {
  print STDERR "Invalid start date: $start_date\n";
  usage($0);
}
if (!($end_date =~ /20[01][0-9][01][0-9][0-3][0-9]/)) {
  print STDERR "Invalid end date: $end_date\n";
  usage($0);
}
my $predict_file = shift(@ARGV);
my $ranking_file = shift(@ARGV);

usage($0) if (!defined($ranking_file));

my %wpcts;
my %ranks;
load_rankings($ranking_file, \%wpcts, \%ranks);
my %games;
load_games($predict_file, \%games);

my $t = localtime();
my $num_games = scalar(keys %games);
printf "# This file generated at %s\n", $t;
printf "# Contains data for %d games from %s - %s\n", $num_games, $start_date, $end_date;
printf "# HomeRank,HomeTeam,HomeScore,AwayRank,AwayTeam,AwayScore\n";

exit 0 if (!$num_games);

my %id2name;
my %id2conf;
LoadConferences(\%id2name, \%id2conf, undef, undef);

my %names;
LoadPrintableNames(\%names);

my %name2id;
LoadNameToId(\%name2id);

foreach my $gid (sort { $a cmp $b } keys %games) {
  my $l = $games{$gid};
  next if (!defined($l));
  print_prediction($l, \%ranks);
}

sub load_rankings($$$) {
  my $rankfile = shift;
  my $wpct_href = shift;
  my $rank_href = shift;
  LoadCurrentRankings($rankfile, \%id2conf, $wpct_href, $rank_href);
}

sub load_games($$) {
  my $predict_file = shift;
  my $predict_href = shift;
  # Now fetch and prettify the predictions
  my $cmd = "$PRETTYPRINT $predict_file 1 | tr '[a-z]' '[A-Z]'";
  open(CMD, "$cmd|") or do {
    warn "Cannot execute \"$cmd\": $!";
    next;
  };
  my %predictions;
  my $cnt = 0;
  while(<CMD>) {
    chomp;
    @_ = split;
    my $gid = $_[0];
    my $date = substr($gid, 0, 8);
    ++$cnt;
    next if (($date < $start_date) or ($date > $end_date));
    $$predict_href{$gid} = $_;
  }
  close(CMD);
}

sub print_prediction($$) {
  my $pred_line = shift;
  my $rank_href = shift;
  @_ = split(/\s+/, $pred_line);
  return if (scalar(@_) < 6);
#  print STDERR "HT $_[1] AT $_[3]\n";
  my $hometeam = $_[1];
  my $home_id = $name2id{$hometeam};
  my $home_rank = $$rank_href{$home_id};
  if (defined($home_rank)) {
    $home_rank = sprintf "%d", $home_rank;
  } else {
    $home_rank = "NA";
  }

  my $awayteam = $_[3];
  my $away_id = $name2id{$awayteam};
  my $away_rank = $$rank_href{$away_id};
  if (defined($away_rank)) {
    $away_rank = sprintf "%d", $away_rank;
  } else {
    $away_rank = "NA";
  }
  if (defined($names{$hometeam})) {
    $hometeam = $names{$hometeam};
  }
  if (defined($names{$awayteam})) {
    $awayteam = $names{$awayteam};
  }

  printf "%s,%s,%d,%s,%s,%d\n", $home_rank, $hometeam, $_[2],
         $away_rank, $awayteam, $_[4];
}

sub usage($) {
  my $p = shift;
  my @parts = split(/\//, $p);
  $p = pop(@parts);
  print STDERR "\n";
  print STDERR "Usage: $p <minDate> <maxDate> <predict_file> <rank_file>\n";
  print STDERR "\n";
  exit 1;
}
