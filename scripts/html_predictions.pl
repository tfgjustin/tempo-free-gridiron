#!/usr/bin/perl -w

use TempoFree;
use strict;

sub get_bin($);

if (scalar(@ARGV) != 1) {
  print STDERR "\n";
  print STDERR "Usage: $0 <rankfile>\n";
  print STDERR "\n";
  exit 1;
}

my $rankfile = shift(@ARGV);

my @bins = qw( 0.896 0.811 0.730 0.653 0.576 );

sub get_bin($) {
  my $wpct = shift;
  return 1 if (!defined($wpct));
  return 1 if ($wpct < 0.5);
  return 6 if ($wpct > 1.0);
  foreach my $i (0..$#BINS) {
    if ($wpct > $BINS[$i]) {
      return 6 - $i;
    }
  }
  return 1;
}

my %omap;
my %dmap;
my %wpcts;
my $max_week = 0;
open(RANK, "$rankfile") or die "Can't open rankings: $rankfile: $!";
while(<RANK>) {
  next unless (/RANKING/);
  chomp;
  @_ = split(/,/);
  if (scalar(@_) < 6) {
    warn "Invalid line: \"$_\"\n";
    next;
  }
  my $week_num = $_[1];
  $max_week = $week_num if ($week_num > $max_week);
  my $wpct = $_[3];
  my $team_id = $_[2];
  my $oeff = $_[5];
  my $deff = 35 - $_[6];
  $omap{$week_num}{$team_id} = $oeff;
  $dmap{$week_num}{$team_id} = $deff;
  $wpcts{$week_num}{$team_id} = $wpct;
}
close(RANK);

my $r = 1;
my %rankings;
my $max_week_wpct_href = $wpcts{$max_week};
foreach my $t_id (sort { $wpcts{$max_week}{$b} <=> $wpcts{$max_week}{$a} } keys %$max_week_wpct_href) {
  $rankings{$t_id} = $r++;
}

my %id2name;
LoadIdToName(\%id2name);

my %names;
LoadPrintableNames(\%names);

print "<table cellpadding=\"3\" cellspacing=\"0\">
<tr align=\"center\">
  <th colspan=2>Home</th>
  <th colspan=2>Visitors</th>
  <th>Odds</th> 
</tr>\n";
while(<STDIN>) {
  chomp;
  @_ = split;
  my $home_id = $_[1];
  my $away_id = $_[3];
  my $hometeam = $id2name{$home_id};
  my $awayteam = $id2name{$away_id};
  if (!defined($hometeam)) {
    warn "Could not find name for team $home_id";
    next;
  }
  if (!defined($awayteam)) {
    warn "Could not find name for team $away_id";
    next;
  }
  my $home_rank = $rankings{$home_id};
  my $away_rank = $rankings{$away_id};
  my $home_oeff = $omap{$home_id};
  my $home_deff = $dmap{$home_id};
  my $home_wpct = $wpcts{$home_id};
  my $away_oeff = $omap{$away_id};
  my $away_deff = $dmap{$away_id};
  my $away_wpct = $wpcts{$away_id};
  $home_rank = "NA" if (!defined($home_rank));
  $home_oeff = -100 if (!defined($home_oeff));
  $home_deff = -100 if (!defined($home_deff));
  $home_wpct = -100 if (!defined($home_wpct));

  $away_rank = "NA" if (!defined($away_rank));
  $away_oeff = -100 if (!defined($away_oeff));
  $away_deff = -100 if (!defined($away_deff));
  $away_wpct = -100 if (!defined($away_wpct));
  $hometeam =~ s/_/\ /g;
  $awayteam =~ s/_/\ /g;
  if (defined($names{$hometeam})) {
    $hometeam = $names{$hometeam};
  }
  if (defined($names{$awayteam})) {
    $awayteam = $names{$awayteam};
  }

  my ($hc, $ac);
  if ($_[2] > $_[4]) {
    $hc = $favorite_color;
    $ac = "white";
  } else {
    $hc = "white";
    $ac = $favorite_color;
  }
  printf "  <!-- %20s %20s %6.1f %5.1f %5.1f %4.3f %.3f -->\n", $_[1], $_[3],
         $home_oeff + $away_deff, $away_oeff + $home_deff,
         $home_oeff + $away_oeff, $home_wpct + $away_wpct, 1 - $_[5];

  printf "<tr>\n  <td bgcolor=\"$hc\">(%s) %s</td>"
         . "<td bgcolor=\"$hc\" align=\"right\">%d</td>\n",
         $home_rank, $hometeam, $_[2];
  printf "  <td bgcolor=\"$ac\">(%s) %s</td>"
         . "<td bgcolor=\"$ac\" align=\"right\">%d</td>\n",
         $away_rank, $awayteam, $_[4];
  printf "  <td align=\"right\">%.1f</td>\n</tr>\n\n", $_[5] * 100;
}
print "</table>\n";
