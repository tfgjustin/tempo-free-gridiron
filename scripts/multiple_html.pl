#!/usr/bin/perl -w

use TempoFree;
use strict;

sub load_rankings($$);
sub load_games($$);
sub get_bin($);
sub print_prediction($$$);
sub usage($);

my $BASEDIR = ".";
my $PRETTYPRINT = "$BASEDIR/scripts/prettyprint.pl";
my @BINS = qw( 0.896 0.811 0.730 0.653 0.576 );

if (scalar(@ARGV) != 9) {
  printf STDERR "Only had %d parameters instead of 8.", scalar(@ARGV);
  usage($0);
}

my $start_date = shift(@ARGV);
my $end_date = shift(@ARGV);
if (!($start_date =~ /20[01][0-9][01][0-9][0-3][0-9]/)) {
  print STDERR "Invalid start date: $start_date\n";
  usage($0);
}
if (!($end_date =~ /20[01][0-9][01][0-9][0-3][0-9]/)) {
  print STDERR "Invalid end date: $end_date\n";
  usage($0);
}
my $post_time = shift(@ARGV);
my $tfg_predict_file = shift(@ARGV);
my $tfg_ranking_file = shift(@ARGV);
my $rba_predict_file = shift(@ARGV);
my $rba_ranking_file = shift(@ARGV);

my $post_title = shift(@ARGV);
my $post_tags = shift(@ARGV);

usage($0) if (!defined($rba_ranking_file));

my %tfg_ranks;
load_rankings($tfg_ranking_file, \%tfg_ranks);
my %tfg_games;
load_games($tfg_predict_file, \%tfg_games);
my %rba_ranks;
load_rankings($rba_ranking_file, \%rba_ranks);
my %rba_games;
load_games($rba_predict_file, \%rba_games);

my %gids;
foreach my $gid (keys %tfg_games) {
  $gids{$gid} = 1;
}
foreach my $gid (keys %rba_games) {
  $gids{$gid} = 1;
}

exit 0 if (!scalar(keys %gids));

my %id2name;
my %id2conf;
LoadConferences(\%id2name, \%id2conf, undef ,undef);
my %name2id;
LoadNameToId(\%name2id);

my %names;
LoadPrintableNames(\%names);

print "<link rel=\"stylesheet\" type=\"text/css\" href=\"ncaa.css\" />\n";
print "<!-- POSTTITLE|$post_title| -->\n";
print "<!-- POSTTAGS|$post_tags| -->\n";
print "<!-- POSTTIME|$post_time| -->\n";

sub sort_games {
  my ($home1, $home2) = (undef, undef);
  if ($a =~ /\d{8}-(\d{4})-\d{4}/) {
    $home1 = $1;
  }
  if ($b =~ /\d{8}-(\d{4})-\d{4}/) {
    $home2 = $1;
  }
  my $h1name = "";
  $h1name = $id2name{$home1} if defined($home1);
  my $h2name = "";
  $h2name = $id2name{$home2} if defined($home2);
  return $h1name cmp $h2name;
}

my $num_games = 0;
my @games = sort sort_games keys %gids;
foreach my $gid (@games) {
  print "<table border=0 cellpadding=0 cellspacing=0>\n";
  print "<tr><td>\n";
  my $l = $tfg_games{$gid};
  if (defined($l)) {
    print_prediction($l, \%tfg_ranks, "tfg");
  }
  print "</td><td>\n";
  $l = $rba_games{$gid};
  if (defined($l)) {
    print_prediction($l, \%rba_ranks, "rba");
  }
  print "</td></tr>\n";
  print "</table>\n<br />\n";
  ++$num_games;
}
print "</table>\n<br/>\n";
print "<!-- Table contains $num_games games -->\n";
print "<table class=\"pred-key\">\n";
print "<tr><th colspan=8>Key</th></tr>\n";
print "<tr>\n";
print "  <td rowspan=2 align=\"center\">Close<br>game</td>\n";
foreach my $i (1..6) {
  print "  <td class=\"tfg$i\">&nbsp;&nbsp;&nbsp;</td>\n";
}
print "  <td rowspan=2 align=\"center\">Certain<br>victory</td>\n";
print "</tr>\n<tr>\n";
foreach my $i (1..6) {
  print "  <td class=\"rba$i\">&nbsp;&nbsp;&nbsp;</td>\n";
}
print "</tr>\n";
print "</table>\n";
print "<br />\n<br />\n";
print "<i>Follow us on Twitter at "
      . "<a href=\"http://twitter.com/TFGridiron\">\@TFGridiron</a> "
      . "and <a href=\"http://twitter.com/TFGLiveOdds\">\@TFGLiveOdds</a>.</i>\n";

