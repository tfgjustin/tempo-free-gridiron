#!/usr/bin/perl -w

use TempoFree;
use strict;

my $DATADIR = "data";
my $PRED_IDS = $DATADIR

sub parse_predictions($);
sub parse_odds($);
sub parse_actual();
sub parse_pt_ids($);
sub calculate_results();
sub calculate_results_onegame($$$$);

if (scalar(@ARGV) != 2) {
  print STDERR "\n";
  print STDERR "Usage: $0 <odds> <predictions>\n";
  print STDERR "\n";
  exit 1;
}

my $odds_file = shift(@ARGV);
my $pred_file = shift(@ARGV);

my %ptname2id;
parse_pt_ids(\%ptname2id);

my %id2name;
LoadIdToName(\%id2name);

my %results;
LoadResults(\%results);

my %predictions;
LoadPredictions($pred_file, 1, \%predictions);

my %pred_games;
parse_predictions();
my %odds_games;
parse_odds();
my %actual_games;
parse_actual();

calculate_results();

sub parse_predictions($) {
  my $pred_href = shift;
  foreach my $gid (keys %predictions) {
    my $aref = $predictions{$gid};
    next if (!defined($aref) or scalar(@$aref) < 6);
    my $str = undef;
    if ($$aref[2] > $$aref[4]) {
      $str = sprintf "%d,%d,%.2f\n", $$aref[1], $$aref[3], $$aref[2] - $$aref[4];
    } else {
      $str = sprintf "%d,%d,%.2f\n", $$aref[3], $$aref[1], $$aref[4] - $$aref[2];
    }
    $$pred_href{$gid} = $str;
  }
}

sub parse_odds() {
  my $openlinecol = undef;
  my $closelinecol = undef;
  open(ODDS, "$odds_file") or die "Cannot open odds $odds_file: $!";
  while(<ODDS>) {
    chomp;
    my @cols = split(/,/);
    if ($cols[0] == "Home") {
      $openlinecol = undef;
      $closelinecol = undef;
      foreach my $i (0..$#cols) {
        if ($cols[$i] == "line") {
          $closelinecol = $i;
        } elsif ($cols[$i] == "lineopen") {
          $openlinecol = $i;
        }
      }
      next;
    }
    my $t1 = $ptname2id{$cols[0]};
    my $t2 = $ptname2id{$cols[1]};
    next if (!defined($t1) or !defined($t2));
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
  foreach my $gid (keys %results) {
    my $aref = $results{$gid};
    next if (!defined($aref) or scalar(@$aref) < 11);
    my $gid = $$aref[2];
    my $hid = $$aref[5];
    my $hs  = $$aref[7];
    my $aid = $$aref[8];
    my $as  = $$aref[10];
    next if (!$hs and !$as);
    my $str = undef;
    if ($hs > $as) {
      $str = sprintf "%d,%d,%d", $hid, $aid, $hs - $as;
    } else {
      $str = sprintf "%d,%d,%d", $aid, $hid, $as - $hs;
    }
    $actual_games{$gid} = $str;
  }
  close(REAL);
}

sub calculate_results() {
  foreach my $gid (sort keys %odds_games) {
    my $odds_aref = $odds_games{$gid};
    my $actual = $actual_games{$gid};
    my $pred = $pred_games{$gid};
    next if (!defined($actual) or !defined($pred));
    foreach my $i (0..$#$odds_aref) {
      calculate_results_onegame($gid, $pred, $$odds_aref[$i], $actual);
    }
  }
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
  my ($pred_fav, $pred_under, $pred_s) = split(/,/, $pred);
  my ($odds_fav, $odds_under, $odds_s) = split(/,/, $odds);
  my ($actual_fav, $actual_under, $actual_s) = split(/,/, $actual);
  my $pick_favorite = undef;
  if ($pred_fav != $odds_fav) {
    $pick_favorite = -1;
  } elsif ($pred_s < $odds_s) {
    $pick_favorite = 0;
  } else {
    $pick_favorite = 1;
  }
  my $tag = undef;
  if ($odds_fav == $actual_fav) {
    # The favorite won.  Did we pick the favorite?
    if ($pick_favorite > 0) {
      # Yes.  Did they win by enough?
      if ($actual_s > $odds_s) {
        $tag = "FAVOR_STRAIGHTUP_BEATSPREAD";
      } elsif ($actual_s == $odds_s) {
        $tag = "FAVOR_STRAIGHTUP_TIESPREAD";
      } else {
        $tag = "FAVOR_STRAIGHTUP_LOSSSPREAD";
      }
    } elsif (!$pick_favorite) {
      # No, we picked the underdog b/c of the spread.  How does the actual
      # spread compare to the odds?
      if ($actual_s > $odds_s) {
        $tag = sprintf "UNDOG_SPREAD_LOSSSPREAD %d %d %d", $pred_s, $odds_s, $actual_s;
      } elsif ($actual_s == $odds_s) {
        $tag = sprintf "UNDOG_SPREAD_TIESPREAD %d %d %d", $pred_s, $odds_s, $actual_s;
      } else {
        $tag = sprintf "UNDOG_SPREAD_BEATSPREAD %d %d %d", $pred_s, $odds_s, $actual_s;
      }
    } else {
      # No, we picked the underdog because we thought they'd win.
      # Still, did they beat the spread?
      if ($actual_s > $odds_s) {
        $tag = sprintf "UNDOG_STRAIGHTUP_LOSSSPREAD %d %d %d", $pred_s, $odds_s, $actual_s;
      } elsif ($actual_s == $odds_s) {
        $tag = sprintf "UNDOG_STRAIGHTUP_TIESPREAD %d %d %d", $pred_s, $odds_s, $actual_s;
      } else {
        $tag = sprintf "UNDOG_STRAIGHTUP_BEATSPREAD %d %d %d", $pred_s, $odds_s, $actual_s;
      }
    }
  } else {  # The underdog won.
    if ($pick_favorite > 0) {
      $tag = "FAVOR_STRAIGHTUP_WRONG";
    } elsif (!$pick_favorite) {
      $tag = sprintf "UNDOG_SPREAD_BEATSPREAD %d %d %d", $pred_s, $odds_s, $actual_s
    } else {
      $tag = "UNDOG_STRAIGHTUP_RIGHT";
    }
  }
  print "$gid $tag\n";
}
