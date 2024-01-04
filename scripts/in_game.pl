#!/usr/bin/perl

use POSIX;
use TempoFree;
use warnings;
use strict;

my @ARR = qw( A B C D E F G H I J K L M N O P Q R S T U V W X Y Z
              a b c d e f g h i j k l m n o p q r s t u v w x y z
              0 1 2 3 4 5 6 7 8 9 - . );

sub load_predictions($$$$$);
sub value_to_encoding($);
sub print_img($$$$$$$$);
sub unplayed_game($);
sub at_or_vs($);

my $ingame_log_file = shift(@ARGV);
my $date = shift(@ARGV);

exit 1 if (!defined($date));
exit 1 if (! -f $ingame_log_file);

my $date_str = $date;
$date =~ s/-//g;

my %id2name;
LoadIdToName(\%id2name);

my %names;
LoadPrintableNames(\%names);

my %results;
LoadResults(\%results);

my %gametime;

sub gamesort {
  my $at = $gametime{$a};
  my $bt = $gametime{$b};
  if (!defined($at)) {
    if (!defined($at)) {
      return $a cmp $b;
    } else {
      return 1;
    }
  } else {
    if (!defined($bt)) {
      return -1;
    }
  }
  # If we got here, both $at and $bt are defined.
  if ($at == 3600) {
    if ($bt == 3600) {
      return $a cmp $b;
    } else {
      return 1;
    }
  } else {
    if ($bt == 3600) {
      return -1;
    } else {
      return $bt <=> $at;
    }
  }
}

sub linesort {
  my @aa = split(/,/, $a);
  my @bb = split(/,/, $b);
  # If the second one is greater, then that should be in front.
  # I.e., a team can score when the clock has stopped (e.g., an
  # extra point), and we should use the greater value.
  my $c = $bb[1] <=> $aa[1];
  if ($c) {
    return $c;
  }
  $c = $bb[3] <=> $aa[3];
  return $c;
}

my %tfg_stats;
my %rba_stats;
my %com_stats;
load_predictions($ingame_log_file, \%tfg_stats, \%rba_stats, \%com_stats, \%gametime);

#printf "<!-- TFG %d -->\n", scalar(keys %tfg_stats);
#printf "<!-- RBA %d -->\n", scalar(keys %rba_stats);
#printf "<!-- COM %d -->\n", scalar(keys %com_stats);

my $header = "<link rel=\"stylesheet\" type=\"text/css\" href=\"ncaa.css\" />\n";
my $body = "";
my $t = localtime();
$header .= "<!-- Date $date -->\n";
$header .= "<i>Last updated: $t</i><br /><br />\n";
$header .= sprintf "<!-- Found %d games -->\n", scalar(keys %tfg_stats);
$header .= "<table>\n";
my $chart_server = 0;
foreach my $gid (sort gamesort keys %tfg_stats) {
  my ($d, $hid, $aid) = split(/-/, $gid);
  if ($d != $date) {
#    warn "Date mismatch $d != $date";
    next;
  }
  my $hname = $id2name{$hid};
  if(!defined($hname)) { warn "No name for home team $hid"; next; }
  my $home = $names{$hname};
  if(!defined($home)) { warn "No long name for home team $hname"; next; }
  $home =~ s/&/%26/g;
#  print "<!-- $home -->\n";
  my $aname = $id2name{$aid};
  if(!defined($aname)) { warn "No name for away team $aid"; next; }
  my $away = $names{$aname};
  if(!defined($away)) { warn "No long name for away team $aname"; next; }
  $away =~ s/&/%26/g;
#  print "<!-- $away -->\n";

  my $tfg_game_href = $tfg_stats{$gid};
  my $rba_game_href = $rba_stats{$gid};
  my $com_game_href = $com_stats{$gid};
  if (!defined($tfg_game_href) or !defined($rba_game_href)
      or !defined($com_game_href)) {
    warn "Missing either TFG or RBA data for $gid";
    next;
  }
  my @times = sort { $a <=> $b } keys %$tfg_game_href;
  my ($h, $b) = print_img($gid, $chart_server++ % 10, $home, $away, \@times,
                          $tfg_game_href, $rba_game_href, $com_game_href);
  next if (!defined($b));

  $header .= $h;
  $body .= "<div><div><a name=\"$gid\"/></div>\n";
  $body .= $b;
  $body .= "</div>\n";
#  print "<div>$away at $home</div>\n";
  $body .= "<br />\n";
  $body .= "<br />\n";
}
# TODO: Print the header here
foreach my $rgid (sort { $a cmp $b } keys %results) {
  next if (substr($rgid, 0, 8) != $date);
  next if (defined($tfg_stats{$rgid}));
  $header .= unplayed_game($results{$rgid});
}
$header .= "</table>\n";

