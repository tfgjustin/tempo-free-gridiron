#!/usr/bin/perl 

use strict;
use warnings;

while(<STDIN>) {
  chomp;
  @_ = split;
  if (scalar(@_) != 6) {
    warn "Invalid line: \"$_\" (size " . scalar(@_) . ")";
    next;
  }
  printf "%2d %-30s %2d %-30s %2d %.3f\n", $_[0], $_[3], $_[4], $_[1], $_[2], $_[5];
}

