#!/usr/bin/perl 

use POSIX;
use TempoFree;
use strict;
use warnings;

my @BINS = qw( 0.896 0.811 0.730 0.653 0.576 );

sub get_season_url();
sub get_bin($);
sub print_game_summary($);

my $predictfile = shift(@ARGV);
my $rank = shift(@ARGV);
my $gid_list = shift(@ARGV);
if (!defined($gid_list)) {
  print STDERR "\n";
  print STDERR "Usage: $0 <predictfile> <rank> <gids>\n";
  print STDERR "\n";
  exit 1;
}

my @gids = split(/,/, $gid_list);
my $tid = shift(@gids);
my $season = shift(@gids);
my $num_games = shift(@gids);
my $overall_odds = shift(@gids);
my $pergame_odds = shift(@gids);

my %id2name;
LoadIdToName(\%id2name);

my %names;
LoadPrintableNames(\%names);

my %full_names;
LoadFullNames(\%full_names);

my %predictions;
LoadPredictions($predictfile, 1, \%predictions);

my %results;
LoadResults(\%results);

#my $tname = $full_names{$id2name{$tid}};
my $tname = $full_names{$tid};

my $url = get_season_url();

print "<table class=\"pred-table\">\n";
print "<tr class=\"tfg\">\n";
print "  <th colspan=\"10\" align=\"center\">#$rank: <a href=\"$url\">$season $tname</a></th>\n";
print "</tr>\n";
print "<tr class=\"tfg\">\n";
print "  <th>Date</th>\n";
print "  <th colspan=\"4\">Prediction</th>\n";
print "  <th>Odds</th>\n";
print "  <th colspan=\"4\">Results</th>\n";
print "</tr>\n";
foreach my $g (sort @gids) {
  print_game_summary($g);
}
print "</table>\n";
print "<br />\n";
printf "<div>1-in-%d</div>\n", int(1/$overall_odds);
print "<br />\n<br />\n";

sub get_season_url() {
  my $file = "data/$season/urls.txt";
  my $ncaa_org_id;
  if ($tid =~ /1([0-9]{3})/) {
    $ncaa_org_id = $1;
  } else {
    die "Could not extract ID from $tid";
  }
  my $pattern = sprintf "%s%s", $ncaa_org_id, "teamoff.html";
  open(URLS, "$file") or die "Could not open $file for reading: $!";
  my $url = undef;
  while(<URLS>) {
    next unless(/$pattern/);
    chomp;
    $url = $_;
    last;
  }
  close(URLS);
  die "Could not find pattern $pattern in $file" if (!defined($url));
  return $url;
}

sub print_game_summary($) {
  my $gid = shift;
  my ($year, $month, $day);
  if ($gid =~ /(\d{4})(\d{2})(\d{2})/) {
    $year = $1;
    $month = $2;
    $day = $3;
  } else {
    warn "Invalid GID: $gid";
    return;
  }
  my $pred_href = $predictions{$gid};
  my $res_href = $results{$gid};
  if (!defined($pred_href)) {
    warn "No prediction for $gid";
    return;
  }
  if (!defined($res_href)) {
    warn "No result for $gid";
    return;
  }
  my $home_class = "";
  my $away_class = "";
  my $binnum = get_bin($$pred_href[5]);
  my $odds = undef;
  if ($$pred_href[2] > $$pred_href[4]) {
    $home_class = " class=\"tfg$binnum\"";
    if ($$pred_href[1] == $tid) {
      # The home team is the team we're focusing on, and they're the favorite.
      $odds = $$pred_href[5];
    } else {
      # Home team is the favorite, but they're not the team of the streak.
      $odds = 1 - $$pred_href[5];
    }
  } else {
    $away_class = " class=\"tfg$binnum\"";
    if ($$pred_href[3] == $tid) {
      # The away team is the team we're focusing on, and they're the favorite.
      $odds = $$pred_href[5];
    } else {
      # Away team is the favorite, but they're not the team of the streak.
      $odds = 1 - $$pred_href[5];
    }
  }
  printf "<tr>\n";
  printf "  <td>%4d/%02d/%02d</td>\n", $year, $month, $day;
  printf "  <td$home_class><span class=\"teamName\">%s</span></td><td$home_class>%d</td>\n", $names{$id2name{$$pred_href[1]}}, $$pred_href[2];
  printf "  <td$away_class><span class=\"teamName\">%s</span></td><td$away_class>%d</td>\n", $names{$id2name{$$pred_href[3]}}, $$pred_href[4];
  printf "  <td>%4.1f%%</td>\n", 100 * $odds;
  printf "  <td><span class=\"teamName\">%s</span></td><td>%d</td>\n", $names{$id2name{$$pred_href[1]}},, $$res_href[7];
  printf "  <td><span class=\"teamName\">%s</span></td><td>%d</td>\n", $names{$id2name{$$pred_href[3]}},, $$res_href[10];
  printf "</tr>\n";
}

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
