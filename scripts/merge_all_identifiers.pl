#!/usr/bin/perl -w

use strict;
use TempoFree;

my %id2name;
LoadIdToName(\%id2name);

my %names;
LoadPrintableNames(\%names);

my %full_names;
LoadFullNames(\%full_names);

foreach my $padded_id (keys %id2name) {
  my $caps_name = $id2name{$padded_id};
  my $name = $names{$caps_name};
  next if (!defined($name));
  my $full_name = $full_names{$caps_name};
  next if (!defined($full_name));
  printf "%d,%d,%s,%s,%s\n", $padded_id - 1000, $padded_id, $caps_name, $name, $full_name;
}
