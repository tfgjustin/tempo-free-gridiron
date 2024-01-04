#
#===============================================================================
#
#         FILE:  TempoFree.pm
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  YOUR NAME (), 
#      COMPANY:  
#      VERSION:  1.0
#      CREATED:  09/05/2011 08:54:29 PM
#     REVISION:  ---
#===============================================================================

package TempoFree;
use strict;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

my %YEAR_TO_WEEK = (
  2000 =>  14,
  2001 =>  67,
  2002 => 123,
  2003 => 175,
  2004 => 227,
  2005 => 280,
  2006 => 332,
  2007 => 384,
  2008 => 437,
  2009 => 489,
  2010 => 541,
  2011 => 593,
  2012 => 645,
  2013 => 696,
  2014 => 748,
  2015 => 800,
  2016 => 852,
  2017 => 906,
  2018 => 958,
  2019 => 1010
);

my @YEARS = sort(keys %YEAR_TO_WEEK);
our $CURRENT_SEASON = $YEARS[-1];

our $VERSION = 0.1;
our @ISA = qw(Exporter);
our @EXPORT = qw($CURRENT_SEASON Log5 LoadIdToName LoadIdToTwitter LoadNameToId LoadPrintableNames LoadFullNames
             LoadConferences LoadConferencesForYear PrintableName LoadRanksAndStats
             LoadCurrentRankings LoadCurrentRanksAndStats FetchWeekRankings
             RankValues LoadPredictions LoadPredictionsOddsMode LoadResults LoadResultsFromFile
             LoadResultsForSeason LoadResultsForSeasonBeforeDate ResultsToTeamSeasons DatesToWeek PrintTeamHeaders
             PrintSeasons CalculateGugs LoadPartialResults PrintComparisonSeasons
             GetAllTeamRecords LoadInGamePredictions DateToSeason LeadOdds
             FieldPositionPoints SeasonAndWeekToDates LoadColors SortTeamsByResults);
our @EXPORT_OK = @EXPORT;
our %EXPORT_TAGS = ( DEFAULT => [qw(&Log5), qw(&LoadIdToName), qw(&LoadIdToTwitter), qw(&LoadNameToId),
                             qw(&LoadPrintableNames), qw(&LoadFullNames),
                             qw(&LoadConferences), qw(&LoadConferencesForYear),
                             qw(&GetAllTeamRecords), qw(&LeadOdds),
                             qw(&PrintableName), qw(&LoadRanksAndStats),
                             qw(&LoadCurrentRankings), qw(&LoadCurrentRanksAndStats),
                             qw(&RankValues), qw(&FetchWeekRankings),
                             qw(&LoadPredictions), qw(&LoadPredictionsOddsMode), qw(&LoadResults),
                             qw(&LoadResultsFromFile), qw(&LoadPartialResults), qw(&LoadResultsForSeason),
                             qw(&LoadResultsForSeasonBeforeDate), qw(&ResultsToTeamSeasons), qw(&DatesToWeek),
                             qw(&PrintTeamHeaders), qw(&PrintSeasons),
                             qw(&CalculateGugs), qw(&PrintComparisonSeasons),
                             qw(&LoadInGamePredictions), qw(&DateToSeason),
                             qw(&FieldPositionPoints), qw(&SeasonAndWeekToDates),
                             qw(&LoadColors), qw(&SortTeamsByResults)]);

my $DATADIR = "data";
my $INPUTDIR = "input";
my $ID2NAME = "$DATADIR/id2name.txt";
my $ID2TWITTER = "$DATADIR/id2twitter.csv";
my $NAMEMAP = "$DATADIR/names.txt";
my $FULLNAMEMAP = "$DATADIR/full_names.txt";
my $CONFFILE = "$DATADIR/conferences.txt";
my $SUMMARYFILE = "$INPUTDIR/summaries.csv";
my $LEADFILE = "$DATADIR/leads.txt";
my $POSITIONFILE = "$DATADIR/field_position.csv";
my $COLORFILE = "$DATADIR/teamColors.txt";


# Cache this
# {second}[0-intercept,slope]
my %lead_data;

# Cache this
# {off|def}{yards}[intercept,slope]
my %field_position_points;

sub get_primary_line($$);
sub get_game_components($$$$$);
sub calculate_gugs($$$);
sub print_game_info($$$$$$$$);
sub print_game_info_compare($$$$$$$$$$);
sub get_rank_html($$);
sub get_selected_wpct($$$$);
sub get_wpcts_ranks($$$$);
sub load_lead_data();
sub load_position_points();
sub get_expected_points($$);
sub weight_odds($$$);
sub linear_interpolation($$);
sub distance($$$);
sub get_record_versus($$$$$$);
sub bin_teams_by_win_pct($$);
sub rank_teams_allow_ties($$$$$);

sub Log5($$) {
  my $a = shift;
  my $b = shift;
  my $num = $a - ($a * $b);
  my $den = $a + $b - (2 * $a * $b);

  return ($num / $den);
}

