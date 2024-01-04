#!/usr/bin/perl 

use TempoFree;
use strict;
use warnings;

sub send_tweet($$$$);
sub send_tweet_helper($$);
sub load_twitter_tags();
sub load_in_game($$$);
sub load_blogposts($);
sub merge_predictions($$$);
sub load_tweet_log($$);
sub print_updated_tweet_log($$$$);
sub usage($);

my %TWEET_TYPES = ( "Q1" => "End of Q1", "Q2" => "Halftime",
                    "Q3" => "End of Q3", "Q4" => "Final",
                    "WATCH" => "Upset Watch", "WARN" => "Upset Warning"
                  );

my $TWEET_TAG_FILE = "data/id2twitter.csv";
my $TWEET_BIN = "scripts/send_tweet.py";
my $BLOGPOSTS = "data/blogposts.txt";

my $base_url = shift(@ARGV);
my $tfg_pred_file = shift(@ARGV);
my $rba_pred_file = shift(@ARGV);
my $in_game_log = shift(@ARGV);
my $tweet_log_in = shift(@ARGV);
my $tweet_log_out = shift(@ARGV);

usage($0) if (!defined($tweet_log_out));

if (! -f $tfg_pred_file) {
  print STDERR "No TFG prediction file $tfg_pred_file\n";
  usage($0);
}
if (! -f $rba_pred_file) {
  print STDERR "No RBA prediction file $rba_pred_file\n";
  usage($0);
}
if (! -f $in_game_log) {
  print STDERR "No in-game log $in_game_log\n";
  usage($0);
}

my %id2name;
LoadIdToName(\%id2name);

my %names;
LoadPrintableNames(\%names);

my %id2conf;
LoadConferences(undef, \%id2conf, undef, undef);

my %tfg_pred;
LoadPredictions($tfg_pred_file, 1, \%tfg_pred);
my %rba_pred;
LoadPredictions($rba_pred_file, 1, \%rba_pred);
my %blogposts;
load_blogposts(\%blogposts);
my %com_pred;
merge_predictions(\%tfg_pred, \%rba_pred, \%com_pred);
my %curr_tweet_log;
load_in_game($in_game_log, \%com_pred, \%curr_tweet_log);
my %prev_tweet_log;
load_tweet_log($tweet_log_in, \%prev_tweet_log);
my %twitter_tags;
load_twitter_tags();
#printf "Found tweets for %d games.\n", scalar(keys %prev_tweet_log);
print_updated_tweet_log(\%prev_tweet_log, \%curr_tweet_log, \%blogposts, $tweet_log_out);

