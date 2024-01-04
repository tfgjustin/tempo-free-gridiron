#!/bin/bash

BASEDIR=$(pwd)
SCRIPTDIR=$BASEDIR/scripts
INPUTDIR=$BASEDIR/input
OUTPUTDIR=$BASEDIR/output
TWEETDIR=$BASEDIR/tweets

PLAYOFF_SCRIPT=$SCRIPTDIR/playoff_odds.pl
PLAYOFF_TWEETS=$SCRIPTDIR/playoff_tweets.pl
NONCONF=$INPUTDIR/non_conference.txt
FCSLOSS=$INPUTDIR/fcs_losses.csv

if [[ ! -x $PLAYOFF_SCRIPT ]]
then
  echo "Could not find playoff script: $PLAYOFF_SCRIPT"
  exit 1;
fi

if [[ ! -x $PLAYOFF_TWEETS ]]
then
  echo "Could not find playoff tweets: $PLAYOFF_TWEETS"
  exit 1;
fi

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date +"%F"`
fi
NUMDATE=$(echo $DATE | cut -d'-' -f2,3 | tr -d '-' | sed -e s/^0//g)
declare -a TWEETTIMES
TWEETTIMES[tfg]=$(date --date="${DATE} 15:30" +"%s")
TWEETTIMES[rba]=$(date --date="${DATE} 15:00" +"%s")

MONTH=$(echo $DATE | cut -d'-' -f2 | sed -e s/^0//g)
if [[ -z $MONTH ]]
then
  echo "Could not get month from $DATE"
  exit 1
fi

if [[ $MONTH -lt 9 ]]
then
  echo "Current month is $MONTH; not yet September, so no playoff projections."
  exit 0
fi

if [[ $NUMDATE -gt 1201 ]]
then
  echo "Current month is $MONTH; season is over, so no playoff projections."
  exit 0
fi

for model in tfg rba
do
  RANKFILE=$OUTPUTDIR/${model}.ranking.${DATE}.out
  PREDFILE=$OUTPUTDIR/${model}.predict.${DATE}.out
  OUTFILE=$OUTPUTDIR/${model}.playoff_odds.${DATE}.txt
  time $PLAYOFF_SCRIPT ${RANKFILE} ${PREDFILE} ${NONCONF} ${FCSLOSS} ${DATE} ${OUTFILE}
  if [[ $? -ne 0 ]]
  then
    echo "Error running playoff odds for ${model} @ ${DATE}"
    continue
  fi
#  $PLAYOFF_TWEETS $OUTFILE $TWEETDIR ${TWEETTIMES[$model]} $model
done
