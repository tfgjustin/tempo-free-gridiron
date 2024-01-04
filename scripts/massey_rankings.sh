#!/bin/bash

BASEDIR=$(pwd)
OUTPUTDIR=$BASEDIR/output
SCRIPTDIR=$BASEDIR/scripts
WEBDIR=$BASEDIR/public_html

MASSEY_SCRIPT=$SCRIPTDIR/massey_rankings.pl
GET_WEEK=$SCRIPTDIR/get_week.sh

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date +"%F"`
fi

WEEK_NUM=`$GET_WEEK $DATE`

for sys in tfg rba
do
  RANKING_FILE=$OUTPUTDIR/${sys}.ranking.${DATE}.out
  if [[ ! -f $RANKING_FILE ]]
  then
    echo "Could not find rankings file $RANKING_FILE."
    exit 1
  fi
  OUTFILE=${sys}.massey.${DATE}.csv
  FULLOUTFILE=$WEBDIR/$OUTFILE
  FULLERRFILE=$WEBDIR/${sys}.massey.${DATE}.err
  $MASSEY_SCRIPT $RANKING_FILE $WEEK_NUM > $FULLOUTFILE 2> $FULLERRFILE
  if [[ $? -ne 0 ]]
  then
    echo "Error running $MASSEY_SCRIPT $RANKING_FILE $WEEK_NUM $FULLOUTFILE"
    exit 1
  fi
  CURRFILE=${sys}.massey.current.csv
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
