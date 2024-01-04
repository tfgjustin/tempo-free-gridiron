#!/usr/bin/perl -w

use TempoFree;
use strict;

sub parse_name_map();
sub parse_results_html();
sub lookup_team($);
sub clear_teams();
sub print_score($$$$$$$$);

my %MONTHS = ( 'August' => 8, 'September' => 9, 'October' => 10,
               'November' => 11, 'December' => 12, 'January' => 1 );

if (scalar(@ARGV) != 2) {
  print "\n";
  print "Usage: $0 <name_map> <results_html>\n";
  print "\n";
  exit 1;
}

my $curr_home_id = undef;
my $curr_home_name = undef;
my $curr_hs = undef;
my $curr_away_id = undef;
my $curr_away_name = undef;
my $curr_as = undef;
my $curr_date = undef;

my $map_fname = shift(@ARGV);
my $res_html = shift(@ARGV);

my %results;
LoadResults(\%results);

my %names;
parse_name_map();
parse_results_html();

sub parse_name_map() {
  open(NMAP, "$map_fname") or die "Cannot open names $map_fname: $!";
  while(<NMAP>) {
    chomp;
    my @r = split(/,/);
    my $yahoo = shift(@r);
    $names{$yahoo} = \@r;
  }
  close(NMAP);
}

sub print_score($$$$$$$$) {
  my $date = shift;
  my $home_id = shift;
  my $home_name = shift;
  my $home_score = shift;
  my $away_id = shift;
  my $away_name = shift;
  my $away_score = shift;
  my $time_left = shift;

  my $gid = sprintf "%s-%4d-%4d", $date, $home_id, $away_id;
  if (!defined($results{$gid})) {
    $gid = sprintf "%s-%4d-%4d", $date, $away_id, $home_id;
    if (!defined($results{$gid})) {
      return;
    }
    my ($tid, $tn, $ts) = ( $away_id, $away_name, $away_score );
    $away_id = $home_id;
    $away_name = $home_name;
    $away_score = $home_score;
    $home_id = $tid;
    $home_name = $tn;
    $home_score = $ts;
  }

  print STDERR "PRINTSCORE\n";
  printf "0,%s,%s,%s,%d,%4d,%s,%d,%4d,%s,%d\n", $date, $gid, $home_name,
         $time_left, $home_id, $home_name, $home_score,
         $away_id, $away_name, $away_score;
}

