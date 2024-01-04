#!/bin/bash

#set -x

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date +"%F"`
fi

BASEDIR=$(pwd)
DATADIR=$BASEDIR/data
OUTPUTDIR=$BASEDIR/output
PICKEMDIR=$BASEDIR/pickem
SCRIPTDIR=$BASEDIR/scripts
WEBDIR=$BASEDIR/public_html

GETWEEK=$SCRIPTDIR/get_week.sh
GETSATURDAY=$SCRIPTDIR/get_saturday.sh
PICKEM=$SCRIPTDIR/pickem_games.pl
FORMAT=$SCRIPTDIR/pickem_format.pl
PRETTYPRINT=$SCRIPTDIR/prettyprint.pl
PICKEM_POINTS=$SCRIPTDIR/pickem_points.sh

BLACKLIST=$PICKEMDIR/blacklist.txt
OUTFILE=$WEBDIR/all.pickem.$DATE.txt
ERRFILE=$WEBDIR/all.pickem.$DATE.err
RBAPICKS=$WEBDIR/rba.pickem.$DATE.txt
TFGPICKS=$WEBDIR/tfg.pickem.$DATE.txt

weeknum=`$GETWEEK $DATE`
size="small"
n=$(( ($weeknum - 3) % 4 ))
if [[ $weeknum -gt 3 && $n -eq 0 ]]
then
  size="large"
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

$PICKEM $BLACKLIST $size $saturday $saturday $RBA_FILES $TFG_FILES > $OUTFILE 2> $ERRFILE
if [[ $? -ne 0 ]]
then
  echo "Error running \"$PICKEM $BLACKLIST $size $saturday $saturday $RBA_FILES $TFG_FILES\""
  exit 1
fi
rm -f $ERRFILE

$PICKEM_POINTS $DATE $OUTFILE