sub usage($) {
  my $p = shift;
  my @path = split(/\//, $p);
  $p = pop(@path);
  print STDERR "\n";
  print STDERR "Usage: $p <tfg_pred> <rba_pred> <in_game_log> <tweet_log_in> <tweet_log_out>\n";
  print STDERR "\n";
  exit 1;
}

sub load_blogposts($) {
  my $href = shift;
  open(BLOGPOSTS, "$BLOGPOSTS") or die "Can't open blogposts for reading: $!";
  while(<BLOGPOSTS>) {
    chomp;
    my ($title, $url) = split(/,/);
    next unless (index($url, $base_url) != -1);
    $$href{$title} = $url;
  }
  close(BLOGPOSTS);
}

# In-game log format:
# GID,PredType,Team1ID,Team1Score,Team2ID,Team2Score,SecondsPassed,ProbTeam1
sub load_in_game($$$) {
  my $fname = shift;
  my $pred_href = shift;
  my $tweet_href = shift;
  my $c = 0;
  open(INGAME, "$fname") or die "Can't open in-game log $fname for reading: $!";
  while(<INGAME>) {
    next if (/^#/);
    chomp;
    @_ = split(/,/);
    next if ($_[1] ne "COM");
#    print "INGAME $_\n";
    my $gid = $_[0];
    if ($_[6] == 3600 and $_[3] != $_[5]) {
      $$tweet_href{$gid}{"Q4"} = $_;
      ++$c;
    } elsif ($_[6] >= 2700) {
      if (!defined($$tweet_href{$gid}{"Q3"})) {
        $$tweet_href{$gid}{"Q3"} = $_;
        ++$c;
      }
    } elsif ($_[6] >= 1800) {
      if (!defined($$tweet_href{$gid}{"Q2"})) {
        $$tweet_href{$gid}{"Q2"} = $_;
        ++$c;
      }
    } elsif ($_[6] >= 900) {
      if (!defined($$tweet_href{$gid}{"Q1"})) {
        $$tweet_href{$gid}{"Q1"} = $_;
        ++$c;
      }
    }
    next if (!defined($$pred_href{$gid}));
    next if ($_[6] == 3600);
    if (($$pred_href{$gid} <= (1./4) and $_[7] >= 0.9)
        or ($$pred_href{$gid} >= (3./4) and $_[7] <= 0.1)) {
      if (!defined($$tweet_href{$gid}{"WARN"})) {
        $$tweet_href{$gid}{"WARN"} = $_;
        ++$c;
      }
    }
    elsif (($$pred_href{$gid} <= (1./4) and $_[7] >= 0.7)
        or ($$pred_href{$gid} >= (3./4) and $_[7] <= 0.3)) {
      if (!defined($$tweet_href{$gid}{"WATCH"})) {
        $$tweet_href{$gid}{"WATCH"} = $_;
        ++$c;
      }
    }
  }
#  print "Found $c tweet-worthy items\n";
  close(INGAME);
}

sub merge_predictions($$$) {
  my $tfg_pred_href = shift;
  my $rba_pred_href = shift;
  my $com_pred_href = shift;
  foreach my $gid (keys %$tfg_pred_href) {
    my $tfg_aref = $$tfg_pred_href{$gid};
    my $rba_aref = $$rba_pred_href{$gid};
    next if (!defined($rba_aref) or !defined($tfg_aref));
    my $tfg_odds = $$tfg_aref[5];
    if ($$tfg_aref[2] < $$tfg_aref[4]) { $tfg_odds = 1 - $tfg_odds; }
    my $rba_odds = $$rba_aref[5];
    if ($$rba_aref[2] < $$rba_aref[4]) { $rba_odds = 1 - $rba_odds; }
    $$com_pred_href{$gid} = ($tfg_odds + $rba_odds) / 2;
  }
}

# Tweet log format:
# Type,GameID,Message
sub load_tweet_log($$) {
  my $fname = shift;
  my $tweet_href = shift;
  if (! -f $fname) {
#    warn "No existing tweet log $fname";
    return;
  }
  open(TWEET, "$fname") or die "Can't load tweet log $fname: $!";
  while(<TWEET>) {
    next if (/^#/);
    chomp;
    @_ = split(/,/, $_, 3);
    $$tweet_href{$_[0]}{$_[1]} = $_[2];
  }
  close(TWEET);
}

sub load_twitter_tags() {
  open my $fh, "<", $TWEET_TAG_FILE or return;
  while (<$fh>) {
    chomp;
    if (/^(\d{4}),(#\w+)$/) {
      $twitter_tags{$1} = $2;
    }
  }
  close $fh;
}

sub id_to_name($) {
  my $id = shift;
  my $n = $id2name{$id};
  return undef if (!defined($n));
  my $pn = $names{$n};
  return $n if (!defined($pn));
  return $pn;
}

sub id_to_hashtag($) {
  my $id = shift;
  my $t = $twitter_tags{$id};
  return $t if (defined($t));
  my $n = id_to_name($id);
  $n =~ s/\s//g;
  return "#" . $n;
}

sub seconds_to_time($$) {
  my $time_left = shift;
  my $prob = shift;
  if ($time_left == 3600) {
    if ($prob == 0.0 or $prob == 1.0) {
      return "FINAL";
    } else {
      return "OT";
    }
  } elsif (abs($time_left - 2700) < 5) {
    return "End of 3rd";
  } elsif ($time_left == 1800) {
    return "Half";
  } elsif (abs($time_left - 900) < 5) {
    return "End of 1st";
  }
  my $q = 1 + int($time_left / 900);
  $time_left = $time_left % 900;
  $time_left = 900 - $time_left;
  my $min = int($time_left / 60);
  my $sec = $time_left% 60;
  if ($q == 1) { $q = "1st"; }
  elsif ($q == 2) { $q = "2nd"; }
  elsif ($q == 3) { $q = "3rd"; }
  else { $q = "4th"; }
  return sprintf "%d:%02d %s", $min, $sec, $q;
}

sub send_tweet_helper($$) {
  my $dest = shift;
  my $body = shift;
  my $cmd = "$TWEET_BIN $dest \"$body\"";
  print STDERR "TWEET $cmd\n";
  open(CMD, "$cmd|") or do {
    print STDERR "Error running tweeter: $cmd";
    return;
  };
  my @o = <CMD>;
  close(CMD);
  print STDERR @o;
}

sub url_for_game($$) {
  my $url_href = shift;
  my $gid = shift;

  my ($date, $t1, $t2) = split(/-/, $gid);
  return undef if (!defined($t2));
  my $c1 = $id2conf{$t1};
  my $c2 = $id2conf{$t2};
  print STDERR "C1 '$c1' C2 '$c2'\n";
  return undef if (!defined($c1) and !defined($c2));
  foreach my $title (keys %$url_href) {
    print STDERR "Title '$title'\n";
    return $$url_href{$title} if (index($title, $c1) != -1);
    return $$url_href{$title} if (index($title, $c2) != -1);
  }
  return undef;
}

sub send_tweet($$$$) {
  my $posts_href = shift;
  my $gid = shift;
  my $type = shift;
  my $line = shift;
  # E.g.,
  # GID: 20120901-1513-1726
  # TYPE: Q2
  # LINE: 20120901-1513-1726,COM,1513,40,1726,10,2454,0.998
  my ($a, $b, $t1id, $t1s, $t2id, $t2s, $time_left, $p) = split(/,/, $line);
  return if (!defined($p));
  my $t1n = id_to_name($t1id);
  my $t2n = id_to_name($t2id);
  if (!defined($t1n) or !defined($t2n)) {
    print STDERR "Missing name for either $t1id or $t2id\n";
    return;
  }
  my $t1h = id_to_hashtag($t1id);
  my $t2h = id_to_hashtag($t2id);
  if (!defined($t1h)) { $t1h = ""; }
  if (!defined($t2h)) { $t2h = ""; }
  return if ($time_left < 0);
  my $leader = ($p > .500) ? $t1n : $t2n;
  my $prob = ($p > .500) ? $p : 1 - $p;
  my $t = sprintf "%s %d, %s %d; %s.", $t1n, $t1s, $t2n, $t2s,
                  seconds_to_time($time_left, $prob);
  if ($time_left != 3600 or $prob != 1.0) {
    $t .= sprintf " %s @ %.1f%%", $leader, 100 * $prob;
  }
  my $game_url = url_for_game($posts_href, $gid);
  printf STDERR "GID %s URL %s\n", $gid, (defined($game_url) ? $game_url : "(none)"); 
  my $both = 0;
  if ($type eq "WATCH") {
    if ($time_left == 3600) { $t .= " #UPSET"; }
    else { $t .= " #UpsetWatch"; }
    $both = 1;
  } elsif ($type eq "WARN") {
    if ($time_left == 3600) { $t .= " #UPSET"; }
    else { $t .= " #UpsetWarning"; }
    $both = 1;
  }
  $t .= sprintf " %s %s", $t1h, $t2h;
  # Can we add some other tags?
  # #InGameOdds -> 12 chars total
  # #CFB -> 5 chars total
  # URL -> 22 characters
  if (length($t) <= (280 - 23) and defined($game_url) and length($game_url)) {
    $t .= " $game_url#$gid";
  } elsif (length($t) <= (280 - 23)) {
    $t .= " #InGameOdds #CFB";
  } elsif (length($t) <= (280 - 12)) {
    $t .= " #InGameOdds";
  } elsif (length($t) <= (280 - 5)) {
    $t .= " #CFB";
  }
  send_tweet_helper("odds", $t);
  send_tweet_helper("main", $t) if ($both);
}

sub print_updated_tweet_log($$$$) {
  my $prev_href = shift;
  my $curr_href = shift;
  my $posts_href = shift;
  my $outfile = shift;
  open (OUTF, ">$outfile") or die "Can't open $outfile for writing: $!";
  foreach my $gid (sort keys %$curr_href) {
    my $href = $$curr_href{$gid};
    foreach my $s (sort keys %$href) {
      if (!defined($$prev_href{$gid}{$s})) {
        send_tweet($posts_href, $gid, $s, $$href{$s});
      }
      print OUTF "$gid,$s,$$href{$s}\n";
    }
  }
  close(OUTF);
}