sub LoadIdToName($) {
  my $href = shift;
  open(ID2NAME, "$ID2NAME") or do {
    warn "Could not open $ID2NAME for reading: $!";
    return 1;
  };
  while(<ID2NAME>) {
    next if (/^#/);
    chomp;
    my ($id, $name) = split(/,/);
    next if (!defined($name));
    $$href{$id} = $name;
  }
  close(ID2NAME);
  return 0;
}

sub LoadIdToTwitter($) {
  my $href = shift;
  open(ID2TWITTER, "$ID2TWITTER") or do {
    warn "Could not open $ID2TWITTER for reading: $!";
    return 1;
  };
  while(<ID2TWITTER>) {
    next if (/^#/);
    chomp;
    my ($id, $twitter) = split(/,/);
    next if (!defined($twitter));
    $$href{$id} = $twitter;
  }
  close(ID2TWITTER);
  return 0;
}

# Create the mappings of
# 1) team ID -> short name
# 2) team ID -> Conference
# 3) (conference, subconference) -> set of team IDs
# 4) team ID -> isBcs
sub LoadConferences($$$$) {
  my $name_href = shift;
  my $conf_href = shift;
  my $conf_team_href = shift;
  my $bcs_href = shift;
  LoadConferencesForYear($CURRENT_SEASON, $name_href, $conf_href, $conf_team_href,
                         $bcs_href);
}

sub LoadConferencesForYear($$$$$) {
  my $year = shift;
  my $name_href = shift;
  my $conf_href = shift;
  my $conf_team_href = shift;
  my $bcs_href = shift;
  open(CONF, "$CONFFILE") or do {
    warn "Could not open $CONFFILE for reading: $!";
    return 1;
  };
  while(<CONF>) {
    next if(/^#/);
    chomp;
    @_ = split(/,/);
    if (scalar(@_) != 6) {
      warn "Invalid conference line: \"$_\"";
      next;
    }
    next unless ($_[0] eq $year);
    $$name_href{$_[1]} = $_[2] if (defined($name_href));
    $$conf_href{$_[1]} = $_[3] if (defined($conf_href));
    $$conf_team_href{$_[3]}{$_[4]}{$_[1]} = 1 if (defined($conf_team_href));
    $$bcs_href{$_[1]} = $_[5] if (defined($bcs_href));
#    printf STDERR "bcs_href %d = %d\n", $_[0], $$bcs_href{$_[0]};
  }
  close(CONF);
  return 0;
}

sub LoadNameToId($) {
  my $href = shift;
  open(ID2NAME, "$ID2NAME") or do {
    warn "Could not open $ID2NAME for reading: $!";
    return 1;
  };
  while(<ID2NAME>) {
    next if (/^#/);
    chomp;
    my ($id, $name) = split(/,/);
    next if (!defined($name));
    $$href{$name} = $id;
    $name =~ s/\ /_/g;
    $$href{$name} = $id;
  }
  close(ID2NAME);
  return 0;
}

sub LoadPrintableNames($) {
  my $href = shift;
  open(NAMEMAP, "$NAMEMAP") or do {
    warn "Could not open $NAMEMAP for reading: $!";
    return 1;
  };
  while(<NAMEMAP>) {
    next if (/^#/);
    chomp;
    my ($short_name, $printable_name) = split(/,/);
    next if (!defined($printable_name));
    $$href{$short_name} = $printable_name;
    $short_name =~ s/\ /_/g;
    $$href{$short_name} = $printable_name;
  }
  close(NAMEMAP);
  return 0;
}

sub LoadFullNames($) {
  my $href = shift;
  open(FULLNAMEMAP, "$FULLNAMEMAP") or do {
    warn "Could not open $NAMEMAP for reading: $!";
    return 1;
  };
  while(<FULLNAMEMAP>) {
    next if (/^#/);
    chomp;
    my ($short_name, $full_name) = split(/,/);
    next if (!defined($full_name));
    $$href{$short_name} = $full_name;
    $short_name =~ s/\ /_/g;
    $$href{$short_name} = $full_name;
  }
  close(FULLNAMEMAP);
  return 0;
}

sub LeadOdds($$) {
  my $game_clock = shift;
  my $lead = shift;
  load_lead_data();
  my @marks = sort { $a <=> $b } keys %lead_data;
#  print STDERR "\n";
  if ($lead == 0) {
    return 0.5;
  }
  if ($game_clock < $marks[0]) {
    # Prior to first mark.
#    printf STDERR "LeadOdds PreFirst %2d %2d\n", $game_clock, $lead;
    return weight_odds(0.500, linear_interpolation($lead_data{$marks[0]}, $lead),
                       $game_clock / $marks[0]);
  } elsif ($game_clock > $marks[-1]) {
    # After last mark data.
#    printf STDERR "LeadOdds PostLast %2d %2d\n", $game_clock, $lead;
    return weight_odds(linear_interpolation($lead_data{$marks[-1]}, $lead), 1.000,
                       ($game_clock - $marks[-1]) / (3600 - $marks[-1])); 
  } elsif (defined($lead_data{$game_clock})) {
#    printf STDERR "LeadOdds GoodMark %2d %2d\n", $game_clock, $lead;
    return linear_interpolation($lead_data{$game_clock}, $lead);
  } else {
    my ($min, $max) = (undef, undef);
    foreach my $i (0..($#marks-1)) {
      if ($game_clock > $marks[$i] and $game_clock < $marks[$i+1]) {
        $min = $marks[$i];
        $max = $marks[$i+1];
        last;
      }
    }
    if (!defined($min) or !defined($max)) {
      warn "Could not get lead data for minute mark $game_clock";
      return 0.5;
    }
#    printf STDERR "LeadOdds IsMiddle %2d %2d [%2d,%2d,%.3f]\n", $game_clock, $lead,
#                  $min, $max, distance($min, $game_clock, $max);
    return weight_odds(linear_interpolation($lead_data{$min}, $lead),
                       linear_interpolation($lead_data{$max}, $lead),
                       distance($min, $game_clock, $max));
  }
}

sub FieldPositionPoints($) {
  my $distance_from_goal = shift;
  load_position_points();
  my ($offpts, $defpts) = (undef, undef);
  my $offhref = $field_position_points{"off"};
  my $defhref = $field_position_points{"def"};
  return (get_expected_points($offhref, $distance_from_goal),
          get_expected_points($defhref, $distance_from_goal));
}

sub PrintableName($$) {
  my $href = shift;
  my $name = shift;
  return undef if (!defined($name));
  my $printable_name = $$href{$name};
  return $name if (!defined($printable_name));
  return $printable_name;
}

sub LoadRanksAndStats($$$$$$) {
  my $filename = shift;
  my $wpct_href = shift;
  my $sos_href = shift;
  my $oeff_href = shift;
  my $deff_href = shift;
  my $pace_href = shift;
  open(RANKINGS, "$filename") or do {
    warn "Could not open ranking file $filename: $!";
    return 1;
  };
  while(<RANKINGS>) {
    next unless(/^RANKING/);
    chomp;
    my @d = split(/,/);
    if (scalar(@d) < 8) {
      warn "Invalid ranking line: \"$_\"";
      next;
    }
    my $week_num = $d[1];
    my $team_id = $d[2];
    $$wpct_href{$week_num}{$team_id} = $d[3];
    $$sos_href{$week_num}{$team_id} = $d[4] if (defined($sos_href));
    $$oeff_href{$week_num}{$team_id} = $d[5] if (defined($oeff_href));
    $$deff_href{$week_num}{$team_id} = $d[6] if (defined($deff_href));
    $$pace_href{$week_num}{$team_id} = $d[-1] if (defined($pace_href));
  }
  close(RANKINGS);
  return 0;
}

sub LoadCurrentRankings($$$$) {
  my $filename = shift;
  my $id2conf_href = shift;
  my $wpct_href = shift;
  my $rank_href = shift;
  my %all_wpcts;
  my $rc = LoadRanksAndStats($filename, \%all_wpcts, undef, undef, undef, undef);
  if ($rc) {
    warn "Error loading $filename";
    return 1;
  }
  $rc = FetchWeekRankings(\%all_wpcts, undef, undef, undef, undef, -1,
                          $wpct_href, undef, undef, undef, undef);
  if ($rc) {
    warn "Error fetching most recent rankings from $filename";
    return 1;
  }
  RankValues($wpct_href, $rank_href, 1, $id2conf_href);
  return 0;
}

sub LoadCurrentRanksAndStats($$$$$$) {
  my $filename = shift;
  my $wpct_href = shift;
  my $sos_href = shift;
  my $oeff_href = shift;
  my $deff_href = shift;
  my $pace_href = shift;
  my %all_wpcts;
  my %all_sos;
  my %all_oeff;
  my %all_deff;
  my %all_pace;
  my $rc = LoadRanksAndStats($filename, \%all_wpcts, \%all_sos, \%all_oeff, \%all_deff, \%all_pace);
  if ($rc) {
    warn "Error loading $filename";
    return 1;
  }
  $rc = FetchWeekRankings(\%all_wpcts, \%all_sos, \%all_oeff, \%all_deff, \%all_pace, -1,
                          $wpct_href, $sos_href, $oeff_href, $deff_href, $pace_href);
  if ($rc) {
    warn "Error fetching most recent rankings from $filename";
    return 1;
  }
  return 0;
}

sub FetchWeekRankings($$$$$$$$$$$) {
  my $all_wpct_href = shift;
  my $all_sos_href = shift;
  my $all_oeff_href = shift;
  my $all_deff_href = shift;
  my $all_pace_href = shift;
  my $week_num = shift;
  my $wpct_href = shift;
  my $sos_href = shift;
  my $oeff_href = shift;
  my $deff_href = shift;
  my $pace_href = shift;

  # If the week_num < 0 then we do the most recent (-1),
  # next-to-most-recent (-2), etc.
  # If the week_num > 0 then we use that as the week number.
  if ($week_num < 0) {
    my @weeks = sort { $a <=> $b } keys %$all_wpct_href;
    $week_num = $weeks[$week_num];
  }
  if (!defined($$all_wpct_href{$week_num})) {
    warn "No data for week number $week_num";
    return 1;
  }
  my $h;
  $h = $$all_wpct_href{$week_num};
  %$wpct_href = %$h;
  if (defined($sos_href)) {
    $h = $$all_sos_href{$week_num};
    %$sos_href = %$h;
  }
  if (defined($oeff_href)) {
    $h = $$all_oeff_href{$week_num};
    %$oeff_href = %$h;
  }
  if (defined($deff_href)) {
    $h = $$all_deff_href{$week_num};
    %$deff_href = %$h;
  }
  if (defined($pace_href)) {
    $h = $$all_pace_href{$week_num};
    %$pace_href = %$h;
  }
  return 0;
}

sub RankValues($$$$) {
  my $value_href = shift;
  my $rank_href = shift;
  my $upgood = shift;
  my $id2conf_href = shift;
  $upgood = 1 if (!defined($upgood));
  my @teams;
  if ($upgood) {
    @teams = sort { $$value_href{$b} <=> $$value_href{$a} } keys %$value_href;
  } else {
    @teams = sort { $$value_href{$a} <=> $$value_href{$b} } keys %$value_href;
  }
  my $r = 1;
  foreach my $team_id (@teams) {
    if (defined($id2conf_href)) {
      my $c = $$id2conf_href{$team_id};
      next if (defined($c) and $c eq "FCS");
    }
    $$rank_href{$team_id} = $r++;
  }
}

# Output:
# IsNeutral,HomeID,HomeScore,AwayID,AwayScore,OddsFav,NumPlays
sub LoadPredictions($$$) {
  my $filename = shift;
  my $do_all = shift;
  my $predict_href = shift;
  LoadPredictionsOddsMode($filename, $do_all, 0, $predict_href);
}

sub LoadPredictionsOddsMode($$$$) {
  my $filename = shift;
  my $do_all = shift;
  my $odds_home = shift;
  my $predict_href = shift;
  open (PREDICT, "$filename") or do {
    warn "Error opening $filename for reading: $!";
    return 1;
  };
  while(<PREDICT>) {
    if ($do_all) {
      next unless (/^PREDICT,/);
    } else {
      next unless (/^PREDICT,ALLDONE,/);
    }
    chomp;
    s/\s//g;
    @_ = split(/,/);
    # Put the is_neutral first
    my $gid = $_[2];
    my @info = ($_[3]);
    # Home ID and score
    push(@info, $_[4], $_[5]);
    # Away ID and score
    push(@info, $_[6], $_[7]);
    # Odds
    my $odds = $_[8];
    if (!$odds_home and ($odds < 500)) {
      $odds = 1000 - $odds;
    }
    push(@info, ($odds / 1000));
    # Predicted number of plays.
    push(@info, $_[9]);
    $$predict_href{$gid} = \@info;
  }
  close(PREDICT);
  return 0;
}

sub LoadResults($) {
  my $result_href = shift;
  return LoadResultsFromFileForSeason($SUMMARYFILE, undef, $result_href);
}

sub LoadPartialResults($$) {
  my $result_file = shift;
  my $result_href = shift;
  return LoadResultsFromFileForSeason($result_file, undef, $result_href);
}

sub LoadResultsFromFile($$) {
  my $result_file = shift;
  my $result_href = shift;
  return LoadResultsFromFileForSeason($result_file, undef, $result_href);
}

sub LoadResultsForSeason($$) {
  my $season = shift;
  my $result_href = shift;
  return LoadResultsFromFileForSeason($SUMMARYFILE, $season, $result_href);
}

sub LoadResultsForSeasonBeforeDate($$$) {
  my $season = shift;
  my $max_date = shift;
  my $result_href = shift;
  return LoadResultsFromFileForSeasonBeforeDate($SUMMARYFILE, $season, $max_date, $result_href);
}

sub LoadResultsFromFileForSeason($$$) {
  my $result_file = shift;
  my $season = shift;
  my $result_href = shift;
  return LoadResultsFromFileForSeasonBeforeDate($result_file, $season, undef, $result_href);
}

sub LoadResultsFromFileForSeasonBeforeDate($$$$) {
  my $result_file = shift;
  my $season = shift;
  my $max_date = shift;
  my $result_href = shift;
  open(SUMMARIES, "$result_file") or do {
    warn "Error opening $result_file for reading: $!";
    return 1;
  };
  while(<SUMMARIES>) {
    next if (/^#/);
    chomp;
    my @p = split(/,/);
    my $gid = $p[2];
    my $date = substr($gid, 0, 8);
    if (defined($season)) {
      next if ($season ne DateToSeason($date));
    }
    if (defined($max_date)) {
      next if $date ge $max_date;
    }
    $$result_href{$gid} = \@p;
  }
  close(SUMMARIES);
  return 0;
}

sub DatesToWeek($$) {
  my $results_href = shift;
  my $href = shift;
  foreach my $gid (keys %$results_href) {
    my $aref = $$results_href{$gid};
    $$href{$$aref[1]} = $$aref[0];
  }
}

sub SeasonAndWeekToDates($$$) {
  my $season = shift;
  my $week = shift;
  my $date_to_week_href = shift;
  my $min_absweek_for_season = undef;
  foreach my $date (keys %$date_to_week_href) {
    my $dateabsweek = $$date_to_week_href{$date};
    my $dateseason = int($dateabsweek / 52) + 2000;
    if ($dateseason == $season) {
      if (!defined($min_absweek_for_season)) {
        $min_absweek_for_season = $dateabsweek;
      } elsif ($dateabsweek < $min_absweek_for_season) {
        $min_absweek_for_season = $dateabsweek;
      }
    }
  }
  return undef if (!defined($min_absweek_for_season));
  my %possible_dates;
  my $target_absweek = $min_absweek_for_season + $week - 1;
  foreach my $date (keys %$date_to_week_href) {
    my $dateabsweek = $$date_to_week_href{$date};
    if (abs($target_absweek - $dateabsweek) <= 1) {
      $possible_dates{$date} = 1;
    }
  }
  return keys %possible_dates;
}

sub LoadColors($) {
  my $href = shift;
  open(COLORFILE, "$COLORFILE") or do {
    warn "Could not open $COLORFILE for reading: $!";
    return 1;
  };
  while(<COLORFILE>) {
    next if (/^#/);
    chomp;
    my ($id, $color) = split(/,/);
    next if (!defined($color));
    $$href{$id} = $color;
  }
  close(COLORFILE);
  return 0;
}

sub ResultsToTeamSeasons($$) {
  my $results_href = shift;
  my $team_seasons_href = shift;
  foreach my $gid (sort keys %$results_href) {
    my ($date, $home_id, $away_id);
    if ($gid =~ /(\d{8})-(\d{4})-(\d{4})/) {
      $date = $1;
      $home_id = $2;
      $away_id = $3;
    } else {
      warn "Invalid gid: $gid";
      next;
    }
    my $season = DateToSeason($date);
    next if ($season < 0);
    my $aref = $$team_seasons_href{$home_id}{$season};
    if (!defined($aref)) {
      my @a;
      $$team_seasons_href{$home_id}{$season} = $aref = \@a;      
    }
    push(@$aref, $gid);
    $aref = $$team_seasons_href{$away_id}{$season};
    if (!defined($aref)) {
      my @a;
      $$team_seasons_href{$away_id}{$season} = $aref = \@a;      
    }
    push(@$aref, $gid);
  }
}

sub GetAllTeamRecords($$$$$$) {
  my $results_href = shift;
  my $conf_href = shift;
  my $per_year_wins_href = shift;
  my $per_year_conf_wins_href = shift;
  my $per_year_losses_href = shift;
  my $per_year_conf_losses_href = shift;

  # Go through the summary file and build the mappings of existing game results to
  # teams on a per-year basis.
  my $lastyear = 0;
  my %teams;
  foreach my $gid (keys %$results_href) {
    my $r_aref = $$results_href{$gid};
    my @g = @$r_aref;
    my $week = $g[0];
    my $game_date = $g[1];
    # Since each year has 52w1d in it (leap years have 52w2d) and since week 0 is
    # the first week of the 2000-01 season, this next statement is good for about
    # 40 years' worth of football seasons.
    my $year = int($week / 52) + 2000;
    $lastyear = $year if ($year > $lastyear);
    my $homeid = $g[5];
    my $homescore = $g[7];
    my $awayid = $g[8];
    my $awayscore = $g[10];
    $teams{$homeid} = $teams{$awayid} = 1;
    next if (!$homescore and !$awayscore);
    my ($hwin, $hloss, $awin, $aloss);
    if ($homescore > $awayscore) {
      $hwin = $aloss = 1;
      $hloss = $awin = 0;
    } else {
      $hwin = $aloss = 0;
      $hloss = $awin = 1;
    }
    $$per_year_wins_href{$homeid}{$year} += $hwin;
    $$per_year_losses_href{$homeid}{$year} += $hloss;
    $$per_year_wins_href{$awayid}{$year} += $awin;
    $$per_year_losses_href{$awayid}{$year} += $aloss;
    # If we know the conference of both teams and they're the same, add this to
    # the conference standings.
    next if (!defined($conf_href));
    next if (!defined($per_year_conf_wins_href));
    next if (!defined($per_year_conf_losses_href));
    my $homeconf = $$conf_href{$homeid};
    my $awayconf = $$conf_href{$awayid};
    if (defined($homeconf) and defined($awayconf) and ($homeconf eq $awayconf)) {
      $$per_year_conf_wins_href{$homeid}{$year} += $hwin;
      $$per_year_conf_losses_href{$homeid}{$year} += $hloss;
      $$per_year_conf_wins_href{$awayid}{$year} += $awin;
      $$per_year_conf_losses_href{$awayid}{$year} += $aloss;
    }
  }
  # Go through and put a defined value in each per-team-per-year register.
  foreach my $teamid (keys %teams) {
    if (!defined($$per_year_wins_href{$teamid}{$lastyear})) {
      $$per_year_wins_href{$teamid}{$lastyear} = 0;
    }
    if (!defined($$per_year_losses_href{$teamid}{$lastyear})) {
      $$per_year_losses_href{$teamid}{$lastyear} = 0;
    }
    next if (!defined($conf_href));
    next if (!defined($per_year_conf_wins_href));
    next if (!defined($per_year_conf_losses_href));
    if (!defined($$per_year_conf_wins_href{$teamid}{$lastyear})) {
      $$per_year_conf_wins_href{$teamid}{$lastyear} = 0;
    }
    if (!defined($$per_year_conf_losses_href{$teamid}{$lastyear})) {
      $$per_year_conf_losses_href{$teamid}{$lastyear} = 0;
    }
  }
}

sub PrintComparisonSeasons($$$$$$$$$$$) {
  my $weeks_href = shift;
  my $id2name_href = shift;
  my $names_href = shift;
  my $seasons_aref = shift;
  my $team_id = shift;
  my $team_seasons_href = shift;
  my $results_href = shift;
  my $predictions_a_href = shift;
  my $all_wpcts_a_href = shift;
  my $predictions_b_href = shift;
  my $all_wpcts_b_href = shift;

  foreach my $season (@$seasons_aref) {
    if (!defined($$team_seasons_href{$team_id}{$season})) {
      warn "Cannot find season for $team_id $season";
      return;
    }
  }

  print "<link rel=\"stylesheet\" type=\"text/css\" href=\"ncaa.css\" />\n";
  foreach my $season (@$seasons_aref) {
    my $season_aref = $$team_seasons_href{$team_id}{$season};
    print "<table class=\"pred-table\">\n";
    # Hard code this to have the TFG header colors.
    print "<tr valign=\"bottom\" class=\"tfg\">\n";
    print "  <th>Date</th>\n";
    print "  <th><span class=\"rank\">TFG</span></th>\n";
    print "  <th><span class=\"rank\">RBA</span></th>\n";
    print "  <th colspan=\"2\">Away Team</th>\n";
    print "  <th>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</th>\n";
    print "  <th><span class=\"rank\">TFG</span></th>\n";
    print "  <th><span class=\"rank\">RBA</span></th>\n";
    print "  <th colspan=\"2\">Home Team</th>\n";
    print "  <th>Plays</th>\n";
    print "  <th colspan=\"2\">Odds<br /><span class=\"rank\">TFG / RBA</span></th>\n";
    print "</tr>\n";
    foreach my $game_id (sort @$season_aref) {
      print_game_info_compare($weeks_href, $id2name_href, $names_href, $game_id,
                              $team_id, $results_href, $all_wpcts_a_href,
                              $predictions_a_href, $all_wpcts_b_href,
                              $predictions_b_href);
    }
    print "</table>\n";
    print "<br />\n<br />\n";
  }
}

sub PrintSeasons($$$$$$$$$$) {
  my $weeks_href = shift;
  my $id2name_href = shift;
  my $names_href = shift;
  my $seasons_aref = shift;
  my $team_id = shift;
  my $team_seasons_href = shift;
  my $results_href = shift;
  my $predictions_href = shift;
  my $all_wpcts_href = shift;
  my $pred_system = shift;

  foreach my $season (@$seasons_aref) {
    if (!defined($$team_seasons_href{$team_id}{$season})) {
      warn "Cannot find season for $team_id $season";
      return;
    }
  }

  print "<link rel=\"stylesheet\" type=\"text/css\" href=\"ncaa.css\" />\n";
  foreach my $season (@$seasons_aref) {
    my $season_aref = $$team_seasons_href{$team_id}{$season};
    print "<table class=\"pred-table\">\n";
    print "<tr class=\"$pred_system\">\n";
    print "  <th>Date</th>\n";
    print "  <th colspan=\"3\">Away Team</th>\n";
    print "  <th>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</th>\n";
    print "  <th colspan=\"3\">Home Team</th>\n";
    print "  <th>Plays</th>\n";
    print "  <th>Odds</th>\n";
    print "</tr>\n";
    foreach my $game_id (sort @$season_aref) {
      print_game_info($weeks_href, $id2name_href, $names_href, $game_id, $team_id,
                      $results_href, $all_wpcts_href, $predictions_href);
    }
    print "</table>\n";
    print "<br />\n<br />\n";
  }
}

sub PrintTeamHeaders($$$$$$) {
  my $id2name_href = shift;
  my $full_names_href = shift;
  my $all_data_href = shift;
  my $team_id = shift;
  my $seasons_aref = shift;
  my $pred_system = shift;

  foreach my $season (@$seasons_aref) {
    if (!defined($YEAR_TO_WEEK{$season})) {
      warn "No week data for $season season";
      return;
    }
  }

  my $all_wpcts_href = $$all_data_href{"WPCTS"};
  my $all_sos_href = $$all_data_href{"SOS"};
  my $all_oeff_href = $$all_data_href{"OEFF"};
  my $all_deff_href = $$all_data_href{"DEFF"};
  my $all_pace_href = $$all_data_href{"PACE"};

  my $team_shortname = $$id2name_href{$team_id};
  printf "<table class=\"rank-table\">\n  <tbody>\n";
  printf "  <tr class=\"$pred_system\">\n";
  printf "    <th colspan=\"12\">%s</th>\n", $$full_names_href{$team_shortname};
  printf "  </tr>\n";
  printf "  <tr class=\"$pred_system\">\n";
  printf "    <th>Year</th>\n";
  printf "    <th colspan=\"2\">WinPct</th>\n";
  printf "    <th colspan=\"2\">SoS</th>\n";
  printf "    <th colspan=\"2\">Off.</th>\n";
  printf "    <th colspan=\"2\">Def.</th>\n";
  printf "    <th colspan=\"2\">Pace</th>\n";
  printf "  </tr>\n";
  foreach my $season (@$seasons_aref) {
    my $week = $YEAR_TO_WEEK{$season};
    my %wpct;
    my %sos;
    my %oeff;
    my %deff;
    my %pace;
    my %wpct_rank;
    my %sos_rank;
    my %oeff_rank;
    my %deff_rank;
    my %pace_rank;
    my $rc =  FetchWeekRankings($all_wpcts_href, $all_sos_href, $all_oeff_href,
                                $all_deff_href, $all_pace_href, $week,
                                \%wpct, \%sos, \%oeff, \%deff, \%pace);
    if ($rc) {
      # Nothing for the requested week. Try the most recent one.
      my $rc =  FetchWeekRankings($all_wpcts_href, $all_sos_href, $all_oeff_href,
                                  $all_deff_href, $all_pace_href, -1,
                                  \%wpct, \%sos, \%oeff, \%deff, \%pace);
      if ($rc) {
        warn "No rankings at all?!?";
        return;
      }
    }
    RankValues(\%wpct, \%wpct_rank, 1, undef);
    RankValues(\%sos, \%sos_rank, 1, undef);
    RankValues(\%oeff, \%oeff_rank, 1, undef);
    RankValues(\%deff, \%deff_rank, 0, undef);
    RankValues(\%pace, \%pace_rank, 1, undef);
  
    printf "  <tr class=\"evenRow\">\n";
    printf "    <td class=\"stats\">%d</td>\n", $season;
    printf "    <td class=\"stats\">%.3f</td>\n", $wpct{$team_id};
    printf "    <td class=\"subRank\">%d</td>\n", $wpct_rank{$team_id};
    printf "    <td class=\"stats\">%.3f</td>\n", $sos{$team_id};
    printf "    <td class=\"subRank\">$sos_rank{$team_id}</td>\n";
    printf "    <td class=\"stats\">$oeff{$team_id}</td>\n";
    printf "    <td class=\"subRank\">$oeff_rank{$team_id}</td>\n";
    printf "    <td class=\"stats\">$deff{$team_id}</td>\n";
    printf "    <td class=\"subRank\">$deff_rank{$team_id}</td>\n";
    printf "    <td class=\"stats\">$pace{$team_id}</td>\n";
    printf "    <td class=\"subRank\">$pace_rank{$team_id}</td>\n";
    printf "  </tr>\n";
  }
  print "</table>\n";
}

sub CalculateGugs($$$$$) {
  my $tfg_pred_href = shift;
  my $rba_pred_href = shift;
  my $tfg_wpct_href = shift;
  my $rba_wpct_href = shift;
  my $gugs_href = shift;
  foreach my $gid (keys %$tfg_pred_href) {
    my @p = get_game_components($gid, $tfg_pred_href, $rba_pred_href,
                                $tfg_wpct_href, $rba_wpct_href);
    my $gugs = sprintf "%4.1f", calculate_gugs($p[0], $p[1], $p[2]);
    push(@p, $gugs);
#    print "<!-- GUGS $gid $gugs $c $g $e -->\n";
    $$gugs_href{$gid} = \@p;
  }
}

sub LoadInGamePredictions($$$$) {
  my $directory = shift;
  my $tag = shift;
  my $pergame_href = shift;
  my $gametime_href = shift;
  my $cmd = "find $directory -name 'ingame.*.txt'";
  open(CMD, "$cmd|") or die "Can't execute \"$cmd\": $!";
  my @files = <CMD>;
  close(CMD);
  chomp @files;

  my $last_timestamp = -1;
  foreach my $f (sort @files) {
    open(F, "$f") or next;
    my @s = stat F;
    $last_timestamp = $s[9] if ($s[9] > $last_timestamp);
    while(<F>) {
      next if (/^#/);
      chomp;
      # 20111122-1519-1414,TFG,1519,21,1414,14,3600,1.0
      my ($gid, $ptag, $l) = split(/,/, $_, 3);
      next unless ($tag eq $ptag);
      my @g = split(/,/, $l);
      my $t = $g[4];
      # If t=0 then there should be no score yet.
      next if (!$t and ($g[1] or $g[3]));
      if (!defined($$pergame_href{$gid}{$t})) {
        $$pergame_href{$gid}{$t} = $l;
      } else {
        $$pergame_href{$gid}{$t} = get_primary_line($$pergame_href{$gid}{$t}, $l);
      }
      if (defined($$gametime_href{$gid})) {
        $$gametime_href{$gid} = $t if ($t > $$gametime_href{$gid});
      } else {
        $$gametime_href{$gid} = $t;
      }
    }
    close(F);
  }
  return $last_timestamp;
}

sub DateToSeason($) {
  my $d = shift;
  my $year = substr($d, 0, 4);
  my $month = substr($d, 4, 2);
  if ($year < 2000 or $year > ($CURRENT_SEASON + 1)) {
    return -1;
  }
  return $year - (($month eq "01") ? 1 : 0);
}

# Args:
# 0) Call hierarchy
# 1) combined real/simulated results
# 2) The set of teams we wish to rank against each other
# 3) The set of teams who are allowable opponents
# 4) Where we store the final rankings
# 5) Should we print the results?
sub SortTeamsByResults($$$$$$);
sub SortTeamsByResults($$$$$$) {
  my $calls_aref = shift;
  my $simres_href = shift;
  my $teams_aref = shift;
  my $opp_teams_aref = shift;
  my $rank_href = shift;
  my $do_print = shift;

  my $opp_teams = "(all)";
  $opp_teams = join(', ', @$opp_teams_aref) if defined($opp_teams_aref);
#  print "[ " . join(', ', @$calls_aref) . " ] [ " . join(', ', @$teams_aref)
#        . " ] [ $opp_teams ]\n";

  my %ranks;
  my %team_wpct;
  rank_teams_allow_ties($simres_href, $teams_aref, $opp_teams_aref, \%ranks, \%team_wpct);
  foreach my $rank (sort { $a <=> $b } keys %ranks) {
    my $this_rank_aref = $ranks{$rank};
    if (scalar(@$this_rank_aref) == 1) {
#      print "[Solo] $rank $$this_rank_aref[0]\n" if (!$do_print);
      # There is only one team at this rank.
      $$rank_href{$rank} = $this_rank_aref;
    } elsif (defined($opp_teams_aref) and scalar(@$this_rank_aref) == scalar(@$opp_teams_aref)) {
      # This was a head-to-head matchup where everyone tied. Assign everyone to
      # one rank and kick it back up for the next tiebreaker.
      $$rank_href{$rank} = $this_rank_aref;
#      print "[Child] Sub-H2H tie between " . join(', ', @$this_rank_aref) . "\n";
    } elsif (!defined($opp_teams_aref) and scalar(@$this_rank_aref) == scalar(@$teams_aref)) {
      # This was an attempt at a full head-to-head test and everyone tied.
      $$rank_href{$rank} = $this_rank_aref;
#      print "[Child] Full H2H tie amongst " . join(', ', @$this_rank_aref) . "\n";
    } else {
      # Some of the teams we were trying to distinguish between each other are at
      # this ranking. First, let's look at their head-to-head records.
      my %h2h_ranks;
      push(@$calls_aref, "H2H");
      SortTeamsByResults($calls_aref, $simres_href, $this_rank_aref, $this_rank_aref, \%h2h_ranks, 0);
      if (scalar(keys %h2h_ranks) == 1) {
        my $h2haref = $h2h_ranks{1};
#        print "[Parent] Head-to-head tie amongst " . join(', ', @$h2haref) . "\n";
        # Everyone tied in the head-to-head. This means everyone:
        # a) has the same record against @$opp_teams_aref; and
        # b) has the same record against each other.
        # Is there a difference between the number of teams in @$teams_aref and
        # @$opp_teams_aref?
        if (defined($opp_teams_aref) and scalar(@$teams_aref) != scalar(@$opp_teams_aref)) {
          # Yes. Try ranking the teams against their subconference.
          my %subconf_ranks;
          push(@$calls_aref, "SubConf");
          SortTeamsByResults($calls_aref, $simres_href, $this_rank_aref, $teams_aref, \%subconf_ranks, 0);
          if (scalar(keys %subconf_ranks) == 1) {
            # Everyone tied in the subconference head-to-head.
            my %full_rank;
            push(@$calls_aref, "Full");
            SortTeamsByResults($calls_aref, $simres_href, $this_rank_aref, undef, \%full_rank, 0);
            foreach my $full_r (keys %full_rank) {
              my $r = $rank + $full_r - 1;
              $$rank_href{$r} = $full_rank{$full_r};
            }
            pop(@$calls_aref);
          } else {
            foreach my $subconf_r (sort { $a <=> $b } keys %subconf_ranks) {
              my $r = $rank + $subconf_r - 1;
              my $subc_aref = $subconf_ranks{$subconf_r};
              $$rank_href{$r} = $subc_aref;
            }
          }
          pop(@$calls_aref);
        } else {
          # This is a single-division conference. This means all the teams here
          # a) have the same record against @$opp_teams_aref;
          # b) have the same record in head-to-head; and
          # c) have no chance of breaking the tie against a subset of the teams.
          # Try breaking a tie using their record against EVERYONE.
          my %full_rank;
          push(@$calls_aref, "Full");
          SortTeamsByResults($calls_aref, $simres_href, $this_rank_aref, undef, \%full_rank, 0);
          foreach my $full_r (keys %full_rank) {
            my $r = $rank + $full_r - 1;
            $$rank_href{$r} = $full_rank{$full_r};
          }
          pop(@$calls_aref);
        }
      } else {
        # Head-to-head yielded some differences. For now assign these ranks.
        # TODO: Break ties here.
        foreach my $h2h_rank (keys %h2h_ranks) {
          my $subr = $rank + $h2h_rank - 1;
          my $subr_teams_aref = $h2h_ranks{$h2h_rank};
          $$rank_href{$subr} = $h2h_ranks{$h2h_rank};
        }
      }
      pop(@$calls_aref);
    }
  }
  return 1;
}

############################# Internal Functions ###############################
sub get_primary_line($$) {
  my $a = shift;
  my $b = shift;
  if ($a eq $b) {
    return $a;
  }
  my @aa = split(/,/, $a);
  my @bb = split(/,/, $b);
  my $c = $bb[1] <=> $aa[1];
  if ($c < 0) {
    return $b;
  } elsif ($c > 1) {
    return $a;
  }
  $c = $bb[3] <=> $aa[3];
  if ($c < 0) {
    return $b;
  } else {
    return $a;
  }
}

sub get_game_components($$$$$) {
  my $gid = shift;
  my $tfg_pred_href = shift;
  my $rba_pred_href = shift;
  my $tfg_wpct_href = shift;
  my $rba_wpct_href = shift;
  my ($closeness, $goodness, $excitement) = (0, 0, 0);
  my ($home_id, $away_id);
  if ($gid =~ /\d{8}-(\d{4})-(\d{4})/) {
    $home_id = $1;
    $away_id = $2;
  } else {
    warn "Malformed GID: $gid";
    return ($closeness, $goodness, $excitement);
  }
  # There are three elements:
  # 1) Closeness (close to 0.500)
  # 2) Goodness (winning percent of the teams)
  # 3) Excitement (high scoring)
  # First, get the prediction for each system.
  my $tfg_aref = $$tfg_pred_href{$gid};
  my $rba_aref = $$rba_pred_href{$gid};
  if (!defined($tfg_aref)) {
#    warn "Missing TFG prediction for game $gid";
    return ($closeness, $goodness, $excitement);
  }
  if (!defined($rba_aref)) {
#    warn "Missing RBA prediction for game $gid";
    return ($closeness, $goodness, $excitement);
  }
  # Base it on the odds of the home team winning
  my $tfg_home_win = $$tfg_aref[5];
  if ($$tfg_aref[4] > $$tfg_aref[2]) {
    $tfg_home_win = 1 - $tfg_home_win;
  }
  my $rba_home_win = $$rba_aref[5];
  if ($$rba_aref[4] > $$rba_aref[2]) {
    $rba_home_win = 1 - $rba_home_win;
  }
  # $avg_home_win will be in the range [0,1]
  my $avg_home_win = ($tfg_home_win + $rba_home_win) / 2;
  # Now in the range [0,0.5] (distance from a 0.500 game)
  $avg_home_win = abs(0.5 - $avg_home_win);
  # Now in the range [0,1] (2x distance from a 0.500 game)
  $avg_home_win *= 2;
  # Closeness is now how close it is to 0.500
  $closeness = sprintf "%.3f", 1 - $avg_home_win;
  # Goodness is the combined winning percentage
  my $tfg_home_wpct = $$tfg_wpct_href{$home_id};
  my $tfg_away_wpct = $$tfg_wpct_href{$away_id};
  if (!defined($tfg_home_wpct) or !defined($tfg_away_wpct)) {
#    warn "Missing winning percent for TFG for $home_id or $away_id";
    return ($closeness, $goodness, $excitement); 
  }
  my $rba_home_wpct = $$rba_wpct_href{$home_id};
  my $rba_away_wpct = $$rba_wpct_href{$away_id};
  if (!defined($rba_home_wpct) or !defined($tfg_away_wpct)) {
#    warn "Missing winning percent for RBA for $home_id or $away_id";
    return ($closeness, $goodness, $excitement); 
  }
  $goodness  = ($tfg_home_wpct + $tfg_away_wpct);
  $goodness += ($rba_home_wpct + $rba_away_wpct);
  $goodness = sprintf "%.3f", $goodness / 4;
  # Excitement is the score
  # Combined game scores are in the range [0,80] for our purposes
  my $tfg_score = ($$tfg_aref[2] + $$tfg_aref[4]) / 80;
  my $rba_score = ($$rba_aref[2] + $$rba_aref[4]) / 80;
  $excitement = sprintf "%.3f", ($tfg_score + $rba_score) / 2;
  return ($closeness, $goodness, $excitement); 
}

sub calculate_gugs($$$) {
  my $closeness = shift;
  my $goodness = shift;
  my $excitement = shift;
  my @weights = ( 2, 3, 1 );
  my $denominator = 0;
  foreach my $w (@weights) {
    $denominator += ($w * $w);
  }
  $closeness *= $weights[0];
  $goodness *= $weights[1];
  $excitement *= $weights[2];
  my $score = $closeness * $closeness;
  $score += ($goodness * $goodness);
  $score += ($excitement * $excitement);
  return 100 * ($score / $denominator);
}

sub print_game_info($$$$$$$$) {
  my $weeks_href = shift;
  my $id2name_href = shift;
  my $names_href = shift;
  my $gid = shift;
  my $team_id = shift;
  my $results_href = shift;
  my $all_wpcts_href = shift;
  my $predictions_href = shift;

  my $date = substr($gid, 0, 8);
  my $week = $$weeks_href{$date};
  if (!defined($week)) {
    warn "No week for $date";
    return;
  }
  my ($home_id, $away_id);
  if ($gid =~ /\d{8}-(\d{4})-(\d{4})/) {
    $home_id = $1;
    $away_id = $2;
  } else {
    warn "Invalid gid: $gid";
    return;
  }
  my $home_shortname = $$id2name_href{$home_id};
  if (!defined($home_shortname)) {
    warn "Could not find shortname for $home_id";
    return;
  }
  my $home_name = $$names_href{$home_shortname};
  if (!defined($home_name)) {
    warn "Could not find name for $home_shortname (team $home_id)";
    return;
  }
  my $away_shortname = $$id2name_href{$away_id};
  if (!defined($away_shortname)) {
    warn "Could not find shortname for $away_id";
    return;
  }
  my $away_name = $$names_href{$away_shortname};
  if (!defined($away_name)) {
    warn "Could not find name for $away_shortname (team $away_id)";
    return;
  }
  my %wpcts;
  my $rc =  FetchWeekRankings($all_wpcts_href, undef, undef, undef, undef,
                              $week, \%wpcts, undef, undef, undef, undef);
  if ($rc) {
    # No data for that week. Try the most recent one.
    $rc =  FetchWeekRankings($all_wpcts_href, undef, undef, undef, undef,
                             -1, \%wpcts, undef, undef, undef, undef);
    if ($rc) {
      warn "No rankings at all?!?";
      return;
    }
  }
  my %ranks;
  RankValues(\%wpcts, \%ranks, 1, undef);
  my $result_aref = $$results_href{$gid};
  my $pred_aref = $$predictions_href{$gid};
  if (!defined($pred_aref)) {
    warn "No prediction for game $gid";
    return;
  }
  my $home_rank = $ranks{$home_id};
  if (defined($home_rank)) {
    $home_rank = sprintf "%3d", $home_rank;
  } else {
    $home_rank = " NA";
  }
  $home_rank =~ s/\ /&nbsp;/g;
  my $away_rank = $ranks{$away_id};
  if (defined($away_rank)) {
    $away_rank = sprintf "%3d", $away_rank;
  } else {
    $away_rank = " NA";
  }
  $away_rank =~ s/\ /&nbsp;/g;
  my $row_class = "evenRow";
  my ($home_score, $away_score, $num_plays);
  if (defined($result_aref) and ($$result_aref[7] or $$result_aref[10])) {
    $home_score = $$result_aref[7];
    $away_score = $$result_aref[10];
    $num_plays  = $$result_aref[4];
    if ($home_id == $team_id) {
      # The team of interest is the home team ...
      if ($home_score > $away_score) {
        # ... and they won!
        $row_class = "winRow";
      } else {
        # ... but they lost!
        $row_class = "lossRow";
      }
    } else {
      # The team of interest is the away team ...
      if ($away_score > $home_score) {
        # ... and they won!
        $row_class = "winRow";
      } else {
        # ... but they lost!
        $row_class = "lossRow";
      }
    }
  } else {
    # Making a prediction.
    $home_score = $$pred_aref[2];
    $away_score = $$pred_aref[4];
    $num_plays = $$pred_aref[6];
    print "<!-- No result for $gid -->\n";
  }
  my $wpct = $$pred_aref[5];
  if ($wpct < 0.500) {
    $wpct = 1 - $wpct;
  }
  if ($home_id == $team_id) {
    # Team of interest is the home team ...
    if ($$pred_aref[2] > $$pred_aref[4]) {
      # ... and were the favorites.
      # So do nothing.
    } else {
      # ... and were the underdogs.
      $wpct = 1 - $wpct;
    }
  } else {
    # Team of interest is the away team ...
    if ($$pred_aref[2] < $$pred_aref[4]) {
      # ... and were the favorites.
      # So do nothing.
    } else {
      # ... and were the underdogs.
      $wpct = 1 - $wpct;
    }
  }
  printf "<tr class=\"%s\">\n", $row_class;
  printf "  <td class=\"stats\">%4d/%02d/%02d</td>\n", substr($date, 0, 4), substr($date, 4, 2), substr($date, 6, 2);
  printf "  <td><span class=\"rank\">%s</span></td>\n", $away_rank;
  printf "  <td class=\"teamName\">%s</td>\n", $away_name;
  printf "  <td align=\"right\">%d</td>\n", $away_score;
  printf "  <td class=\"font-size:small\" align=\"center\">%s</td>\n", ($$pred_aref[0] ? "vs" : "at");
  printf "  <td><span class=\"rank\">%s</span></td>\n", $home_rank;
  printf "  <td class=\"teamName\">%s</td>\n", $home_name;
  printf "  <td align=\"right\">%d</td>\n", $home_score;
  printf "  <td align=\"right\">%d</td>\n", $num_plays;
  printf "  <td><span class=\"rank\">%.1f%%</span></td>\n", 100 * $wpct;
  printf "</tr>\n";
}

sub print_game_info_compare($$$$$$$$$$) {
  my $weeks_href = shift;
  my $id2name_href = shift;
  my $names_href = shift;
  my $gid = shift;
  my $team_id = shift;
  my $results_href = shift;
  my $all_wpcts_a_href = shift;
  my $predictions_a_href = shift;
  my $all_wpcts_b_href = shift;
  my $predictions_b_href = shift;

  my $result_aref = $$results_href{$gid};
  if (!defined($result_aref)) {
    warn "No result line for game $gid";
    return;
  }
  my $date = substr($gid, 0, 8);
  my $week = $$weeks_href{$date};
  if (!defined($week)) {
    warn "No week for $date";
    return;
  }
  my ($home_id, $away_id);
  if ($gid =~ /\d{8}-(\d{4})-(\d{4})/) {
    $home_id = $1;
    $away_id = $2;
  } else {
    warn "Invalid gid: $gid";
    return;
  }
  my $home_shortname = $$id2name_href{$home_id};
  if (!defined($home_shortname)) {
    warn "Could not find shortname for $home_id";
    return;
  }
  my $home_name = $$names_href{$home_shortname};
  if (!defined($home_name)) {
    warn "Could not find name for $home_shortname (team $home_id)";
    return;
  }
  my $away_shortname = $$id2name_href{$away_id};
  if (!defined($away_shortname)) {
    warn "Could not find shortname for $away_id";
    return;
  }
  my $away_name = $$names_href{$away_shortname};
  if (!defined($away_name)) {
    warn "Could not find name for $away_shortname (team $away_id)";
    return;
  }

  my %wpcts_a;
  my %ranks_a;
  my $rc = get_wpcts_ranks($all_wpcts_a_href, $week, \%wpcts_a, \%ranks_a);
  if ($rc) {
    warn "No rankings for week $week?!?";
    return;
  }
  my %wpcts_b;
  my %ranks_b;
  $rc = get_wpcts_ranks($all_wpcts_b_href, $week, \%wpcts_b, \%ranks_b);
  if ($rc) {
    warn "No rankings for week $week?!?";
    return;
  }
  my $home_rank_a = get_rank_html(\%ranks_a, $home_id);
  my $away_rank_a = get_rank_html(\%ranks_a, $away_id);
  my $home_rank_b = get_rank_html(\%ranks_b, $home_id);
  my $away_rank_b = get_rank_html(\%ranks_b, $away_id);

  my $pred_aref_a = $$predictions_a_href{$gid};
  if (!defined($pred_aref_a)) {
    warn "No prediction for game $gid";
    return;
  }
  my $pred_aref_b = $$predictions_b_href{$gid};
  if (!defined($pred_aref_b)) {
    warn "No prediction for game $gid";
    return;
  }
  my $row_class = "evenRow";
  my ($home_score, $away_score, $num_plays);
  if (defined($result_aref) and ($$result_aref[7] or $$result_aref[10])) {
    $home_score = $$result_aref[7];
    $away_score = $$result_aref[10];
    $num_plays  = $$result_aref[4];
    if ($home_id == $team_id) {
      # The team of interest is the home team ...
      if ($home_score > $away_score) {
        # ... and they won!
        $row_class = "winRow";
      } else {
        # ... but they lost!
        $row_class = "lossRow";
      }
    } else {
      # The team of interest is the away team ...
      if ($away_score > $home_score) {
        # ... and they won!
        $row_class = "winRow";
      } else {
        # ... but they lost!
        $row_class = "lossRow";
      }
    }
  } else {
    # Making a prediction.
    $home_score = "--";
    $away_score = "--";
    $num_plays = "--";
    print "<!-- No result for $gid -->\n";
  }
  my $wpct_a = get_selected_wpct($pred_aref_a, $home_id, $away_id, $team_id);
  my $wpct_b = get_selected_wpct($pred_aref_b, $home_id, $away_id, $team_id);

  printf "<tr class=\"%s\">\n", $row_class;
  printf "  <td class=\"stats\">%4d/%02d/%02d</td>\n", substr($date, 0, 4), substr($date, 4, 2), substr($date, 6, 2);
  printf "  <td><span class=\"rank\">%s</span></td>\n", $away_rank_a;
  printf "  <td><span class=\"rank\">/&nbsp;%s</span></td>\n", $away_rank_b;
  printf "  <td class=\"teamName\">%s</td>\n", $away_name;
  printf "  <td align=\"right\">%s</td>\n", $away_score;
  printf "  <td class=\"font-size:small\" align=\"center\">%s</td>\n", ($$pred_aref_a[0] ? "vs" : "at");
  printf "  <td><span class=\"rank\">%s</span></td>\n", $home_rank_a;
  printf "  <td><span class=\"rank\">/&nbsp;%s</span></td>\n", $home_rank_b;
  printf "  <td class=\"teamName\">%s</td>\n", $home_name;
  printf "  <td align=\"right\">%s</td>\n", $home_score;
  printf "  <td align=\"right\">%s</td>\n", $num_plays;
  printf "  <td><span class=\"rank\">%s%%</span></td>\n", $wpct_a;
  printf "  <td><span class=\"rank\">/&nbsp;%s%%</span></td>\n", $wpct_b;
  printf "</tr>\n";
}

sub get_rank_html($$) {
  my $rank_href = shift;
  my $teamid = shift;
  my $rank = $$rank_href{$teamid};
  if (defined($rank)) {
    $rank = sprintf "%3d", $rank;
  } else {
    $rank = " NA";
  }
  $rank =~ s/\ /&nbsp;/g;
  return $rank;
}

sub get_selected_wpct($$$$) {
  my $pred_aref = shift;
  my $home_id = shift;
  my $away_id = shift;
  my $team_id = shift;
  my $wpct = $$pred_aref[5];
  if ($wpct < 0.500) {
    $wpct = 1 - $wpct;
  }
  if ($home_id == $team_id) {
    # Team of interest is the home team ...
    if ($$pred_aref[2] > $$pred_aref[4]) {
      # ... and were the favorites.
      # So do nothing.
    } else {
      # ... and were the underdogs.
      $wpct = 1 - $wpct;
    }
  } else {
    # Team of interest is the away team ...
    if ($$pred_aref[2] < $$pred_aref[4]) {
      # ... and were the favorites.
      # So do nothing.
    } else {
      # ... and were the underdogs.
      $wpct = 1 - $wpct;
    }
  }
  $wpct = sprintf "%5.1f", $wpct * 100;
  $wpct =~ s/\ /&nbsp;/g;
  return $wpct;
}

sub get_wpcts_ranks($$$$) {
  my $all_wpcts_href = shift;
  my $week = shift;
  my $wpcts_href = shift;
  my $rank_href = shift;
  
  my $rc =  FetchWeekRankings($all_wpcts_href, undef, undef, undef, undef,
                              $week, $wpcts_href, undef, undef, undef, undef);
  if ($rc) {
    # No data for that week. Try the most recent one.
    $rc =  FetchWeekRankings($all_wpcts_href, undef, undef, undef, undef,
                             -1, $wpcts_href, undef, undef, undef, undef);
    if ($rc) {
      warn "No rankings at all?!?";
      return $rc;
    }
  }
  RankValues($wpcts_href, $rank_href, 1, undef);
  return $rc;
}

sub load_lead_data() {
  return if (scalar keys %lead_data);
  open(LEAD, "$LEADFILE") or do {
    warn "Error opening lead file $LEADFILE: $!";
    return;
  };
  while(<LEAD>) {
    next if (/^#/);
    chomp;
    my @l = split(/,/);
    my $m = shift(@l);
    $lead_data{$m} = \@l;
  }
#  printf STDERR "Loaded %d second mark data:", scalar(keys %lead_data);
#  foreach my $s (keys %lead_data) {
#    my $aref = $lead_data{$s};
#    printf STDERR " [%4d %.6f %.6f]", $s, $$aref[0], $$aref[1];
#  }
#  print STDERR "\n";
  close(LEAD);
}

sub get_expected_points($$) {
  my $href = shift;
  my $distance = shift;
  return undef if (!defined($href) or ($distance < 1) or ($distance > 100));
  my @yards = sort { $a <=> $b } keys %$href;
  foreach my $yard (@yards) {
    next if ($distance > $yard);
    # Format: <slope>:<intercept>
    my ($m, $y0) = split(/:/, $$href{$yard});
    return $y0 + $m * $distance;
  }
  return undef;
}

sub load_position_points() {
  return if (scalar keys %field_position_points);
  open(POINTS, "$POSITIONFILE") or do {
    warn "Error opening lead file $POSITIONFILE: $!";
    return;
  };
  while(<POINTS>) {
    next if (/^#/);
    chomp;
    my ($offdef, $yard, $equation) = split(/,/);
    next if (!defined($equation));
    $field_position_points{$offdef}{$yard} = $equation;
  }
  close(POINTS);
}

sub weight_odds($$$) {
  my $first = shift;
  my $second = shift;
  my $dist_from_first = shift;
  return ($second * $dist_from_first) + ($first * (1 - $dist_from_first));
}

sub linear_interpolation($$) {
  my $lead_aref = shift;
  my $lead = shift;
#  printf STDERR "Linear Zero %.6f Slope %.6f Lead %2d\n", $$lead_aref[0], $$lead_aref[1], $lead;
  my $p = $$lead_aref[0] + $lead * $$lead_aref[1];
  return ($p <= 1.0) ? $p : 1.0;
}

sub distance($$$) {
  my $min = shift;
  my $mid = shift;
  my $max = shift;
  return ($mid - $min) / ($max - $min);
}

sub get_record_versus($$$$$$) {
  my $simres_href = shift;
  my $team_id = shift;
  my $opp_teams_href = shift;
  my $wins_href = shift;
  my $loss_href = shift;
  my $wpct_href = shift;

  my $res_href = $$simres_href{$team_id};
  return if (!defined($res_href));
  my ($num_wins, $num_loss) = (0, 0);
  while (my ($t1, $r) = each %$res_href) {
    next if (defined($opp_teams_href) and !defined($$opp_teams_href{$t1}));
    $num_wins += $r;
    $num_loss += !$r;
  }
  $$wins_href{$team_id} = $num_wins if defined($wins_href);
  $$loss_href{$team_id} = $num_loss if defined($loss_href);
  return unless defined($wpct_href);
  if ($num_wins or $num_loss) {
    $$wpct_href{$team_id} = sprintf "%.3f", $num_wins / ($num_wins + $num_loss);
  } else {
    $$wpct_href{$team_id} = "0.000";
  }
}

sub bin_teams_by_win_pct($$) {
  my $team_wpct_href = shift;
  my $bin_href = shift;
  while (my ($team_id, $wpct) = each %$team_wpct_href) {
    my $w_aref = $$bin_href{$wpct};
    if (!defined($w_aref)) {
      my @a;
      $$bin_href{$wpct} = $w_aref = \@a;
    }
    push(@$w_aref, $team_id);
  }
}

sub rank_teams_allow_ties($$$$$) {
  my $simres_href = shift;
  my $teams_aref = shift;
  my $opp_teams_aref = shift;
  my $rank_href = shift;
  my $wpct_href = shift;

  my %teams = map { $_ => 1 } @$teams_aref;
  my $opp_teams_href = undef;
  if (defined($opp_teams_aref)) {
    my %h = map { $_ => 1 } @$opp_teams_aref;
    $opp_teams_href = \%h;
  }

  my %team_wins;
  my %team_losses;
  my %team_wpct;
  foreach my $team_id (@$teams_aref) {
    get_record_versus($simres_href, $team_id, $opp_teams_href, \%team_wins, \%team_losses, \%team_wpct);
  }
  my %teams_by_wpct;
  bin_teams_by_win_pct(\%team_wpct, \%teams_by_wpct);
  my $p = 1;
  foreach my $wpct (sort { $b <=> $a } keys %teams_by_wpct) {
    my $aref = $teams_by_wpct{$wpct};
    $$rank_href{$p} = $aref;
    $p += scalar(@$aref);
    foreach my $tid (@$aref) {
      $$wpct_href{$tid} = $wpct;
    }
  }
}



##########


1;
