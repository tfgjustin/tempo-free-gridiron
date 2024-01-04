#!/usr/bin/perl 
#===============================================================================
#
#         FILE: playoff_odds.pl
#
#        USAGE: ./playoff_odds.pl  
#
#  DESCRIPTION: Figure out which teams are most likely to get to the playoffs.
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 10/25/2015 09:11:11 AM
#     REVISION: ---
#===============================================================================

use Array::Utils qw(:all);
use Data::Dumper;
use TempoFree;
use strict;
use threads;
use threads::shared;
use warnings;

my $NUM_TOP = 10;
my $FCS_ID = 9999;
my $NOTRE_DAME_ID = 1513;
my $NUM_SIMS = 1000000;
my $NUM_THREADS = 4;
my $SIMS_PER_THREAD = int($NUM_SIMS / $NUM_THREADS);

sub RunOneThread($$$);
sub OneFullSim($$);
sub LoadFcsResults($$);
sub LoadNonConfGames($$$);
sub FindNLossTeams($$$);
sub Aggregate($$);
sub SelectByConference($$$$);
sub SimulateSeason($$$$$);
sub MakePerTeamGameResults($$);
sub GetAllConfTeams($$$);
sub ConferencesWithTitles($$);
sub HasTopTwoTitle($);
sub SortTeamsByPower($$$);
sub PrintResults($$$$);
sub GetWinLoss($$$$$$$);
sub Predict($$);
sub usage($);
sub locklog($);

# TODO: Handle Notre Dame properly
my %POWER5 = map { $_ => 1 } ("ACC", "Big Ten", "Big XII", "Pac-12", "SEC" );
my %NONPOWER5 = map { $_ => 1 } ( "Conference-USA", "Mid-American", "American Athletic",
                                  "Mountain West", "Sun Belt", "Independents"  );

my $rankfile = shift(@ARGV);
my $predfile = shift(@ARGV);
my $nonconffile = shift(@ARGV);
my $fcslossfile = shift(@ARGV);
my $date = shift(@ARGV);
my $outfile = shift(@ARGV);
if (!defined($outfile)) {
  usage($0);
}

if (! -f $rankfile or ! -f $predfile or ! -f $fcslossfile or ! -f $nonconffile) {
  usage($0);
}

$date =~ s/-//g;
my $SEASON = $CURRENT_SEASON;
if (defined($date)) {
  $SEASON = DateToSeason($date);
}

srand(0);

# Preference for who will get into the playoffs:
# 1) Undefeated Power5 teams
# 2) 1-loss Power5 conference champs
# 3) 2-loss Power5 conference champs
# 4) 1-loss Power5 conference title game losers
# 5) 2-loss Power5 conference title game losers
# 6) Undefeated non-Power5 teams

# Steps
# 0) Load teams and conferences
my %id2name;
my %teamconfs;
my %confteams;
my %isbcs;
LoadConferencesForYear($SEASON, \%id2name, \%teamconfs, \%confteams, \%isbcs);

my @titles;
ConferencesWithTitles(\%confteams, \@titles);

my %fcslosses;
LoadFcsResults($fcslossfile, \%fcslosses);

my %nonconfgames;
LoadNonConfGames($nonconffile, $SEASON, \%nonconfgames);

# 1) Load results
my %results;
LoadResultsForSeasonBeforeDate($SEASON, $date, \%results);

# 2) Load predictions and rankings
my %predictions;
LoadPredictionsOddsMode($predfile, 0, 1, \%predictions);

my $LOGGING : shared = 1;
my @SEASONS : shared = ();
open(OUTFILE, ">$outfile") or die "Can't open output file $outfile: $!";
select OUTFILE;

# All games which will get played
my @remain_games = keys %predictions;
# Title games
foreach my $cwt (sort @titles) {
  my $g = sprintf "%d1230-Title-%s", $SEASON, $cwt;
  push(@remain_games, $g);
}
# Top ranking
foreach my $bp (1..$NUM_TOP) {
  my $g = sprintf "%d0000-Rank%02d", $SEASON, $bp;
  push(@remain_games, $g);
}
# Conference champs
foreach my $confname (sort keys %confteams) {
  next if ($confname eq "FCS" or !length($confname));
  my $g = sprintf "%d1231-Champs-%s", $SEASON, $confname;
  push(@remain_games, $g);
  # TODO: Per-team wins
  my $conf_href = $confteams{$confname};
  foreach my $subconf_href (values %$conf_href) {
    # Subconference
    foreach my $team_id (keys %$subconf_href) {
      # ~> ${SEASON}1234-Wins-${TEAMID}
      my $g = sprintf "%d1234-Wins-%d", $SEASON, $team_id;
      push(@remain_games, $g);
      $g = sprintf "%d1234-ConfWins-%d", $SEASON, $team_id;
      push(@remain_games, $g);
    }
  }
}
print "RemainGames,Iteration," . join(',', sort @remain_games) . ",Odds\n";

