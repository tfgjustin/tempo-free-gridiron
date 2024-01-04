#!/usr/bin/perl 

use TempoFree;
use HTML::Parser;
use strict;
use warnings;
my %IGNORE_TAGS = ( "br" => 1, "hr" => 1, "img" => 1, "ul" => 1, "option" => 1);
my %START_CALLBACKS = ( "div"  => \&start_tag_div,
                        "tr"   => \&start_tag_tr,
                        "td"   => \&start_tag_td,
                        "a"    => \&start_tag_a,
                        "span" => \&start_tag_span,
                        "meta" => \&start_tag_meta,
                );

my %END_CALLBACKS = ( "div" => \&end_tag_div,
                      "td"  => \&end_tag_td,
                    );

my $CBSSPORTS_TFG = "data/cbssports2ncaa.txt";
my $CBSSPORTS_ABBR_TFG = "data/cbssportsabbr2ncaa.txt";

my %cbssportsIdToTfgId;
my %cbssportsAbbrToTfgId;

my $infile = shift(@ARGV);
my $outfile = shift(@ARGV);
my $logfile = shift(@ARGV);
exit 1 if (!defined($outfile) or ! -f $infile);

if (!defined($logfile) or !length($logfile)) {
  $logfile = "/dev/null";
}

my %id2name;
LoadIdToName(\%id2name);
my %results;
LoadResults(\%results);
my %dates_to_week;
DatesToWeek(\%results, \%dates_to_week);

open(OUTF, ">$outfile") or die "Cannot open outfile $outfile: $!";
open(LOGF, ">$logfile") or die "Cannot open logfile $logfile: $!";

# CBSsports IDs->TFG ID
sub load_cbssports_tfg();

# State machine management
sub increment_mode($);
sub set_mode($$);
sub revert_mode($);
# Start functions
sub start_tag_div($);
sub start_tag_tr($);
sub start_tag_td($);
sub start_tag_a($);
sub start_tag_span($);
sub start_tag_meta($);
# End functions
sub end_tag_div();
sub end_tag_td();
# Helper functions
sub print_and_reset_scores();
sub reset_scores();

# Modes
# Pre box score
my $MODE_PRE_BOX = 0;
# Found the header of the box score
my $MODE_FOUND_BOXHEADER = $MODE_PRE_BOX + 1;
# Found the header for the amount of time left
my $MODE_FOUND_TIMELEFT_HEADER = $MODE_FOUND_BOXHEADER + 1;
# Found the amount of time left
my $MODE_FOUND_TIMELEFT = $MODE_FOUND_TIMELEFT_HEADER + 1;
# Box score away team: header
my $MODE_AWAY_TEAMNAME = $MODE_FOUND_TIMELEFT + 1;
# Looking for the start of scores
my $MODE_AWAY_START_SCORES = $MODE_AWAY_TEAMNAME + 1;
# Box score away team: quater-by-quarter
my $MODE_AWAY_QUARTER = $MODE_AWAY_START_SCORES + 1;
# Box score away team: final score
my $MODE_AWAY_FINAL = $MODE_AWAY_QUARTER + 1;
# Post away-team box score
my $MODE_POST_AWAY = $MODE_AWAY_FINAL + 1;
# Box score home team: header
my $MODE_HOME_TEAMNAME = $MODE_POST_AWAY + 1;
# Looking for the start of scores
my $MODE_HOME_START_SCORES = $MODE_HOME_TEAMNAME + 1;
# Box score home team: quater-by-quarter
my $MODE_HOME_QUARTER = $MODE_HOME_START_SCORES + 1;
# Box score home team: final score
my $MODE_HOME_FINAL = $MODE_HOME_QUARTER + 1;
# Post home-team box score
my $MODE_POST_HOME = $MODE_HOME_FINAL + 1;
# Found the down and distance header tag
my $MODE_FOUND_DOWNDIST_TAG = $MODE_POST_HOME + 1;
# Found the down text
my $MODE_FOUND_DOWN_INFO = $MODE_FOUND_DOWNDIST_TAG + 1;
# Found the header for the distance
my $MODE_FOUND_DIST_TAG = $MODE_FOUND_DOWN_INFO + 1;
# Found the info for the distance
my $MODE_FOUND_DIST_INFO = $MODE_FOUND_DIST_TAG + 1;
# Found the header for the field position
my $MODE_FOUND_FIELDPOS_TAG = $MODE_FOUND_DIST_INFO + 1;
# Found the info for the field position
my $MODE_FOUND_FIELDPOS_INFO = $MODE_FOUND_FIELDPOS_TAG + 1;
# Start of a scoring play
my $MODE_START_SCORES = $MODE_FOUND_FIELDPOS_INFO + 1;
# Total score for both teams
my $MODE_SCORE_TOTALS = $MODE_START_SCORES + 1;
# GAME OVER, MAN
my $MODE_GAME_OVER = $MODE_SCORE_TOTALS + 1;

