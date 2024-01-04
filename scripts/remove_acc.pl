#!/usr/bin/perl 

use TempoFree;
use strict;
use warnings;

my %names;
my %t2c;
my %c2t;
my %t2b;
die if (LoadConferences(\%names, \%t2c, \%c2t, \%t2b));

my %acc;
my $href = $c2t{"ACC"};
foreach my $sub (keys %$href) {
  my $subhref = $$href{$sub};
  foreach my $t (keys %$subhref) {
    $acc{"-$t"} = 1;
  }
}

while(<STDIN>) {
  chomp;
  my $s = 0;
  foreach my $t (keys %acc) {
    if (/$t/) { $s = 1; last; }
  }
  next if ($s);
  print "$_\n";
}
