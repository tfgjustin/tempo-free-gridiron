#!/usr/bin/perl -w

use TempoFree;
use strict;

sub WriteTweet($$);
sub usage();

my $playoff_file = shift(@ARGV);
my $output_dir = shift(@ARGV);
my $base_time = shift(@ARGV);
my $model = shift(@ARGV);
usage() if (!defined($playoff_file) or ! -f $playoff_file);
usage() if (!defined($output_dir) or ! -d $output_dir);
usage() if (!defined($base_time));
usage() if (!defined($model));
$model = uc $model;
usage() if ($model ne "RBA" and $model ne "TFG");

my %id2name;
LoadIdToName(\%id2name);

my %names;
LoadPrintableNames(\%names);

my $num_sims = 0;
my %team_count;
open (PLAYOFF, "$playoff_file") or die "Can't open $playoff_file for reading: $!";
while(<PLAYOFF>) {
  chomp;
  if (/^Season/) {
    $num_sims++;
  } elsif (/^TEAM/) {
    @_ = split(/,/);
    $team_count{$_[2]} = $_[1];
  }
}
close(PLAYOFF);
exit if (!$num_sims);

print "# NumSims: $num_sims\n";

my @lines;
my $n = 1;
foreach my $tid (sort {$team_count{$b} <=> $team_count{$a}} keys %team_count) {
  my $sn = $id2name{$tid};
  die "No name for team $tid" if (!defined($sn));
  my $name = $names{$sn};
  die "No printable name for $sn" if (!defined($name));
  $name =~ s/[\W]//g;
  my $odds = 100.0 * $team_count{$tid} / $num_sims;
  last if ($odds < 0.11);
  my $l = sprintf "%d) #%s: %.1f%%\n", $n++, $name, $odds;
  push(@lines, $l);
}
printf "# NumLines: %d\n", scalar(@lines);

my $curr_line = 0;
my $curr_time = $base_time;
my $text = "#CFBPlayoff Odds: $model\n";
my $char_count = length($text);
my $fname = $output_dir . "/main." . $curr_time . ".txt";
while ($curr_line < scalar(@lines) and $curr_line < 20) {
  if (length($lines[$curr_line]) + $char_count > 280) {
    WriteTweet($text, $fname);
    $curr_time -= 65;
    $text = "#CFBPlayoff Odds: $model (cont'd)\n";
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
  print STDERR "Usage: $0 <playoff_file> <output_directory> <base_time> <rba|tfg>\n";
  print STDERR "\n";
  exit 1;
}
