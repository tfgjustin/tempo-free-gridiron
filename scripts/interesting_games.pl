#!/usr/bin/perl -w

use strict;

my $BASEDIR = ".";
my $NAMEMAP = "$BASEDIR/data/names.txt";
my $CONFMAP = "$BASEDIR/data/conferences.txt";

my $PRETTYPRINT = "$BASEDIR/scripts/prettyprint.pl";

if (!@ARGV or ((scalar(@ARGV) % 2) == 0)) {
  print STDERR "\n";
  print STDERR "Usage: $0 <pattern> <predict0> <rank0> [<predict1> <rank1>] ...\n";
  print STDERR "\n";
  exit 1;
}

my $PATTERN = shift(@ARGV);

my @all_preds;
my @all_wpcts;
my %gids;

foreach my $i (0..int($#ARGV / 2)) {
  my $predictfile = $ARGV[$i * 2 + 0];
  my $rankfile    = $ARGV[$i * 2 + 1];

  # First do the rankings
  my %wpcts;
  open(RANK, "$rankfile") or die "Can't open rankings: $rankfile: $!";
  while(<RANK>) {
    chomp;
#    print STDERR "Rank \"$_\"\n";
    next if (/PREDICT/);
    next unless (/[A-Z]/);
    next if (/^\s+/);
    @_ = split(/,/);
    if (scalar(@_) < 6) {
      warn "Invalid line: \"$_\"\n";
      next;
    }
    my $wpct = $_[0];
    my $team = $_[2];
#    printf STDERR "Team %s Wpct %.3f\n", $team, $wpct;
    $wpcts{$team} = $wpct;
  }
  close(RANK);
  push(@all_wpcts, \%wpcts);
  
  # Now fetch and prettify the predictions
  my $cmd = "$PRETTYPRINT $predictfile 1 | tr '[a-z]' '[A-Z]' | grep $PATTERN";
  open(CMD, "$cmd|") or do {
    warn "Cannot execute \"$cmd\": $!";
    next;
  };
  my %predictions;
  while(<CMD>) {
    chomp;
    @_ = split;
    my $gid = $_[0];
    $predictions{$gid} = $_;
    $gids{$gid} = 1;
  }
  close(CMD);
  push(@all_preds, \%predictions);
}

my %names;
open(NAMES, "$NAMEMAP") or die "Can't open name map $NAMEMAP: $!";
while(<NAMES>) {
  chomp;
  my ($CAPS, $bettername) = split(/,/);
  $names{$CAPS} = $bettername;
}
close(NAMES);

my %is_bcs;
open(CONF, "$CONFMAP") or die "Can't open conference map $CONFMAP: $!";
while(<CONF>) {
  chomp;
  s/\s/_/g;
  @_ = split(/,/);
  $is_bcs{$_[1]} = $_[4];
}
close(CONF);

foreach my $gid (sort { $a cmp $b } keys %gids) {
  my $closeness = 0;
  my $goodness = 0;
  my $excitement = 0;
  my $h_team = undef;
  my $a_team = undef;
  foreach my $i (0..$#all_preds) {
    my $pred_href = $all_preds[$i];
    my $wpct_href = $all_wpcts[$i];
    my $l = $$pred_href{$gid};
    next if (!defined($l));
    @_ = split(/\s+/, $l);
    next if (scalar(@_) != 6);
    my $hometeam = $_[1];
    my $hs = $_[2];
    my $awayteam = $_[3];
    my $as = $_[4];
    my $favewin = $_[5];
    my $score = $hs + $as;
    $excitement += $score;
    $h_team = $hometeam;
    $a_team = $awayteam;
    printf STDERR "== GID %s IDX %d SC %3d RFV %4.2f ", $gid, $i, $score, $favewin;
    printf STDERR "BefFW %5.3f ", $favewin;
    $favewin -= 0.5;
    $favewin *= 2;
    printf STDERR "AdjFW %5.3f ", $favewin;
    $closeness += $favewin;
    $hometeam =~ s/_/\ /g;
    $awayteam =~ s/_/\ /g;
    my $home_wpct = $$wpct_href{$hometeam};
    my $away_wpct = $$wpct_href{$awayteam};
    $home_wpct = 0.0 if (!defined($home_wpct));
    $away_wpct = 0.0 if (!defined($away_wpct));
    my $g = ((2 - ($home_wpct + $away_wpct)) / 2);
    printf STDERR "HWP %.3f AWP %.3f GOOD %.3f\n", $home_wpct, $away_wpct, $g;
    $goodness += $g;
  }
  my $h_bcs = $is_bcs{$h_team};
  $h_bcs = 0 if (!defined($h_bcs));
  my $a_bcs = $is_bcs{$a_team};
  $a_bcs = 0 if (!defined($a_bcs));
  $closeness = abs($closeness) / scalar(@all_preds);
  $goodness /= scalar(@all_preds);
  $excitement /= (scalar(@all_preds) * 75);
  $excitement = 1 - $excitement;
  my ($c_weight, $g_weight, $e_weight) = ( 2, 3, 1 );
#  $closeness /= 2;
  my $d = ($c_weight * $closeness) ** 2 + ($g_weight * $goodness) ** 2 + ($e_weight * $excitement) ** 2;
  $d /= (($c_weight ** 2) + ($g_weight ** 2) + ($e_weight ** 2));
  $d = $d ** (1. / 3);
  printf "%s %.4f %.4f %.4f %.4f %d\n", $gid, 1 - $d, 1 - $closeness, 1 - $goodness,
         1 - $excitement, $h_bcs + $a_bcs;
}
