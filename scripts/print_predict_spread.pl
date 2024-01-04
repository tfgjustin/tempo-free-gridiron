#!/usr/bin/perl -w

use strict;

sub parse_predictions();
sub parse_odds();
sub parse_actual();
sub calculate_results();
sub calculate_results_onegame($$$$);
sub print_result_line($$$$$$$$$$$$$$$);

if (scalar(@ARGV) != 3) {
  print STDERR "\n";
  print STDERR "Usage: $0 <predictions> <odds> <actual>\n";
  print STDERR "\n";
  exit 1;
}

my $pred_file = shift(@ARGV);
my $odds_file = shift(@ARGV);
my $real_file = shift(@ARGV);

my %pred_games;
parse_predictions();
my %odds_games;
parse_odds();
my %actual_games;
my %teams;
parse_actual();

calculate_results();

sub parse_predictions() {
  open(PRED, "$pred_file") or die "Cannot open predictions $pred_file: $!";
  while(<PRED>) {
    next unless(/PARTIAL/);
    chomp;
    @_ = split(/,/);
    my $gid = $_[2];
    my $hid = $_[4];
    my $hs  = $_[5];
    my $aid = $_[6];
    my $as  = $_[7];
    my $str = undef;
    if ($hs > $as) {
      $str = sprintf "%d,%d,%d,%d,%d", $hid, $aid, $hs, $as, $hs - $as;
    } else {
      $str = sprintf "%d,%d,%d,%d,%d", $aid, $hid, $as, $hs, $as - $hs;
    }
    $pred_games{$gid} = $str;
  }
  close(PRED);
}

sub parse_odds() {
  open(ODDS, "$odds_file") or die "Cannot open odds $odds_file: $!";
  while(<ODDS>) {
    chomp;
    my ($gid, $str) = split(/,/, $_, 2);
    my $aref = $odds_games{$gid};
    if (!defined($aref)) {
      my @arr;
      $odds_games{$gid} = $aref = \@arr;
    }
    push(@$aref, $str);
  }
  close(ODDS);
}