my %id2conf;
my %power;
my %standings;
LoadCurrentRankings($rankfile, \%id2conf, \%power, \%standings);

my %playoff_count :shared = map { $_ => 0 } keys %power;
# 3) Simulate rest of regular season
# Simresults ~> [gameid] => [winner,loser]
my @threads;
foreach my $i (1..$NUM_THREADS) {
#  RunOneThread(($i - 1) * $SIMS_PER_THREAD, $SIMS_PER_THREAD, \%playoff_count);
  push(@threads, threads->create(\&RunOneThread, ($i - 1) * $SIMS_PER_THREAD, $SIMS_PER_THREAD, \%playoff_count));
}

foreach my $thr (@threads) {
  $thr->join();
}

foreach my $s (@SEASONS) {
  print $s;
}

#foreach my $tid (sort { $playoff_count{$b} <=> $playoff_count{$a} } keys %playoff_count) {
#  my $c = $playoff_count{$tid};
#  last if (not $c);
#  printf "TEAM,%d,%d,%s\n", $c, $tid, $id2name{$tid};
#}

select STDOUT;
close(OUTFILE);
printf "Found results for %d seasons\n", scalar(@SEASONS);

sub RunOneThread($$$) {
  my $base_iter = shift;
  my $num_sims = shift;
  my $playoff_count_href = shift;
  foreach my $i (1..$num_sims) {
    OneFullSim($i + $base_iter, $playoff_count_href);
  }
}

