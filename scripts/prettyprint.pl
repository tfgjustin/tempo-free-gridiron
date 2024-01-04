#!/usr/bin/perl -w

use TempoFree;
use strict;

my $predictions = shift(@ARGV);
my $do_all = shift(@ARGV);
$do_all = 0 if(!defined($do_all));

if (!defined($predictions)) {
  print "\n";
  print "Usage: $0 <predictions> [doAll]\n";
  print "\n";
  exit 1;
}

my %id2name;
LoadIdToName(\%id2name);

my $maxlen = 0;
foreach my $name (values %id2name) {
  my $l = length($name);
  $maxlen = $l if ($l > $maxlen);
}

my $fmt = sprintf "%%s %%-%ds %%3d %%-%ds %%3d %%.3f\n", $maxlen, $maxlen;

open(GAMES, "$predictions") or die "Cannot open $predictions for reading: $!";
while(<GAMES>) {
  if ($do_all) {
    next unless(/^PREDICT,/);
  } else {
    next unless(/PREDICT,ALLDONE,/);
  }
  chomp;
  s/\s//g;
  @_ = split(/,/);
  if (scalar(@_) < 9) {
    printf STDERR "scalar(@_) = %d < 9\n", scalar(@_);
    next;
  }
  my $gid  = $_[2];
  my $t1id = $_[4];
  my $t1s  = $_[5];
  my $t2id = $_[6];
  my $t2s  = $_[7];
  my $t1wp = $_[8];
  if ($t1wp < 500) {
    $t1wp = 1000 - $t1wp;
  }
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
  if ($t1s > $t2s) {
    $t2n = lc $t2n;
  } else {
    $t1n = lc $t1n;
  }

  printf "$fmt", $gid, $t1n, $t1s, $t2n, $t2s, $t1wp / 1000;
}
close(GAMES);
