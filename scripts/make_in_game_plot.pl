#!/usr/bin/perl 

use strict;
use warnings;

my $datafile = shift(@ARGV);
my $gplotfile = shift(@ARGV);
my $outfile = shift(@ARGV);
my $title = shift(@ARGV);

exit 1 if (!defined($title));

open(INDATAF, "$datafile") or die "Can't open $datafile for reading: $!";
open(OUTDATAF, ">$datafile.tmp") or die "Can't open $datafile.tmp for writing: $!";
while(<INDATAF>) {
  next unless(/^sum/);
  chomp;
  @_ = split;
  print OUTDATAF "$_[7] $_[9]\n";
}
close(INDATAF);
close(OUTDATAF);

open(OUTF, ">$gplotfile") or die "Can't open $gplotfile for writing: $!";
select OUTF;
print "set terminal png\n";
print "set output \"$outfile\"\n";
print "set title \"$title\"\n";
print "set xrange [0.4:1.0] ; set xtics 0.1\n";
print "set yrange [0.4:1.0] ; set ytics 0.1\n";
print "set grid xtics ytics\n";
print "set key bottom right\n";
print "set xlabel \"Predicted Win Probability\"\n";
print "set ylabel \"Actual Win Probability\"\n";
print "plot x title \"Target\", '$datafile.tmp' title \"Model\" w p ps 2\n";
select STDOUT;
close(OUTF);

open(PLOT, "gnuplot $gplotfile|") or die "Can't execute gnuplot: $!";
@_ = <PLOT>;
close(PLOT);
print @_;
