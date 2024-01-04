#!/bin/bash

BASEDIR=$(pwd)
DATADIR=$BASEDIR/data
OUTPUTDIR=$BASEDIR/output
SCRIPTDIR=$BASEDIR/scripts
WEBDIR=$BASEDIR/public_html

UNDEFEATED_SCRIPT=$SCRIPTDIR/undefeateds.pl
GETWEEK=$SCRIPTDIR/get_week.sh

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date +"%F"`
fi
NUMDATE=`echo $DATE | cut -d'-' -f2,3 | tr -d '-'`
TFGPOSTTIME=`date --date="$DATE +2days 10:30" +"%FT%T%::z"`
RBAPOSTTIME=`date --date="$DATE +2days 10:00" +"%FT%T%::z"`

if [[ ! -x $UNDEFEATED_SCRIPT ]]
then
  echo "Could not find undefeated script: $UNDEFEATED_SCRIPT"
  exit 1;
fi

CURR_WEEK=`$GETWEEK $DATE`
if [[ -z $CURR_WEEK ]]
then
  echo "Couldn't get current week from $DATE"
  exit 1
fi

MONTH=`echo $DATE | cut -d'-' -f2 | sed -e s/^0//g`
if [[ -z $MONTH ]]
then
  echo "Could not get month from $DATE"
  exit 1
fi

if [[ $MONTH -lt 10 ]]
then
  echo "Current month is $MONTH; not yet October, so no undefeated projections."
  exit 0
fi

if [[ $NUMDATE -gt 1202 ]]
then
  echo "Current month is $MONTH; season is over, so no undefeated projections."
  exit 0
fi

for sys in tfg rba
do
  PREDICT_FILE=$OUTPUTDIR/${sys}.predict.${DATE}.out
  RANKING_FILE=$OUTPUTDIR/${sys}.ranking.${DATE}.out
  if [[ ! -f $PREDICT_FILE ]]
  then
    echo "Could not find prediction file $PREDICT_FILE."
    exit 1
  fi
  if [[ ! -f $RANKING_FILE ]]
  then
    echo "Could not find rankings file $RANKING_FILE."
    exit 1
  fi
  POSTTIME="${TFGPOSTTIME}"
  if [[ $sys == "rba" ]]
  then
    POSTTIME="${RBAPOSTTIME}"
  fi
  SYS_PARAMS="$PREDICT_FILE $RANKING_FILE $sys $CURR_WEEK"
  OUTFILE=$WEBDIR/${sys}.undefeated.${DATE}.html
  $UNDEFEATED_SCRIPT $SYS_PARAMS $DATE $POSTTIME > $OUTFILE 2> /dev/null
  if [[ $? -ne 0 ]]
  then
    echo "Error running $UNDEFEATED_SCRIPT $PARAMS $SYS_PARAMS $DATE \"$OUTFILE\""
    exit 1
  fi
done
