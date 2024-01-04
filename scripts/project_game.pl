#!/usr/bin/perl -w

use strict;

sub winpct($$);
sub calcpts($$$$);

if (scalar(@ARGV) != 12) {
  print "\n";
  print "Usage: $0 "
        . "<hometeam> <homepct> <homesos> <homeoff> <homedef> <homepace>\n"
        . "<awayteam> <awaypct> <awahsos> <awayoff> <awaydef> <awaypace>\n";
  print "\n";
  exit 1;
}

my $hometeam = shift(@ARGV);
my $homepct = shift(@ARGV);
my $homesos = shift(@ARGV);
my $homeoff = shift(@ARGV);
my $homedef = shift(@ARGV);
my $homepace = shift(@ARGV);
my $awayteam = shift(@ARGV);
my $awaypct = shift(@ARGV);
my $awaysos = shift(@ARGV);
my $awayoff = shift(@ARGV);
my $awaydef = shift(@ARGV);
my $awaypace = shift(@ARGV);

my $hpct = winpct($homepct, $awaypct);
my $totalpace = ($homepace + $awaypace) / 2;

my $hpts = calcpts($homeoff, $awaydef, $totalpace, .5);
my $apts = calcpts($awayoff, $homedef, $totalpace, 1 - .5);

printf "\n%-20s %4.1f | %-20s %4.1f | %3d %5.3f\n\n", $hometeam, $hpts, $awayteam,
       $apts, $totalpace, $hpct;

sub winpct($$) {
  my ($a, $b) = @_;
  my $num = $a - ($a * $b);
  my $den = $a + $b - (2 * $a * $b);
  return $num / $den;
}

sub calcpts($$$$) {
  my ($off, $def, $pace, $opct) = @_;
  my $pts = $opct * $off + (1 - $opct) * $def;
  $pts *= ($pace / 100);
  return sprintf "%.1f", $pts;
}
