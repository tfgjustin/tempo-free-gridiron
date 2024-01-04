#!/usr/bin/perl -w

use strict;

sub get_teamid($);
sub is_datarow($);
sub is_teamline($);
sub is_dateline($);
sub is_winlossline($);
sub is_lineline($);
sub usage($);

my $START_PARSE   = 0;
my $FOUND_DATAROW = 1;
my $FOUND_DATE    = 2;
my $FOUND_OPP     = 3;
my $FOUND_WINLOSS = 4;

my $id_map_file = shift(@ARGV);
my $team_input = shift(@ARGV);
if (!defined($team_input)) {
  usage($0);
}

my $team_id = get_teamid($team_input);
if (!defined($team_id)) {
  warn "Could not get team ID from \"$team_input\"";
  exit 1;
}

my %idmap;
open(IDMAP, "$id_map_file") or die "Can't open $id_map_file: $!";
while(<IDMAP>) {
  chomp;
  @_ = split(/,/);
  $idmap{$_[0]} = $_[1];
}
close(IDMAP);

if (!defined($idmap{$team_id})) {
  die "No ID for team $team_id";
}
$team_id = $idmap{$team_id};

my $current_stage = $START_PARSE;
my $current_date = undef;
my $current_opp = undef;
open(INFILE, "$team_input") or die "Can't open $team_input for reading: $!";
while(<INFILE>) {
  if ($current_stage == $START_PARSE) {
    $current_stage = $FOUND_DATAROW if (is_datarow($_));
  } elsif ($current_stage == $FOUND_DATAROW) {
    my $d = is_dateline($_);
    if ($d) {
      $current_date = $d;
      $current_stage = $FOUND_DATE;
    }
  } elsif ($current_stage == $FOUND_DATE) {
    my $t = is_teamline($_);
    if ($t) {
      $current_opp = $t;
      $current_stage = $FOUND_OPP;
    }
  } elsif ($current_stage == $FOUND_OPP) {
    $current_stage = $FOUND_WINLOSS if (is_winlossline($_));
  } elsif ($current_stage == $FOUND_WINLOSS) {
    my $l = is_lineline($_);
    if (defined($l)) {
      chomp($l);
      printf "%s-%d,%s\n", $current_date, $team_id, $l;
      $current_stage = $START_PARSE;
      $current_date = undef;
      $current_opp = undef;
    }
  } else {
    warn "Whuh: $_";
  }
}
close(INFILE);

sub get_teamid($) {
  my $_ = shift;
  if (/team(0{0,2})(\d+).html/) {
    return $2;
  }
  return undef;
}

sub is_datarow($) {
  my $_ = shift;
  return 1 if (/.*class="datarow".*/);
  return 0;
}

sub is_teamline($) {
  my $_ = shift;
  if (/pageLoader/ and /ncf\/teams\/team(\d{2,3}).html/) {
    return $1;
  }
  return 0;
}

sub is_dateline($) {
  my $_ = shift;
  if (/\w+\s(\d{2})\/(\d{2})\/(\d{2})/) {
    return sprintf "20%s%s%s", $3, $1, $2;
  }
  return 0;
}

sub is_winlossline($) {
  my $_ = shift;
  return 1 if (/\s+[WL]\s+.*\d+-\d+</);
  return 0;
}

sub is_lineline($) {
  my $_ = shift;
  if (/^\s+(-{0,1})([\d\.]+)<\/td>.*$/) {
    return "$1$2";
  }
  return undef;
}

sub usage($) {
  my $p = shift;
  my @path = split(/\//, $p);
  $p = pop(@path);
  print STDERR "\n";
  print STDERR "$p <idMapFile> <teamFile>\n";
  print STDERR "\n";
  exit 1;
}
