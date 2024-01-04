#!/usr/bin/perl -w

use TempoFree;
use strict;

sub prune_predictions($);
sub win_pct_to_bin($);
sub get_games($$$$);
sub select_games($$$$$);
sub load_game_descriptions($);

my $BASEDIR = ".";
my $SUMMARY = "$BASEDIR/input/summaries.csv";

my $PRETTYPRINT = "$BASEDIR/scripts/prettyprint.pl";

my @WINPCT = ( 0.583 , 0.652 , 0.731 , 0.780 , 0.873 );

my $blacklist_file = shift(@ARGV);
if (!defined($blacklist_file) or !@ARGV or ((scalar(@ARGV) % 2) == 0)) {
  print STDERR "\n";
  print STDERR "Usage: $0 <blacklist> [small|large] <start_date> <end_date> <predict0> <rank0> <predict1> <rank1>\n";
  print STDERR "\n";
  exit 1;
}
my %blacklist_teams;
open(BLACKLIST, "$blacklist_file") or die "Can't open blacklist file $blacklist_file: $!";
while (<BLACKLIST>) {
  chomp;
  $blacklist_teams{$_} = 1;
}
close(BLACKLIST);

my @SMALLBINS = ( 2 , 3 ,  7 );
my @LARGEBINS = ( 3 , 2 , 10 );

