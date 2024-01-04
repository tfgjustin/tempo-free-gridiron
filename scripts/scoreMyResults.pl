#!/usr/bin/perl -w

use strict;

my %predictions;
my %perweek_correct;
my %peryear_correct;

my $good_fname = shift(@ARGV);
my $pred_fname = shift(@ARGV);

sub usage($);
sub avg_dev($);
sub score_game($$$$);
sub gid_to_season($);
sub print_results($$$);

if (!defined($pred_fname)) {
  usage($0);
}

if (! -r $good_fname or ! -r $pred_fname) {
  warn "Could not find one of provided filenames";
  usage($0);
}

open(GOOD, "$good_fname") or die "Could not open $good_fname for reading: $!";
while(<GOOD>) {
  next unless (/\d{1,3},200[2-9]/ or /\d{1,3},201[0-9]/);
  chomp;
  @_ = split(/,/);
  if (scalar(@_) < 11) {
    warn "Invalid line: $_\n";
    next;
  }
  my $week = $_[0];
  my $gid  = $_[2];
  my $site = $_[3];
  my $np   = $_[4];
  my $hs   = $_[7];
  my $as   = $_[10];
  next unless (length($hs) and length($as) and $hs > 0 and $as > 0);
  # GameID => "Home:Away"
  my $season = gid_to_season($gid);
  my $pwc_href = $perweek_correct{$week};
  if (!defined($pwc_href)) {
    my %pw_hash;
    $pwc_href = \%pw_hash;
    $perweek_correct{$week} = $pwc_href;
  }
  my $psc_href = $peryear_correct{$season};
  if (!defined($psc_href)) {
    my %ps_hash;
    $psc_href = \%ps_hash;
    $peryear_correct{$season} = $psc_href;
  }
  if ($site eq "NEUTRAL") {
    $site = 1;
  } else {
    $site = 0;
  }
#  printf "PWC W %d HRP %x GID %s\n", $week, $pwc_href, $gid;
  $$pwc_href{$gid} = "$hs:$as:$np:$site";
  $$psc_href{$gid} = "$hs:$as:$np:$site";
}
close(GOOD);

open(PRED, "$pred_fname") or die "Could not open $pred_fname for reading: $!";
while(<PRED>) {
  next unless(/^PREDICT,PARTIAL/);
#  next unless(/^PREDICT/);
  chomp;
  @_ = split(/,/);
  if (scalar(@_) < 8) {
    warn "Invalid line: $_\n";
    next;
  }
  my $gid  = $_[2];
  my $hs   = $_[5];
  my $as   = $_[7];
  my $val = "$hs:$as";
  if (scalar(@_) >= 9) {
    if ($_[8] > 1000) {
      $_[8] = 1000;
    }
    if ($_[8] < 0) {
      $_[8] = 0;
    }
    $val .= ":$_[8]";
    if (scalar(@_) >= 11) {
      $val .= ":$_[9]:$_[10]";
      if (scalar(@_) >= 12) {
	      $val .= ":$_[11]";
      }
    }
  }
  # GameID => "Home:Away[:Odds]"
  $predictions{$gid} = $val;
  #print STDERR "Predict $gid\n";
}
close(PRED);

#printf "PWC=%d\n", scalar(keys %perweek_correct);

print_results(\%perweek_correct, "WK", 1);
print_results(\%peryear_correct, "YR", 0);

sub print_results($$$) {
  my $href = shift;
  my $tag = shift;
  my $do_print = shift;
  foreach my $wk (sort { $a <=> $b } keys %$href) {
    my $correct_href = $$href{$wk};
#  printf "PW[$wk] = %d\n", scalar(keys %$correct_href);
    my $WINS = 0;
    my $games = 0;
    my $expected = 0;
    foreach my $gid (sort keys %$correct_href) {
      my $good_s = $$correct_href{$gid};
      my $pred_s = $predictions{$gid};
      if (!defined($pred_s)) {
#        print STDERR "No prediction for game $gid\n";
        next;
      }
      my ($w, $e) = score_game($gid, $good_s, $pred_s, $do_print);
      if ($e < 500) { $e = 1000 - $e; }
      $expected += $e;
      $WINS += $w;
      $games++;
    }
    if (!$games) {
      print "No games!\n";
      next;
    }
    
    $expected /= 1000;
    printf "$tag %3d GS %3d WS %3d EW %6.2f WP %.4f ERR %6.2f\n", $wk,
           $games, $WINS, $expected, ($WINS / $games), $WINS - $expected;
  }
}

sub score_game($$$$) {
  my $win = 0;
  my $game_id = shift;
  my $good_info = shift;
  my $pred_info = shift;
  my $print_res = shift;
  my ($good_h, $good_a, $good_p, $good_s) = split(/:/, $good_info);
  my ($pred_h, $pred_a, $pred_oh, $h_sos, $a_sos, $pred_p) = split(/:/, $pred_info);
  if (!defined($pred_oh)) { $pred_oh = 0; }
  if (!defined($h_sos) or !defined($a_sos)) {
    $h_sos = $a_sos = 0;
  }
  if ((($good_h > $good_a) and ($pred_h > $pred_a))
      or (($good_h < $good_a) and ($pred_h < $pred_a))) {
    $win = 1;
  }
  my ($pred_he, $pred_ae) = ( -1, -1 );
  if (defined($pred_p) and ($pred_p != 0)) {
    $pred_he = 100 * $pred_h / $pred_p;
    $pred_ae = 100 * $pred_a / $pred_p;
  }
  my ($good_he, $good_ae) = ( -1, -1 );
  if (defined($good_p) and $good_p) {
    $good_he = 100 * $good_h / $good_p;
    $good_ae = 100 * $good_a / $good_p;
  }
  if ($print_res) {
    printf "%s G %2d %2d  P %2d %2d S %1d N %1d %4d SS %4d %4d "
           . "GE %4.1f %4.1f PE %4.1f %4.1f\n",
           $game_id, $good_h, $good_a, $pred_h, $pred_a, $win, $good_s, $pred_oh,
	   $h_sos, $a_sos, $good_he, $good_ae, $pred_he, $pred_ae;
  }
  return ($win, $pred_oh);
}

sub avg_dev($) {
  my $aref = shift;
  my $sum = 0;

  foreach my $v (@$aref) {
    $sum += $v;
  }

  my $num = scalar(@$aref);
  if(!$num) {
    return (-1, -1);
  }
  my $avg = $sum / $num;

  my $sos = 0;
  foreach my $v (@$aref) {
    my $diff = $v - $avg;
    $diff *= $diff;

    $sos += $diff;
  }

  my $dev = 0;
  if($num > 1) {
    $dev = sqrt($sos) / ($num - 1);
  }
  return ($avg, $dev);
}

sub usage($) {
  print STDERR "\n";
  print STDERR "Usage: $0 <golden_results> <pred_results>\n";
  print STDERR "\n";
  exit 1;
}

sub gid_to_season($) {
  my $gid = shift;
  if ($gid =~ /(\d{4})(\d{2})\d{2}.*/) {
    my $year = $1;
    my $month = $2;
    if ($month eq "01") {
      return $year - 1;
    } else {
      return $year;
    }
  } else {
    return "00unknown";
  }
}
