#!/usr/bin/perl 

use HTML::Parser;
use strict;
use warnings;

my %START_CALLBACKS = ( "div"  => \&start_tag_div,
                        "td"   => \&start_tag_td,
                        "a"    => \&start_tag_a,
                        "h5"   => \&start_tag_h5,
                );

my %END_CALLBACKS = ( "div" => \&end_tag_div,
                      "td"  => \&end_tag_td,
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
sub start_tag_h5($);
# End functions
sub end_tag_div();
sub end_tag_td();
# Helper functions
sub set_base_time($);
sub set_current_clock($);
sub append_current_scores($);
sub set_current_scores();
sub check_valid_score();
sub print_score();
sub reset_score();

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
    $MODE_AWAY_HEADER => "Box score away team: header",
    $MODE_AWAY_QUARTER => "Box score away team: quater-by-quarter",
    $MODE_AWAY_FINAL => "Box score away team: final score",
    $MODE_POST_AWAY => "Post away-team box score",
    $MODE_HOME_HEADER => "Box score home team: header",
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

my $base_time = 0;
my $ot_counter = 1;
my $curr_clock = undef;
my $curr_team_id = undef;
my $curr_scores = undef;
my $curr_away_score = undef;
my $curr_home_score = undef;

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
  if ($curr_mode == $MODE_POST_HOME) {
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

sub start_tag_td($) {
  my $href = shift;
  if ($curr_mode == $MODE_PRE_BOX or $curr_mode == $MODE_POST_AWAY) {
    my $v = $$href{"class"};
    if (defined($v)) {
      if ($v eq "team title") {
    	my $s = $$href{"scope"};
        if (defined($s) and $s eq "row") {
          increment_mode("Found team title header");
        }
      }
    }
  } elsif ($curr_mode == $MODE_AWAY_QUARTER or $curr_mode == $MODE_HOME_QUARTER) {
    my $v = $$href{"class"};
    if (defined($v)) {
      if ($v eq "score" or $v eq "score winner") {
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
  } elsif ($curr_mode == $MODE_TEAM_SCORE) {
    if (defined($url) and $url =~ /^\/ncaaf\/teams\/(\w{3})$/) {
      my $tfg_id = $yahooIdToTfgId{$1};
      die "Undefined ID: $1" if (!defined($tfg_id));
      $curr_team_id = $tfg_id;
      increment_mode("Found team that scored: $curr_team_id");
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
    set_current_scores();
    check_valid_score();
    print_score();
    reset_score();
    set_mode($MODE_START_SCORES, "Printed score line");
  }
}

sub text($) {
  my $t = shift;
  if ($t =~ /^\s*(.*?)\s*$/) {
    $t = $1;
  }
  return if (!length($t));
  if ($curr_mode == $MODE_AWAY_QUARTER) {
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
  } elsif ($curr_mode == $MODE_QUARTER) {
    set_base_time($t);
  } elsif ($curr_mode == $MODE_SCORE_TIMESTAMP) {
    set_current_clock($t);
  } elsif ($curr_mode == $MODE_SCORE_TOTALS) {
    append_current_scores($t);
  }
}

sub append_current_scores($) {
  my $t = shift;
  if (!defined($curr_scores)) {
    $curr_scores = $t;
  } else {
    $curr_scores .= " $t";
  }
}

sub set_current_clock($) {
  my $t = shift;
  if ($base_time < 3600) {
    if ($t =~ /^(\d+):0{0,1}(\d+)$/) {
      $curr_clock = $base_time + (900 - ((60 * $1) + $2));
      increment_mode("Set current clock to '$curr_clock'");
    }
  } else {
    printf LOGF "Probably in OT, clock is '$t'; not sure what to do\n";
    $curr_clock = $base_time + $ot_counter++;
    increment_mode("Set current clock to '$curr_clock'");
  }
}

sub set_current_scores() {
  if (!defined($curr_scores)) {
    print LOGF "Undefined current scores\n";
    return;
  }
  if ($curr_scores =~ /^(\d+)\s{0,2}-\s{0,2}(\d+)$/) {
    $curr_away_score = $1;
    $curr_home_score = $2;
  } else {
    print LOGF "Invalid current scores: '$curr_scores'\n";
  }
}

sub print_score() {
  printf OUTF "%d-%d-%d,%d,%d,%d,%d\n",
              $date,
              $home_team_id,
              $away_team_id,
              $curr_clock,
              $curr_home_score,
              $curr_away_score,
              $curr_team_id;
}

sub check_valid_score() {
  if (!defined($curr_clock) or ($curr_clock < 0) or ($curr_clock > 10000)) {
    die "Invalid clock: $curr_clock";
  }
  if (!defined($curr_home_score) or ($curr_home_score < 0)) {
    die "Invalid home score: $curr_home_score";
  }
  if (!defined($curr_away_score) or ($curr_away_score < 0)) {
    die "Invalid away score: $curr_away_score";
  }
  if (!defined($curr_team_id) or ($curr_team_id < 0)) {
    die "Invalid team ID: $curr_team_id";
  }
}

sub reset_score() {
  $curr_clock = undef;
  $curr_scores = undef;
  $curr_home_score = undef;
  $curr_away_score = undef;
  $curr_team_id = undef;
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
    $ot_counter = 1;
    print LOGF "OVERTIME: '$t' ~> $base_time\n";
  } elsif ($t eq "Quarter") {
    # This is a harmless artifact of bad HMTL
  } else {
    print LOGF "Unknown quarter: '$t'\n";
    return;
  }
  revert_mode("Set base time to $base_time");
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
