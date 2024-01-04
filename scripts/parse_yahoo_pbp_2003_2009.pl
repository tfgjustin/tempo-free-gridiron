#!/usr/bin/perl 

use HTML::Parser;
use strict;
use warnings;

my %START_CALLBACKS = ( "div"  => \&start_tag_div,
                        "td"   => \&start_tag_td,
                        "a"    => \&start_tag_a,
                        "dl"   => \&start_tag_dl,
                        "dt"   => \&start_tag_dt,
                        "dd"   => \&start_tag_dd,
                        "span" => \&start_tag_span,
                        "h5"   => \&start_tag_h5,
                        "table" => \&start_tag_table,
                );

my %END_CALLBACKS = ( "div"  => \&end_tag_div,
                      "dt"   => \&end_tag_dt,
                      "dd"   => \&end_tag_dd,
                      "span" => \&end_tag_span
                    );

my $YAHOO_IDS = "data/yahoo_ids.txt";
my $YAHOO_TFG = "data/yahoo2ncaa.txt";

my %yahooIdToTfgId;
my %yahooNameToTfgId;
my %yahooAbbrToTfgId;

my $infile = shift(@ARGV);
my $outfile = shift(@ARGV);
my $logfile = shift(@ARGV);
exit 1 if (!defined($outfile) or ! -f $infile);

my $date = "00000000";
if ($infile =~ /^.*\/(\d{8})\d{4}.*html$/) {
  $date = $1;
}

if (!defined($logfile) or !length($logfile)) {
  $logfile = "/dev/null";
}

open(OUTF, ">$outfile") or die "Cannot open outfile $outfile: $!";
open(LOGF, ">$logfile") or die "Cannot open logfile $logfile: $!";

# Yahoo IDs->TFG ID
sub load_yahoo_ids();
sub load_yahoo_tfg();

# State machine management
sub increment_mode($);
sub set_mode($$);
sub revert_mode($);
# Start functions
sub start_tag_div($);
sub start_tag_td($);
sub start_tag_a($);
sub start_tag_dl($);
sub start_tag_dt($);
sub start_tag_dd($);
sub start_tag_span($);
sub start_tag_h5($);
sub start_tag_table($);
# End functions
sub end_tag_div();
sub end_tag_dt();
sub end_tag_dd();
sub end_tag_span();
# Helper functions
sub set_base_time($);
sub set_team_and_time();
sub set_down_and_distance();
sub set_current_clock($);
sub append_team_and_time($);
sub append_down_and_distance($);
sub append_play_description($);
sub check_valid_play_status();
sub print_play();
sub print_kickoff_play();
sub reset_play_status($);
sub play_has_advanced($);

# Modes
# Pre box score
my $MODE_PRE_BOX = 0;
# Box score away team: header
my $MODE_AWAY_HEADER = $MODE_PRE_BOX + 1;
# Box score away team: quater-by-quarter
my $MODE_AWAY_QUARTER = $MODE_AWAY_HEADER + 1;
# Box score away team: final score
my $MODE_AWAY_FINAL = $MODE_AWAY_QUARTER + 1;
# Post away-team box score
my $MODE_POST_AWAY = $MODE_AWAY_FINAL + 1;
# Box score home team: header
my $MODE_HOME_HEADER = $MODE_POST_AWAY + 1;
# Box score home team: quater-by-quarter
my $MODE_HOME_QUARTER = $MODE_HOME_HEADER + 1;
# Box score home team: final score
my $MODE_HOME_FINAL = $MODE_HOME_QUARTER + 1;
# Post home-team box score
my $MODE_POST_HOME = $MODE_HOME_FINAL + 1;
# Looking for the HTML table with the 
my $MODE_FINDING_TABLE = $MODE_POST_HOME + 1;
# Start of possession for a team
my $MODE_START_POSSESSION = $MODE_FINDING_TABLE + 1;
# Tag of the team who has the ball and the time remaining in the quarter
my $MODE_TEAM_AND_TIME = $MODE_START_POSSESSION + 1;
# Start of a single play-by-play entry
my $MODE_PLAY_START = $MODE_TEAM_AND_TIME + 1;
# Down, distance, and field position
my $MODE_DOWN_DISTANCE = $MODE_PLAY_START + 1;
# Time remaining in quarter
my $MODE_PLAY_TIMESTAMP = $MODE_DOWN_DISTANCE + 1;
# Play description
my $MODE_PLAY_DESCRIPTION = $MODE_PLAY_TIMESTAMP + 1;
# OUT-OF-ORDER: Quarter
my $MODE_QUARTER = $MODE_PLAY_DESCRIPTION + 1;
# GAME OVER, MAN
my $MODE_GAME_OVER = $MODE_QUARTER + 1;

