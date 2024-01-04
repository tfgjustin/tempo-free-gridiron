#!/usr/bin/perl

use POSIX;
use TempoFree;
use warnings;
use strict;

sub load_predictions($$$);
sub print_log($$$$);
sub usage($);

my $directory = shift(@ARGV);
my $date = shift(@ARGV);
my $outfile = shift(@ARGV);

if (!defined($directory) or ! -d $directory) {
  print STDERR "No valid directory provided.\n";
  usage($0);
}

$date = strftime "%Y-%m-%d", localtime if (!defined($date));
my $date_str = $date;
$date =~ s/-//g;

if (!defined($outfile)) {
  print STDERR "No outfile specified.\n";
  usage($0);
}

my %gametime;

sub gamesort {
  my $at = $gametime{$a};
  my $bt = $gametime{$b};
  if (!defined($at)) {
    if (!defined($at)) {
      return $a cmp $b;
    } else {
      return 1;
    }
  } else {
    if (!defined($bt)) {
      return -1;
    }
  }
  # If we got here, both $at and $bt are defined.
  if ($at == 3600) {
    if ($bt == 3600) {
      return $a cmp $b;
    } else {
      return 1;
    }
  } else {
    if ($bt == 3600) {
      return -1;
    } else {
      return $bt <=> $at;
    }
  }
}

sub linesort {
  my @aa = split(/,/, $a);
  my @bb = split(/,/, $b);
  my $c = $bb[-1] cmp $aa[-1];
  if ($c) {
    return $c;
  }
  $c = $bb[3] <=> $aa[3];
  return $c;
}

my %tfg_stats;
my $tfg_t = load_predictions("tfg", \%tfg_stats, \%gametime);
my %rba_stats;
my $rba_t = load_predictions("rba", \%rba_stats, \%gametime);

my $last_time = ($rba_t > $tfg_t) ? $rba_t : $tfg_t;

my $t = localtime();
open(OUTFILE, ">$outfile") or die "Can't open $outfile for writing: $!";
select OUTFILE;
print "# Date $date\n";
print "# Games for $date_str\n";
print "# Last updated: $t\n";
printf "# Found %d games\n", scalar(keys %tfg_stats);
foreach my $gid (sort gamesort keys %tfg_stats) {
  my ($d, $hid, $aid) = split(/-/, $gid);
  if ($d != $date) {
#    warn "Date mismatch $d != $date";
    next;
  }

  my $tfg_game_href = $tfg_stats{$gid};
  my $rba_game_href = $rba_stats{$gid};
  if (!defined($tfg_game_href) or !defined($rba_game_href)) {
    warn "Missing either TFG or RBA data for $gid";
    next;
  }
  my @times = sort { $a <=> $b } keys %$tfg_game_href;
  print "# GID $gid\n";
#  foreach my $t (@times) {
#    my $tfg_h = $$tfg_game_href{$t};
#    my $rba_h = $$rba_game_href{$t};
#    my @tfg_l = sort linesort keys %$tfg_h;
#    my @rba_l = sort linesort keys %$rba_h;
#  }
  print_log($gid, \@times, $tfg_game_href, $rba_game_href);
}
select STDOUT;
close(OUTFILE);

sub load_predictions($$$) {
  my $suffix = shift;
  my $pergame_href = shift;
  my $gametime_href = shift;
  my $cmd = "find $directory -name '*.$suffix'";
  open(CMD, "$cmd|") or die "Can't execute \"$cmd\": $!";
  my @files = <CMD>;
  close(CMD);
  chomp @files;

  my $last_timestamp = -1;
  foreach my $f (sort @files) {
    open(F, "$f") or next;
    my @s = stat F;
    $last_timestamp = $s[9] if ($s[9] > $last_timestamp);
    while(<F>) {
      chomp;
      # 20111119-1051-1522,BAYLOR,45,OKLAHOMA,38,3600,1.0
      my ($gid, $l) = split(/,/, $_, 2);
      my @g = split(/,/, $l);
      my $t = $g[4];
      # If t=0 then there should be no score yet.
      next if (!$t and ($g[2] or $g[4]));
      # Append the filename so we can always grab the most recent one when we sort them.
      $l .= ",$f";
      $$pergame_href{$gid}{$t}{$l} = 1;
      if (defined($$gametime_href{$gid})) {
        $$gametime_href{$gid} = $t if ($t > $$gametime_href{$gid});
      } else {
        $$gametime_href{$gid} = $t;
      }
    }
    close(F);
  }
  return $last_timestamp;
}

