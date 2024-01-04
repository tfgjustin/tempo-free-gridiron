#!/usr/bin/perl 

use strict;
use warnings;

while(<STDIN>) {
  chomp;
  next if (/99BF60/ or /^<\/tr>/);
  if (/<tr (id="row_\d+" )class="(\w+)".*>/) {
    print "<tr class=\"$2" . "Row\">\n";
  } elsif (/by Commissioner/) {
    print "</table>\n";
  } elsif (/justin/) {
    print "        <td class=\"teamName\">TFG (Justin)</td>\n";
  } elsif (/_ed_/) {
    print "        <td class=\"teamName\">RBA (Eddie)</td>\n";
  } elsif (/align="center">(\d+)-(\d+)</) {
    my $w = sprintf "%3d", $1;
    my $l = sprintf "%3d", $2;
    $w =~ s/\s/&nbsp;/g;
    $l =~ s/\s/&nbsp;/g;
    print "        <td class=\"stats\">$w -$l</td>\n";
  } elsif (/^<table/) {
    print "<table class=\"rank-table\">\n";
  } else {
    s/^<tr>/<tr class="tfg">/g;
    s/align="center" style="line-height:150%"/class="bigRank"/g;
    s/align="left"/class="teamName"/g;
    s/align="right"/class="stats"/g;
    s/'s picks//g;
    s/\*\*//g;
    print "$_\n";
  }
}
