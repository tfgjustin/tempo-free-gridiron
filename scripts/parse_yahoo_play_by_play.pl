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
  open(PBP, "$filename") or die "Can't open $filename for reading: $!";
  while(<PBP>) {
    next if (/^$/);
    if (!$found_data) {
      if ((/yspscores/ or /team title/) and /"\/ncaaf\/teams\/([a-z]{3})"/) {
        print "Team: $_";
        if (!defined($t1)) {
          $t1 = $1;
          while (<PBP>) {
            last if (/ysptblclbg6/);
            last if (/class="score/);
            if (/^<td class=\"yspscores\">(\d+)<\/td>.*$/) {
              push (@t1_quarters, $1);
            } elsif (/^<td class=\"period\">(\d+)<\/td>.*$/) {
              push (@t1_quarters, $1);
            }
          }
        } else {
          $t2 = $1;
          while (<PBP>) {
            last if (/ysptblclbg6/);
            last if (/class="score/);
            if (/^<td class=\"yspscores\">(\d+)<\/td>.*$/) {
              push (@t2_quarters, $1);
            } elsif (/^<td class=\"period\">(\d+)<\/td>.*$/) {
              push (@t2_quarters, $1);
            }
          }
        }
      } elsif (/Play by Play/) {
        if (!defined($t1) or !defined($t2)) {
          warn "Could not get teams from $filename";
          return;
        }
        printf "T1 %s Scores %s\n", $t1, join(' ', @t1_quarters);
        printf "T2 %s Scores %s\n", $t2, join(' ', @t2_quarters);
        if (!@t1_quarters or (scalar(@t1_quarters) != scalar(@t2_quarters))) {
          warn "Error grabbing scores from $filename for $t1 and $t2";
          return;
        }
        print "Found start\n";
        $found_data = 1;
      }
    }
    next if (!$found_data);
    if (/^<th colspan=\"3\">(\d)\w{2} Quarter<\/th>$/
        or /<h5>(\d)\w{2} Quarter<\/h5>$/) {
      $curr_quarter = $1;
      print "= Quarter: $curr_quarter\n";
    }
    elsif (/^<th colspan=\"3\">(\d*\w{2})<\/th>$/) {
      $curr_quarter = $1;
      print "= Quarter: $curr_quarter\n";
    }
    elsif (/^<th.+colspan=\"3\">(.+)\s-\s+(\d+):(\d{2})<\/th>.*$/) {
      my $team = $1;
      my $min  = $2;
      my $sec  = $3;
      my $r = clock_remaining($curr_quarter, $min, $sec);
      printf "Team: %-20s Min: %2d Sec: %2d Remain: %4d\n", $team, $min, $sec, $r;
      $curr_team = undef;
    }
#<td nowrap="nowrap" valign="top">1st-10, CLEM20</td>
#<td valign="top">15:00</td>
#<td valign="top">Y. Kelly rushed to the left for no gain</td>
    elsif (/^<td \S*\s*valign="top">(\d{1})\w{2}-(\d+), ([A-Za-z]+)(\d+)<\/td>$/) {
      my $down = $1;
      my $dist = $2;
      my $side = $3;
      my $yard = $4;
#      print "$1 $2 $3 $4\n";
      $_ = <PBP>;
      return if (!defined($_));
      my $r = undef;
      if (/^<td \S*\s*valign="top">(\d+):(\d{2})<\/td>$/) {
        $r = clock_remaining($curr_quarter, $1, $2);
      } elsif ($curr_quarter =~ /OT/ and /^<td \S*\s*valign="top"><\/td>$/) {
        $r = 0;
      }
      next if (!defined($r));
      $_ = <PBP>;
      return if (!defined($_));
      my $p = undef;
      if (/^<td \S*\s*valign="top">(.*)<\/td>$/) {
        $p = $1;
      } else { next; }
      printf "%4d Down %d Dist %2d Side %-5s Yard %4s Play %s\n", $r, $down, $dist, $side, $yard, $p;
    }
#    elsif (/^(.*)\s-\s(\d{1,2}):(\d{2})$/) {
#      my $team = $1;
#      my $min  = $2;
#      my $sec  = $3;
#      my $r = clock_remaining($curr_quarter, $min, $sec);
#      print "\nTeam: $team Min: $min Sec: $sec Remain: $r\n";
#      $curr_team = undef;
#    }
#    # Sample line:
#    # 1st-10, FAU17 13:25 G. Wilbert incomplete pass to the left
#    elsif (/\s+(\d)\w{2}-(\d{1,2}),\s([A-Za-z]{0,4})(\d{1,2})\s(\d{1,2}):(\d{2})\s(.*)$/) {
#      my $down = $1;
#      my $dist = $2;
#      my $side = $3;
#      my $yard = $4;
#      my $min  = $5;
#      my $sec  = $6;
#      my $r = clock_remaining($curr_quarter, $min, $sec);
#      print "Down: $down Dist: $dist Side: $side Yard: $yard Min: $min Sec: $sec Remain: $r\n";
#
#      my $details = $7;
#      chomp($details);
#      print "** Details: \"$details\"\n";
#      my $points = 0;
#      my $scoretype = undef;
#      if ($details =~ / touchdown/) {
#        $scoretype = "Touchdown";
#        $points = 6;
#        if ($details =~ / made PAT/) {
#          $points += 1;
#        } elsif ($details =~ /2pt attempt converted/) {
#          $points += 2;
#        }
#      } elsif ($details =~ / field goal/) {
#        if ($details =~ / kicked a/) {
#          $scoretype = "Field goal";
#          $points = 3;
#        }
#      }
#      if ($points and defined($scoretype)) {
#        print "**** $scoretype! $points points\n";
#      }
#    }
  }
}

foreach my $f (@ARGV) {
  parse_file($f);
}
