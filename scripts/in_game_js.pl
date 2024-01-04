#!/usr/bin/perl

use Digest::SHA(sha256_hex);
use POSIX;
use TempoFree;
use warnings;
use strict;

my $CHART_STYLE = "width: 600px; height: 400px;";

sub timeofday($);
sub load_predictions($$$$$);
sub should_include($);
sub image_functions($$$$$$$$$);
sub insert_midpoint($$$$);
sub unplayed_game($);
sub at_or_vs($);

my $ingame_log_file = shift(@ARGV);
my $date = shift(@ARGV);

exit 1 if (!defined($date));
exit 1 if (! -f $ingame_log_file);

my %confs;
for my $c (@ARGV) {
  $confs{$c} = 1;
}

my $date_str = $date;
$date =~ s/-//g;

my %id2name;
LoadIdToName(\%id2name);

my %names;
LoadPrintableNames(\%names);

my %results;
LoadResults(\%results);

my %colors;
LoadColors(\%colors);

my %team2conf;
LoadConferences(undef, \%team2conf, undef, undef);

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
#
my $t = localtime();
my $num_games = scalar(keys %tfg_stats);
my $table_header = <<TABLEHDR;
<!-- Date $date -->
<i>Last updated: $t</i><br /><br />
<table>
TABLEHDR
my $js_function_bodies = <<JSBODIES;
<script type="text/javascript" src="https://www.google.com/jsapi"></script>
<script type="text/javascript">
  google.load("visualization", "1", {packages:["corechart"]});
  google.setOnLoadCallback(drawCharts);
JSBODIES
my $draw_charts_function = <<DRAWCHARTS;
  function drawCharts() {
    var t0 = performance.now();
DRAWCHARTS

my $body = "";
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
#  $home =~ s/&/%26/g;
#  print "<!-- $home -->\n";
  my $aname = $id2name{$aid};
  if(!defined($aname)) { warn "No name for away team $aid"; next; }
  my $away = $names{$aname};
  if(!defined($away)) { warn "No long name for away team $aname"; next; }
#  $away =~ s/&/%26/g;
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
  my ($hdr, $div_line, $js_body, $js_name) = image_functions($gid, $home, $away,
    $hid, $aid, \@times, $tfg_game_href, $rba_game_href, $com_game_href);
  next if (!defined($js_name));

  $js_function_bodies .= $js_body;
  $table_header .= $hdr;
  $draw_charts_function .= "    $js_name;\n";
  $body .= "<div><div><a name=\"$gid\"/></div>\n";
  $body .= $div_line;
  $body .= "</div>\n<br />\n";
}
$draw_charts_function .=<<DRAWEND;
    var t1 = performance.now();
    console.log("Charts took " + (t1 - t0) + " milliseconds.");
  }
</script>
DRAWEND
# TODO: Print the header here
foreach my $rgid (sort { $a cmp $b } keys %results) {
  next if (substr($rgid, 0, 8) != $date);
  next if (defined($tfg_stats{$rgid}));
  next unless (should_include($rgid));
  ++$num_games;
  $table_header .= unplayed_game($results{$rgid});
}
$table_header .= "</table>\n";

my $checksum = sha256_hex($js_function_bodies);

print "$js_function_bodies\n";
print "$draw_charts_function\n";
print "$table_header\n";
print "<!-- Found $num_games games -->\n";
print "<!-- more --><br />\n";
print "$body\n";
print "<!-- CHECKSUM|$checksum| -->\n";

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
    next unless (should_include($gid));
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