my %MODE_NAMES = (
    $MODE_PRE_BOX => "Pre box score",
    $MODE_AWAY_HEADER => "Box score away team: header",
    $MODE_AWAY_QUARTER => "Box score away team: quater-by-quarter",
    $MODE_AWAY_FINAL => "Box score away team: final score",
    $MODE_POST_AWAY => "Post away-team box score",
    $MODE_HOME_HEADER => "Box score home team: header",
    $MODE_HOME_QUARTER => "Box score home team: quater-by-quarter",
    $MODE_HOME_FINAL => "Box score home team: final score",
    $MODE_POST_HOME => "Post home-team box score",
    $MODE_FINDING_TABLE => "Looking for play-by-play table",
    $MODE_START_POSSESSION => "Start of possession for a team",
    $MODE_TEAM_AND_TIME => "Team who has the ball and the time remaining in quarter",
    $MODE_PLAY_START => "Start of a single play-by-play entry",
    $MODE_DOWN_DISTANCE => "Down, distance, and field position",
    $MODE_PLAY_TIMESTAMP => "Time remaining in quarter",
    $MODE_PLAY_DESCRIPTION => "Play description",
    $MODE_QUARTER => "OUT-OF-ORDER: Quarter",
    $MODE_GAME_OVER => "GAME OVER, MAN. GAME OVER"
  );

my $curr_mode = 0;
my $last_mode = 0;
# Use this to figure out when we've hit the end
my $div_nesting = 0;

# Current state that gets inferred from headers
my $base_time = 0;
my $ot_counter = 0;
my $curr_team_and_time = undef;
my $curr_team_id = undef;
my $curr_away_score = 0;
my $curr_home_score = 0;
my $curr_play_count = 0;
my $curr_drive_count = 0;
my $drive_count_inc = 0;

# These are all pulled from the current play
my $curr_clock = undef;
my $max_clock = undef;
my $curr_down_and_distance = undef;
my $curr_down = undef;
my $curr_distance = undef;
my $curr_field_half = undef;
my $curr_field_yard = undef;
my $curr_play_description = undef;
# Keep track of the previous printed play
my $last_clock = undef;
my $last_down = undef;
my $last_distance = undef;
my $last_field_half = undef;
my $last_field_yard = undef;
my $last_play_description = undef;

# Quarter-by-quarter scores
my $away_team_id = undef;
my $home_team_id = undef;
my $away_regulation_score = 0;
my $home_regulation_score = 0;
my $away_ot_score = 0;
my $home_ot_score = 0;
my @away_team_scores;
my @home_team_scores;

sub load_yahoo_ids() {
  load_yahoo_tfg();
  open(YID, "$YAHOO_IDS") or die "Can't open yahoo IDS: $!";
  while(<YID>) {
    chomp;
    @_ = split(/,/);
    my $tfg_id = $yahooIdToTfgId{$_[0]};
    next if (!defined($tfg_id));
    $yahooNameToTfgId{$_[1]} = $tfg_id;
    $yahooAbbrToTfgId{$_[2]} = $tfg_id;
  }
  close(YID);
}

sub load_yahoo_tfg() {
  open(YTFG, "$YAHOO_TFG") or die "Can't open Yahoo->TFG mapping: $!";
  while(<YTFG>) {
    chomp;
    @_ = split(/,/);
    $yahooIdToTfgId{$_[0]} = $_[1];
  }
  close(YTFG);
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
  if ($curr_mode >= $MODE_START_POSSESSION) {
    ++$div_nesting;
    print LOGF "Div nesting: $div_nesting\n";
  }
}