print "$header\n";
print "<!-- more --><br />\n";
print "$body\n";

sub load_predictions($$$$$) {
  my $log_file = shift;
  my $tfg_pergame_href = shift;
  my $rba_pergame_href = shift;
  my $com_pergame_href = shift;
  my $gametime_href = shift;

  open(L, "$log_file") or die "Can't open $log_file for reading: $!";
  while (<L>) {
    # 20111125-1028-1107,TFG,1028,0,1107,0,5,0.543
    next if (/^#/);
    chomp;
    my ($gid, $model, $l) = split(/,/, $_, 3);
    my @g = split(/,/, $l);
    my $t = $g[4];
    # If t=0 then there should be no score yet.
    next if (!$t and ($g[1] or $g[3]));
    if ($model eq "COM") {
      $$com_pergame_href{$gid}{$t} = $l;
#      print "<!-- COM Game $gid Time $t -->\n";
    } elsif ($model eq "TFG") {
      $$tfg_pergame_href{$gid}{$t} = $l;
    } elsif ($model eq "RBA") {
      $$rba_pergame_href{$gid}{$t} = $l;
    } else {
      warn "Invalid model: $model";
      next;
    }
    if (defined($$gametime_href{$gid})) {
      $$gametime_href{$gid} = $t if ($t > $$gametime_href{$gid});
    } else {
      $$gametime_href{$gid} = $t;
    }
  }
  close(L);
}

sub value_to_encoding($) {
  my $v = shift;
  return 'AA' if (!defined($v) or ($v < 0));
  $v *= (4095 / 1000);
  my $f = int($v / 64);
  my $s = int($v % 64);
  return $ARR[$f] . $ARR[$s];
}

sub time_to_play($) {
  my $t = shift;
  my @Q = qw( 1st 2nd 3rd 4th );
  my $q = int($t / 900);
  if ($t == 3600) {
    return "Final";
  } elsif ($t == 1800) {
    return "Half";
  } elsif ($t % 900 == 0) {
    return sprintf "End of %s", $Q[$q - 1];
  } else {
    $t -= ($q * 900);
    $t = 900 - $t;
    my $s = $t % 60;
    my $m = int($t / 60);
    return sprintf "%d:%02d %s", $m, $s, $Q[$q];
  }
}

sub print_img($$$$$$$$) {
  my $gid = shift;
  my $chart_server = shift;
  my $home = shift;
  my $away = shift;
  my $times_aref = shift;
  my $tfg_href = shift;
  my $rba_href = shift;
  my $com_href = shift;

  my $home_html = $home;
  $home_html =~ s/%26/&amp;/g;
  my $away_html = $away;
  $away_html =~ s/%26/&amp;/g;

  my $chco = "chco=001A57,8B0A00,76A4FB";
  my $chdl = "chdl=TFG|RBA|Combined&chdlp=b";

  my $url =
  "http://$chart_server.chart.apis.google.com/chart?cht=lc&chs=500x300&$chco&$chdl&chls=2.0&chxt=y,t,x&chds=0,1000";

  my $chxl0 = "0:|$away|75%|50%|75%|$home";
  my $chxl1 = "1:|0";
  my $chxl2 = "2:|0";
  my $chxp0 = "0,0,25,50,75,100";
  my $chxp1 = "1,0";
  my $chxp2 = "2,0";
#  print "<!-- Checking COM at $$times_aref[-1] -->\n";
  my $com_last_line = $$com_href{$$times_aref[-1]};
  if(!defined($com_last_line)) {
    warn "No combined last line\n";
    return undef;
  }
  my ($h, $hs, $a, $as, $t, $p) = split(/,/, $com_last_line);
  if(!defined($p)) {
    warn "No combined probability\n";
    return undef;
  }
  my $tstep = $t / 90;
  my $max_t = $t;

  my $hdr = sprintf "<tr><td class=\"teamName\">%s</td><td class=\"score\">%d</td>"
                    . "<td class=\"teamName\">%s</td><td class=\"score\">%d</td>"
                    . "<td class=\"score\"><a href=\"#%s\">%s</a></td></tr>\n",
                    $away_html, $as, $home_html, $hs,
                    $gid, time_to_play($max_t);
  my $chtt = sprintf "chtt=%s+%d,+%s+%d; %s|%s+%%40+%.1f%%", $away, $as, $home, $hs,
             time_to_play($max_t), ($p < 0.500) ? $away : $home,
             100 * (($p < 0.500) ? 1 - $p : $p);
  $url .= "&$chtt";

  my $first_tfg_line = $$tfg_href{$$times_aref[0]};
  ($h, $hs, $a, $as, $t, $p) = split(/,/, $first_tfg_line);
  return undef if(!defined($p));
  my $curr_tfg_p = $p;

  my $first_rba_line = $$rba_href{$$times_aref[0]};
  ($h, $hs, $a, $as, $t, $p) = split(/,/, $first_rba_line);
  return undef if(!defined($p));
  my $curr_rba_p = $p;

  my $first_com_line = $$com_href{$$times_aref[0]};
  ($h, $hs, $a, $as, $t, $p) = split(/,/, $first_com_line);
  return undef if(!defined($p));
  my $curr_com_p = $p;

  my ($chd_t, $chd_r, $chd_C) = ( "", "", "" );

  my $curr_hs    = 0;
  my $curr_as    = 0;
  my $curr_tpos  = 0;
  foreach my $lt (@$times_aref) {
    my $tfg_l = $$tfg_href{$lt};
    ($h, $hs, $a, $as, $t, $p) = split(/,/, $tfg_l);
    next unless defined($p);
    next unless ($t > 0);
    if ($hs > $curr_hs) {
      $chxl1 .= "|$hs";
      $chxp1 .= sprintf ",%d", 100 * $t / $max_t;
      $curr_hs = $hs;
    }
    if ($as > $curr_as) {
      $chxl2 .= "|$as";
      $chxp2 .= sprintf ",%d", 100 * $t / $max_t;
      $curr_as = $as;
    }
    my $tpos = int($t / $tstep);
    my $tposdiff = $tpos - $curr_tpos;
    next if ($tposdiff <= 0);

    my $tfg_pdiff = $p - $curr_tfg_p;
    $tfg_pdiff /= $tposdiff;

    my $rba_l = $$rba_href{$lt};
    ($h, $hs, $a, $as, $t, $p) = split(/,/, $rba_l);
    my $rba_pdiff = $p - $curr_rba_p;
    $rba_pdiff /= $tposdiff;

    my $com_l = $$com_href{$lt};
    ($h, $hs, $a, $as, $t, $p) = split(/,/, $com_l);
    my $com_pdiff = $p - $curr_com_p;
    $com_pdiff /= $tposdiff;

    foreach my $i (1..$tposdiff) {
      $curr_tfg_p += $tfg_pdiff;
      $chd_t .= sprintf "%s", value_to_encoding($curr_tfg_p * 1000);
      $curr_rba_p += $rba_pdiff;
      $chd_r .= sprintf "%s", value_to_encoding($curr_rba_p * 1000);
      $curr_com_p += $com_pdiff;
      $chd_C .= sprintf "%s", value_to_encoding($curr_com_p * 1000);
    }
    $curr_tpos = $tpos;
  }
  my $chd = "e:$chd_t,$chd_r,$chd_C";

  $url .= "&chxl=" . join('|', $chxl0, $chxl1, $chxl2);
  $url .= "&chxp=" . join('|', $chxp0, $chxp1, $chxp2);
  $url .= sprintf "&chg=%d,25", 100 / ($max_t / 900);
  $url .= "&chd=$chd";
  my $img_body = "<img src=\"$url\">\n";
  return ($hdr, $img_body);
}

sub unplayed_game($) {
  my $aref = shift;
  my $atvs = at_or_vs($aref);
  my $hid = $$aref[5];
  my $aid = $$aref[8];
  my $hname = $id2name{$hid};
  if(!defined($hname)) { warn "No name for home team $hid"; return ""; }
  my $home = $names{$hname};
  if(!defined($home)) { warn "No long name for home team $hname"; return ""; }
  $home =~ s/&/&amp;/g;
#  print "<!-- $home -->\n";
  my $aname = $id2name{$aid};
  if(!defined($aname)) { warn "No name for away team $aid"; return ""; }
  my $away = $names{$aname};
  if(!defined($away)) { warn "No long name for away team $aname"; return ""; }
  $away =~ s/&/&amp;/g;
#  print "<!-- $away -->\n";
  return sprintf "<tr><td class=\"teamName\">%s</td><td>%s</td>"
                 . "<td class=\"teamName\">%s</td><td>&nbsp;</td>"
                 . "<td>Later</td></tr>\n", $away, $atvs, $home;
}

sub at_or_vs($) {
  my $aref = shift;
  my $home = $$aref[6];
  my $away = $$aref[9];
  if ($$aref[3] eq $home) {
    return "at";
  } else {
    return "vs";
  }
}
