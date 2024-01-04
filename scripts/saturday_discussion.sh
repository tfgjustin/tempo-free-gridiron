#!/bin/bash

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date +"%F"`
fi

BASEDIR=$(pwd)
OUTPUTDIR=$BASEDIR/output
SCRIPTDIR=$BASEDIR/scripts
WEBDIR=$BASEDIR/public_html

GETWEEK=$SCRIPTDIR/get_week.sh
GETSATURDAY=$SCRIPTDIR/get_saturday.sh
MATCHUPS=$SCRIPTDIR/saturday_discussion.pl

OUTFILE=$WEBDIR/matchups.$DATE.html
ERRFILE=matchups.$DATE.err

weeknum=`$GETWEEK $DATE`
if [[ -z $weeknum ]]
then
  echo "Could not get week for $DATE"
  exit 1
fi

saturday=`$GETSATURDAY $DATE`
if [[ -z $saturday ]]
then
  echo "Could not get Saturday after $DATE"
  exit 1
fi

RBA_PREDICT="$OUTPUTDIR/rba.predict.$DATE.out"
TFG_PREDICT="$OUTPUTDIR/tfg.predict.$DATE.out"
RBA_FILES="$RBA_PREDICT $OUTPUTDIR/rba.ranking.$DATE.out"
TFG_FILES="$TFG_PREDICT $OUTPUTDIR/tfg.ranking.$DATE.out"

$MATCHUPS $weeknum $saturday $TFG_FILES $RBA_FILES > $OUTFILE 2> $ERRFILE
if [[ $? -ne 0 ]]
then
  echo "Error running \"$MATCHUPS $weeknum $saturday $TFG_FILES $RBA_FILES\""
  exit 1
fi