sub start_tag_td($) {
  my $href = shift;
  if ($curr_mode == $MODE_PRE_BOX or $curr_mode == $MODE_POST_AWAY) {
    my $v = $$href{"class"};
    if (defined($v)) {
      if ($v eq "yspscores team") {
        increment_mode("Found team title header");
      }
    }
  } elsif ($curr_mode == $MODE_AWAY_QUARTER or $curr_mode == $MODE_HOME_QUARTER) {
    my $v = $$href{"class"};
    if (defined($v)) {
      if ($v eq "ysptblclbg6 total") {
        increment_mode("Found tag for final score");
      }
    }
  }
}

sub start_tag_a($) {
  my $href = shift;
  my $url = $$href{"href"};
  if ($curr_mode == $MODE_AWAY_HEADER) {
    if (defined($url) and $url =~ /^\/ncaaf\/teams\/(\w{3})$/) {
      my $tfg_id = $yahooIdToTfgId{$1};
      die "Undefined ID: $1" if (!defined($tfg_id));
      $away_team_id = $tfg_id;
      increment_mode("Found away team: $away_team_id");
    }
  } elsif ($curr_mode == $MODE_HOME_HEADER) {
    if (defined($url) and $url =~ /^\/ncaaf\/teams\/(\w{3})$/) {
      my $tfg_id = $yahooIdToTfgId{$1};
      die "Undefined ID: $1" if (!defined($tfg_id));
      $home_team_id = $tfg_id;
      increment_mode("Found home team: $home_team_id");
    }
  }
}

sub start_tag_dl($) {
  my $href = shift;
  # Change of possession
  if ($curr_mode >= $MODE_POST_HOME) {
    set_mode($MODE_START_POSSESSION, "Change of possession");
  }
}

sub start_tag_dt($) {
  my $href = shift;
  # Name of team, time remaining
  if ($curr_mode == $MODE_START_POSSESSION) {
    increment_mode("Looking for team and start time");
  }
}

sub start_tag_dd($) {
  my $href = shift;
  # Inside a play
}

sub start_tag_span($) {
  my $href = shift;
  # Play element (down, distance, team)
  # OR time remaining in quarter
  # OR text description of play
  my $c = $$href{"class"};
  if ($curr_mode == $MODE_PLAY_START) {
    if (defined($c) and ($c eq "event")) {
      # Check we have clock and current possession
      increment_mode("Looking for down and distance");
    }
  } elsif ($curr_mode == $MODE_DOWN_DISTANCE) {
    if (defined($c) and ($c eq "time")) {
      # Check we have down and distance first
      increment_mode("Looking for timestamp");
    }
  } elsif ($curr_mode == $MODE_PLAY_TIMESTAMP) {
    if (defined($c) and ($c eq "play")) {
      # Check we have the current clock first
      increment_mode("Need play description");
    }
  }
}

sub start_tag_h5($) {
  my $href = shift;
  # Briefly looking for the quarter name
  if ($curr_mode >= $MODE_POST_HOME) {
    set_mode($MODE_QUARTER, "Temporary update to quarter search");
  }
}

sub start_tag_table($) {
  my $href = shift;
  if ($curr_mode == $MODE_FINDING_TABLE) {
    increment_mode("Found start of play-by-play table");
  }
}

sub end_tag_div() {
  if ($curr_mode >= $MODE_START_POSSESSION) {
    --$div_nesting;
    print LOGF "Div nesting: $div_nesting\n";
    if ($div_nesting == 0) {
      set_mode($MODE_GAME_OVER, "We're done here, folks");
    }
  }
}

sub end_tag_dt() {
  if ($curr_mode == $MODE_TEAM_AND_TIME) {
    set_team_and_time();
  }
}

sub end_tag_dd() {
  if ($curr_mode == $MODE_PLAY_START) {
    if (defined($curr_play_description)) {
      print_kickoff_play();
      reset_play_status(1);
    }
  }
}

sub end_tag_span() {
  if ($curr_mode == $MODE_PLAY_DESCRIPTION) {
    check_valid_play_status();
    print_play();
  	reset_play_status(0);
	set_mode($MODE_PLAY_START, "Printed play; back to the beginning");
  } elsif ($curr_mode == $MODE_DOWN_DISTANCE) {
    set_down_and_distance();
  }
}