sub OneFullSim($$) {
  my $sim_num = shift;
  my $playoff_count_href = shift;
  my %simresults;
  my %allresults;
  my $odds = SimulateSeason(\%results, \%predictions, \%simresults, \%fcslosses, \%allresults);
  
  my %perteam_game_results;
  MakePerTeamGameResults(\%allresults, \%perteam_game_results);
  
  # 4) Identify conference title game teams
  my %conf_champs;
  my %conf_runnerup;
  foreach my $confname (sort keys %confteams) {
    next if (!length($confname) or $confname eq "FCS");
    my @allconfteams;
    GetAllConfTeams($confname, \%confteams, \@allconfteams);
    my $conf_href = $confteams{$confname};
    my %subconf_winners;
    foreach my $subconf_name (keys %$conf_href) {
      my $subconf_href = $$conf_href{$subconf_name};
      my @subconfteams = keys %$subconf_href;
#      print "\n\n=== $confname $subconf_name ===\n";
      my %team_rankings;
      my @calls = ($confname, $subconf_name);
      SortTeamsByResults(\@calls, \%perteam_game_results, \@subconfteams, \@allconfteams, \%team_rankings, 0);
      my $aref = $team_rankings{1};
      if (scalar(@$aref) > 1) {
#        print "$confname $subconf_name MULTIPLES " . join('+', sort @$aref) . "\n";
        my @s;
        SortTeamsByPower($aref, \%power, \@s);
        $subconf_winners{$subconf_name} = $s[0];
        if (HasTopTwoTitle($confname)) {
          $subconf_winners{"b"} = $s[1];
        }
#        print "SCW $subconf_name $subconf_winners{$subconf_name}\n";
      } else {
        $subconf_winners{$subconf_name} = $$aref[0];
        if (HasTopTwoTitle($confname)) {
          my $two_aref = $team_rankings{2};
          if (scalar(@$two_aref) > 1) {
            my @s;
            SortTeamsByPower($two_aref, \%power, \@s);
            $subconf_winners{"b"} = $s[0];
          } else {
            $subconf_winners{"b"} = $$two_aref[0];
          }
        }  
      }
    }
    if (scalar(keys %subconf_winners) == 1) {
      $conf_champs{$confname} = (values %subconf_winners)[0];
    } else {
      # 5) Predict conference title game champions
      my @subconf_champs = values %subconf_winners;
      my ($winner, $loser, $c_odds) = Predict(\@subconf_champs, \%power);
      if (defined($winner) and defined($loser)) {
        $conf_champs{$confname} = $winner;
        $conf_runnerup{$confname} = $loser;
        if (defined($winner) and defined($loser)) {
          my $k = sprintf "%d1230-%s", $SEASON, $confname;
          $simresults{$k} = $winner . "d" . $loser;
          $perteam_game_results{$winner}{"conftitle"} = 1;
          $perteam_game_results{$loser}{"conftitle"} = 0;
        }
        $odds += $c_odds;
      } else {
        print "XXX Error predicting winner of $confname conference title\n";
      }
    }
    my $k = sprintf "%d1231-Champs-%s", $SEASON, $confname;
    $simresults{$k} = $conf_champs{$confname};
  }
  my %num_wins;
  my %num_losses;
  my %num_conf_wins;
  my %num_conf_losses;
  GetWinLoss(\%perteam_game_results, \%teamconfs, \%nonconfgames,
             \%num_wins, \%num_losses, \%num_conf_wins, \%num_conf_losses);
  foreach my $team_id (keys %num_wins) {
    my $k = sprintf "%d1234-Wins-%d", $SEASON, $team_id;
    $simresults{$k} = $num_wins{$team_id};
    $k = sprintf "%d1234-ConfWins-%d", $SEASON, $team_id;
    $simresults{$k} = $num_conf_wins{$team_id};
  }
  my $num_left = $NUM_TOP;
  # 6) Bin everything by the categories above (and below).
  # Preference for who will get into the playoffs:
  my %this_playoff;
  my @modules;
  # 1) Undefeated Power5 teams or Notre Dame
  my @zeroloss;
  FindNLossTeams(\%num_losses, 0, \@zeroloss);
  my @p5zero;
  SelectByConference(\@zeroloss, \%POWER5, 1, \@p5zero);
  push(@p5zero, $NOTRE_DAME_ID) if (grep(/^$NOTRE_DAME_ID$/, @zeroloss));
  locklog("Zero-loss teams: [ " . join(', ', sort @p5zero) . " ]\n");
  my @topN;
  SortTeamsByPower(\@p5zero, \%power, \@topN);
  locklog(sprintf "Found %d P5ZeroLoss\n", scalar(@p5zero));
  push(@modules, "P5ZeroLoss");
  foreach my $tid (@p5zero) {
    $this_playoff{$tid} = $NUM_TOP - ($num_left - 1);
    --$num_left;
    last if (!$num_left)
  }
  if (!$num_left) {
    locklog(sprintf "DONE %s\n", join(' ', @modules));
    Aggregate(\%this_playoff, $playoff_count_href);
    PrintResults($sim_num, \%simresults, \%this_playoff, $odds);
    return;
#  } else {
#    print "REMAIN $numleft\n";
  }
  # 2) 1-loss Power5 conference champs or Notre Dame
  my @oneloss;
  FindNLossTeams(\%num_losses, 1, \@oneloss);
  my @p5oneloss;
  foreach my $tid (@oneloss) {
    foreach my $confname (keys %conf_champs) {
      next if (!defined($POWER5{$confname}));
      next if (!defined($conf_champs{$confname}));
      next if ($conf_champs{$confname} != $tid);
      push(@p5oneloss, $tid);
    }
  }
  push(@p5oneloss, $NOTRE_DAME_ID) if (grep(/^$NOTRE_DAME_ID$/, @oneloss));
  SortTeamsByPower(\@p5oneloss, \%power, \@topN);
  locklog(sprintf "Found %d P5oneloss [ %s ]\n", scalar(@p5oneloss), join(', ', sort @p5oneloss));
  push(@modules, "P5OneLossChamp");
  foreach my $tid (@p5oneloss) {
    $this_playoff{$tid} = $NUM_TOP - ($num_left - 1);
    --$num_left;
    last if (!$num_left);
  }
  if (!$num_left) {
    locklog(sprintf "DONE %s\n", join(' ', @modules));
    Aggregate(\%this_playoff, $playoff_count_href);
    PrintResults($sim_num, \%simresults, \%this_playoff, $odds);
    return;
#  } else {
#    print "REMAIN $numleft\n";
  }
  # 3) 1-loss Power5 conference title game losers
  my @p5onelossrunnerup;
  foreach my $tid (@oneloss) {
    foreach my $confname (keys %conf_runnerup) {
      next if (!defined($POWER5{$confname}));
      next if (!defined($conf_runnerup{$confname}));
      next if ($conf_runnerup{$confname} != $tid);
      push(@p5onelossrunnerup, $tid);
    }
  }
  SortTeamsByPower(\@p5onelossrunnerup, \%power, \@topN);
  locklog(sprintf "Found %d P5onelossrunnerup [ %s ]\n", scalar(@p5onelossrunnerup), join(', ', sort @p5onelossrunnerup));
  push(@modules, "P5onelossrunnerup");
  foreach my $tid (@p5onelossrunnerup) {
    $this_playoff{$tid} = $NUM_TOP - ($num_left - 1);
    --$num_left;
    last if (!$num_left);
  }
  if (!$num_left) {
    locklog(sprintf "DONE %s\n", join(' ', @modules));
    Aggregate(\%this_playoff, $playoff_count_href);
    PrintResults($sim_num, \%simresults, \%this_playoff, $odds);
    return;
#  } else {
#    print "REMAIN $numleft\n";
  }
  # 4) 1-loss Power5 non-conference title game non-participant
  my @p5onelossleftout;
  foreach my $tid (@oneloss) {
    my $confname = $teamconfs{$tid};
    next if (!defined($POWER5{$confname}));
    next if (!defined($conf_champs{$confname}));
    next if (!defined($conf_runnerup{$confname}));
    next if ($conf_champs{$confname} == $tid);
    next if ($conf_runnerup{$confname} == $tid);
    push(@p5onelossleftout, $tid);
  }
  SortTeamsByPower(\@p5onelossleftout, \%power, \@topN);
  locklog(sprintf "Found %d P5onelossleftout [ %s ]\n", scalar(@p5onelossleftout), join(', ', sort @p5onelossleftout));
  push(@modules, "P5onelossleftout");
  foreach my $tid (@p5onelossleftout) {
    $this_playoff{$tid} = $NUM_TOP - ($num_left - 1);
    --$num_left;
    last if (!$num_left);
  }
  if (!$num_left) {
    locklog(sprintf "DONE %s\n", join(' ', @modules));
    Aggregate(\%this_playoff, $playoff_count_href);
    PrintResults($sim_num, \%simresults, \%this_playoff, $odds);
    return;
#  } else {
#    print "REMAIN $numleft\n";
  }

  # 5) 2-loss Power5 conference champs or Notre Dame
  my @twoloss;
  FindNLossTeams(\%num_losses, 2, \@twoloss);
  my @p5twoloss;
  foreach my $tid (@twoloss) {
    foreach my $confname (keys %conf_champs) {
      next if (!defined($POWER5{$confname}));
      next if (!defined($conf_champs{$confname}));
      next if ($conf_champs{$confname} != $tid);
      push(@p5twoloss, $tid);
    }
  }
  push(@p5twoloss, $NOTRE_DAME_ID) if (grep(/^$NOTRE_DAME_ID$/, @twoloss));
  SortTeamsByPower(\@p5twoloss, \%power, \@topN);
  locklog(sprintf "Found %d P5twoloss [ %s ]\n", scalar(@p5twoloss), join(', ', sort @p5twoloss));
  push(@modules, "P5twoloss");
  foreach my $tid (@p5twoloss) {
    $this_playoff{$tid} = $NUM_TOP - ($num_left - 1);
    --$num_left;
    last if (!$num_left);
  }
  if (!$num_left) {
    locklog(sprintf "DONE %s\n", join(' ', @modules));
    Aggregate(\%this_playoff, $playoff_count_href);
    PrintResults($sim_num, \%simresults, \%this_playoff, $odds);
    return;
#  } else {
#    print "REMAIN $numleft\n";
  }
  # 6) Undefeated non-Power5 teams
  my @nonp5zero;
  SelectByConference(\@zeroloss, \%NONPOWER5, 1, \@nonp5zero);
  # Remove Notre Dame from the non-P5
  if (grep(/^$NOTRE_DAME_ID$/, @nonp5zero)) {
    my $i = 0; $i++ until $nonp5zero[$i] eq $NOTRE_DAME_ID; splice(@nonp5zero, $i, 1);
  }
  SortTeamsByPower(\@nonp5zero, \%power, \@topN);
  locklog("Found " . scalar(@nonp5zero) . " NonP5ZeroLoss teams: [ " . join(', ', sort @nonp5zero) . " ]\n");
  push(@modules, "NonP5ZeroLoss");
  foreach my $tid (@nonp5zero) {
    $this_playoff{$tid} = $NUM_TOP - ($num_left - 1);
    --$num_left;
    last if (!$num_left);
  }
  if (!$num_left) {
    locklog(sprintf "DONE %s\n", join(' ', @modules));
    Aggregate(\%this_playoff, $playoff_count_href);
    PrintResults($sim_num, \%simresults, \%this_playoff, $odds);
    return;
#  } else {
#    print "REMAIN $numleft\n";
  }
  # 7) 2-loss Power5 conference title game losers
  my @p5twolossrunnerup;
  foreach my $tid (@twoloss) {
    foreach my $confname (keys %conf_runnerup) {
      next if (!defined($POWER5{$confname}));
      next if (!defined($conf_champs{$confname}));
      next if (!defined($conf_runnerup{$confname}));
      next if ($conf_runnerup{$confname} != $tid);
      push(@p5twolossrunnerup, $tid);
    }
  }
  SortTeamsByPower(\@p5twolossrunnerup, \%power, \@topN);
  locklog(sprintf "Found %d P5twolossrunnerup: [ %s ]\n", scalar(@p5twolossrunnerup), join(', ', sort @p5twolossrunnerup));
  push(@modules, "P5twolossrunnerup");
  foreach my $tid (@p5twolossrunnerup) {
    $this_playoff{$tid} = $NUM_TOP - ($num_left - 1);
    --$num_left;
    last if (!$num_left);
  }
  if (!$num_left) {
    locklog(sprintf "DONE %s\n", join(' ', @modules));
    Aggregate(\%this_playoff, $playoff_count_href);
    PrintResults($sim_num, \%simresults, \%this_playoff, $odds);
    return;
#  } else {
#    print "REMAIN $numleft\n";
  }
  if (scalar(keys %this_playoff) >= 4) {
    Aggregate(\%this_playoff, $playoff_count_href);
    PrintResults($sim_num, \%simresults, \%this_playoff, $odds);
  }

  # Out of choices
#  locklog("NEED $numleft MORE\n");
}

