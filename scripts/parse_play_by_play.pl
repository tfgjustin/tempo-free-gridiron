#!/usr/bin/perl 

use TempoFree;
use strict;
use warnings;

sub clock_remaining($$$) {
  my $q = shift;
  my $m = shift;
  my $s = shift;
  my $t = (4 - $q) * 900;
  $t += (60 * $m);
  $t += $s;
  return $t;
}

sub parse_file($) {
  my $filename = shift;
  my $found_data = 0;
  my $score_lines = 0;
  my ($t1, $t2) = ( undef, undef );
  my ($t1_total, $t2_total) = (undef, undef);
  my @t1_quarters;
  my @t2_quarters;
  my $curr_team = undef;
  my $curr_quarter = undef;
  my $num_quarters = undef;
  open(PBP, "w3m -dump -cols 500 $filename|") or die "Can't open $filename for reading: $!";
  while(<PBP>) {
    next if (/^$/);
    if (!$found_data) {
      if ((/Team/ or /Bowl/) and /Total/) {
        @_ = split;
        $num_quarters = scalar(@_) - 2;
        print "NumQuarters: $num_quarters\n";
        $score_lines = 1;
      } elsif ($score_lines == 1) {
        @_ = split;
        $t1_total = pop(@_);
        foreach my $i (1..$num_quarters) {
          push(@t1_quarters, pop(@_));
        }
        @t1_quarters = reverse @t1_quarters;
        $t1 = join(' ', @_);
        print "Line: $_";
        print "* Team1: \"$t1\" Scores: " . join(' ', @t1_quarters) . " Final: $t1_total\n";
        $score_lines++;
      } elsif ($score_lines == 2) {
        @_ = split;
        $t2_total = pop(@_);
        foreach my $i (1..$num_quarters) {
          push(@t2_quarters, pop(@_));
        }
        @t2_quarters = reverse @t2_quarters;
        $t2 = join(' ', @_);
        print "Line: $_";
        print "* Team2: \"$t2\" Scores: " . join(' ', @t2_quarters) . " Final: $t2_total\n";
        $score_lines++;
      } elsif (/^Play by Play$/) {
        print "Found start\n";
        $found_data = 1;
      }
    }
    next if (!$found_data);
    if (/^(\d)(\w{2}) Quarter$/) {
      $curr_quarter = $1;
      print "= Quarter: $curr_quarter\n";
    }
    elsif (/^(.*)\s-\s(\d{1,2}):(\d{2})$/) {
      my $team = $1;
      my $min  = $2;
      my $sec  = $3;
      my $r = clock_remaining($curr_quarter, $min, $sec);
      print "\nTeam: $team Min: $min Sec: $sec Remain: $r\n";
      $curr_team = undef;
    }
    # Sample line:
    # 1st-10, FAU17 13:25 G. Wilbert incomplete pass to the left
    elsif (/\s+(\d)\w{2}-(\d{1,2}),\s([A-Za-z]{0,4})(\d{1,2})\s(\d{1,2}):(\d{2})\s(.*)$/) {
      my $down = $1;
      my $dist = $2;
      my $side = $3;
      my $yard = $4;
      my $min  = $5;
      my $sec  = $6;
      my $r = clock_remaining($curr_quarter, $min, $sec);
      print "Down: $down Dist: $dist Side: $side Yard: $yard Min: $min Sec: $sec Remain: $r\n";

      my $details = $7;
      chomp($details);
      print "** Details: \"$details\"\n";
      my $points = 0;
      my $scoretype = undef;
      if ($details =~ / touchdown/) {
        $scoretype = "Touchdown";
        $points = 6;
        if ($details =~ / made PAT/) {
          $points += 1;
        } elsif ($details =~ /2pt attempt converted/) {
          $points += 2;
        }
      } elsif ($details =~ / field goal/) {
        if ($details =~ / kicked a/) {
          $scoretype = "Field goal";
          $points = 3;
        }
      }
      if ($points and defined($scoretype)) {
        print "**** $scoretype! $points points\n";
      }
    }
  }
}

foreach my $f (@ARGV) {
  parse_file($f);
}
