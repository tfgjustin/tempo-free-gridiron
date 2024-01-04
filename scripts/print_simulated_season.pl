#!/usr/bin/perl -w

use strict;

use Data::Dumper;
use TempoFree;
use Text::CSV;

sub LoadFcsLosses($$);
sub MergeResults($$$$$$);
sub MakePerTeamGameResults($$);
sub IdMatches($);
sub SortTeamsByPower($$$);
sub GetAllConfTeams($$$);
sub PrintStandings($$$$$);
sub PrintGamelog($$$);
sub GetWinLoss($$$);
sub GetNiceName($);

my $CURR_SEASON = 2019;
my $SEASON_HDR = "RemainGames";
my $ITERATION_HDR = "Iteration";
my $SEASON_TAG = "SeasonResult";

my $simfile = shift(@ARGV);
my $sim_id = shift(@ARGV);
my $rankfile = shift(@ARGV);
my $fcslossfile = shift(@ARGV);

exit 1 if (!defined($fcslossfile));

my %results;
LoadResults(\%results);

my %fcslosses;
LoadFcsLosses($fcslossfile, \%fcslosses) if (defined($fcslossfile));

my @columns;
my $csv_parser = Text::CSV->new ( { binary => 1 } );
open my $fh, "<:encoding(utf8)", $simfile or die "Can't open $simfile: $!";
my $colref = $csv_parser->getline($fh);
@columns = @$colref;
$csv_parser->column_names(@columns);

my %all_results;
my %conf_titles;
my %playoff_teams;
while (my $href = $csv_parser->getline_hr($fh)) {
  next unless IdMatches($href);
  MergeResults(\%results, \%fcslosses, $href, \%all_results, \%conf_titles, \%playoff_teams);
  last;
}
close $fh;

my %perteam_game_results;
MakePerTeamGameResults(\%all_results, \%perteam_game_results);

my %id2name;
my %id2conf;
my %confteams;
my %isbcs;
LoadConferences(\%id2name, \%id2conf, \%confteams, \%isbcs);

my %names;
LoadPrintableNames(\%names);

my %power;
my %standings;
LoadCurrentRankings($rankfile, \%id2conf, \%power, \%standings);

my %records;
GetWinLoss(\%perteam_game_results, \%id2conf, \%records);

{
  foreach my $confname (sort keys %confteams) {
    next if (!length($confname) or $confname eq "FCS");
    my @allconfteams;
    GetAllConfTeams($confname, \%confteams, \@allconfteams);
    my $conf_href = $confteams{$confname};
    my %subconf_winners;
    foreach my $subconf_name (sort keys %$conf_href) {
      my $subconf_href = $$conf_href{$subconf_name};
      my @subconfteams = keys %$subconf_href;
#      print "\n\n=== $confname $subconf_name ===\n";
      my %team_rankings;
      my @calls = ($confname, $subconf_name);
      SortTeamsByResults(\@calls, \%perteam_game_results, \@subconfteams, \@allconfteams, \%team_rankings, 0);
#      print Dumper(%team_rankings);
      PrintStandings(join(" ", @calls), \%team_rankings, \%records, \%playoff_teams, $conf_titles{$confname});
      my $aref = $team_rankings{1};
      if (scalar(@$aref) > 1) {
        # Tie at the top. Give up.
#        print "$confname $subconf_name MULTIPLES " . join('+', sort @$aref) . "\n";
        my @s;
        SortTeamsByPower($aref, \%power, \@s);
        $subconf_winners{$subconf_name} = $s[0];
#        print "SCW $subconf_name $subconf_winners{$subconf_name}\n";
        next;
      }
      $subconf_winners{$subconf_name} = $$aref[0];
    }
    PrintGamelog(\@allconfteams, \%all_results, $conf_titles{$confname});
    # TODO: Find the title game in the sim and grab out the winners
  }
}


#sub SortTeamsByResults($$$$$$) {
#  my $calls_aref = shift;
#  my $simres_href = shift;
#  my $teams_aref = shift;
#  my $opp_teams_aref = shift;
#  my $rank_href = shift;
#  my $do_print = shift;

###