sub text($) {
  my $t = shift;
  if ($t =~ /^\s*(.*?)\s*$/) {
    $t = $1;
  }
  return if (!length($t));
  if ($curr_mode == $MODE_AWAY_QUARTER) {
    if ($t !~ /^\d+$/) {
      print LOGF "Invalid score: '$t'\n";
      return;
    }
    push(@away_team_scores, $t);
    if (scalar(@away_team_scores) <= 4) {
      $away_regulation_score += $t;
    } else {
      $away_ot_score += $t;
    }
  } elsif ($curr_mode == $MODE_HOME_QUARTER) {
    if ($t !~ /^\d+$/) {
      print LOGF "Invalid score: '$t'\n";
      return;
    }
    push(@home_team_scores, $t);
    if (scalar(@home_team_scores) <= 4) {
      $home_regulation_score += $t;
    } else {
      $home_ot_score += $t;
    }
  } elsif ($curr_mode == $MODE_AWAY_FINAL) {
    if ($t =~ /^\d+$/) {
      if ($t != ($away_regulation_score + $away_ot_score)) {
        die "Away final score ($t) != regulation ($away_regulation_score) "
            . "plus OT ($away_ot_score)";
      }
      increment_mode("Away score: $t");
    } else {
      print LOGF "Non-numeric final away score text: \"$t\"\n";
    }
  } elsif ($curr_mode == $MODE_HOME_FINAL) {
    if ($t =~ /^\d+$/) {
      if ($t != ($home_regulation_score + $home_ot_score)) {
        die "Home final score ($t) != regulation ($home_regulation_score) "
            . "plus OT ($home_ot_score)";
      }
      increment_mode("Home score: $t");
    } else {
      print LOGF "Non-numeric final home score text: \"$t\"\n";
    }
  } elsif ($curr_mode == $MODE_POST_HOME) {
    if ($t eq "Play by Play") {
      increment_mode("Found play-by-play header");
    }
  } elsif ($curr_mode == $MODE_QUARTER) {
    set_base_time($t);
  } elsif ($curr_mode == $MODE_TEAM_AND_TIME) {
    append_team_and_time($t);
  } elsif ($curr_mode == $MODE_PLAY_START) {
    # Generic play start. This is probably a kickoff.
    append_play_description($t);
  } elsif ($curr_mode == $MODE_DOWN_DISTANCE) {
    append_down_and_distance($t);
  } elsif ($curr_mode == $MODE_PLAY_TIMESTAMP) {
    set_current_clock($t);
  } elsif ($curr_mode == $MODE_PLAY_DESCRIPTION) {
    append_play_description($t);
  }
}

sub set_down_and_distance() {
  if (!defined($curr_down_and_distance)) {
    print LOGF "Undefined down and distance\n";
    return;
  }
  if ($curr_down_and_distance =~ /^(\d)\w{2}-(\d+), 50$/) {
    $curr_down = $1;
    $curr_distance = $2;
    $curr_field_half = 0;
    $curr_field_yard = 50;
    $curr_down_and_distance = undef;
  } elsif ($curr_down_and_distance =~ /^(\d)\w{2}-(\d+), (\D+?)(\d+)$/) {
    $curr_down = $1;
    $curr_distance = $2;
    my $tfg_id = $yahooAbbrToTfgId{$3};
    die "Undefined team abbreviation: '$3'" if (!defined($tfg_id));
    $curr_field_half = $tfg_id;
    $curr_field_yard = $4;
    $curr_down_and_distance = undef;
  }
}

sub set_current_clock($) {
  my $t = shift;
  if ($base_time < 3600) {
    if ($t =~ /^(\d+):0{0,1}(\d+)$/) {
      $curr_clock = $base_time + (900 - ((60 * $1) + $2));
      time_check();
    }
  } else {
    $ot_counter++;
    $curr_clock = $base_time + $ot_counter;
    time_check();
  }
}

sub append_team_and_time($) {
  my $t = shift;
  if (!defined($curr_team_and_time)) {
    $curr_team_and_time = $t;
  } else {
    $curr_team_and_time .= " $t";
  }
}

