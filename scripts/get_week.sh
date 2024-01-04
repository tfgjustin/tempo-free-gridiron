#!/bin/bash

BASEDIR=$(pwd)
INPUTDIR=$BASEDIR/input
SUMMARY=$INPUTDIR/summaries.csv

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date +"%F"`
fi

RANK_DATE=`echo $DATE | tr -d '-'`
YEAR_WEEK=`date +"%G %V" --date="${RANK_DATE}"`
YEAR=`echo $YEAR_WEEK | cut -d' ' -f1`
WEEK=`echo $YEAR_WEEK | cut -d' ' -f2 | sed -e s/^0//g`

if [[ $WEEK -lt 34 ]]
then
  YEAR=$(( $YEAR - 1 ))
  WEEK=$(( $WEEK + 53 ))
fi

PATTERN=",${YEAR}0[89]"
FIRST_DAY=`grep $PATTERN $SUMMARY | head -2 | tail -1 | cut -d',' -f2`
DAY_OF_WEEK=`date --date="$FIRST_DAY" +"%w"`
FIRST_YEAR_WEEK=`date --date="$FIRST_DAY -$DAY_OF_WEEK days" +"%G %V"`
FIRST_YEAR=`echo $FIRST_YEAR_WEEK | cut -d' ' -f1`
FIRST_WEEK=`echo $FIRST_YEAR_WEEK | cut -d' ' -f2 | sed -e s/^0//g`
if [[ $FIRST_YEAR -ne $YEAR ]]
then
  echo "Year mismatch: $FIRST_YEAR != $YEAR"
  exit 1
fi
CURR_WEEK=$(( $WEEK - $FIRST_WEEK + 1))
echo "$CURR_WEEK"
