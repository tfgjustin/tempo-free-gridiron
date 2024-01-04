#!/bin/bash

# Directories and files for which we know the names ahead of time.
BASEDIR=$(pwd)
DATADIR=$BASEDIR/data
SCRIPTDIR=$BASEDIR/scripts
OUTPUTDIR=$BASEDIR/output
UPSETDIR=$BASEDIR/upsets
WEBDIR=$BASEDIR/public_html

GETWEEK=$SCRIPTDIR/get_week.sh
DETAILED=$SCRIPTDIR/detailed_results.pl

GREEN_LIGHT=$UPSETDIR/collect

if [[ ! -f $GREEN_LIGHT ]]
then
  exit 0
fi

FULLDATE=$1
if [[ -z $FULLDATE ]]
then
  FULLDATE=`date --date="-8hours" +"%F %T"`
fi

DAYOFWEEK=`date --date="$FULLDATE" +"%w"`
HOUR=`date --date="$FULLDATE" +"%H"`
MONTH=`date --date="$FULLDATE" +"%m"`
YEAR=`date --date="$FULLDATE" +"%Y"`
if [[ $MONTH == "01" ]]
then
  YEAR=$(( $YEAR - 1 ))
fi
DAY=`echo $FULLDATE | cut -d' ' -f1`
DATE=`echo $FULLDATE | cut -d' ' -f1`
PREDDAY=`date --date="$DATE -${DAYOFWEEK}days" +"%F"`
WEEK=`$GETWEEK $PREDDAY`

# Files and directories we're going to use.
TFGPRED=$OUTPUTDIR/tfg.predict.${PREDDAY}.out
RBAPRED=$OUTPUTDIR/rba.predict.${PREDDAY}.out
TFGHTML=$WEBDIR/tfg.current.html
RBAHTML=$WEBDIR/rba.current.html

THIS_UPSETDIR=$UPSETDIR/${YEAR}/week${WEEK}/$DAYOFWEEK/$HOUR

if [[ ! -f $TFGPRED ]]
then
  echo "No TFG prediction file for $PREDDAY: $TFGPRED"
  exit 1
fi

if [[ ! -f $RBAPRED ]]
then
  echo "No RBA prediction file for $PREDDAY: $RBAPRED"
  exit 1
fi

if [[ ! -d $THIS_UPSETDIR ]]
then
  echo "Failed to find directory $THIS_UPSETDIR"
  exit 1
fi

#LASTCSV=`find -L $THIS_UPSETDIR -name 'yahoo.*.csv' | sort | tail -1`
#LASTCSV=`find -L $THIS_UPSETDIR -name 'foxsports.*.csv' | sort | tail -1`
LASTCSV=`find -L $THIS_UPSETDIR -name 'cbssports.*.csv' | sort | tail -1`
if [[ -z $LASTCSV ]]
then
  echo "No CSV files found in $THIS_UPSETDIR"
  exit 1
fi

$DETAILED $TFGPRED $LASTCSV "tfg" > $TFGHTML
if [[ $? -ne 0 ]]
then
  echo "Error creating detailed report for TFG"
  exit 1
fi

$DETAILED $RBAPRED $LASTCSV "rba" > $RBAHTML
if [[ $? -ne 0 ]]
then
  echo "Error creating detailed report for RBA"
  exit 1
fi