sub append_down_and_distance($) {
  my $t = shift;
  if (!defined($curr_down_and_distance)) {
    $curr_down_and_distance = $t;
  } else {
    $curr_down_and_distance .= " $t";
  }
}

sub append_play_description($) {
  my $t = shift;
  if (!defined($curr_play_description)) {
    $curr_play_description = $t;
  } else {
    $curr_play_description .= " $t";
  }
}

sub check_valid_play_status() {
  if (!defined($curr_clock) or ($curr_clock < 0) or ($curr_clock > 10000)) {
    die "Invalid current clock: $curr_clock";
  }
  if (!defined($curr_down) or ($curr_down < 1) or ($curr_down > 4)) {
    die "Invalid down: $curr_down";
  }
  if (!defined($curr_distance) or ($curr_distance < 1) or ($curr_distance > 100)) {
    die "Invalid distance: $curr_distance";
  }
  if (!defined($curr_field_half) or ($curr_field_half < 0)) {
    die "Invalid current field half: $curr_field_half";
  }
  if (!defined($curr_field_yard) or ($curr_field_yard < 0) or ($curr_field_yard > 50)) {
    die "Invalid current field yard: $curr_field_yard";
  }
  if (!defined($curr_play_description) or !length($curr_play_description)) {
    die "Missing play description";
  }
}

sub print_play() {
  if (has_play_advanced(0) == 0) {
    $drive_count_inc = 0;
    return;
  }
  $max_clock = $curr_clock;
  $curr_drive_count += $drive_count_inc;
  $drive_count_inc = 0;
  printf OUTF "%d-%d-%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,\"%s\"\n",
              $date,
              $home_team_id,
              $away_team_id,
              $curr_drive_count,
              ++$curr_play_count,
              $curr_clock,
              $curr_home_score,
              $curr_away_score,
              $curr_team_id,
              $curr_field_half,
              $curr_field_yard,
              $curr_down,
              $curr_distance,
              $curr_play_description;
}

sub print_kickoff_play() {
  return if (has_play_advanced(1) == 0);
  $max_clock = $curr_clock;
  printf OUTF "%d-%d-%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,\"%s\"\n",
              $date,
              $home_team_id,
              $away_team_id,
              0,
              ++$curr_play_count,
              $curr_clock,
              $curr_home_score,
              $curr_away_score,
              $curr_team_id,
              $curr_team_id,
              35,         # $curr_field_yard,
              1,          # $curr_down,
              10,         # $curr_distance,
              $curr_play_description;
}

sub reset_play_status($) {
  my $is_kickoff = shift;
  if (has_play_advanced($is_kickoff)) {
    $last_down = $curr_down;
    $last_distance = $curr_distance;
    $last_field_half = $curr_field_half;
    $last_field_yard = $curr_field_yard;
    $last_play_description = $curr_play_description;
  }
  $curr_clock = undef;
  $curr_down = undef;
  $curr_distance = undef;
  $curr_field_half = undef;
  $curr_field_yard = undef;
  $curr_play_description = undef;
}

sub has_play_advanced($) {
  my $is_kickoff = shift;
  $is_kickoff = 0 if (!defined($is_kickoff));
  if (defined($max_clock) and ($curr_clock < $max_clock)) {
    printf LOGF "Time went backwards from $max_clock to $curr_clock\n";
    return 0;
  }
  if ($is_kickoff) {
    # For a kickoff we only see if the play description is identical.
    if (defined($max_clock) and defined($curr_clock) and
        ($curr_clock == $max_clock) and
        defined($curr_play_description) and defined($last_play_description) and
        ($curr_play_description eq $last_play_description)) {
      return 0;
    }
    return 1;
  }
  if (!defined($curr_down) or !defined($curr_distance) or
      !defined($curr_field_half) or !defined($curr_field_yard) or
      !defined($curr_play_description)) {
    print LOGF "Missing some current data\n";
    return 0;
  }
  if (!defined($last_down) or !defined($last_distance) or
      !defined($last_field_half) or !defined($last_field_yard) or
      !defined($last_play_description)) {
     return 1;
  }
  if (($curr_down ne $last_down) or ($curr_distance ne $last_distance) or
      ($curr_field_half ne $last_field_half) or
      ($curr_field_yard ne $last_field_yard) or
      ($curr_play_description ne $last_play_description)) {
    return 1;
  }
  print LOGF "Exact duplicate match of last play\n";
  return 0;
}

