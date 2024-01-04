#!/usr/bin/perl 

use TempoFree;
use strict;
use warnings;

sub usage() {
  my @p = split(/\//, $0);
  my $prog = pop(@p);
  print STDERR "\n";
  print STDERR "$prog <week> <date> <field> <home_id> <away_id>\n";
  print STDERR "\n";
  exit 1;
}

my $week = shift(@ARGV);
my $date = shift(@ARGV);
my $field = shift(@ARGV);
my $home_id = shift(@ARGV);
my $away_id = shift(@ARGV);

usage() if (!defined($away_id));

$field = uc $field;

my %id2name;
LoadIdToName(\%id2name);
my $ending = "0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0";

my $home_n = $id2name{$home_id};
my $away_n = $id2name{$away_id};

if ($field ne "NEUTRAL") {
  if ($field eq $home_id) {
    $field = $home_n;
  } elsif ($field eq $away_id) {
    $field = $away_n;
  } else {
    die "Invalid field: $field";
  }
}


# Week,Date,GameID,Site,NumPoss,HomeID,HomeName,HomeScore,AwayID,AwayName
printf "%d,%s,%s-%d-%d,%s,0,%d,%s,0,%d,%s,%s\n", $week, $date, $date, $home_id,
       $away_id, $field, $home_id, $home_n, $away_id, $away_n, $ending;
