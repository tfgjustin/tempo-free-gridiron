#!/usr/bin/perl -w

use strict;

my $odds_file = shift(@ARGV);
my $summary_file = shift(@ARGV);
exit 1 if (!defined($summary_file));

my %odds;
open(ODDS, "$odds_file") or die "Can't open $odds_file: $!";
while(<ODDS>) {
  next if(/^#/);
  chomp;
  @_ = split(/,/);
  $odds{$_[0]} = $_[1];
}
close(ODDS);

open(SUMMARY, "$summary_file") or die "Can't open $summary_file: $!";
while(<SUMMARY>) {
  next if (/^#/);
  chomp;
  @_ = split(/,/);
  my $gid = $_[2];
  my ($date, $home, $away) = split(/-/, $gid);
  my $hid = $date . "-" . $home;
  my $aid = $date . "-" . $away;
  if (!defined($odds{$hid})) {
    print STDERR "No odds for home team in $gid\n";
    next;
  }
  if (!defined($odds{$aid})) {
    print STDERR "No odds for away team in $gid\n";
    next;
  }
  my $sum = $odds{$hid} + $odds{$aid};
  if ($sum > 0.001) {
    print STDERR "Mismatched odds for $gid: $odds{$hid} $odds{$aid}\n";
    next;
  }
  if ($odds{$hid} < 0) {
    print "$gid,$home,$away,$odds{$aid}\n";
  } elsif ($odds{$aid} < 0) {
    print "$gid,$away,$home,$odds{$hid}\n";
  } else {
    print STDERR "PUSH in game $gid\n";
  }
}
close(SUMMARY);
