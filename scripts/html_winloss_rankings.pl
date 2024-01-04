#!/usr/bin/perl -w
#
# WARNING WARNING WARNING WARNING
# As of the Great Ranking File Format Rewrite of Sept 2011, THIS CHUNK OF CODE
# NO LONGER WORKS PROPERLY!!!
#
# DO NOT USE IT
# DO NOT USE IT
# DO NOT USE IT

use POSIX;
use strict;

sub up_down_cell($$$$);
sub log5win($$);

my $CHANGEUP = "#008000";
my $CHANGEDOWN = "#800000";

if (scalar(@ARGV) < 2) {
  print STDERR "\n";
  print STDERR "Usage: $0 <namemap> <thisWeekData> [<lastWeekData>]\n";
  print STDERR "\n";
  exit 1;
}

my $namemap = shift(@ARGV);
my $datafile = shift(@ARGV);
my $lastweekdata = shift(@ARGV);
my $topX = shift(@ARGV);

my @data;
open(DATA, "$datafile") or die "Can't open data file $datafile: $!";
while(<DATA>) {
  next if(/PREDICT/);
  next if(/P[FA]Diff/);
  next unless(/[A-Z]/);
  chomp;
  push(@data, $_);
}
close(DATA);
exit if (!@data);
if (!defined($topX)) { $topX = scalar(@data); }

my %last_rank;
my %last_wpct;
my %last_oeff;
my %last_deff;
my %last_sos;
my %last_pace;
if (defined($lastweekdata)) {
  my @lastdata;
  open(LDATA, "$lastweekdata") or die "Can't open data file $lastweekdata: $!";
  while(<LDATA>) {
    next if(/PREDICT/);
    next if(/P[FA]Diff/);
    next unless(/[A-Z]/);
    chomp;
    push(@lastdata, $_);
    @_ = split(/,/);
    my $wpct = $_[0];
    my $sos = $_[1];
    my $team = $_[2];
    my $off = $_[3];
    my $def = $_[4];
    my $pace = $_[-1];
    $last_wpct{$team} = $wpct;
    $last_oeff{$team} = $off;
    $last_deff{$team} = $def;
    $last_sos{$team} = $sos;
    $last_pace{$team} = $pace;
  }
  close(LDATA);
  exit if (!@lastdata);
  my $last_r = 1;
  foreach my $ll (sort { $b cmp $a } @lastdata) {
    my @p = split(/,/, $ll);
    $last_rank{$p[2]} = $last_r++;
  }
}

my %names;
open(NAMES, "$namemap") or die "Can't open name map $namemap: $!";
while(<NAMES>) {
  chomp;
  my ($CAPS, $bettername) = split(/,/);
  next if(!defined($bettername));
  $names{$CAPS} = $bettername;
}
close(NAMES);

my $t = strftime "%F_%H-%M", localtime();
#print "<html><head><script src='http://themooresnc.org/sortable.js' ";
#print "type='text/javascript'/></head><body>\n";
print "<table class=\"sortable\" id=\"$t\" cellpadding=\"2\">\n";
print "<tr align=\"center\">
  <th colspan=3>&nbsp;</th>
  <th colspan=2>Record</th>
  <th colspan=2>WinPct</th>
  <th colspan=2>&nbsp;</th>
  <th colspan=2>Efficiency</th>
  <th colspan=1>&nbsp;</th>
</tr>
<tr align=\"center\">
  <th>Rank</th>
  <th>+/-</th>
  <th>Team</th>
  <th>Wins</th>
  <th>Losses</th>
  <th>Actual</th>
  <th>Expected</th>
  <th>Power</th>
  <th>SoS</th>
  <th>Offense</th>
  <th>Defense</th>
";
#print "  <th>Off Yds</th>
#  <th>Def Yds</th>
#";
print "  <th>Pace</th>
</tr>\n";
my $r = 1;
foreach my $l (sort { $b cmp $a } @data) {
#  my ($wpct, $sos, $team, $off, $def, $oyds, $dyds, $pace) = split(/,/, $l);
#  my ($wpct, $sos, $team, $off, $def, $pace) = split(/,/, $l);
  my @d = split(/,/, $l);
  my $wpct = $d[0];
  my $sos = $d[1];
  my $team = $d[2];
  my $off = $d[3];
  my $def = $d[4];
  my $wins = $d[-3];
  my $loss = $d[-2];
  my $act_wpct = 0.0;
  if ($wins or $loss) {
    $act_wpct = $wins / ($wins + $loss);
  }
  my $pace = $d[-1];
  my $teamname = $names{$team};
  if (!defined($teamname)) {
    $teamname = $team;
  }
  my $change = "--";
  my $changecolor = "black";
  my $last_r = $last_rank{$team};
  if (defined($last_r)) {
    if ($last_r < $r) {
      $changecolor = $CHANGEDOWN;
      $change = $last_r - $r;
    } elsif ($last_r > $r) {
      $changecolor = $CHANGEUP;
      if ($last_r <= $topX) {
        $change = "+" . ($last_r - $r);
      } else {
	$change = "NA";
      }
    }
  }
  printf "<tr align=\"right\">\n  <td>%03d</td><td><font color=\"%s\">%s</font></td>\n",
         $r++, $changecolor, $change;
  printf "  <td align=\"left\">%s</td>\n", $teamname;
  printf "%s", up_down_cell("%d", 1, $wins, 0);
  printf "%s", up_down_cell("%d", 0, $loss, 0);
  printf "%s", up_down_cell("%.4f", 1, $act_wpct, 0);
  printf "%s", up_down_cell("%.4f", 0, log5win($wpct, $sos), $act_wpct);
  printf "%s", up_down_cell("%.4f", 1, $wpct, $last_wpct{$team});
  printf "%s", up_down_cell("%.4f", 1, $sos, $last_sos{$team});
  printf "%s", up_down_cell("%.1f", 1, $off, $last_oeff{$team});
  printf "%s", up_down_cell("%.1f", 0, $def, $last_deff{$team});
#  printf "<td>%03.1f</td><td>%03.1f</td>", $oyds, $dyds;
  printf "<td>%3.1f</td>\n</tr>\n", $pace;
  last if ($r > $topX);
}
print "</table>\n";
#print "</body></html>\n";

sub up_down_cell($$$$) {
  my $fmt = shift;
  my $goodup = shift;
  my $currval = shift;
  my $oldval = shift;

  my $fontcolor  = "black";
  if(defined($oldval)) {
    return sprintf "  <td>$fmt</td>\n", $currval;
  } elsif ($currval > $oldval) {
    if ($goodup) {
      $fontcolor = $CHANGEUP;
    } else {
      $fontcolor = $CHANGEDOWN;
    }
  } elsif ($currval < $oldval) {
    if ($goodup) {
      $fontcolor = $CHANGEDOWN;
    } else {
      $fontcolor = $CHANGEUP;
    }
  }
  return sprintf "  <td><font color=\"%s\">$fmt</font></td>\n",
                 $fontcolor, $currval;
}

sub log5win($$) {
  my $a = shift;
  my $b = shift;
  my $num = $a - ($a * $b);
  my $den = $a + $b - (2 * $a * $b);
  return sprintf "%.3f\n", $num / $den;
}
