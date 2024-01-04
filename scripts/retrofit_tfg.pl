#!/usr/bin/perl 

use POSIX;
use TempoFree;
use strict;
use warnings;

sub fix_prediction($);
sub fix_ranking($);

my %id2name;
LoadIdToName(\%id2name);
my %name2id;
foreach my $tid (keys %id2name) {
  $name2id{$id2name{$tid}} = $tid;
}

my $FIRST_DAY = POSIX::mktime(0, 0, 0, 23, 7, 100);

my $filename = shift(@ARGV);
if (!defined($filename)) {
  die "Invalid or missing filename";
}
my ($year, $month, $day);
if ($filename =~ /.*\/tfg.predict.(\d{4})-(\d{2})-(\d{2}).out/) {
  $year = $1;
  $month = $2;
  $day = $3;
} else {
  die "Invalid filename: $filename";
}

my $t = POSIX::mktime(0, 0, 12, $day, $month - 1, $year - 1900);
$t -= $FIRST_DAY;
my $week_num = int($t / (7 * 24 * 3600));

open(TFG, "$filename") or die "Couldn't open $filename for reading: $!";
while(<TFG>) {
  chomp;
  if (/PREDICT/) {
    fix_prediction($_);
  } elsif (/^[01]/ and /[A-Z]/) {
    fix_ranking($_);
  }
}
close(TFG);

sub fix_prediction($) {
  my $line = shift;
  @_ = split(/,/, $line);
  my $tag = shift(@_);
  my $fluff = shift(@_);
  unshift(@_, $tag);
  unshift(@_, $fluff);
  my $l = join(',', @_);
  print "$l\n";
}

sub fix_ranking($) {
  my $line = shift;
  @_ = split(/,/, $line);
  # tag,weeknum,teamID,wpct,sos,etc,etc,etc...
  my $wpct = shift(@_);
  my $sos = shift(@_);
  my $teamname = shift(@_);
  my $tid = $name2id{$teamname};
  if (!defined($tid)) {
    warn "Could not find ID for $teamname";
    return;
  }
  unshift(@_, $sos);
  unshift(@_, $wpct);
  unshift(@_, $tid);
  unshift(@_, $week_num);
  unshift(@_, "RANKING");
  my $l = join(',', @_);
  print "$l\n";
}
