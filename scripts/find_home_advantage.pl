#!/usr/bin/perl -w

use strict;

my %pred_winpcts;
my %pred_gamecount;
my %act_wins;
my %act_gamecount;

if (scalar(@ARGV) != 2) {
  print STDERR "\n";
  print STDERR "Usage: $0 <predicted> <actual>\n";
  print STDERR "\n";
  exit 1;
}

my $predict_fname = shift(@ARGV);
my $actual_fname = shift(@ARGV);

sub date_to_bin($) {
  my $date = shift;
  my $month = substr($date, 4, 2);
  my $mhalf = int(substr($date, 6, 2) / 16);
  return "$month$mhalf";
}

sub add_predict_win_pct($$) {
  my ($gid, $hwinpct) = @_;
  my $b = date_to_bin($gid);
  $pred_winpcts{$b} += $hwinpct;
  $pred_gamecount{$b} += 1;
}

sub add_actual_result($$$) {
  my ($gid, $hscore, $ascore) = @_;
  my $b = date_to_bin($gid);
  if ($hscore > $ascore) {
    $act_wins{$b} += 1;
  }
  $act_gamecount{$b} += 1;
}

open(PRED, "$predict_fname") or die "Cannot open predictions $predict_fname: $!";
while(<PRED>) {
  next unless(/PARTIAL/);
  chomp;
  @_ = split(/,/);
  next if ($_[3] == 1);
  my $gid = $_[2];
  my $hwinpct = $_[8];
  next if ($hwinpct =~ /"624"/);
  add_predict_win_pct($gid, $hwinpct);
}
close(PRED);

open(ACTUAL, "$actual_fname") or die "Cannot open results $actual_fname: $!";
while(<ACTUAL>) {
  next if (/^#/);
  chomp;
  @_ = split(/,/);
  next if ($_[3] eq "NEUTRAL");
  my $gid = $_[2];
  my $hscore = $_[7];
  my $ascore = $_[10];
  add_actual_result($gid, $hscore, $ascore);
}
close(ACTUAL);

printf "%3s %5s %5s %5s %5s\n", "Bin", "Num", "Pred.", "Found", "Ratio";
foreach my $bin (sort keys %pred_winpcts) {
  if (!defined($act_gamecount{$bin}) or ($act_gamecount{$bin} == 0)) {
    warn "No actual games during $bin (?)";
    next;
  }
  my $pred_winpct = $pred_winpcts{$bin} / (1000 * $pred_gamecount{$bin});
  my $act_winpct = $act_wins{$bin} / $act_gamecount{$bin};
  my $adj_factor = $act_winpct / $pred_winpct / 2;
  if ($pred_gamecount{$bin} != $act_gamecount{$bin}) {
    warn "Gamecounts do not match for $bin!\n";
    next;
  }
  printf "%3s %5d %.3f %.3f %.3f\n", $bin, $pred_gamecount{$bin}, $pred_winpct,
         $act_winpct, $adj_factor;
}