sub parse_results_html() {
  my $team_count = 0;
  my $score_count = 0;
  my $is_final = 0;
  my $is_half = 0;
  my $is_ot = 0;
  my $time_left = -1;
  my $do_print = 0;
  open(RES, "$res_html") or die "Cannot open results $res_html: $!";
  while(<RES>) {
    chomp;
    if (/^\s+\w+\s(\w+)\s+(\d{1,2}),\s(\d{4})$/) {
      print STDERR "DATE: $_\n";
      my $month = $MONTHS{$1};
      if (!defined($month)) {
        warn "Invalid month: $1";
        next;
      }
      my $day = $2;
      my $year = $3;
      $curr_date = sprintf "%4d%02d%02d", $year, $month, $day;
    } elsif (/href="\/ncaaf\/teams\/([a-z]{3})"/) {
      print STDERR "TEAM: $_\n";
      $team_count++;
      if ($team_count == 2) {
        ($curr_home_id, $curr_home_name) = lookup_team($1);
      } else {
        ($curr_away_id, $curr_away_name) = lookup_team($1);
      }
    } elsif (/ysptblclbg6\stotal/) {
      print STDERR "SCORE: $_\n";
      if (/yspscores/) {
        if (/>Final</) {
          $is_final = 1;
          $time_left = 0;
          print STDERR "TIMELEFT: FINAL\n";
        } elsif (/>(\d{1,2}):(\d{2})/) {
          $time_left = ($1 * 60) + $2;
          print STDERR "TIMELEFT: $time_left\n";
        } elsif (/>1st</) {
          $time_left += (3 * 15 * 60);
          $do_print = 1;
          print STDERR "TIMELEFT: 1s $time_left\n";
        } elsif (/>2nd</) {
          $time_left += (2 * 15 * 60);
          $do_print = 1;
          print STDERR "TIMELEFT: 2n $time_left\n";
        } elsif (/>3rd</) {
          $time_left += (1 * 15 * 60);
          $do_print = 1;
          print STDERR "TIMELEFT: 3r $time_left\n";
        } elsif (/>4th</) {
          $time_left += (0 * 15 * 60);
          $do_print = 1;
          $time_left = 0 if ($time_left < 0);
          print STDERR "TIMELEFT: 4t $time_left\n";
        } elsif (/>OT</) {
          $is_ot = 1;
          $time_left = -1;
          print STDERR "TIMELEFT: OT $time_left\n";
        } elsif (/>Half</) {
          $is_half = 1;
          $time_left = 1800;
          print STDERR "TIMELEFT: HF $time_left\n";
        }
        if ($do_print) {        
          if (defined($curr_date) and defined($curr_home_id) and
              defined($curr_home_name) and defined($curr_hs) and
              defined($curr_away_id) and defined($curr_home_name) and
              defined($curr_as)) {
            print_score($curr_date, $curr_home_id, $curr_home_name, $curr_hs,
                        $curr_away_id, $curr_away_name, $curr_as, $time_left);
          } else {
            print STDERR "ERROR No date\n" if (!defined($curr_date));
            print STDERR "ERROR No home_id\n" if (!defined($curr_home_id));
            print STDERR "ERROR No home_name\n" if (!defined($curr_home_name));
            print STDERR "ERROR No hs\n" if (!defined($curr_hs));
            print STDERR "ERROR No away_id\n" if (!defined($curr_away_id));
            print STDERR "ERROR No away_name\n" if (!defined($curr_away_name));
            print STDERR "ERROR No as\n" if (!defined($curr_as));
          }
          clear_teams();
          $team_count = $score_count = 0;
          $do_print = $is_final = $is_half = $is_ot = 0;
          $time_left = -1;
        }
        next;
      }
      print STDERR "VALIDSCORE: $_\n";
      $_ = <RES>;
      die "Unexpected EOF" if (!defined($_));
      chomp;
      print STDERR "VALUE: $_\n";
      if (/span\sclass=\"yspscores\">(<b>)*(\d+)(<\/b>)*<\/span>/) {
        print STDERR "GOODVALUE: $_\n";
        ++$score_count;
        if ($score_count == 2) {
          $curr_hs = $2;
        } else {
          $curr_as = $2;
        }
        if ($team_count != $score_count) {
          print STDERR "TCOUNT ADJUST $team_count -> $score_count\n";
          $team_count = $score_count;
        }
        print STDERR "TCOUNT: $team_count\n";
        if ($team_count == 2 and ($is_final or $is_half or $is_ot)) {
          if (defined($curr_date) and defined($curr_home_id) and
              defined($curr_home_name) and defined($curr_hs) and
              defined($curr_away_id) and defined($curr_home_name) and
              defined($curr_as)) {
            print_score($curr_date, $curr_home_id, $curr_home_name, $curr_hs,
                        $curr_away_id, $curr_away_name, $curr_as, $time_left);
          } else {
            print STDERR "ERROR No date\n" if (!defined($curr_date));
            print STDERR "ERROR No home_id\n" if (!defined($curr_home_id));
            print STDERR "ERROR No home_name\n" if (!defined($curr_home_name));
            print STDERR "ERROR No hs\n" if (!defined($curr_hs));
            print STDERR "ERROR No away_id\n" if (!defined($curr_away_id));
            print STDERR "ERROR No away_name\n" if (!defined($curr_away_name));
            print STDERR "ERROR No as\n" if (!defined($curr_as));
          }
          clear_teams();
          $team_count = $score_count = 0;
          $do_print = $is_final = $is_half = $is_ot = 0;
          $time_left = -1;
        }
      }
    } else {
      print STDERR "SKIP: $_\n";
    }
  }
  close(RES);
}

sub lookup_team($) {
  my $n = shift;
  my $aref = $names{$n};
  if (defined($aref)) {
    return @$aref;
  } else {
    return (undef, undef);
  }
}

sub clear_teams() {
  print STDERR "CLEAR TEAMS\n";
  $curr_home_id = undef;
  $curr_home_name = undef;
  $curr_hs = undef;
  $curr_away_id = undef;
  $curr_away_name = undef;
  $curr_as = undef;
}
