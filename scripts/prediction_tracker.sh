#!/bin/bash

BASEDIR=$(pwd)
OUTPUTDIR=$BASEDIR/output
SCRIPTDIR=$BASEDIR/scripts
WEBDIR=$BASEDIR/public_html

PREDICT_SCRIPT=$SCRIPTDIR/prediction_tracker.pl
WEEK_RANGE_SCRIPT=$SCRIPTDIR/get_week_range.sh

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date +"%F"`
fi

PARAMS=`$WEEK_RANGE_SCRIPT $DATE`

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
  OUTFILE=${sys}.predtracker.${DATE}.csv
  FULLOUTFILE=$WEBDIR/$OUTFILE
  FULLERRFILE=$WEBDIR/${sys}.predtracker.${DATE}.err
  SYS_PARAMS="$PREDICT_FILE $RANKING_FILE"
  $PREDICT_SCRIPT $PARAMS $SYS_PARAMS > $FULLOUTFILE 2> $FULLERRFILE
  if [[ $? -ne 0 ]]
  then
    echo "Error running $PREDICT_SCRIPT $PARAMS $SYS_PARAMS $FULLOUTFILE"
    exit 1
  fi
  CURRFILE=${sys}.predtracker.current.csv
  FULLCURRFILE=$WEBDIR/$CURRFILE
  if [[ -f $FULLCURRFILE || -L $FULLCURRFILE ]]
  then
    rm -f $FULLCURRFILE
    if [[ $? -ne 0 ]]
    then
      echo "Error removing $FULLCURRFILE"
      exit 1
    fi
  fi
  cd $WEBDIR
  ln -s $OUTFILE $CURRFILE
  if [[ $? -ne 0 ]]
  then
    echo "Could not ln -s $OUTFILE $CURRFILE"
  fi
done
exit 0