sub load_rankings($$) {
  my $rankfile = shift;
  my $rankhref = shift;
  my %wpct;
  LoadCurrentRankings($rankfile, \%id2conf, \%wpct, $rankhref);
}

sub load_games($$) {
  my $predict_file = shift;
  my $predict_href = shift;
  # Now fetch and prettify the predictions
  my $cmd = "$PRETTYPRINT $predict_file 1 | tr '[a-z]' '[A-Z]'";
  open(CMD, "$cmd|") or do {
    warn "Cannot execute \"$cmd\": $!";
    next;
  };
  my %predictions;
  my $cnt = 0;
  while(<CMD>) {
    chomp;
    @_ = split;
    my $gid = $_[0];
    my $date = substr($gid, 0, 8);
    ++$cnt;
    next if (($date < $start_date) or ($date > $end_date));
    $$predict_href{$gid} = $_;
  }
  close(CMD);
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

sub print_prediction($$$) {
  my $pred_line = shift;
  my $rank_href = shift;
  my $pred_sys = shift;
  @_ = split(/\s+/, $pred_line);
  if (scalar(@_) < 6) {
#    print "  <td colspan=6>&nbsp;</td>\n";
    return;
  }
  my $home_id = $name2id{$_[1]};
  my $away_id = $name2id{$_[3]};
  my $home_rank = $$rank_href{$home_id};
  my $away_rank = $$rank_href{$away_id};
  if (defined($home_rank)) {
    $home_rank = sprintf "%3d", $home_rank;
  } else {
    $home_rank = "NA";
  }
  $home_rank =~ s/\ /&nbsp;/g;
  if (defined($away_rank)) {
    $away_rank = sprintf "%3d", $away_rank;
  } else {
    $away_rank = "NA";
  }
  $away_rank =~ s/\ /&nbsp;/g;
  my $hometeam = $id2name{$home_id};
  if (defined($names{$hometeam})) {
    $hometeam = $names{$hometeam};
  }
  my $awayteam = $id2name{$away_id};
  if (defined($names{$awayteam})) {
    $awayteam = $names{$awayteam};
  }

  my $bin = get_bin($_[5]);
  my $base_class = sprintf "%s%d", $pred_sys, $bin;

  my ($hc, $ac);
  if ($_[2] > $_[4]) {
    $hc = sprintf " class=\"%s%d\"", $pred_sys, $bin;
    $ac = "";
  } else {
    $hc = "";
    $ac = sprintf " class=\"%s%d\"", $pred_sys, $bin;
  }
  print  "<table class=\"pred-table\">\n";
  printf "<tr>\n  <td$hc><span class=\"rank\">%s</span></td>"
         . "<td$hc width=\"175\"><span class=\"teamName\">%s</span></td>"
         . "<td$hc><span class=\"score\">%d</span></td>\n</tr>\n",
         $home_rank, $hometeam, $_[2];
  printf "<tr>\n  <td$ac><span class=\"rank\">%s</span></td>"
         . "<td$ac><span class=\"teamName\">%s</span></td>"
         . "<td$ac><span class=\"score\">%d</span></td>\n</tr>\n",
         $away_rank, $awayteam, $_[4];
  printf "</table>\n";
}

sub usage($) {
  my $p = shift;
  my @parts = split(/\//, $p);
  $p = pop(@parts);
  print STDERR "\n";
  print STDERR "Usage: $p <minDate> <maxDate> <tfgPredict> <tfgRank> <rbaPredict> <rbaRank>\n";
  print STDERR "\n";
  exit 1;
}