sub should_include($) {
  my $gid = shift;
  # If no specific conferences are listed, skip
  if (scalar(keys %confs) == 0) {
    return 1;
  }
  my ($gdate, $t1id, $t2id) = split(/-/, $gid);
  if (!defined($t1id) or !defined($t2id)) {
    return 0;
  }
  my $c1 = $team2conf{$t1id};
  my $c2 = $team2conf{$t2id};
  if (defined($confs{$c1}) or defined($confs{$c2})) {
    return 1;
  }
  return 0;
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

# Returns
# (table_row, div_element, js_function_body, js_function_name)
sub image_functions($$$$$$$$$) {
  my $gid = shift;
  my $home = shift;
  my $away = shift;
  my $home_id = shift;
  my $away_id = shift;
  my $times_aref = shift;
  my $tfg_href = shift;
  my $rba_href = shift;
  my $com_href = shift;

  my $home_html = $home;
  $home_html =~ s/%26/&amp;/g;
  my $away_html = $away;
  $away_html =~ s/%26/&amp;/g;
  my $flat_gid = $gid;
  $flat_gid =~ s/-/_/g;

  my $home_color = $colors{$home_id};
  $home_color = "#000" if (!defined($home_color));
  my $away_color = $colors{$away_id};
  $away_color = "#000" if (!defined($away_color));

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
  my $max_t = $t;

  my $hdr = sprintf "<tr><td class=\"teamName\">%s</td><td class=\"score\">%d</td>"
                    . "<td class=\"teamName\">%s</td><td class=\"score\">%d</td>"
                    . "<td class=\"score\"><a href=\"#%s\">%s</a></td></tr>\n",
                    $away_html, $as, $home_html, $hs,
                    $gid, time_to_play($max_t);
  my $game_status = sprintf "%s %d, %s %d; %s  -- %s @ %.1f%%", $away, $as, $home, $hs,
             time_to_play($max_t), ($p < 0.500) ? $away : $home,
             100 * (($p < 0.500) ? 1 - $p : $p);

  my $function_name = "draw_$flat_gid()";
  my $div_id = "game_$flat_gid";
  my $div_line = "<div id=\"$div_id\" style=\"$CHART_STYLE\"></div>\n";
  my $js_function_body = <<JSEND;
  function $function_name {
    var options = {
      titleTextStyle: {fontName: 'Tahoma', fontSize: 16},
      series: {
        0: {color: "$away_color", targetAxisIndex: 1},
        1: {color: "$home_color"},
        2: {color: "$away_color", visibleInLegend: false, lineWidth: 0},
        3: {color: "$home_color", visibleInLegend: false, lineWidth: 0},
      },
      legend: { position: "bottom" },
      hAxis: { ticks: [{v:[0,0,0,0], f:"Q1"}, {v:[0,15,0,0], f:"Q2"}, {v:[0,30,0,0], f:"Q3"}, {v:[0,45,0,0],f:"Q4"}, {v:[1,0,0,0],f:"Final"}]},
      vAxes: [
       { ticks: [{v:0, f:"$away 100%"}, {v:25,f:"75%"}, {v:50,f:"50%"}, {v:75,f:"75%"}, {v:100,f:"$home 100%"}]},
       { direction: -1, minValue: 0, maxValue: 100}
      ],
      title: "$game_status",
    };

    var data = new google.visualization.DataTable();
    data.addColumn('timeofday', 'Time');
    data.addColumn('number', '$away');
    data.addColumn('number', '$home');
    data.addColumn('number', 'away');
    data.addColumn({type: 'string', role: 'annotation'});
    data.addColumn({type: 'string', role: 'annotationText'});
    data.addColumn('number', 'home');
    data.addColumn({type: 'string', role: 'annotation'});
    data.addColumn({type: 'string', role: 'annotationText'});
    data.addRows([
JSEND

  my $last_p = undef;
  my $last_t = undef;
  my $curr_hs    = 0;
  my $curr_as    = 0;
  foreach my $lt (@$times_aref) {
    my @values = ( timeofday($lt) );
    my $com_l = $$com_href{$lt};
    ($h, $hs, $a, $as, $t, $p) = split(/,/, $com_l);
    next unless defined($p);
    next unless ($t >= 0);
    if (!defined($last_p)) { $last_p = $p; }
    if ($p > 0.5) {
      if ($last_p <= 0.5) {
        # Crossed over. Insert a midpoint line
        $js_function_body .= insert_midpoint($last_t, $last_p, $lt, $p);
      }
      push(@values, "null", (sprintf "%.1f", 100 * $p));
    } else {
      if ($last_p > 0.5) {
        # Crossed over. Insert a midpoint line
        $js_function_body .= insert_midpoint($last_t, $last_p, $lt, $p);
      }
      push(@values, (sprintf "%.1f", 100 * (1 - $p)), "null");
    }
    $last_p = $p;
    my $home_annotation = "";
    if ($hs > $curr_hs) {
      # Home team scored
      $home_annotation = $hs;
      $curr_hs = $hs;
    }
    my $away_annotation = "";
    if ($as > $curr_as) {
      # Away teams scored
      $away_annotation = $as;
      $curr_as = $as;
    }
    if (!length($away_annotation)) {
      push(@values, "null", "null", "null");
    } else {
      push(@values, "0", "'$away_annotation'", (sprintf "'%s %d, %s %d'", $home, $hs, $away, $as));
    }
    if (!length($home_annotation)) {
      push(@values, "null", "null", "null");
    } else {
      push(@values, "100", "'$home_annotation'", (sprintf "'%s %d, %s %d'", $home, $hs, $away, $as));
    }
    $js_function_body .= sprintf "      [ %s ],\n", join(', ', @values);
    $last_t = $lt;
  }
  $js_function_body .= <<JSEND;
    ]);
    var chart = new google.visualization.LineChart(document.getElementById("$div_id"));
    chart.draw(data, options);
  }
JSEND
  return ($hdr, $div_line, $js_function_body, $function_name);
}

sub timeofday($) {
  my $seconds = shift;
  if ($seconds == 3600) {
    return "[1,0,0,0]";
  }
  my $minutes = int($seconds / 60);
  $seconds -= ($minutes * 60);
  return sprintf "[0,%d,%d,0]", $minutes, $seconds;
}

sub insert_midpoint($$$$) {
  my $last_x = shift;
  my $last_y = shift;
  my $new_x = shift;
  my $new_y = shift;
  return "" if (!defined($last_x));
  return "" if ($last_x == $new_x);
  my $slope = ($new_y - $last_y) / ($new_x - $last_x);
  my $intercept_x = (0.5 - $last_y) / $slope;
#  printf "<!-- $last_x $new_x $last_y $new_y $slope $intercept_x -->\n";
  $intercept_x += $last_x;
  my @values = ( timeofday($intercept_x) );
  push(@values, "50", "50", "null", "null", "null", "null", "null", "null");
  return sprintf "      [ %s ],\n", join(', ', @values);
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
