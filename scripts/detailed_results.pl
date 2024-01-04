#!/usr/bin/perl 

use TempoFree;
use strict;
use warnings;

my $predict_file = shift(@ARGV);
my $results_file = shift(@ARGV);
my $predsystem = shift(@ARGV);

exit 1 if (!defined($predsystem));

my %predictions;
LoadPredictions($predict_file, 1, \%predictions);

my %results;
LoadResultsFromFile($results_file, \%results);

my %id2name;
LoadIdToName(\%id2name);

my %names;
LoadPrintableNames(\%names);

sub get_printable_name($) {
  my $tid = shift;
  my $shortname = $id2name{$tid};
  return "(unknown)" if (!defined($shortname));
  my $name = $names{$shortname};
  return $shortname if (!defined($name));
  return $name;
}

my $exp_win = 0;
my $exp_loss = 0;
my $act_win = 0;
my $act_loss = 0;

my %right;
my %wrong;
my %odds;
foreach my $gid (keys %results) {
  my $res_aref = $results{$gid};
  my $pred_aref = $predictions{$gid};
  next if (!defined($pred_aref));
  next if ($$res_aref[4]);
  if ($$pred_aref[2] > $$pred_aref[4]) {
    # We expected the home team to win
    if ($$res_aref[7] > $$res_aref[10]) {
      # Home team won!
      $act_win++;
      $right{$gid} = 1;
    } else {
      $act_loss++;
      $wrong{$gid} = 1;
    }
  } else {
    # We expected the away team to win
    if ($$res_aref[7] > $$res_aref[10]) {
      # Home team won. Boo!
      $act_loss++;
      $wrong{$gid} = 1;
    } else {
      $act_win++;
      $right{$gid} = 1;
    }
  }
  $odds{$gid} = $$pred_aref[5];
  $exp_win += $$pred_aref[5];
  $exp_loss += (1 - $$pred_aref[5]);
}

exit 0 if (!scalar keys %results);

print "<html><head>\n";
print "<link rel=\"stylesheet\" type=\"text/css\" href=\"ncaa.css\" />\n";
print  "</head><body><table class=\"conf-table\"><tr class=\"$predsystem\"><th colspan=4>Record</th></tr>\n";
printf "<tr><td>Expected:</td><td><span class=\"score\">%5.2f</span></td><td>&nbsp;-&nbsp;</td>"
       . "<td><span class=\"score\">%5.2f</span></td></tr>\n", $exp_win, $exp_loss;
printf "<tr><td>Actual</td><td><span class=\"score\">%5.2f</span></td><td>&nbsp;-&nbsp;</td>"
       . "<td><span class=\"score\">%5.2f</span></td></tr>\n", $act_win, $act_loss;
my $t = localtime();
printf "<tr><td colspan=4 class=\"disclaimer\">Last updated: %s</td></tr>\n", $t;
print  "</table>\n";

print  "<h4>Incorrect</h4>\n";
foreach my $gid (sort { $odds{$b} <=> $odds{$a} } keys %wrong) {
  my $res_aref = $results{$gid};
  my $pred_aref = $predictions{$gid};
  print  "<table class=\"pred-table\">\n";
  printf "<tr align=\"center\">\n  <td width=\"200\" bgcolor=\"red\">%4.1f%%</td>\n", 100 * $$pred_aref[5];
  print  "  <th>Pred</th>\n  <th>Act</th>\n</tr>\n";
  printf "<tr><td><span class=\"teamName\">%s</span></td><td><span class=\"score\">%d</span></td>",
         get_printable_name($$pred_aref[1]), $$pred_aref[2];
  printf "<td><span class=\"score\">%d</span></td></tr>\n", $$res_aref[7];
  printf "<tr><td><span class=\"teamName\">%s</span></td><td><span class=\"score\">%d</span></td>",
         get_printable_name($$pred_aref[3]), $$pred_aref[4];
  printf "<td><span class=\"score\">%d</span></td></tr>\n", $$res_aref[10];
  print  "</table>\n";
  print  "<br />\n";
}

print  "<h4>Correct</h4>\n";
foreach my $gid (sort { $odds{$a} <=> $odds{$b} } keys %right) {
  my $res_aref = $results{$gid};
  my $pred_aref = $predictions{$gid};
  print  "<table class=\"pred-table\">\n";
  printf "<tr align=\"center\">\n  <td width=\"200\" bgcolor=\"green\">%4.1f%%</td>\n", 100 * $$pred_aref[5];
  print  "  <th>Pred</th>\n  <th>Act</th>\n</tr>\n";
  printf "<tr><td><span class=\"teamName\">%s</span></td><td><span class=\"score\">%d</span></td>",
         get_printable_name($$pred_aref[1]), $$pred_aref[2];
  printf "<td><span class=\"score\">%d</span></td></tr>\n", $$res_aref[7];
  printf "<tr><td><span class=\"teamName\">%s</span></td><td><span class=\"score\">%d</span></td>",
         get_printable_name($$pred_aref[3]), $$pred_aref[4];
  printf "<td><span class=\"score\">%d</span></td></tr>\n", $$res_aref[10];
  print  "</table>\n";
  print  "<br />\n";
}

print  "</body></html>\n";