sub Aggregate($$) {
  my $from_href = shift;
  my $to_href = shift;
#  print Dumper($from_href);
  foreach my $tid (keys %$from_href) {
    next if ($$from_href{$tid} > 4);
    $$to_href{$tid} += 1;
  }
}

sub GetWinLoss($$$$$$$) {
  my $perteam_results_href = shift;
  my $id2conf_href = shift;
  my $nonconf_href = shift;
  my $wins_href = shift;
  my $loss_href = shift;
  my $conf_wins_href = shift;
  my $conf_loss_href = shift;
  foreach my $tid (keys %$perteam_results_href) {
    my @r = (0, 0, 0, 0);
    my $res_href = $$perteam_results_href{$tid};
    my $team_conf = $$id2conf_href{$tid};
    next if (!defined($team_conf) or !length($team_conf) or ($team_conf eq "FCS"));
    foreach my $opp_id (keys %$res_href) {
      my $opp_conf = $$id2conf_href{$opp_id};
      my $win = $$res_href{$opp_id};
      $r[0] += $win;
      $r[1] += !$win;
      # 2019,1749,1457
      if (defined($$nonconf_href{$tid})) {
        if (defined($$nonconf_href{$tid}{$opp_id})) {
          next;
        }
      }
      if (defined($opp_conf) and ($team_conf eq $opp_conf)) {
        $r[2] += $win;
        $r[3] += !$win;
      }
    }
    $$wins_href{$tid} = $r[0];
    $$loss_href{$tid} = $r[1];
    $$conf_wins_href{$tid} = $r[2];
    $$conf_loss_href{$tid} = $r[3];
  }
}


