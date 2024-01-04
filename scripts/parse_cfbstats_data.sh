#!/bin/bash

BASEDIR=$(pwd)
SCRIPTDIR=$BASEDIR/scripts
DATADIR=$BASEDIR/data
INPUTDIR=$BASEDIR/input
PARSE_GAMELOG=$SCRIPTDIR/parse_cfbstats_gamelog.pl
PARSE_GAMEDATA=$SCRIPTDIR/parse_cfbstats_game.pl
MERGE=$SCRIPTDIR/merge_offense_with_gamelog.pl
DROPBOXDIR=${DROPBOXDIR:-"$HOME/Dropbox/2014/collegefootballdata.org-2019"}

CURRYEAR=${CURRYEAR:-2019}
CURRDATADIR=$DATADIR/$CURRYEAR

$PARSE_GAMELOG "$DROPBOXDIR/game.csv" > $CURRDATADIR/gamelog.csv
if [[ $? -ne 0 ]]
then
  echo "Error parsing game log"
  exit 1
fi

$PARSE_GAMEDATA "$DROPBOXDIR/team-game-statistics.csv" > $CURRDATADIR/offense.csv
if [[ $? -ne 0 ]]
then
  echo "Error parsing game stats"
  exit 1
fi

$MERGE $CURRDATADIR/offense.csv $CURRDATADIR/gamelog.csv 2> /dev/null | sort -n > $CURRDATADIR/summaries.csv
if [[ $? -ne 0 ]]
then
  echo "Error merging game log and stats"
  exit 1
fi

cat $DATADIR/20*/summaries.csv | sort -n | uniq > $INPUTDIR/summaries.csv
(head -1 $INPUTDIR/summaries.csv && grep 0,0,0,0,0 $INPUTDIR/summaries.csv) > $INPUTDIR/to_predict.csv
