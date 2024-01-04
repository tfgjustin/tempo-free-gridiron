#!/usr/bin/perl 

use TempoFree;
use HTML::Parser;
use strict;
use warnings;
my %IGNORE_TAGS = ( "br" => 1, "hr" => 1, "img" => 1, "ul" => 1);
my %START_CALLBACKS = ( "div"  => \&start_tag_div,
                        "td"   => \&start_tag_td,
                        "a"    => \&start_tag_a,
                        "span" => \&start_tag_span,
                );

my %END_CALLBACKS = ( "div" => \&end_tag_div,
                      "td"  => \&end_tag_td,
                    );

my $FOXSPORTS_TFG = "data/foxsports2ncaa.txt";
my $FOXSPORTS_ABBR_TFG = "data/foxsportsabbr2ncaa.txt";

my %foxsportsIdToTfgId;
my %foxsportsAbbrToTfgId;

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

open(OUTF, ">$outfile") or die "Cannot open outfile $outfile: $!";
open(LOGF, ">$logfile") or die "Cannot open logfile $logfile: $!";

# Foxsports IDs->TFG ID
sub load_foxsports_tfg();

# State machine management
sub increment_mode($);
sub set_mode($$);
sub revert_mode($);
# Start functions
sub start_tag_div($);
sub start_tag_td($);
sub start_tag_a($);
sub start_tag_span($);
# End functions
sub end_tag_div();
sub end_tag_td();
# Helper functions
sub print_and_reset_scores();
sub reset_scores();

# Modes
# Pre box score
my $MODE_PRE_BOX = 0;
# Found the status of the box score
my $MODE_FOUND_STATUS = $MODE_PRE_BOX + 1;
# Found the amount of time left
my $MODE_FOUND_TIMELEFT = $MODE_FOUND_STATUS + 1;
# Found the down and distance header tag
my $MODE_FOUND_DOWNDIST_TAG = $MODE_FOUND_TIMELEFT + 1;
# Found the down and distance text
my $MODE_FOUND_DOWNDIST_INFO = $MODE_FOUND_DOWNDIST_TAG + 1;
# Box score away team: header
my $MODE_AWAY_TEAMNAME = $MODE_FOUND_DOWNDIST_INFO + 1;
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
# Start of a scoring play
my $MODE_START_SCORES = $MODE_POST_HOME + 1;
# Time at which the score occurred
my $MODE_SCORE_TIMESTAMP = $MODE_START_SCORES + 1;
# Tag of the team who scored
my $MODE_TEAM_SCORE = $MODE_SCORE_TIMESTAMP + 1;
# Post-team-tag
my $MODE_POST_TEAM_SCORE = $MODE_TEAM_SCORE + 1;
# Total score for both teams
my $MODE_SCORE_TOTALS = $MODE_POST_TEAM_SCORE + 1;
# OUT-OF-ORDER: Quarter
my $MODE_QUARTER = $MODE_SCORE_TOTALS + 1;
# GAME OVER, MAN
my $MODE_GAME_OVER = $MODE_QUARTER + 1;

my %MODE_NAMES = (
    $MODE_PRE_BOX => "Pre box score",
    $MODE_FOUND_STATUS => "Found game status",
    $MODE_FOUND_TIMELEFT => "Found game time",
    $MODE_FOUND_DOWNDIST_TAG => "Found down and distance header",
    $MODE_FOUND_DOWNDIST_INFO => "Found down and distance info",
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
    $MODE_START_SCORES => "Start of a scoring play",
    $MODE_SCORE_TIMESTAMP => "Time at which the score happened",
    $MODE_TEAM_SCORE => "Team who scored",
    $MODE_POST_TEAM_SCORE => "Post-team-tag",
    $MODE_SCORE_TOTALS => "Current total scores",
    $MODE_QUARTER => "OUT-OF-ORDER: Quarter",
    $MODE_GAME_OVER => "GAME OVER, MAN. GAME OVER"
  );

my $curr_mode = 0;
my $last_mode = 0;
# Use this to figure out when we've hit the end
my $div_nesting = 0;

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
my $curr_ball_spot_text = undef;
my $curr_down = undef;
my $curr_dist = undef;
my $curr_side = undef;
my $curr_spot = undef;
my $team_poss = undef;

sub load_foxsports_tfg() {
  open(FSTFG, "$FOXSPORTS_TFG") or die "Can't open Foxsports->TFG mapping: $!";
  while(<FSTFG>) {
    chomp;
    @_ = split(/,/);
    $foxsportsIdToTfgId{$_[0]} = $_[1];
  }
  close(FSTFG);
}

