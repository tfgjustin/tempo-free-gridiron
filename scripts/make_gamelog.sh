#!/bin/bash

BASEDIR=$(pwd)
PARSE_SUMMARY=$BASEDIR/scripts/parse_summary.pl

if [ $# -eq 0 ]
then
  echo ""
  echo "Usage $0 <gamelog0.csv> [<gamelog1.csv> ... <gamelogN>.csv]"
  echo ""
  exit 1
fi

for fname in $*
do
  if [ ! -f $fname ]
  then
    echo ""
    echo "Cannot find file $fname"
    echo ""
    exit 1
  fi
done

# 1) Cat the files
# 2) Remove the quotes
# 3) Uppercase all team names
# 4) Parse the summaries (extract date and the two team names and IDs)
cat $* | \
  tr -d '"' | \
  tr '[a-z]' '[A-Z]' | \
  $PARSE_SUMMARY
