#!/usr/bin/perl -w
#
# A 'dashboard' to check how the predictions do in terms of bias, raw error, and
# squared error. Input is the output of scoreMyResults.pl

use strict;

sub dev($$);

my @biases;
my $bias_sum = 0;
my $abs_err_sum = 0;
my $brier = 0;

while(<STDIN>) {
  next unless (/^20/);
  chomp;
  @_ = split;
  my $home_p = $_[5];
  my $away_p = $_[6];
  my $home_a = $_[2];
  my $away_a = $_[3];
  next if (!defined($home_p) or !defined($home_a));
  next if (!defined($away_p) or !defined($away_a));
  next if ($home_p =~ /[A-Z]/ or $home_a =~ /[A-Z]/);
  next if ($home_a == 0 and $away_a == 0);
  my $home_b = $home_p - $home_a;
  my $away_b = $away_p - $away_a;
  push(@biases, $home_b);
  push(@biases, $away_b);
  $bias_sum += ($home_b + $away_b);
  $abs_err_sum += (abs($home_b) + abs($away_b));
  $brier += (($_[8] - ($_[11] / 1000.)) ** 2)
}
exit if(!@biases);
$abs_err_sum /= scalar(@biases);
$brier /= scalar(@biases);
my $bias_avg = $bias_sum / scalar(@biases);
my $stddev = dev(\@biases, $bias_avg);
printf "MeanError %7.4f Bias %7.4f MSE %7.3f Brier %5.3f\n",
  $abs_err_sum, $bias_avg, $stddev, $brier;

sub dev($$) {
  my $aref = shift;
  my $mean = shift;
  my $sos = 0;
  foreach my $b (@$aref) {
    $sos += (($b - $mean) ** 2);
  }
  return $sos / (scalar(@$aref) - 1);
}