sub LoadFcsResults($$) {
  my $fname = shift;
  my $href = shift;
  open(LOSSES, "$fname") or die "Can't open FCS loss file: $!";
  while(<LOSSES>) {
    chomp;
    @_ = split(/,/);
    $$href{$_[0]} = $_[1];
  }
  close(LOSSES);
}

sub LoadNonConfGames($$$) {
  my $fname = shift;
  my $season = shift;
  my $href = shift;
  open(NONCONF, "$fname") or die "Can't open non-conference games file: $!";
  while(<NONCONF>) {
    next if (/^#/);
    chomp;
    @_ = split(/,/);
    next if ((scalar(@_) != 3) or ($_[0] != $season));
    my $a_href = $$href{$_[1]};
    if (!defined($a_href)) {
      my %ah;
      $$href{$_[1]} = $a_href = \%ah;
    }
    my $b_href = $$href{$_[2]};
    if (!defined($b_href)) {
      my %bh;
      $$href{$_[2]} = $b_href = \%bh;
    }
    $$a_href{$_[2]} = 1;
    $$b_href{$_[1]} = 1;
  }
  close(NONCONF);
}

sub FindNLossTeams($$$) {
  my $loss_href = shift;
  my $loss_count = shift;
  my $targetloss_aref = shift;
  @$targetloss_aref = ();
  foreach my $team_id (keys %$loss_href) {
    my $num_loss = $$loss_href{$team_id};
    if ($num_loss == $loss_count) {
      locklog(sprintf "E%4d has %2d losses (%2d)\n", $team_id, $num_loss, $loss_count);
      push(@$targetloss_aref, $team_id);
    }
  }
}

sub SelectByConference($$$$) {
  my $teams_aref = shift;
  my $target_conf_href = shift;
  my $match = shift;
  my $out_teams_aref = shift;
  foreach my $tid (@$teams_aref) {
    my $c = $teamconfs{$tid};
    if (defined($c) and !($match xor defined($$target_conf_href{$c}))) {
      push(@$out_teams_aref, $tid);
    }
  }
}

sub MatchesSeason($$) {
  my $gid = shift;
  my $season = shift;
  return 0 if ($season ne substr($gid, 0, 4));
  return 0 if ("01" eq substr($gid, 4, 2));
  return 1;
}

sub SimulateSeason($$$$$) {
  my $results_href = shift;
  my $pred_href = shift;
  my $sim_href = shift;
  my $fcsloss_href = shift;
  my $all_href = shift;
  # Start block of function
  my $season = undef;
  my $log_odds = 0;
  foreach my $gid (sort keys %$pred_href) {
    # TODO: Make sure we can handle predictions for all seasons
    # IsNeutral,HomeID,HomeScore,AwayID,AwayScore,OddsFav,NumPlays
    my $aref = $$pred_href{$gid};
    my $odds = $$aref[-2];
    my $r = rand();
    my @res = ();
    if ($r < $odds) {
      # Home team won
      push(@res, $$aref[1], $$aref[3]);
      $log_odds += log($odds);
    } else {
      push(@res, $$aref[3], $$aref[1]);
      $log_odds += log(1 - $odds);
    }
    $$sim_href{$gid} = $res[0] . "d" . $res[1];
    $$all_href{$gid} = \@res;
    $season = DateToSeason(substr($gid, 0, 8)) if (!defined($season));
  }
  foreach my $gid (sort { $b cmp $a } keys %$results_href) {
#    print "DEBUG $gid $season\n";
    last unless MatchesSeason($gid, $season);
    my $g_season = DateToSeason(substr($gid, 0, 8));
    next if ($season != $g_season);
    my $g_aref = $$results_href{$gid};
    my @res = ();
    next if ($$g_aref[7] == 0 and $$g_aref[10] == 0);
    if ($$g_aref[7] > $$g_aref[10]) {
      push(@res, $$g_aref[5], $$g_aref[8]);
    } else {
      push(@res, $$g_aref[8], $$g_aref[5]);
    }
    $$all_href{$gid} = \@res;
  }

  # Each FCS loss counts as two losses since it's really hard to overcome that.
  foreach my $fbs_id (keys %$fcsloss_href) {
    my $id = $FCS_ID;
    my @res0 = ($id, $fbs_id);
    my $gid0 = sprintf "%d0821-%d-%d", $season, $fbs_id, $id;
    $$all_href{$gid0} = \@res0;
    $id = $FCS_ID - 1;
    my @res1 = ($id, $fbs_id);
    my $gid1 = sprintf "%d0821-%d-%d", $season, $fbs_id, $id;
    $$all_href{$gid1} = \@res1;
  }
  return $log_odds;
}

sub SortTeamsByPower($$$) {
  my $teams_aref = shift;
  my $power_href = shift;
  my $sorted_aref = shift;
  my @power_teams = keys %$power_href;
  my @unweighted = array_minus(@$teams_aref, @power_teams);
  foreach my $tid (@unweighted) {
    $$power_href{$tid} = 0.0;
  }
  @$sorted_aref = sort { $$power_href{$b} <=> $$power_href{$a} } @$teams_aref;
}

sub PrintResults($$$$) {
  my $sim_num = shift;
  my $simres_href = shift;
  my $playoff_href = shift;
  my $odds = shift;
  my $i = 1;
  foreach my $tid (sort { $$playoff_href{$a} <=> $$playoff_href{$b} } keys %$playoff_href) {
    my $k = sprintf "%d0000-Rank%02d", $SEASON, $i;
    $$simres_href{$k} = $tid;
    ++$i;
  }
  foreach my $j ($i..10) {
    my $k = sprintf "%d0000-Rank%02d", $SEASON, $j;
    $$simres_href{$k} = "xxxx";
  }
  my @res;
  foreach my $gid (sort keys %$simres_href) {
    push(@res, $$simres_href{$gid});
  }
  my $s = sprintf "SeasonResult,%d,%s,%.3f\n", $sim_num, join(',', @res), $odds;
  locklog($s);
  lock(@SEASONS);
  push(@SEASONS, $s);
}

sub Predict($$) {
  my $teams_aref = shift;
  my $wpct_href = shift;
  my $t1 = $$teams_aref[0];
  my $t2 = $$teams_aref[1];
  if (defined($t1)) {
    if (defined($t2)) {
      my $p1 = $$wpct_href{$t1};
      my $p2 = $$wpct_href{$t2};
      my $odds = Log5($p1, $p2);
      if (rand() < $odds) {
        return ($t1, $t2, log($odds));
      } else {
        return ($t2, $t1, log(1 - $odds));
      }
    } else {
      return ($t1, $t2, log(1));
    }
  } elsif (defined($t2)) {
    return ($t2, $t1, log(1));
  } else {
    return (undef, undef, undef);
  }
}

sub MakePerTeamGameResults($$) {
  my $sim_results_href = shift;
  my $perteam_game_results_href = shift;
  foreach my $gid (keys %$sim_results_href) {
    my $aref = $$sim_results_href{$gid};
    $$perteam_game_results_href{$$aref[0]}{$$aref[1]} = 1;
    $$perteam_game_results_href{$$aref[1]}{$$aref[0]} = 0;
  }
#  my $clem_href = $$perteam_game_results_href{1147};
#  print Dumper($clem_href);
}

sub GetAllConfTeams($$$) {
  my $conf_name = shift;
  my $confteam_href = shift;
  my $teams_aref = shift;
  my $href = $$confteam_href{$conf_name};
  if (!defined($href)) {
    print STDERR "BAIL\n";
    return;
  }
  while (my ($subconf, $sub_href) = each %$href) {
    push(@$teams_aref, keys %$sub_href);
  }
}

# $$conf_team_href{$_[3]}{$_[4]}{$_[1]} = 1 if (defined($conf_team_href));
sub ConferencesWithTitles($$) {
  my $conf_href = shift;
  my $titles_aref = shift;
  foreach my $conf (keys %$conf_href) {
    my $thisconf_href = $$conf_href{$conf};
    if (scalar(keys %$thisconf_href) == 2) {
      push(@$titles_aref, $conf);
    } elsif (HasTopTwoTitle($conf)) {
      push(@$titles_aref, $conf);
    }
  }
}

sub HasTopTwoTitle($) {
  my $name = shift;
  return 0 if (!defined($name));
  return 1 if ($name eq "Big XII");
  return 0;
}

sub usage($) {
  my $argv0 = shift;
  print STDERR "\n";
  print STDERR "Usage: $argv0 <rankfile> <predfile> <nonconffile> <fcslossfile> <outfile>\n";
  print STDERR "\n";
  exit 1;
}

sub locklog($) {
  my $l = shift;
  lock($LOGGING);
  $LOGGING++;
#  print $l;
  $LOGGING--;
}