my %MODE_NAMES = (
    $MODE_PRE_BOX => "Pre box score",
    $MODE_FOUND_BOXHEADER => "Found game boxscore header",
    $MODE_FOUND_TIMELEFT_HEADER => "Found game time header",
    $MODE_FOUND_TIMELEFT => "Found game time",
    $MODE_AWAY_TEAMNAME => "Box score away team: name",
    $MODE_AWAY_START_SCORES=> "Box score away team: start of scores",
    $MODE_AWAY_QUARTER => "Box score away team: quater-by-quarter",
    $MODE_AWAY_FINAL => "Box score away team: final score",
    $MODE_POST_AWAY => "Post away-team box score",
    $MODE_HOME_TEAMNAME => "Box score home team: name",
    $MODE_HOME_START_SCORES=> "Box score home team: start of scores",
    $MODE_HOME_QUARTER => "Box score home team: quater-by-quarter",
    $MODE_HOME_FINAL => "Box score home team: final score",
    $MODE_POST_HOME => "Post home-team box score",
    $MODE_FOUND_DOWNDIST_TAG => "Found down and distance header",
    $MODE_FOUND_DOWN_INFO => "Found down info",
    $MODE_FOUND_DIST_TAG => "Found the distance header",
    $MODE_FOUND_DIST_INFO => "Found distance info",
    $MODE_FOUND_FIELDPOS_TAG => "Found the field position header",
    $MODE_FOUND_FIELDPOS_INFO => "Found field position info",
    $MODE_START_SCORES => "Start of a scoring play",
    $MODE_SCORE_TOTALS => "Current total scores",
    $MODE_GAME_OVER => "GAME OVER, MAN. GAME OVER"
  );

my $curr_mode = 0;
my $last_mode = 0;
# Use this to figure out when we've hit the end
my $div_nesting = 0;

my $season = undef;
my $week = undef;
my @possible_dates = ();

my $away_team_id = undef;
my $home_team_id = undef;
my $away_team_name = undef;
my $home_team_name = undef;
my $away_regulation_score = 0;
my $home_regulation_score = 0;
my $away_ot_score = 0;
my $home_ot_score = 0;
my $game_time_left = undef;
my $game_date = undef;
my @away_team_scores;
my @home_team_scores;
my $curr_team_name = undef;
my $curr_down = undef;
my $curr_dist = undef;
my $curr_side = undef;
my $curr_spot = undef;
my $team_poss = undef;

sub load_cbssports_tfg() {
  open(CBSSTFG, "$CBSSPORTS_TFG") or die "Can't open CBSsports->TFG mapping: $!";
  while(<CBSSTFG>) {
    chomp;
    @_ = split(/,/);
    $cbssportsIdToTfgId{$_[0]} = $_[1];
  }
  close(CBSSTFG);
}