sub LoadFcsLosses($$) {
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

sub MergeResults($$$$$$) {
  my $results_href = shift;
  my $fcsloss_href = shift;
  my $sims_href = shift;
  my $all_href = shift;
  my $titles_href = shift;
  my $playoffs_href = shift;
  foreach my $gid (keys %$sims_href) {
    if ($gid =~ /0000-Rank0[1-4]/) {
      $$playoffs_href{$$sims_href{$gid}} = 1;
    } elsif ($gid =~ /\d{4}1234-\w+/) {
      my ($date, $c) = split(/-/, $gid, 2);
      my $r = $$sims_href{$gid};
      if ($r =~ /\d{4}d\d{4}/) {
        my @res = (substr($r, 0, 4),  substr($r, 5, 4));
        $$titles_href{$c} = \@res;
      }
    } elsif ($gid =~ /\d{8}-\d{4}-\d{4}/) {
      my $r = $$sims_href{$gid};
      if ($r =~ /(\d{4})d(\d{4})/) {
        my @res = ($1, $2);
        $$all_href{$gid} = \@res;
      }
    }
  }
  foreach my $gid (keys %$results_href) {
    my $g_season = DateToSeason(substr($gid, 0, 8));
    next if ($CURR_SEASON != $g_season);
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
}

sub IdMatches($) {
  my $href = shift;
  return 0 if (!defined($$href{$ITERATION_HDR}) or !defined($$href{$SEASON_HDR}));
  return 0 if ($$href{$SEASON_HDR} ne $SEASON_TAG);
  return $$href{$ITERATION_HDR} eq $sim_id;
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

sub MakePerTeamGameResults($$) {
  my $sim_results_href = shift;
  my $perteam_game_results_href = shift;
  foreach my $gid (keys %$sim_results_href) {
    my $aref = $$sim_results_href{$gid};
    $$perteam_game_results_href{$$aref[0]}{$$aref[1]} = 1;
    $$perteam_game_results_href{$$aref[1]}{$$aref[0]} = 0;
  }
}

sub SortTeamsByPower($$$) {
  my $teams_aref = shift;
  my $power_href = shift;
  my $sorted_aref = shift;
  foreach my $tid (@$teams_aref) {
    $$power_href{$tid} = 0 if (!defined($$power_href{$tid}));
  }
  if (scalar(@$teams_aref) == 1) {
    @$sorted_aref = @$teams_aref;
  } else {
    @$sorted_aref = sort { $$power_href{$b} <=> $$power_href{$a} } @$teams_aref;
  }
}

sub GetNotes($$$$) {
  my $tid = shift;
  my $playoff_href = shift;
  my $t_winner = shift;
  my $t_loser = shift;
  my $notes = "";
  if (defined($$playoff_href{$tid})) {
    $notes = "x ";
  }
  if ($tid eq $t_winner) {
    $notes .= "y ";
  }
  if ($tid eq $t_loser) {
    $notes .= "z ";
  }
  return $notes;
}

sub PrintStandings($$$$$) {
  my $confname = shift;
  my $rankings_href = shift;
  my $records_href = shift;
  my $playoff_href = shift;
  my $conf_title_aref = shift;
  my $title_winner = -1;
  my $title_loser = -1;
  if (defined($conf_title_aref)) {
    $title_winner = $$conf_title_aref[0];
    $title_loser = $$conf_title_aref[1];
  }
  print "Standings: $confname\n";
  foreach my $r (sort { $a <=> $b } keys %$rankings_href) {
    my $aref = $$rankings_href{$r};
    my @s;
    SortTeamsByPower($aref, \%power, \@s);
    foreach my $tid (@s) {
      my $records_aref = $$records_href{$tid};
      if ($tid eq $title_winner) {
        $$records_aref[0] += 1;
        $$records_aref[2] += 1;
      } elsif ($tid eq $title_loser) {
        $$records_aref[1] += 1;
        $$records_aref[3] += 1;
      }
      my $notes = GetNotes($tid, $playoff_href, $title_winner, $title_loser);
      my $fmt = sprintf "%%s%%-%ds\t%%s\n", 20 - length($notes);
      printf $fmt, $notes, GetNiceName($tid), join("\t", @$records_aref);
    }
  }
  print "\n";
}

sub PrintGamelog($$$) {
  my $teams_aref = shift;
  my $results_href = shift;
  my $title_results = shift;
  my $curr_date = "";
  foreach my $gid (sort keys %$results_href) {
    my ($date, $t1, $t2) = split(/-/, $gid, 3);
    next unless (grep(/$t1/, @$teams_aref) or grep(/$t2/, @$teams_aref));
    my $print_date = "";
    if ($curr_date ne $date) {
      $print_date = $curr_date = $date;
    }
    my $aref = $$results_href{$gid};
    my $win = GetNiceName($$aref[0]);
    my $loss = GetNiceName($$aref[1]);
    printf "%-9s\t%-20s def %-20s\n", $print_date, $win, $loss;
  }
  if (defined($title_results)) {
    my $win = GetNiceName($$title_results[0]);
    my $loss = GetNiceName($$title_results[1]);
    printf "Championship\t%-20s def %-20s\n", $win, $loss;
  }
  print "\n\n";
}

sub GetWinLoss($$$) {
  my $perteam_results_href = shift;
  my $id2conf_href = shift;
  my $records_href = shift;
  foreach my $tid (keys %$perteam_results_href) {
    my @r = (0, 0, 0, 0);
    my $team_href = $$perteam_results_href{$tid};
    my $team_conf = $$id2conf_href{$tid};
    next if (!defined($team_conf) or !length($team_conf) or ($team_conf eq "FCS"));
    foreach my $opp_id (keys %$team_href) {
      my $opp_conf = $$id2conf_href{$opp_id};
      my $win = $$team_href{$opp_id};
      $r[0] += $win;
      $r[1] += !$win;
      if (defined($opp_conf) and ($team_conf eq $opp_conf)) {
        $r[2] += $win;
        $r[3] += !$win;
      }
    }
    $$records_href{$tid} = \@r;
  }
}

sub GetNiceName($) {
  my $tid = shift;
  my $bigname = $id2name{$tid};
  return $tid if (!defined($bigname));
  my $name = $names{$bigname};
  return $bigname if (!defined($name));
  return $name;
}
