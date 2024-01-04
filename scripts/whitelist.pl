#!/usr/bin/perl 

use TempoFree;
use strict;
use warnings;

my $summaryfile = shift(@ARGV);
my $whitelistfile = shift(@ARGV);
my $currdate = shift(@ARGV);

if (!defined($currdate)) {
  print STDERR "\n";
  print STDERR "$0 <summaryfile> <whitelist> <data>\n";
  print STDERR "\n";
  exit 1;
}

my %id2name;
my %id2conf;
my %conf2teams;
my %is_bcs;
LoadConferences(\%id2name, \%id2conf, \%conf2teams, \%is_bcs);

my %whitelist;
open(WHITELIST, "$whitelistfile") or die "Can't open whitelist $whitelistfile for reading: $!";
while(<WHITELIST>) {
  chomp;
  @_ = split(/,/);
  my $gid = $_[2];
  $whitelist{$gid} = $_;
  print STDERR "Whitelisted $gid\n";
}
close(WHITELIST);

$currdate =~ s/-//g;

open(SUMMARY, "$summaryfile") or die "Can't open summary $summaryfile for reading: $!";
while(<SUMMARY>) {
  if (/^#/) {
    print;
    next;
  }
  chomp;
  @_ = split(/,/);
  my $gid = $_[2];
  my $filedate = $_[1];
  my $home_id = $_[5];
  my $away_id = $_[8];
  my $home_conf = $id2conf{$home_id};
  my $away_conf = $id2conf{$away_id};
  if (!defined($home_conf) or !defined($away_conf)) {
    warn "Could not get conference for a team in game $gid";
    next;
  }
  if ($home_conf eq "FCS" or $away_conf eq "FCS") {
    warn "FCS team in game $gid";
    next;
  }
  if (!defined($whitelist{$gid})) {
    if ($filedate < $currdate) {
      # The game here happened before today. We *shoud* have a score.
      if (!($_[7] or $_[10])) {
        warn "Today is $currdate; game $gid was $filedate but no score";
        next;
      }
    }
    print "$_\n";
  } else {
    warn "Replacing $gid\n";
    print "$whitelist{$gid}\n";
  }
}
close(SUMMARY);
exit 0;
