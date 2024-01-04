#!/bin/bash

BASEDIR=$(pwd)
DATADIR=$BASEDIR/data
INPUTDIR=$BASEDIR/input
OUTPUTDIR=$BASEDIR/output
SCRIPTDIR=$BASEDIR/scripts
WEBDIR=$BASEDIR/public_html

INPUT_FILE=$INPUTDIR/summaries.csv

CONF_SCRIPT=$SCRIPTDIR/conference_projections.pl
GETWEEK=$SCRIPTDIR/get_week.sh
GETSATURDAY=$SCRIPTDIR/get_saturday.sh

DATE=$1
if [[ -z $DATE ]]
then
  DATE=$(date +"%F")
fi

MONTH=$(echo $DATE | cut -d'-' -f2 | sed -e s/^0//g)
if [[ -z $MONTH ]]
then
  echo "Could not get month from $DATE"
  exit 1
fi

if [[ $MONTH -lt 10 ]]
then
  echo "Current month is $MONTH; not yet October, so no conference projections."
  exit 0
fi

if [[ $MONTH -eq 12 ]]
then
  echo "Current month is $MONTH; season is over, so no conference projections."
  exit 0
fi

CURR_WEEK=$($GETWEEK $DATE)
if [[ -z $CURR_WEEK ]]
then
  echo "Couldn't get current week from $DATE"
  exit 1
fi

if [[ ! -f $INPUT_FILE ]]
then
  echo "Could not find input file $INPUT_FILE."
  exit 1
fi

TWO_WEEKS=`date --date="$DATE -14days" +"%F"`
LAST_WEEK=`date --date="$DATE -7days" +"%F"`
NEXT_WEEK=`date --date="$DATE +7days" +"%F"`
TWO_SATURDAYS=`$GETSATURDAY $TWO_WEEKS`
LAST_SATURDAY=`$GETSATURDAY $LAST_WEEK`
THIS_SATURDAY=`$GETSATURDAY $DATE`

DATES="$CURR_WEEK $TWO_SATURDAYS $LAST_SATURDAY $THIS_SATURDAY $DATE"

mins=10
for sys in rba tfg
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
  SYS_PARAMS="$PREDICT_FILE $RANKING_FILE $sys"
  num_days=3
  for i in "ACC,American Athletic,Conference-USA" "Big Ten,Big XII,Mid-American,Independents" "SEC,Pac-12,Mountain West,Sun Belt"
  do
    POSTTIME=`date --date="$LAST_SATURDAY +${num_days}days 11:${mins}" +"%FT%T%::z"`
    filename=`echo $i | tr '[A-Z]' '[a-z]' | tr -d ' ' | tr ',' '_' | tr -d '-'`
    filename=$WEBDIR/${sys}.${DATE}.${filename}.html
    $CONF_SCRIPT $INPUT_FILE $SYS_PARAMS $DATES $POSTTIME "$i" > $filename 2> /dev/null
    if [[ $? -ne 0 ]]
    then
      echo "Error running $CONF_SCRIPT $PARAMS $SYS_PARAMS $DATES $POSTTIME \"$i\" $filename"
      exit 1
    fi
    let num_days=num_days+1
  done
  let mins=mins+30
done
