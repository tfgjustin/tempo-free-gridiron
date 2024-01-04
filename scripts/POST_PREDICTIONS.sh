#!/bin/bash

BASEDIR=$(pwd)
INPUTDIR=$BASEDIR/input
SCRIPTDIR=$BASEDIR/scripts
WEBDIR=$BASEDIR/public_html
DATE=

if [[ $# -eq 0 ]]
then
  DATE=`date +"%F"`
elif [[ $# -eq 1 ]]
then
  DATE=$1
else
  echo "Error getting date information."
  exit 1
fi

$SCRIPTDIR/run_rankings.sh tfg $DATE
if [[ $? -ne 0 ]]
then
  echo "Error running TFG rankings."
  exit 1
fi

$SCRIPTDIR/run_rankings.sh rba $DATE
if [[ $? -ne 0 ]]
then
  echo "Error running RBA rankings."
  exit 1
fi

$SCRIPTDIR/pickem_games.sh $DATE
if [[ $? -ne 0 ]]
then
  echo "Error selecting pick'em games."
  exit 1
fi

$SCRIPTDIR/all_conference_projections.sh $DATE
if [[ $? -ne 0 ]]
then
  echo "Error creating conference projections."
  exit 1
fi

$SCRIPTDIR/pergame_projections.sh $DATE
if [[ $? -ne 0 ]]
then
  echo "Error generating per-day projections."
  exit 1
fi

#$SCRIPTDIR/saturday_discussion.sh $DATE
#if [[ $? -ne 0 ]]
#then
#  echo "Error creating Saturday discussion outline."
#  exit 1
#fi

#$SCRIPTDIR/sunday_recap.sh $DATE
#if [[ $? -ne 0 ]]
#then
#  echo "Error creating recap of previous Saturday."
#  exit 1
#fi

$SCRIPTDIR/undefeateds.sh $DATE
if [[ $? -ne 0 ]]
then
  echo "Error creating undefeated team statuses."
  exit 1
fi

$SCRIPTDIR/prediction_tracker.sh $DATE
if [[ $? -ne 0 ]]
then
  echo "Error generating prediction tracker files."
  exit 1
fi

$SCRIPTDIR/massey_rankings.sh $DATE
if [[ $? -ne 0 ]]
then
  echo "Error generating rankings for Massey files."
  exit 1
fi

#$SCRIPTDIR/playoff_odds.sh $DATE
#if [[ $? -ne 0 ]]
#then
#  echo "Error running playoff odds."
#  exit 1
#fi

