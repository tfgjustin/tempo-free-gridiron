#!/usr/bin/perl 

use TempoFree;
use strict;
use warnings;

sub usage($);

my $TFG = "TFG";
my $RBA = "RBA";

usage($0) if (scalar(@ARGV) < 4);

my $tfg_predict = shift(@ARGV);
my $tfg_ranking = shift(@ARGV);
my $rba_predict = shift(@ARGV);
my $rba_ranking = shift(@ARGV);
my $print_all = shift(@ARGV);
$print_all = 0 if (!defined($print_all));

my %id2name;
LoadIdToName(\%id2name);

my %names;
LoadPrintableNames(\%names);

my %full_names;
LoadFullNames(\%full_names);

my %tfg_predictions;
my $rc = LoadPredictions($tfg_predict, $print_all, \%tfg_predictions);
if ($rc) {
  die "Error loading TFG predictions from $tfg_predict";
}

my %tfg_wpct;
my %tfg_sos;
my %tfg_oeff;
my %tfg_deff;
my %tfg_pace;
LoadCurrentRanksAndStats($tfg_ranking, \%tfg_wpct, \%tfg_sos, \%tfg_oeff, \%tfg_deff, \%tfg_pace);

my %rba_predictions;
$rc = LoadPredictions($rba_predict, $print_all, \%rba_predictions);
if ($rc) {
  die "Error loading RBA predictions from $rba_predict";
}

my %rba_wpct;
my %rba_sos;
my %rba_oeff;
my %rba_deff;
my %rba_pace;
LoadCurrentRanksAndStats($rba_ranking, \%rba_wpct, \%rba_sos, \%rba_oeff, \%rba_deff, \%rba_pace);

my %all_gugs;
CalculateGugs(\%tfg_predictions, \%rba_predictions, \%tfg_wpct, \%rba_wpct, \%all_gugs);

my $maxlen = 0;
foreach my $name (values %id2name) {
  my $l = length($name);
  $maxlen = $l if ($l > $maxlen);
}

my $fmt = sprintf "%%s %%-%ds / %%-%ds @ %%s\n", $maxlen, $maxlen;

foreach my $gid (sort keys %all_gugs) {
  my $gugs_aref = $all_gugs{$gid};
  my ($d, $t1id, $t2id) = split(/-/, $gid);
  next if (!defined($t2id));
  my $t1n = $id2name{$t1id};
  if (!defined($t1n)) {
    $t1n = $t1id;
  }
  my $t2n = $id2name{$t2id};
  if (!defined($t2n)) {
    $t2n = $t2id;
  }
  if (!defined($t1n) or !defined($t2n)) {
    warn "Whuh? ($t1id) ($t2id)";
    next;
  }
  $t1n =~ s/\s/_/g;
  $t2n =~ s/\s/_/g;

  printf "$fmt", $gid, $t1n, $t2n, join(' ', @$gugs_aref);
}

sub usage($) {
  my $p = shift;
  my @parts = split(/\//, $p);
  $p = pop(@parts);
  print STDERR "\n";
  print STDERR "Usage: $p <tfg_predict> <tfg_ranking> <rba_predict> <rba_ranking> [<print_all>]\n";
  print STDERR "\n";
  exit 1;
}
