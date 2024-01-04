#!/usr/bin/perl -w

use TempoFree;
use Text::CSV;
use strict;
use warnings;

my $playfile = shift(@ARGV);
my $scorefile = shift(@ARGV);
my $mergedfile = shift(@ARGV);
my $logfile = shift(@ARGV);

if (!defined($playfile) or ! -f $playfile) {
  die "Missing play file\nUsage: $0 <playfile> <scorefile> <mergedfile> [logfile]\n";
}
if (!defined($scorefile) or ! -f $scorefile) {
  die "Missing score file\nUsage: $0 <scorefile> <scorefile> <mergedfile> [logfile]\n";
}
if (!defined($mergedfile)) {
  die "Missing merged file\nUsage: $0 <scorefile> <scorefile> <mergedfile> [logfile]\n";
}
if (!defined($logfile)) {
  $logfile = "/dev/null";
}

my %results;
LoadResults(\%results);

my $csv = Text::CSV->new() or die "Cannot use CSV: " . Text::CSV->error_diag();

my @plays;
open my $p, "<", $playfile or die "Can't open play file: $!";
while (my $row = $csv->getline($p)) {
  push (@plays, $row);
}
close $p;

my @scores;
open my $s, "<", $scorefile or die "Can't open score file: $!";
while(my $row = $csv->getline($s)) {
  push (@scores, $row);
}
close $s;

if (!@plays or !@scores) {
  die "Missing play and/or score data";
}

my $play_gid = $plays[0]->[0];
my $score_gid = $scores[0]->[0];
if ($play_gid ne $score_gid) {
  die "PlayGid $play_gid != ScoreGid $score_gid";
}

open my $logf, ">", $logfile or die "Can't open log file: $!";
my ($date, $home, $away) = split(/-/, $play_gid);
my $href = $results{$play_gid};
my $swap_home_away = 0;
if (!defined($href)) {
  $play_gid = sprintf "%d-%d-%d", $date, $away, $home;
  $href = $results{$play_gid};
  if (!defined($href)) {
    die "Cannot find GID $score_gid or $play_gid";
  }
  print $logf "Swapping scores\n";  
  $swap_home_away = 1;
}

my $score_idx = 0;
my $score_time = $scores[$score_idx]->[1];
my $curr_away_score = 0;
my $curr_home_score = 0;
for (my $play_idx = 0; $play_idx <= $#plays; ++$play_idx) {
  printf $logf "PlayIdx %d ScoreIdx %d PlayClock %4d ScoreClock %4d\n",
               $play_idx, $score_idx, $plays[$play_idx]->[3],
               defined($score_time) ? $score_time : -1;
  # Is this potentially a scoring play?
  if (defined($score_time) and ($plays[$play_idx]->[3] == $score_time)
      and ($plays[$play_idx]->[3] <= 3600)) {
    printf $logf "Possible scoring play\n";
    # Yes. But if there is a next play ...
    if (($play_idx + 1) <= $#plays) {
      # ... but the clock on the next play NOT is the same as this clock
      if ($plays[$play_idx + 1]->[1] != $plays[$play_idx]->[1]) {
        # ... then we've found a new scoring play.
        # Set the new away and home score.
        $curr_away_score = $scores[$score_idx]->[2];
        $curr_home_score = $scores[$score_idx]->[3];
        print $logf "Found new score at $score_time\n";
        # Then try and advance the score_idx
        if (++$score_idx <= $#scores) {
          $score_time = $scores[$score_idx]->[1];
        } else {
          print $logf "Last score of game happened at $score_time\n";
          $score_time = undef;
        }
      } else {
        printf $logf "Duplicate of scoring play at $score_time\n";
      }
    } else {
      print $logf "Score on last play of game\n";
      $curr_away_score = $scores[$score_idx]->[2];
      $curr_home_score = $scores[$score_idx]->[3];
      print $logf "Found new score at $score_time\n";
      # Then try and advance the score_idx
      if (++$score_idx <= $#scores) {
        $score_time = $scores[$score_idx]->[1];
      } else {
        print $logf "Last score of game happened at $score_time\n";
        $score_time = undef;
      }
    }
  }
  $plays[$play_idx]->[0] = $play_gid;
  if (!$swap_home_away) {
    $plays[$play_idx]->[4] = $curr_away_score;
    $plays[$play_idx]->[5] = $curr_home_score;
  } else {
    $plays[$play_idx]->[4] = $curr_home_score;
    $plays[$play_idx]->[5] = $curr_away_score;
  }
  if ($plays[$play_idx]->[3] == 3601) {
    print $logf "OVERTIME!!!\n";
  }
  # Now check to see if there's a wonky possession turnover without noticing it
  # for a down.
  next if ($play_idx == $#plays);
  my $curr_off = $plays[$play_idx]->[6];
  my $curr_down = $plays[$play_idx]->[9];
  my $next_off = $plays[$play_idx + 1]->[6];
  my $next_down = $plays[$play_idx + 1]->[9];
  if ($curr_off != $next_off and $curr_down == 1 and $next_down == 2) {
    print $logf "Wonky missed change of possession\n";
    $plays[$play_idx]->[6] = $next_off;
    $plays[$play_idx]->[1] = $plays[$play_idx + 1]->[1];
  }
}

open my $m, ">", $mergedfile or die "Can't open merged file: $!";
foreach my $aref (@plays) {
  $csv->print($m, $aref);
  print $m "\n";
}
close $m;
