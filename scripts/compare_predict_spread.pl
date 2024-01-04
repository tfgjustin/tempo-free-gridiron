#!/usr/bin/perl -w

use strict;

my $PICK_FAVORITE_COVER = 1;
my $PICK_UNDERDOG_SPREAD = 0;
my $PICK_UNDERDOG_STRAIGHT = -1;

sub parse_predictions();
sub parse_odds();
sub parse_actual();
sub calculate_results();
sub calculate_results_onegame($$$$);

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
#printf "Found %d predictions\n", scalar(keys %pred_games);
my %odds_games;
parse_odds();
#printf "Found %d odds\n", scalar(keys %odds_games);
my %actual_games;
parse_actual();
#printf "Found %d games\n", scalar(keys %actual_games);

calculate_results();

sub parse_predictions() {
  open(PRED, "$pred_file") or die "Cannot open predictions $pred_file: $!";
  while(<PRED>) {
    next unless(/PREDICT,PARTIAL/);
    chomp;
    @_ = split(/,/);
    my $gid = $_[2];
    my $hid = $_[4];
    my $hs  = $_[5];
    my $aid = $_[6];
    my $as  = $_[7];
    my $o = $_[8];
    if ($o < 500) { $o = 1000 - $o; };
    my $str = undef;
    if ($hs > $as) {
      $str = sprintf "%d,%d,%d,%d", $hid, $aid, $hs - $as, $o;
    } else {
      $str = sprintf "%d,%d,%d,%d", $aid, $hid, $as - $hs, $o;
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
    my $gid = $_[2];
    my $hid = $_[5];
    my $hs  = $_[7];
    my $aid = $_[8];
    my $as  = $_[10];
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
#    print "m\n";
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
  my ($pred_fav, $pred_under, $pred_s, $pred_o) = split(/,/, $pred);
  my ($odds_fav, $odds_under, $odds_s) = split(/,/, $odds);
  my ($actual_fav, $actual_under, $actual_s) = split(/,/, $actual);
  my $pick_favorite = undef;
  if ($pred_fav != $odds_fav) {
    $pick_favorite = $PICK_UNDERDOG_STRAIGHT;
  } elsif ($pred_s < $odds_s) {
    $pick_favorite = $PICK_UNDERDOG_SPREAD;
  } else {
    $pick_favorite = $PICK_FAVORITE_COVER;
  }
  my $tag = undef;
  if ($odds_fav == $actual_fav) {
    # The favorite won.  Did we pick the favorite?
    if ($pick_favorite == $PICK_FAVORITE_COVER) {
      # Yes.  Did they win by enough?
      if ($actual_s > $odds_s) {
        $tag = "FAVOR_COVERSPREAD_BEATSPREAD";
      } elsif ($actual_s == $odds_s) {
        $tag = "FAVOR_COVERSPREAD_TIESPREAD";
      } else {
        $tag = "FAVOR_COVERSPREAD_LOSSSPREAD";
      }
    } elsif ($pick_favorite == $PICK_UNDERDOG_SPREAD) {
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
        $tag = sprintf "UNDOG_STRAIGHTUP_LOSSSPREAD %d %d %d %d", $pred_s, $odds_s, $actual_s, $pred_o;
      } elsif ($actual_s == $odds_s) {
        $tag = sprintf "UNDOG_STRAIGHTUP_TIESPREAD %d %d %d %d", $pred_s, $odds_s, $actual_s, $pred_o;
      } else {
        $tag = sprintf "UNDOG_STRAIGHTUP_BEATSPREAD %d %d %d %d", $pred_s, $odds_s, $actual_s, $pred_o;
      }
    }
  } else {  # The underdog won.
    if ($pick_favorite == $PICK_FAVORITE_COVER) {
      $tag = "FAVOR_COVERSPREAD_WRONG";
    } elsif ($pick_favorite == $PICK_UNDERDOG_SPREAD) {
      $tag = sprintf "UNDOG_SPREAD_BEATSPREAD %d %d %d", $pred_s, $odds_s, $actual_s
    } else {
      $tag = sprintf "UNDOG_STRAIGHTUP_RIGHT %d", $pred_o;
    }
  }
  print "$gid $tag\n";
}
