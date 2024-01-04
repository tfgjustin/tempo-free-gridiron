#!/usr/bin/perl -w

use strict;

my $a = shift(@ARGV);
my $b = shift(@ARGV);

exit if (!defined($b));

my $num = $a - ($a * $b);
my $den = $a + $b - (2 * $a * $b);

printf "%.3f\n", $num / $den;