sub print_log($$$$) {
  my $gid = shift;
  my $times_aref = shift;
  my $tfg_href = shift;
  my $rba_href = shift;

  my $tfg_last_line_href = $$tfg_href{$$times_aref[-1]};
  my $rba_last_line_href = $$rba_href{$$times_aref[-1]};
  my @tfg_last_line = sort linesort keys %$tfg_last_line_href;
  my @rba_last_line = sort linesort keys %$rba_last_line_href;
  my ($ht, $hs, $at, $as, $t, $p, $fname) = split(/,/, $tfg_last_line[0]);
  return if(!defined($p));
  ($ht, $hs, $at, $as, $t, $p, $fname) = split(/,/, $rba_last_line[0]);
  return if(!defined($p));

  my $curr_hs = $hs;
  my $curr_as = $as;

  my $first_tfg_line_href = $$tfg_href{$$times_aref[0]};
  my @first_tfg_line = sort linesort keys %$first_tfg_line_href;
  ($ht, $hs, $at, $as, $t, $p, $fname) = split(/,/, $first_tfg_line[0]);
  return if(!defined($p));
  my $curr_tfg_p = $p;

  my $first_rba_line_href = $$rba_href{$$times_aref[0]};
  my @first_rba_line = sort linesort keys %$first_rba_line_href;
  ($ht, $hs, $at, $as, $t, $p, $fname) = split(/,/, $first_rba_line[0]);
  return if(!defined($p));
  my $curr_rba_p = $p;

  my @loglines;
  foreach my $lt (reverse @$times_aref) {
    my $total_p = 0;
    my $tfg_h = $$tfg_href{$lt};
    my $tfg_l = (sort linesort keys %$tfg_h)[0];
    ($ht, $hs, $at, $as, $t, $p, $fname) = split(/,/, $tfg_l);
    next unless defined($p);
    next if ($hs > $curr_hs or $as > $curr_as);
    # Extra point weirdness.
    next if (($hs + 1) == $curr_hs or ($as + 1) == $curr_as);
    if (($hs + 1) < $curr_hs) { $curr_hs = $hs; }
    if (($as + 1) < $curr_as) { $curr_as = $as; }
    $total_p += $p;
    next unless ($t > 0);
    # Re-create the line but without the filename
    $tfg_l = join(',', $ht, $hs, $at, $as, $t, $p);
    my $rba_h = $$rba_href{$lt};
    my $rba_l = (sort linesort keys %$rba_h)[0];
    ($ht, $hs, $at, $as, $t, $p, $fname) = split(/,/, $rba_l);
    next unless defined($p);
    $rba_l = join(',', $ht, $hs, $at, $as, $t, $p);
    $total_p += $p;

    my $ll = sprintf "$gid,TFG,$tfg_l\n";
    push(@loglines, $ll);
    $ll = sprintf "$gid,RBA,$rba_l\n";
    push(@loglines, $ll);
    $ll = sprintf "$gid,COM,%s,%s,%s,%s,%s,%.3f\n", $ht, $hs, $at, $as, $t, $total_p / 2;
    push(@loglines, $ll);
  }
  print @loglines;
}

sub usage($) {
  my $p = shift;
  my @parts = split(/\//, $p);
  $p = pop(@parts);
  print STDERR "\n";
  print STDERR "Usage: $p <directory> <date> <outfile>\n";
  print STDERR "\n";
  exit 1;
}