sub parse_actual() {
  open(REAL, "$real_file") or die "Cannot open results $real_file: $!";
  while(<REAL>) {
    next if(/^#/);
    @_ = split(/,/);
    my $gid   = $_[2];
    my $hid   = $_[5];
    my $hname = $_[6];
    my $hs    = $_[7];
    my $aid   = $_[8];
    my $aname = $_[9];
    my $as    = $_[10];
    next if (!$hs and !$as);
    my $str = undef;
    if ($hs > $as) {
      $str = sprintf "%d,%d,%d,%d,%d", $hid, $aid, $hs, $as, $hs - $as;
    } else {
      $str = sprintf "%d,%d,%d,%d,%d", $aid, $hid, $as, $hs, $as - $hs;
    }
    $actual_games{$gid} = $str;
    $teams{$hid} = $hname;
    $teams{$aid} = $aname;
  }
  close(REAL);
}

sub calculate_results() {
  print "<html><body>\n";
  print "<table border=1 cellpadding=3>\n";
  print "<tr align=\"center\"><th colspan=3>Odds</th>";
  print "<th colspan=5>Prediction</th><th colspan=5>Result</th>";
  print "<th rowspan=2 valign=\"bottom\">Verdict</th></tr>\n";
  print "<tr align=\"center\"><th>Favorite</th><th>Underdog</th>";
  print "<th>Spread</th><th colspan=2>Favorite</th>";
  print "<th colspan=2>Underdog</th><th>Spread</th>";
  print "<th>Spread</th><th colspan=2>Favorite</th>";
  print "<th colspan=2>Underdog</th></tr>";

  foreach my $gid (sort keys %odds_games) {
    my $odds_aref = $odds_games{$gid};
    my $actual = $actual_games{$gid};
    my $pred = $pred_games{$gid};
    next if (!defined($actual) or !defined($pred));
    foreach my $i (0..$#$odds_aref) {
      calculate_results_onegame($gid, $pred, $$odds_aref[$i], $actual);
    }
  }
  print "</table></body></html>\n";
}

sub calculate_results_onegame($$$$) {
  my ($gid, $pred, $odds, $actual) = @_;
  # We need to figure out which one we're betting on.
  # - If our prediction differs from the odds, then we pick the underdog
  #   + We win if the underdog wins
  #   + We also win if the underdog loses by less than the spread.
  # - If our prediction matches the odds BUT by less than the spread => underdog
  #   + We win if the underdog wins
  #   + We also win if the underdog loses by less than the spread
  # - If our prediction matches the odds AND by more than the spread => favorite
  my ($pred_fav, $pred_under, $pfav_score, $pund_score, $pred_s) = 
    split(/,/, $pred);
  my ($odds_fav, $odds_under, $odds_s) = split(/,/, $odds);
  my ($actual_fav, $actual_under, $afav_score, $aund_score, $actual_s) =
    split(/,/, $actual);
  my $pick_favorite = undef;
  if ($pred_fav != $odds_fav) {
    $pick_favorite = -1;
  } elsif ($pred_s < $odds_s) {
    $pick_favorite = 0;
  } else {
    $pick_favorite = 1;
  }
  my $tag = undef;
  my $mode = undef;
  if ($odds_fav == $actual_fav) {
    # The favorite won.  Did we pick the favorite?
    if ($pick_favorite > 0) {
      # Yes.  Did they win by enough?
      if ($actual_s > $odds_s) {
        $tag = "FAVOR_STRAIGHTUP_BEATSPREAD";
        $mode = 1;
      } elsif ($actual_s == $odds_s) {
        $tag = "FAVOR_STRAIGHTUP_TIESPREAD";
        $mode = 0;
      } else {
        $tag = "FAVOR_STRAIGHTUP_LOSSSPREAD";
        $mode = -1;
      }
    } elsif (!$pick_favorite) {
      # No, we picked the underdog b/c of the spread.  How does the actual
      # spread compare to the odds?
      if ($actual_s > $odds_s) {
        $tag = sprintf "UNDOG_SPREAD_LOSSSPREAD";
        $mode = -1;
      } elsif ($actual_s == $odds_s) {
        $tag = sprintf "UNDOG_SPREAD_TIESPREAD";
        $mode = 0;
      } else {
        $tag = sprintf "UNDOG_SPREAD_BEATSPREAD";
        $mode = 1;
      }
    } else {
      # No, we picked the underdog because we thought they'd win.
      # Still, did they beat the spread?
      if ($actual_s > $odds_s) {
        $tag = sprintf "UNDOG_STRAIGHTUP_LOSSSPREAD";
        $mode = -1;
      } elsif ($actual_s == $odds_s) {
        $tag = sprintf "UNDOG_STRAIGHTUP_TIESPREAD";
        $mode = 0;
      } else {
        $tag = sprintf "UNDOG_STRAIGHTUP_BEATSPREAD";
        $mode = 1;
      }
    }
  } else {  # The underdog won.
    if ($pick_favorite > 0) {
      $tag = "FAVOR_STRAIGHTUP_WRONG";
      $mode = -1;
    } elsif ($pick_favorite == 0) {
      $tag = "UNDOG_SPREAD_BEATSPREAD";
      $mode = 1;
    } else {
      $tag = "UNDOG_STRAIGHTUP_RIGHT";
      $mode = 1;
    }
  }
  print_result_line($odds_fav, $odds_under, $odds_s, $pred_fav,
                    $pred_under, $pfav_score, $pund_score, $pred_s,
                    $actual_fav, $actual_under, $afav_score, $aund_score,
                    $actual_s, $tag, $mode);
}

sub print_result_line($$$$$$$$$$$$$$$) {
 my ($odds_fav, $odds_under, $odds_s, $pred_fav, $pred_under, $pfav_score,
     $pund_score, $pred_s, $actual_fav, $actual_under, $afav_score,
     $aund_score, $actual_s, $tag, $mode) = @_;
 print "<tr align=\"left\">\n";
 print "  <td>$teams{$odds_fav}</td>\n";
 print "  <td>$teams{$odds_under}</td>\n";
 printf "  <td align=\"right\">%.1f</td>\n", $odds_s;
 if ($odds_fav == $pred_fav) {
   print "  <td>$teams{$pred_fav}</td>\n";
   print "  <td>$pfav_score</td>\n";
   print "  <td>$teams{$pred_under}</td>\n";
   print "  <td>$pund_score</td>\n";
   printf "  <td>%.1f</td>\n", $pred_s;
 } else {
   print "  <td>$teams{$pred_under}</td>\n";
   print "  <td>$pund_score</td>\n";
   print "  <td>$teams{$pred_fav}</td>\n";
   print "  <td>$pfav_score</td>\n";
   printf "  <td>%.1f</td>\n", -$pred_s;
 }
 if ($odds_fav == $actual_fav) {
   print "  <td>$teams{$actual_fav}</td>\n";
   print "  <td>$afav_score</td>\n";
   print "  <td>$teams{$actual_under}</td>\n";
   print "  <td>$aund_score</td>\n";
   printf "  <td>%.1f</td>\n", $actual_s;
 } else {
   print "  <td>$teams{$actual_under}</td>\n";
   print "  <td>$aund_score</td>\n";
   print "  <td>$teams{$actual_fav}</td>\n";
   print "  <td>$afav_score</td>\n";
   printf "  <td>%.1f</td>\n", -$actual_s;
 }
 my $c = "black";
 if ($mode < 0) {
   $c = "red";
 } elsif ($mode > 0) {
   $c = "green";
 }
 printf "  <td><font color=\"$c\">$tag</font></td>\n";
 print "</tr>\n";
}
