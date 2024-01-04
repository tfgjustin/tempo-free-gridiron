#!/usr/bin/perl -w

use strict;

sub log5pct($$);

while(<STDIN>) {
  next unless(/^0\./);
  chomp;
  @_ = split(/,/);
  my $wpct = $_[0];
  my $sos = $_[1];
  my $wins = $_[-3];
  my $loss = $_[-2];
  next if (!($wins || $loss));
  printf "T %.4f %.4f\n", ($wins / ($wins + $loss)), log5pct($wpct, $sos);
}

sub log5pct($$) {
  my $a = shift;
  my $b = shift;
  my $num = $a - ($a * $b);
  my $den = $a + $b - (2 * $a * $b);
  return sprintf "%.3f\n", $num / $den;
}
