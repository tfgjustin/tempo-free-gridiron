#!/usr/bin/perl 
use strict;
use warnings;

sub parse_file($);

while (<STDIN>) {
  chomp;
  next unless (-f $_);
  parse_file($_);
}

sub parse_file($) {
  my $fname = shift;
  open (DATA, "w3m -dump -cols 300 $fname|") or do {
    warn "Error parsing $fname";
    return;
  };
  my $found_header = 0;
  while(<DATA>) {
    if (!$found_header) {
      next unless
    } else {

    }
  }
  close(DATA);
}