sub load_foxsports_abbr_tfg() {
  open(FSTFG, "$FOXSPORTS_ABBR_TFG") or die "Can't open AbbrFoxsports->TFG mapping: $!";
  while(<FSTFG>) {
    next if (/^#/);
    chomp;
    @_ = split(/,/);
    $foxsportsAbbrToTfgId{$_[1]} = $_[0];
  }
  close(FSTFG);
  printf LOGF "Loaded %d abbreviations\n", scalar(keys %foxsportsAbbrToTfgId);
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
      if ($c eq "sbScoreboxFinal") {
        $game_time_left = 0;
        set_mode($MODE_FOUND_DOWNDIST_INFO, "Found game which is over");
      } elsif ($c eq "sbScorebox") {
        my $s = $$href{"state"};
        if (defined($s)) {
          if ($s eq "In-Progress") {
            increment_mode("Game is in progress");
          } elsif ($s eq "Pre-Game") {
            print LOGF "Game is not yet started\n";
          }
        }
      }
    }
  } elsif ($curr_mode == $MODE_POST_HOME) {
    my $id = $$href{"id"};
    if (defined($id) and $id =~ /^.*boxscore$/) {
      increment_mode("Found boxscore id: \"$id\"");
    }
  }
  if ($curr_mode >= $MODE_START_SCORES) {
    ++$div_nesting;
    print LOGF "Div nesting: $div_nesting\n";
  }
}

sub start_tag_span($) {
  my $href = shift;
  if ($curr_mode == $MODE_FOUND_DOWNDIST_INFO or $curr_mode == $MODE_POST_AWAY) {
    my $v = $$href{"class"};
    if (defined($v)) {
      if ($v =~ /sbScorebox[HA][ow][ma][ey]Team/) {
        increment_mode("Found team title header");
      }
    }
  } elsif ($curr_mode == $MODE_AWAY_TEAMNAME) {
    my $v = $$href{"class"};
    if (defined($v) and $v eq "sbScoreboxFootballIndicator") {
      $team_poss = "AWAY";
      print LOGF "Unknown away team has the ball\n";
    }
  } elsif ($curr_mode == $MODE_HOME_TEAMNAME) {
    my $v = $$href{"class"};
    if (defined($v) and $v eq "sbScoreboxFootballIndicator") {
      $team_poss = "HOME";
      print LOGF "Unknown home team has the ball\n";
    }
  }
}

sub start_tag_td($) {
  my $href = shift;
  if ($curr_mode == $MODE_FOUND_TIMELEFT) {
    my $v = $$href{"id"};
    if (defined($v)) {
      if ($v =~ /sbScoreboxPossession-\d+/) {
        increment_mode("Found possession header");
      } elsif (!defined($curr_down) and ($v =~ /sbScoreboxQ\d/)) {
        set_mode($MODE_FOUND_DOWNDIST_INFO, "No current field position");
      }
    }
  } elsif ($curr_mode == $MODE_FOUND_DOWNDIST_INFO or $curr_mode == $MODE_POST_AWAY) {
    my $v = $$href{"class"};
    if (defined($v)) {
      if ($v =~ /sbScoreboxTeam[HA][ow][ma][ey]/) {
        increment_mode("Found team title header");
      }
    }
  } elsif ($curr_mode == $MODE_AWAY_START_SCORES or $curr_mode == $MODE_HOME_START_SCORES) {
    my $v = $$href{"id"};
    if (defined($v)) {
      if ($v =~ /sbScoreboxQ\d\w{4}-(20\d{6})\d{4}/) {
        $game_date = $1;
        increment_mode("Found start of scores");
      }
    }
  } elsif ($curr_mode == $MODE_AWAY_QUARTER or $curr_mode == $MODE_HOME_QUARTER) {
    my $v = $$href{"id"};
    if (defined($v)) {
      if ($v =~ /sbScoreboxTotal\w{4}-\d{12}/) {
        increment_mode("Found tag for final score");
      }
    }
  } else {
    my $c = $$href{"class"};
    if ($curr_mode == $MODE_START_SCORES) {
      if (defined($c) and ($c eq "time title")) {
        increment_mode("Found time of score");
      }
    } elsif ($curr_mode == $MODE_POST_TEAM_SCORE) {
      if (defined($c) and ($c eq "score")) {
        increment_mode("Found score line");
      }
    }
  }
}

