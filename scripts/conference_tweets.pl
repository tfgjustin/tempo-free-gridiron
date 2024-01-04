#!/usr/bin/perl -w

use Math::Round;
use TempoFree;
use strict;

sub WriteTweet($$);
sub usage();

my $conf_file = shift(@ARGV);
my $output_dir = shift(@ARGV);
my $base_time = shift(@ARGV);
my $model = shift(@ARGV);
usage() if (!defined($conf_file) or ! -f $conf_file);
usage() if (!defined($output_dir) or ! -d $output_dir);
usage() if (!defined($base_time));
usage() if (!defined($model));
$model = uc $model;
usage() if ($model ne "RBA" and $model ne "TFG");

my %confs;
open (CONFS, "$conf_file") or die "Can't open $conf_file for reading: $!";
while(<CONFS>) {
  chomp;
  next unless(/^CONF/);
  my @p = split(/,/);
  my $t = shift(@p);
  my $c = shift(@p);
  $confs{$c} = \@p;
}
close(CONFS);
exit if (!%confs);

my @lines;
my $n = 1;
foreach my $conf (sort {${$confs{$b}}[-1] <=> ${$confs{$a}}[-1]} keys %confs) {
  my $aref = $confs{$conf};
  $conf =~ s/[\W]//g;
  my $wins = round($$aref[0]);
  my $loss = round($$aref[1]);
  my $odds = 100.0 * $$aref[-1];
  my $l = sprintf "%d) #%s: %.1f%% (%3d - %3d)\n", $n++, $conf, $odds, $wins, $loss;
  push(@lines, $l);
}

my $curr_line = 0;
my $curr_time = $base_time;
my $text = "Full round-robin win %: $model\n";
my $char_count = length($text);
my $fname = $output_dir . "/main." . $curr_time . ".txt";
while ($curr_line < scalar(@lines)) {
  if (length($lines[$curr_line]) + $char_count > 280) {
    WriteTweet($text, $fname);
    $curr_time -= 65;
    $text = "#CFBPlayff Odds: $model (cont'd)\n";
    $char_count = length($text);
    $fname = $output_dir . "/main." . $curr_time . ".txt";
  }
  $text .= $lines[$curr_line++];
  $char_count = length($text);
}
WriteTweet($text, $fname);

sub WriteTweet($$) {
  my $t = shift;
  my $f = shift;
  open(TWEET, ">$f") or die "Can't open $f for writing: $!";
  print TWEET $t;
  close(TWEET);
}

sub usage() {
  print STDERR "\n";
  print STDERR "Usage: $0 <conf_file> <output_directory> <base_time> <rba|tfg>\n";
  print STDERR "\n";
  exit 1;
}