sub load_cbssports_abbr_tfg() {
  open(CBSSTFG, "$CBSSPORTS_ABBR_TFG") or die "Can't open AbbrCBSsports->TFG mapping: $!";
  while(<CBSSTFG>) {
    next if (/^#/);
    chomp;
    @_ = split(/,/);
    $cbssportsAbbrToTfgId{$_[1]} = $_[0];
  }
  close(CBSSTFG);
  printf LOGF "Loaded %d abbreviations\n", scalar(keys %cbssportsAbbrToTfgId);
}

sub increment_mode($) {
  my $n = shift;
  my $next_mode = $curr_mode + 1;
  printf LOGF "Mode update: '%s' ~> '%s'%s\n",
              $MODE_NAMES{$curr_mode}, $MODE_NAMES{$next_mode},
              (defined($n) and length($n)) ? ", $n" : "";
  $last_mode = $curr_mode++;
}

sub set_mode($$) {
  my $m = shift;
  my $n = shift;
  $last_mode = $curr_mode;
  $curr_mode = $m;
  printf LOGF "Mode set: '%s' ~> '%s'%s\n",
              $MODE_NAMES{$last_mode}, $MODE_NAMES{$curr_mode},
              (defined($n) and length($n)) ? ", $n" : "";
}

sub revert_mode($) {
  my $n = shift;
  printf LOGF "Mode revert: '%s' ~> '%s'%s\n",
              $MODE_NAMES{$curr_mode}, $MODE_NAMES{$last_mode},
              (defined($n) and length($n)) ? ", $n" : "";

  my $t = $curr_mode;
  $curr_mode = $last_mode;
  $last_mode = $t;
}

sub start_tag_div($) {
  my $href = shift;
  if ($curr_mode == $MODE_PRE_BOX) {
    my $c = $$href{"class"};
    if (defined($c)) {
      if ($c =~ /^scoreBox/) {
        increment_mode("Found start of box score");
      }
    }
  } else {
    my $c = $$href{"class"};
    if (defined($c)) {
      if ($c =~ /^scoreBox/) {
        set_mode($MODE_PRE_BOX + 1, "Found out-of-order box score; attempting to print scores");
        print_and_reset_scores();
        return;
      }
    }
  }
  if ($curr_mode == $MODE_POST_HOME) {
    my $c = $$href{"class"};
    if (defined($c) and $c eq "downDistance") {
      increment_mode("Found downDistance header");
    }
  }
  if ($curr_mode >= $MODE_START_SCORES) {
    ++$div_nesting;
    print LOGF "Div nesting: $div_nesting\n";
  }
}

sub start_tag_span($) {
  my $href = shift;
  if ($curr_mode == $MODE_FOUND_BOXHEADER) {
    my $c = $$href{"class"};
    if (defined($c) and $c eq "gameDate") {
      set_mode($MODE_PRE_BOX, "Game has not yet started yet");
    }
  } elsif ($curr_mode == $MODE_AWAY_START_SCORES) {
    my $v = $$href{"class"};
    if (defined($v) and $v eq "teamPossession") {
      $team_poss = $away_team_id;
      print LOGF "Away team $team_poss has the ball\n";
    }
  } elsif ($curr_mode == $MODE_HOME_START_SCORES) {
    my $v = $$href{"class"};
    if (defined($v) and $v eq "teamPossession") {
      $team_poss = $home_team_id;
      print LOGF "Home team $team_poss has the ball\n";
    }
  }
}

sub start_tag_meta($) {
  my $href = shift;
  if ($curr_mode == $MODE_PRE_BOX) {
    my $c = $$href{"content"};
    if (defined($c) and $c =~ /collegefootball\/scoreboard\/FBS\/(\d{4})\/week(\d{1,2})/) {
      $season = $1;
      $week = $2;
      print LOGF "This scoreboard is for the $season season, week $week\n";
      if (!@possible_dates) {
        @possible_dates = SeasonAndWeekToDates($season, $week, \%dates_to_week);
        printf LOGF "Found %d possible dates\n", scalar(@possible_dates);
      }
    }
  }
}

sub start_tag_tr($) {
  my $href = shift;
  if ($curr_mode == $MODE_FOUND_TIMELEFT) {
    my $c = $$href{"class"};
    if (defined($c) and $c =~ /teamInfo awayTeam/) {
      increment_mode("Found away team header");
    }
  } elsif ($curr_mode == $MODE_POST_AWAY) {
    my $c = $$href{"class"};
    if (defined($c) and $c =~ /teamInfo homeTeam/) {
      increment_mode("Found home team header");
    }
  }
}

sub start_tag_td($) {
  my $href = shift;
  if ($curr_mode == $MODE_FOUND_BOXHEADER) {
    my $c = $$href{"class"};
    if (defined($c) and $c =~ /gameStatus/) {
      increment_mode("Found start of a box score");
    }
  } elsif ($curr_mode == $MODE_FOUND_TIMELEFT_HEADER) {
    my $c = $$href{"class"};
    if (defined($c) and $c eq "finalStatus") {
      $game_time_left = 0;
      increment_mode("Found finished game");
    }
  } elsif ($curr_mode == $MODE_AWAY_START_SCORES or $curr_mode == $MODE_HOME_START_SCORES) {
    my $c = $$href{"class"};
    if (defined($c) and $c eq "periodScore") {
      increment_mode("Found start of scores");
    }
  } elsif ($curr_mode == $MODE_AWAY_QUARTER or $curr_mode == $MODE_HOME_QUARTER) {
    my $c = $$href{"class"};
    if (defined($c) and $c eq "finalScore") {
      increment_mode("Found tag for final score");
    }
  }
}

sub start_tag_a($) {
  my $href = shift;
  my $url = $$href{"href"};
  if ($curr_mode == $MODE_AWAY_TEAMNAME) {
    if (defined($url) and $url =~ /^\/collegefootball\/teams\/page\/(\S+)\/.*$/) {
      $away_team_id = $cbssportsAbbrToTfgId{$1};
      if (!defined($away_team_id)) {
        set_mode($MODE_PRE_BOX,  "Unknown away team ID: $1");
        reset_scores();
        return;
      }
      $away_team_name = $id2name{$away_team_id};
      if (!defined($away_team_name)) {
        set_mode($MODE_PRE_BOX, "Unknown away team ID: $away_team_id");
        reset_scores();
        return;
      }
      increment_mode("Found away team: $away_team_id");
    }
  } elsif ($curr_mode == $MODE_HOME_TEAMNAME) {
    if (defined($url) and $url =~ /^\/collegefootball\/teams\/page\/(\S+)\/.*$/) {
      $home_team_id = $cbssportsAbbrToTfgId{$1};
      if (!defined($home_team_id)) {
        set_mode($MODE_PRE_BOX,  "Unknown home team ID: $1");
        reset_scores();
        return;
      }
      $home_team_name = $id2name{$home_team_id};
      if (!defined($home_team_name)) {
        set_mode($MODE_PRE_BOX, "Unknown home team ID: $home_team_id");
        reset_scores();
        return;
      }
      increment_mode("Found home team: $home_team_id");
    }
  } elsif ($curr_mode >= $MODE_POST_HOME) {
    if (defined($url)) {
      if ($url =~ /^\/collegefootball\/gametracker\/live\/NCAAF_(\d{8})_\S+@\S+$/) {
        $game_date = $1;
        set_mode($MODE_PRE_BOX, "Found game date; printing the score");
        print_and_reset_scores();
      } else {
        my $c = $$href{"class"};
        if (defined($c) and $c eq "scoreboardExtra") {
          set_mode($MODE_PRE_BOX, "Cannot find game date for game");
          print_and_reset_scores();
        }
      }
    }
  }
}

sub end_tag_div() {
  if ($curr_mode >= $MODE_START_SCORES) {
    --$div_nesting;
    print LOGF "Div nesting: $div_nesting\n";
    if ($div_nesting == 0) {
      set_mode($MODE_GAME_OVER, "We're done here, folks");
    }
  }
}

sub end_tag_td() {
  if ($curr_mode == $MODE_SCORE_TOTALS) {
    set_mode($MODE_START_SCORES, "Printed score line");
  } elsif ($curr_mode == $MODE_AWAY_TEAMNAME) {
    if (defined($curr_team_name)) {
      $away_team_id = $cbssportsAbbrToTfgId{$curr_team_name};
      print LOGF "TEAM NAME: $curr_team_name\n";
      $curr_team_name = undef;
    }
    if (!defined($away_team_id)) {
      set_mode($MODE_PRE_BOX, "Failed to get away team ID; resetting");
      reset_scores();
      return;
    }
    $away_team_name = $id2name{$away_team_id};
    if (!defined($away_team_name)) {
      set_mode($MODE_PRE_BOX, "Unknown away team ID: $away_team_id");
      reset_scores();
      return;
    }
    if (defined($team_poss) and $team_poss eq "AWAY") {
      $team_poss = $away_team_id;
      print LOGF "Away team $team_poss has the ball\n";
    }
    increment_mode("Found away team: $away_team_id");
  } elsif ($curr_mode == $MODE_HOME_TEAMNAME) {
    if (defined($curr_team_name)) {
      $home_team_id = $cbssportsAbbrToTfgId{$curr_team_name};
      print LOGF "TEAM NAME: $curr_team_name\n";
      $curr_team_name = undef;
    }
    if (!defined($home_team_id)) {
      set_mode($MODE_PRE_BOX, "Failed to get home team ID; resetting");
      reset_scores();
      return;
    }
    $home_team_name = $id2name{$home_team_id};
    if (!defined($home_team_name)) {
      set_mode($MODE_PRE_BOX, "Unknown home team ID: $home_team_id");
      reset_scores();
      return;
    }
    if (defined($team_poss) and $team_poss eq "HOME") {
      $team_poss = $home_team_id;
      print LOGF "Home team $team_poss has the ball\n";
    }
    increment_mode("Found home team: $home_team_id");
  }
}

sub text($) {
  my $t = shift;
  if ($t =~ /^\s*(.*?)\s*$/) {
    $t = $1;
  }
  return if (!length($t));
  if ($curr_mode == $MODE_FOUND_TIMELEFT_HEADER) {
    $t = uc $t;
    if ($t =~ /(\d)\w{2} QTR, (\d{1,2}):0{0,1}(\d{1,2})/) {
      $game_time_left = ($2 * 60) + $3;
      if ($1 >= 1 and $1 <= 4) {
        $game_time_left += ((4 - $1) * 900);
      }
      increment_mode("Game time left: $game_time_left");
    } elsif ($t eq "HALFTIME") {
      $game_time_left = 1800;
      increment_mode("Halftime: $game_time_left");
    } elsif ($t =~ /END OF (\d)\w{2} Q.*T.*R/) {
      $game_time_left = 3600 - (900 * $1);
      increment_mode("$t: $game_time_left");
    }
  } elsif ($curr_mode == $MODE_AWAY_QUARTER) {
    $t = 0 if ($t eq "-");
    push(@away_team_scores, $t);
    if (scalar(@away_team_scores) <= 4) {
      $away_regulation_score += $t;
    } else {
      $away_ot_score += $t;
    }
  } elsif ($curr_mode == $MODE_HOME_QUARTER) {
    $t = 0 if ($t eq "-");
    push(@home_team_scores, $t);
    if (scalar(@home_team_scores) <= 4) {
      $home_regulation_score += $t;
    } else {
      $home_ot_score += $t;
    }
  } elsif ($curr_mode == $MODE_AWAY_FINAL) {
    $t = 0 if ($t eq "-");
    if ($t =~ /^\d+$/) {
      if ($t != ($away_regulation_score + $away_ot_score)) {
        warn "Away final score ($t) != regulation ($away_regulation_score) "
            . "plus OT ($away_ot_score)";
      }
      increment_mode("Away score: $t");
    } else {
      print LOGF "Non-numeric final away score text: \"$t\"\n";
    }
  } elsif ($curr_mode == $MODE_HOME_FINAL) {
    $t = 0 if ($t eq "-");
    if ($t =~ /^\d+$/) {
      if ($t != ($home_regulation_score + $home_ot_score)) {
        warn "Home final score ($t) != regulation ($home_regulation_score) "
            . "plus OT ($home_ot_score)";
      }
      increment_mode("Home score: $t");
    } else {
      print LOGF "Non-numeric final home score text: \"$t\"\n";
    }
  } elsif ($curr_mode == $MODE_AWAY_TEAMNAME) {
    if ($t =~ /^\d+$/) { return; }
    if (!defined($curr_team_name)) {
      $curr_team_name = $t;
    } else {
      $curr_team_name .= " $t";
    }
  } elsif ($curr_mode == $MODE_HOME_TEAMNAME) {
    if ($t =~ /^\d+$/) { return; }
    if (!defined($curr_team_name)) {
      $curr_team_name = $t;
    } else {
      $curr_team_name .= " $t";
    }
  } elsif ($curr_mode == $MODE_FOUND_DOWNDIST_TAG) {
    if ($t eq "Down:") {
      increment_mode("Found 'down' header");
    }    
  } elsif ($curr_mode == $MODE_FOUND_DOWNDIST_TAG) {
    if ($t =~ /^(\d)\w{2}$/) {
      $curr_down = $1;
      increment_mode("Current down: $curr_down");
    }
  } elsif ($curr_mode == $MODE_FOUND_DOWN_INFO) {
    if ($t eq "To Go:") {
      increment_mode("Found distance header");
    }
  } elsif ($curr_mode == $MODE_FOUND_DIST_TAG) {
    $curr_dist = $t;
    increment_mode("Current distance: $curr_dist");
  } elsif ($curr_mode == $MODE_FOUND_DIST_INFO) {
    if ($t eq "Ball On:") {
      increment_mode("Found field position header");
    }
  } elsif ($curr_mode == $MODE_FOUND_FIELDPOS_TAG) {
    if ($t =~ /^(\w+) (\d+)$/) {
      my $tfgid = $cbssportsAbbrToTfgId{$1};
      if (!defined($tfgid)) {
        printf LOGF "Unknown side of field: $1\n";
        return;
      }
      $curr_side = $tfgid;
      if (defined($curr_dist) and $curr_dist eq "Goal") {
        $curr_dist = $2;
      }
      $curr_spot = $2;
      increment_mode("Side: $curr_side Pos: $curr_spot");
    }
  }
}

sub get_adjusted_points() {
  return (0,0) unless (defined($team_poss) and defined($curr_side) and defined($curr_spot));
  my $dist = $curr_spot;
  if ($team_poss == $curr_side) {
    $dist = 100 - $curr_spot;
  }
  return (0,0) if ($dist == 0);
  my ($off_pts, $def_pts) = FieldPositionPoints($dist);
  $off_pts = 0 if (!defined($off_pts));
  $def_pts = 0 if (!defined($def_pts));
  if ($team_poss == $home_team_id) {
    return ($off_pts, $def_pts);
  } else {
    return ($def_pts, $off_pts);
  }
}

sub print_and_reset_scores() {
  my $gid = get_game_id();
  if (defined($gid) and defined($away_team_id) and defined($home_team_id)
      and defined($game_date) and defined($game_time_left)) {
    # 0,20121201,20121201-1030-1419,ARKANSAS ST.,638,1030,ARKANSAS ST.,45,1419,MIDDLE TENN.,0
    # Week,Date,Date-Home-Away,Location,TimeLeft,HomeID,HomeTeam,HomeScore,AwayID,AwayTeam,AwayScore[,AdjHomeScore,AdjAwayScore]
    my ($home_adj_pts, $away_adj_pts) = get_adjusted_points();
    print LOGF "Home-adjusted: $home_adj_pts | Away-adjusted: $away_adj_pts\n";
    printf OUTF "0,%d,%s,%s,%d,%d,%s,%d,%d,%s,%d,%.2f,%.2f\n", $game_date, $gid,
           $home_team_name, $game_time_left,
           $home_team_id, $home_team_name, $home_regulation_score + $home_ot_score,
           $away_team_id, $away_team_name, $away_regulation_score + $away_ot_score,
           $home_regulation_score + $home_ot_score + $home_adj_pts,
           $away_regulation_score + $away_ot_score + $away_adj_pts;
  } else {
    printf LOGF "Away is defined: %d Home is defined: %d\n",
           defined($away_team_id), defined($home_team_id);
  }
  reset_scores();
}

sub get_game_id() {
  return undef if (!defined($away_team_id) or !defined($home_team_id));
  if (!defined($game_date) and @possible_dates) {
    printf LOGF "No game date: attempting to infer from %d options\n", scalar(@possible_dates);
    foreach my $gd (@possible_dates) {
      my $gid = sprintf "%d-%d-%d", $gd, $home_team_id, $away_team_id;
      printf LOGF "Attempting GID $gid\n";
      if (defined($results{$gid})) {
        $game_date = $gd;
        last;
      }
      $gid = sprintf "%d-%d-%d", $gd, $away_team_id, $home_team_id;
      printf LOGF "Attempting GID $gid\n";
      if (defined($results{$gid})) {
        $game_date = $gd;
        last;
      }
    }
    if (!defined($game_date)) {
      print LOGF "Could not infer game date; bailing\n";
      return undef;
    }
  }
  my $gid = sprintf "%d-%d-%d", $game_date, $home_team_id, $away_team_id;
  return $gid if (defined($results{$gid}));
  $gid = sprintf "%d-%d-%d", $game_date, $away_team_id, $home_team_id;
  if (defined($results{$gid})) {
    if (defined($team_poss)) {
      if ($team_poss == $away_team_id) {
        $team_poss = $home_team_id;
      } elsif ($team_poss == $home_team_id) {
        $team_poss = $away_team_id;
      }
    }
    my ($tmp_id, $tmp_name, $tmp_r_score, $tmp_ot_score) = ($away_team_id, $away_team_name, $away_regulation_score, $away_ot_score);
    $away_team_id = $home_team_id;
    $away_team_name = $home_team_name;
    $away_regulation_score = $home_regulation_score;
    $away_ot_score = $home_ot_score;
    $home_team_id = $tmp_id;
    $home_team_name = $tmp_name;
    $home_regulation_score = $tmp_r_score;
    $home_ot_score = $tmp_ot_score;
    return $gid;
  }
  return undef;
}

sub reset_scores() {
  $away_team_id = undef;
  $home_team_id = undef;
  $away_team_name = undef;
  $home_team_name = undef;
  $away_regulation_score = 0;
  $home_regulation_score = 0;
  $away_ot_score = 0;
  $home_ot_score = 0;
  @away_team_scores = ();
  @home_team_scores = ();
  $game_time_left = undef;
  $game_date = undef;
  $curr_team_name = undef;
  $curr_down = undef;
  $curr_dist = undef;
  $curr_side = undef;
  $curr_spot = undef;
  $team_poss = undef;
}

my $indent_level = 0;
my %start_count;
my %end_count;

sub end_handler {
  my ($self, $tagname) = @_;
  return if (defined($IGNORE_TAGS{$tagname}));
  my $i = " " x (2 * --$indent_level);
  print LOGF $i . "END $tagname\n";
  $end_count{$tagname} += 1;
  my $c = $END_CALLBACKS{$tagname};
  if (defined($c) and $curr_mode != $MODE_GAME_OVER) {
    $c->();
  }
}

sub text_handler {
  my ($self, $is_cdata, $dtext) = @_;
  return if $is_cdata;
  my $i = " " x (2 * $indent_level);
  $dtext =~ s/[^[:ascii:]]+//g;
  if ($dtext =~ /^\s*(.*?)\s*$/) {
    print LOGF $i . "TEXTM \"$1\"\n" if (length($1));
    $dtext = $1 if length($1);
  } else {
    print LOGF $i . "TEXTR \"$dtext\"\n" if (length($dtext));
  }
  text($dtext);
}

sub start_handler {
  my ($self, $tagname, $attr, $origtext) = @_;
  return if (defined($IGNORE_TAGS{$tagname}));
  my $i = " " x (2 * $indent_level++);
  print LOGF $i . "START $tagname $origtext\n";
  $start_count{$tagname} += 1;
  my $c = $START_CALLBACKS{$tagname};
  if (defined($c) and $curr_mode != $MODE_GAME_OVER) {
    $c->($attr);
  }
  if ($origtext =~ /.*\/\s*>$/) {
    end_handler $self, $tagname
  }
}

##########################
### Start of true main ###
##########################
#load_cbssports_tfg();
load_cbssports_abbr_tfg();
my $parser = HTML::Parser->new(api_version => 3);
$parser->handler(start => \&start_handler, "self,tagname,attr,text");
$parser->handler(end => \&end_handler, "self,tagname");
$parser->handler(text => \&text_handler, "self,is_cdata,dtext");
print LOGF "===\n";
$parser->parse_file($infile);
print LOGF "===\n";
foreach my $t (sort { $start_count{$b} <=> $start_count{$a} } keys %start_count) {
  my $s = $start_count{$t};
  my $e = $end_count{$t};
  $e = 0 if (!defined($e));
  printf LOGF "%10s %5d %5d %s\n", $t, $s, $e, ($s == $e) ? "" : "ERROR";
}
close(OUTF);
close(LOGF);