sub start_tag_a($) {
  my $href = shift;
  my $url = $$href{"href"};
  if ($curr_mode == $MODE_AWAY_TEAMNAME) {
    if (defined($url) and $url =~ /^\/collegefootball\/team\/.+-football\/(\d{4,7})$/) {
      $away_team_id = $foxsportsIdToTfgId{$1};
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
      if (defined($team_poss) and $team_poss eq "AWAY") {
        $team_poss = $away_team_id;
        print LOGF "Away team $team_poss has the ball\n";
      }
      increment_mode("Found away team: $away_team_id");
    }
  } elsif ($curr_mode == $MODE_HOME_TEAMNAME) {
    if (defined($url) and $url =~ /^\/collegefootball\/team\/.+-football\/(\w{4,7})$/) {
      $home_team_id = $foxsportsIdToTfgId{$1};
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
      if (defined($team_poss) and $team_poss eq "HOME") {
        $team_poss = $home_team_id;
        print LOGF "Home team $team_poss has the ball\n";
      }
      increment_mode("Found home team: $home_team_id");
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
      $away_team_id = $foxsportsIdToTfgId{$curr_team_name};
      print LOGF "TEAM NAME: $curr_team_name\n";
      $curr_team_name = undef;
    }
    if (!defined($away_team_id)) {
      reset_scores();
      set_mode($MODE_PRE_BOX, "Failed to get away team ID; resetting");
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
      $home_team_id = $foxsportsIdToTfgId{$curr_team_name};
      print LOGF "TEAM NAME: $curr_team_name\n";
      $curr_team_name = undef;
    }
    if (!defined($home_team_id)) {
      reset_scores();
      set_mode($MODE_PRE_BOX, "Failed to get home team ID; resetting");
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
  } elsif ($curr_mode == $MODE_FOUND_DOWNDIST_TAG) {
    if (!defined($curr_ball_spot_text)) {
      increment_mode("No current possession info");
      return;
    }
    if ($curr_ball_spot_text =~ /^(\d)\w{2} \& (\d+) on (.*) (\d+)$/) {
      $curr_side = $foxsportsAbbrToTfgId{$3};
      if (!defined($curr_side)) {
        increment_mode("Unknown team ID: $3");
        return;
      }
      $curr_down = $1;
      $curr_dist = $2;
      $curr_spot = $4;
      increment_mode("Down: $curr_down Dist: $curr_dist Side: \"$curr_side\" "
                     . "Spot: $curr_spot\n");
    } else {
      increment_mode("In down/dist tag, found malformed text \"$curr_ball_spot_text\"");
    }
    $curr_ball_spot_text = undef;
  }
}

sub text($) {
  my $t = shift;
  if ($t =~ /^\s*(.*?)\s*$/) {
    $t = $1;
  }
  return if (!length($t));
  if ($curr_mode == $MODE_FOUND_DOWNDIST_TAG) {
    if (!defined($curr_ball_spot_text)) {
      $curr_ball_spot_text = $t;
    } else {
      $curr_ball_spot_text .= " $t";
    }
  } elsif ($curr_mode == $MODE_FOUND_STATUS) {
    $t = uc $t;
    if ($t =~ /(\d{1,2}):0{0,1}(\d{1,2}) - (\d)\w{2}/) {
      $game_time_left = ($1 * 60) + $2;
      if ($3 >= 1 and $3 <= 4) {
        $game_time_left += ((4 - $3) * 900);
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
    push(@away_team_scores, $t);
    if (scalar(@away_team_scores) <= 4) {
      $away_regulation_score += $t;
    } else {
      $away_ot_score += $t;
    }
  } elsif ($curr_mode == $MODE_HOME_QUARTER) {
    push(@home_team_scores, $t);
    if (scalar(@home_team_scores) <= 4) {
      $home_regulation_score += $t;
    } else {
      $home_ot_score += $t;
    }
  } elsif ($curr_mode == $MODE_AWAY_FINAL) {
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
    if ($t =~ /^\d+$/) {
      if ($t != ($home_regulation_score + $home_ot_score)) {
        warn "Home final score ($t) != regulation ($home_regulation_score) "
            . "plus OT ($home_ot_score)";
      }
      set_mode($MODE_PRE_BOX, "Home score: $t");
      print_and_reset_scores();
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
  }
}

sub get_adjusted_points() {
  return (0,0) unless (defined($team_poss) and defined($curr_side) and defined($curr_spot));
  my $dist = $curr_spot;
  if ($team_poss == $curr_side) {
    $dist = 100 - $curr_spot;
  }
  my ($off_pts, $def_pts) = FieldPositionPoints($dist);
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
    my $home_game_points = $home_regulation_score + $home_ot_score;
    my $away_game_points = $away_regulation_score + $away_ot_score;
    my $home_eff_points = $home_game_points + $home_adj_pts;
    my $away_eff_points = $away_game_points + $away_adj_pts;
    $home_eff_points = 0 if ($home_eff_points < 0);
    $away_eff_points = 0 if ($away_eff_points < 0);
    print LOGF "Home-adjusted: $home_adj_pts | Away-adjusted: $away_adj_pts\n";
    printf OUTF "0,%d,%s,%s,%d,%d,%s,%d,%d,%s,%d,%.2f,%.2f\n", $game_date, $gid,
           $home_team_name, $game_time_left,
           $home_team_id, $home_team_name, $home_game_points,
           $away_team_id, $away_team_name, $away_game_points,
           $home_eff_points, $away_eff_points;
  } else {
    printf LOGF "Away is defined: %d Home is defined: %d\n",
           defined($away_team_id), defined($home_team_id);
  }
  reset_scores();
}

sub get_game_id() {
  return undef if (!defined($away_team_id) or !defined($home_team_id));
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
  $curr_ball_spot_text = undef;
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
load_foxsports_tfg();
load_foxsports_abbr_tfg();
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
