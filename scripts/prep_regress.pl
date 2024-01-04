#!/usr/bin/perl -w

use POSIX;
use TempoFree;
use strict;

my $FIRST_DAY = POSIX::mktime(0, 0, 0, 23, 7, 100);
my %FACTORS = (
  "090" => 1.0550,
  "091" => 1.0415,
  "100" => 1.0375,
  "101" => 1.0475,
  "110" => 1.0175,
  "111" => 1.0000);

sub date_to_week($);
sub remove_home_field($$$$$$);
sub usage($) {
  my $p = shift;
  my @parts = split(/\//, $p);
  $p = $parts[-1];
  print STDERR "\n";
  print STDERR "Usage: $p <currdate> <decay> <matrix_out> <result_out> <init_out>\n";
  print STDERR "\n";
  exit 1;
}

my $currdate = shift(@ARGV);
my $decay = shift(@ARGV);
my $matrix_out = shift(@ARGV);
my $result_out = shift(@ARGV);
my $init_out = shift(@ARGV);

usage($0) if (!defined($init_out));

my $currweek = date_to_week($currdate);
usage($0) if (!defined($currweek));
# Create the mappings of
# 1) team ID -> short name
# 2) team ID -> Conference
# 3) (conference, subconference) -> set of team IDs
# 4) team ID -> isBcs
my %id2name;
my %id2conf;
my %conf2subconf;
my %id2bcs;
LoadConferences(\%id2name, \%id2conf, \%conf2subconf, \%id2bcs);

my %idrank;
my $i = 0;
foreach my $id (sort { $a <=> $b } keys %id2bcs) {
  next if (!defined($id2conf{$id}) or $id2conf{$id} eq "FCS");
  printf "%3d => %s\n", $i, $id2name{$id};
  $idrank{$id} = $i++;
}
my $MAX_IDX = 2 * scalar(keys %idrank) - 1;

my %allresults;
LoadResults(\%allresults);
printf "Loaded results for %d games\n", scalar(keys %allresults);

my @rows;
my %indata;
my %respoints;
my %resplays;
my $total_points = 0;
my $total_plays = 0;
foreach my $gid (keys %allresults) {
  my $results = $allresults{$gid};
  my $t1idx = $idrank{$$results[5]};
  my $t2idx = $idrank{$$results[8]};
  next if (!defined($t1idx) or !defined($t2idx));

  my $weeks_ago = $currweek - $$results[0];
  next if ($weeks_ago < 0 or $weeks_ago > 155);
  my $df = $decay ** $weeks_ago;
  my $num_plays = sprintf "%.6f", $$results[4] / 100;
  my ($t1pts, $t2pts) = remove_home_field($$results[1], $$results[3], $$results[6],
                                          $$results[9], $$results[7], $$results[10]);
  next if (!defined($t1pts) or !defined($t2pts));
  $t1pts = sprintf "%.6f", $t1pts * $df;
  $t2pts = sprintf "%.6f", $t2pts * $df;
  $t1pts /= $num_plays;
  $t2pts /= $num_plays;
  my $t1o = $t1idx * 2 + 0;
  my $t1d = $t1idx * 2 + 1;
  my $t2o = $t2idx * 2 + 0;
  my $t2d = $t2idx * 2 + 1;
  $indata{$t1o}{$t2d} += $df;
  $resplays{$t1o} += $df;
  $respoints{$t1o} += $t1pts;
  $indata{$t2d}{$t1o} += $df;
  $resplays{$t2d} += $df;
  $respoints{$t2d} += $t1pts;
  $indata{$t2o}{$t1d} += $df;
  $resplays{$t2o} += $df;
  $respoints{$t2o} += $t2pts;
  $indata{$t1d}{$t2o} += $df;
  $resplays{$t2d} += $df;
  $respoints{$t1d} += $t2pts;

  push(@rows, join(',', $t1o, $t2d, $num_plays, $t1pts));
  push(@rows, join(',', $t2o, $t1d, $num_plays, $t2pts));
  $total_points += $t1pts + $t2pts;
  $total_plays += ($num_plays * 2);
}

printf "Found %d rows\n", scalar(@rows);
printf "Max IDX: $MAX_IDX\n";
printf "Avg eff: %5.2f\n", $total_points / $total_plays;

open(MATRIX, ">$matrix_out") or die "Can't open $matrix_out for writing: $!";
open(RESULT, ">$result_out") or die "Can't open $result_out for writing: $!";
foreach my $i (0..$MAX_IDX) {
  my $href = $indata{$i};
  my $pts = $respoints{$i};
  my @a = ();
  if (!defined($href)) {
    @a = (("0") x ($MAX_IDX + 1));
    $pts = 0;
  } else {
    foreach my $j (0..$MAX_IDX) {
      my $v = $$href{$j};
      if (defined($v)) {
        push(@a, $v);
      } else {
        push(@a, 0);
      }
    }
  }

  print MATRIX join(' ', @a) . "\n";
  print RESULT "$pts\n";
}
#foreach my $r (@rows) {
#  my @p = split(/,/, $r);
#  next if (scalar(@p) != 4);
#  print ".";
#  print RESULT "$p[3]\n";
#  my @a = ();
#  foreach my $i (0..$MAX_IDX) {
#    if ($i == $p[0]) { push(@a, $p[2]); }
#    elsif ($i == $p[1]) { push(@a, $p[2]); }
#    else { push(@a, "0"); }
#  }
##  print "Size(a) " . scalar(@a) . " idx1 " . $p[0] . " idx2 " . $p[1] . " #P " . $p[2] . "\n";
#  print MATRIX join(' ', @a) . "\n";
#}

open(INIT, ">$init_out") or die "Can't open $init_out for writing: $!";
#my @a = ();
foreach my $i (0..$MAX_IDX) {
  my $pts = $respoints{$i};
  my $plays = $resplays{$i};
  if (!defined($pts) or !defined($plays) or !$plays) {
    printf INIT "%5.2f\n", 0;
  } else {
    printf INIT "%5.2f\n", $pts / $plays;
  }
#  push(@a, 1);
#  printf INIT "%5.2f\n", $total_points / $total_plays;
}
#print MATRIX join(' ', @a) . "\n";
#print RESULT "$total_points\n";
close(MATRIX);
close(RESULT);
close(INIT);
print "\n";

sub date_to_week($) {
  my $date = shift;
  if ($date =~ /(\d{4})(\d{2})(\d{2})/) {
    my $year = $1 - 1900;
    my $month = $2 - 1;
    my $day = $3;
    my $t = POSIX::mktime(0, 0, 12, $day, $month, $year);
    $t -= $FIRST_DAY;
    my $week = int($t / (7 * 24 * 3600));
    return $week;
  } else {
    warn "Invalid date format: $date";
    return undef;
  }
}

sub remove_home_field($$$$$$) {
  my $gdate = shift;
  my $site = shift;
  my $t1n = shift;
  my $t2n = shift;
  my $t1p = shift;
  my $t2p = shift;
  if ($site eq "NEUTRAL") {
    return ($t1p, $t2p);
  }
  my $d = substr($gdate, 4, 3);
  my $f = $FACTORS{$d};
  $f = 1.0 if (!defined($f));
  if ($site eq $t1n) {
    # T1 was the home team. This means they artificially scored more points and allowed fewer points.
    return ($t1p / $f, $t2p * $f);
  } elsif ($site eq $t2n) {
    # T2 was the home team. Strip T2's points and beef up T1's points.
    return ($t1p * $f, $t2p / $f);
  } else {
    warn "Site $site is not NEUTRAL or $t1n or $t2n";
    return (undef, undef);
  }
}