my $num_picks = 0;
my $bin_aref = undef;
my $PICK_SIZE = lc shift(@ARGV);
if ($PICK_SIZE eq "small") {
  $num_picks = 12;
  $bin_aref = \@SMALLBINS;
} elsif ($PICK_SIZE eq "large") {
  $num_picks = 15;
  $bin_aref = \@LARGEBINS;
} else {
  print STDERR "Invalid bin size: $PICK_SIZE\n";
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

my %id2name;
my %id2conf;
my %confteams;
my %is_bcs;
LoadConferences(\%id2name, \%id2conf, \%confteams, \%is_bcs);

my @all_preds;
my @all_wpcts;
my %gids;

foreach my $i (0..int($#ARGV / 2)) {
  my $predictfile = $ARGV[$i * 2 + 0];
  my $rankfile    = $ARGV[$i * 2 + 1];

  # First do the rankings
  my %wpcts;
  my %rankings;
  LoadCurrentRankings($rankfile, \%id2conf, \%wpcts, \%rankings);
  push(@all_wpcts, \%wpcts);

  my %predictions;
  LoadPredictions($predictfile, 0, \%predictions);
  prune_predictions(\%predictions);
  foreach my $gid (keys %predictions) { $gids{$gid} = 1; }
  push(@all_preds, \%predictions);
}

my %gugs;
CalculateGugs($all_preds[0], $all_preds[1], $all_wpcts[0], $all_wpcts[1], \%gugs);

my %names;
LoadPrintableNames(\%names);

# [is_bcs][bin][gid] = quality
my %games;
get_games(\%gids, \@all_preds, \@all_wpcts, \%games);

my @selected;
select_games(\%games, \%gugs, $bin_aref, $num_picks, \@selected);

my %descriptions;
load_game_descriptions(\%descriptions);

foreach my $s_gid (@selected) {
  my $d = $descriptions{$s_gid};
  if (!defined($d)) {
    warn "No description for game $s_gid";
    next;
  }
  print "$s_gid $d\n";
}

sub load_game_descriptions($) {
  my $games_href = shift;
  open(SUMMARY, "$SUMMARY") or die "Cannot open summary $SUMMARY: $!";
  while(<SUMMARY>) {
    chomp;
    next unless(/^[0-9]+,/);
    @_ = split(/,/);
    my $gid = $_[2];
    my $home = $_[6];
    my $away = $_[9];
#    print STDERR "\$_[3] \"$_[3]\" home \"$home\" away \"$away\"\n";
    my $at_vs = ($_[3] eq $home) ? "at" : "vs";
    my $h = $names{$home};
    my $a = $names{$away};
    $h = $home if (!defined($h));
    $a = $away if (!defined($a));
  
#    $home =~ s/\s/_/g;
#    $away =~ s/\s/_/g;
    $$games_href{$gid} = sprintf "%-30s %s %-30s", $a, $at_vs, $h;
  }
  close(SUMMARY);
}

sub select_games($$$$$) {
  my $games_href = shift;
  my $gugs_href = shift;
  my $bin_aref = shift;
  my $num_picks = shift;
  my $selected_aref = shift;
  my $per_winbin = $num_picks / scalar(@WINPCT);
  my %per_winbin_count;
#  print STDERR "B W GID\n";
  # For each of the 3 BCS "bins" ...
  my $carry = 0;
  my $num_chosen = 0;
  my %selected;
  my $round = 0;
  while (1) {
    $num_chosen = 0;
    for (my $bcs_bin = $#$bin_aref; $bcs_bin >= 0; --$bcs_bin) {
#    foreach my $bcs_bin (0..$#$bin_aref) {
      next if (!defined($$games_href{$bcs_bin}));
      my $bin_count = 0;
#      print STDERR "bcs_bin = $bcs_bin\n";
      # ... go through from most competitive to least competitive ...
      foreach my $win_bin (0..$#WINPCT) {
        my $curr_winbin = $per_winbin_count{$win_bin};
        next if (defined($curr_winbin) and ($curr_winbin >= $per_winbin) and !$round);
        my $href = $$games_href{$bcs_bin}{$win_bin};
        next unless (defined($href));
#        my @gid_arr = sort { $$href{$b} <=> $$href{$a} } keys %$href;
        my @gid_arr = sort { $$gugs_href{$b}[3] <=> $$gugs_href{$a}[3] } keys %$href;
        foreach my $i (0..$#gid_arr) {
          next if ($selected{$gid_arr[$i]});
          # Weed out ACC conference games.
#          if ($gid_arr[$i] =~ /\d{8}-(\d{4})-(\d{4})/) {
#            next if ($id2conf{$1} eq "ACC" and $id2conf{$2} eq "ACC");
#          }
          $per_winbin_count{$win_bin}++;
          ++$bin_count;
          push(@$selected_aref, $gid_arr[$i]);
          $selected{$gid_arr[$i]} = 1;
          ++$num_chosen;
#          printf STDERR "%d %d %s %5.3f %2d %2d\n", $bcs_bin, $win_bin, $gid_arr[$i],
#                 $$href{$gid_arr[$i]}, $per_winbin_count{$win_bin}, $bin_count;
          return if (scalar(keys %selected) >= $num_picks);
          last if ($per_winbin_count{$win_bin} >= $per_winbin and !$round);
          last if ($bin_count >= ($$bin_aref[$bcs_bin] + $carry) and !$round);
        }
        last if ($bin_count >= ($$bin_aref[$bcs_bin] + $carry));
      }
      $carry = ($$bin_aref[$bcs_bin] + $carry) - $bin_count;
#      print STDERR "Carry,$bcs_bin,$carry\n";
    }
    last if (!$num_chosen);
    ++$round;
  }
  if (scalar(keys %selected) < $num_picks) {
    # We couldn't get what we needed from what was available. Try less
    # competitive and ACC games.
    warn "Drastic measures.";
    while (1) {
      $num_chosen = 0;
      for (my $bcs_bin = $#$bin_aref; $bcs_bin >= 0; --$bcs_bin) {
        next if (!defined($$games_href{$bcs_bin}));
        my $bin_count = 0;
#        print STDERR "bcs_bin = $bcs_bin\n";
        # ... go through from most competitive to least competitive ...
        my $win_bin = -1;
        my $href = $$games_href{$bcs_bin}{$win_bin};
        next unless (defined($href));
#        my @gid_arr = sort { $$href{$b} <=> $$href{$a} } keys %$href;
        my @gid_arr = sort { $$gugs_href{$b}[3] <=> $$gugs_href{$a}[3] } keys %$href;
        foreach my $i (0..$#gid_arr) {
          next if ($selected{$gid_arr[$i]});
          $per_winbin_count{$win_bin}++;
          ++$bin_count;
          push(@$selected_aref, $gid_arr[$i]);
          $selected{$gid_arr[$i]} = 1;
          ++$num_chosen;
#          printf STDERR "%d %d %s %5.3f %2d %2d\n", $bcs_bin, $win_bin, $gid_arr[$i],
#                 $$href{$gid_arr[$i]}, $per_winbin_count{$win_bin}, $bin_count;
          return if (scalar(keys %selected) >= $num_picks);
          last if ($bin_count >= ($$bin_aref[$bcs_bin] + $carry) and !$round);
        }
        last if ($bin_count >= ($$bin_aref[$bcs_bin] + $carry));
        $carry = ($$bin_aref[$bcs_bin] + $carry) - $bin_count;
#        print STDERR "Carry,$bcs_bin,$carry\n";
      }
      last if (!$num_chosen);
      ++$round;
    }
  }
}

sub prune_predictions($) {
  my $pred_href = shift;
  my %remove;
  foreach my $gid (keys %$pred_href) {
    my ($d, $t1, $t2) = split(/-/, $gid);
    if ($d < $start_date or $d > $end_date) {
      $remove{$gid} = 1;
    }
  }
  foreach my $gid (keys %remove) {
    delete $$pred_href{$gid};
  }
}

sub win_pct_to_bin($) {
  my $pct = shift;
  foreach my $i (0..$#WINPCT) {
    if ($pct < $WINPCT[$i]) {
      return $i;
    }
  }
  return -1;
}

sub get_games($$$$) {
  my $gids_href = shift;
  my $all_preds_aref = shift;
  my $all_wpcts_aref = shift;
  my $games_href = shift;
  my $num_sys = scalar(@$all_preds_aref);
  foreach my $gid (sort { $a cmp $b } keys %$gids_href) {
    my $h_team = undef;
    my $a_team = undef;
    my $homeodds = 0;
    my $wpct_sum = 0;
    if ($gid =~ /\d{8}-(\d{4})-(\d{4})/) {
      $h_team = $1;
      $a_team = $2;
    } else {
      warn "Invalid GID: $gid";
      next;
    }
    if (defined($blacklist_teams{$h_team})) {
#      warn "Team $h_team is blacklisted";
      next;
    }
    if (defined($blacklist_teams{$a_team})) {
#      warn "Team $a_team is blacklisted";
      next;
    }
    foreach my $i (0..$#$all_preds_aref) {
      my $pred_href = $$all_preds_aref[$i];
      my $wpct_href = $$all_wpcts_aref[$i];
      my $p_aref = $$pred_href{$gid};
      next if (!defined($p_aref));
      my $hometeam = $$p_aref[1];
      my $hs = $$p_aref[2];
      my $awayteam = $$p_aref[3];
      my $as = $$p_aref[4];
      my $favewin = $$p_aref[5];
      if ($hs > $as) {
        $homeodds += $favewin;
      } else {
        $homeodds += (1 - $favewin);
      }
      my $score = $hs + $as;
      $hometeam =~ s/_/\ /g;
      $awayteam =~ s/_/\ /g;
#      print STDERR "HT $hometeam AT $awayteam\n";
      my $home_wpct = $$wpct_href{$hometeam};
      my $away_wpct = $$wpct_href{$awayteam};
      if (!defined($home_wpct)) { $home_wpct = 0.0; }
      if (!defined($away_wpct)) { $away_wpct = 0.0; }
      $wpct_sum += ($home_wpct + $away_wpct);
    }
#    printf STDERR "Pre = (%5.3f , %5.3f) / %d\n", $homeodds, $wpct_sum, $num_sys;
    $homeodds /= $num_sys;
    if ($homeodds < 0.500) {
      $homeodds = 1 - $homeodds;
    }
    $wpct_sum /= ($num_sys * 2);
    my $binnum = win_pct_to_bin($homeodds);
#    next if ($binnum < 0);
#    printf STDERR "Post = (%5.3f , %5.3f) Bin = %1d\n", $homeodds, $wpct_sum, $binnum;
    my $h_bcs = $is_bcs{$h_team};
    $h_bcs = 0 if (!defined($h_bcs));
    my $a_bcs = $is_bcs{$a_team};
    $a_bcs = 0 if (!defined($a_bcs));
    my $bcs_sum = $h_bcs + $a_bcs;
    $$games_href{$bcs_sum}{$binnum}{$gid} = $wpct_sum;
#    printf STDERR "SUMMARY,$gid,$bcs_sum,$binnum,%5.3f,%.3f\n", $homeodds,$wpct_sum;
  }
}
