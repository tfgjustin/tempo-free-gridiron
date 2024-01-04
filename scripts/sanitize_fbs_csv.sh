#!/bin/bash

if [[ $# -eq 0 ]]
then
  echo "Usage: $0 <input_csv> <output_csv>"
  exit 1
fi

if [[ ! -f $1 ]]
then
  echo "No such input CSV: $1"
  exit 1
fi

cat $1 | tr -d '\r' |\
  perl -ne 'if(/^Div/){print $_;next;}next unless(/^FBS,[0-9]/);chomp; @_ = split(/,/);my $l = $_[6]; if ($l eq "Home") { $l = "Away"; } elsif ($l eq "Away") { $l = "Home"; } print "$_[0],$_[3],$_[4],$_[1],$_[2],$_[5],$l\n$_\n";' |\
 sort | uniq  > $2