sub set_team_and_time() {
  if (!defined($curr_team_and_time)) {
    print LOGF "Undefined team and time\n";
    return;
  }
  if ($base_time < 3600) {
    if ($curr_team_and_time =~ /^(.*?)\s{0,1}-\s{0,1}(\d+):0{0,1}(\d+)$/) {
      my $tfg_id = $yahooNameToTfgId{$1};
      die "No TFG ID for yahoo team '$1'" if (!defined($tfg_id));
      $curr_team_id = $tfg_id;
      $curr_clock = $base_time + (900 - ((60 * $2) + $3));
      time_check();
      $curr_team_and_time = undef;
      $drive_count_inc = 1;
      increment_mode("Possession: '$curr_team_id' Clock: $curr_clock Drive: $curr_drive_count");
    } elsif ($curr_team_and_time =~ /^(.*?)\scontinued$/) {
      my $tfg_id = $yahooNameToTfgId{$1};
      die "No TFG ID for yahoo team '$1'" if (!defined($tfg_id));
      $curr_team_id = $tfg_id;
      $curr_clock = $base_time;
      time_check();
      increment_mode("Possession: '$curr_team_id' maintains, Clock: $curr_clock");
      $curr_team_and_time = undef;
    }
  } elsif ($base_time >= 3600) {
    if ($curr_team_and_time =~ /^(.*?)\s{0,1}-\s{0,1}\d{1,2}:\d{2}$/) {
      my $tfg_id = $yahooNameToTfgId{$1};
      die "No TFG ID for yahoo team '$1'" if (!defined($tfg_id));
      $curr_team_id = $tfg_id;
      $curr_clock = $base_time + $ot_counter;
      time_check();
      $curr_team_and_time = undef;
      $drive_count_inc = 1;
      increment_mode("Possession: '$curr_team_id' Clock: $curr_clock (OT) Drive: $curr_drive_count");
    } elsif ($curr_team_and_time =~ /^(.*?)\scontinued$/) {
      my $tfg_id = $yahooNameToTfgId{$1};
      die "No TFG ID for yahoo team '$1'" if (!defined($tfg_id));
      $curr_team_id = $tfg_id;
      $curr_clock = $base_time;
      time_check();
      increment_mode("Possession: '$curr_team_id' maintains, Clock: $curr_clock");
      $curr_team_and_time = undef;
    }
  } else {
    print LOGF "Invalid team and time: '$curr_team_and_time'\n";
  }
}

sub set_base_time($) {
  my $t = shift;
  # This should be a quarter tag
  if ($t =~ /^1st\s{0,1}\w*$/) {
    $base_time = 0;
  } elsif ($t =~ /^2nd\s{0,1}\w*$/) {
    $base_time = 900;
  } elsif ($t =~ /^3rd\s{0,1}\w*$/) {
    $base_time = 1800;
  } elsif ($t =~ /^4th\s{0,1}\w*$/) {
    $base_time = 2700;
  } elsif ($t =~ /(\d*)OT/) {
    if (!length($1)) { $base_time = 3600; }
    else { $base_time = 3600 + (($1 - 1) * 100); }
    $ot_counter = 0;
    print LOGF "OVERTIME: '$t' ~> $base_time\n";
  } elsif ($t eq "Quarter") {
    # This is a harmless artifact of bad HMTL
  } else {
    print LOGF "Unknown quarter: '$t'\n";
    return;
  }
  revert_mode("Set base time to $base_time");
}

sub time_check() {
  if (defined($last_clock)) {
    if($curr_clock - $last_clock > 60) {
      print LOGF "Possible missing plays: clock jumped from $last_clock to $curr_clock\n";
    } elsif ($curr_clock < $last_clock) {
      print LOGF "Time went backwards from $last_clock to $curr_clock\n";
    }
  }
  $last_clock = $curr_clock;
}

my $indent_level = 0;
my %start_count;
my %end_count;

sub end_handler {
  my ($self, $tagname) = @_;
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
  $dtext =~ s/\n/\ /g;
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
load_yahoo_ids();
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
