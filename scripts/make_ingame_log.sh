#!/bin/bash

# Directories and files for which we know the names ahead of time.
BASEDIR=$(pwd)
SCRIPTDIR=$BASEDIR/scripts
UPSETDIR=$BASEDIR/upsets

GETWEEK=$SCRIPTDIR/get_week.sh
INGAMELOG=$SCRIPTDIR/make_ingame_log.pl

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date --date="-8hours" +"%F"`
fi

DAYOFWEEK=`date --date="$DATE" +"%w"`
NAMEOFDAY=`date --date="$DATE" +"%A"`
MONTH=`date --date="$DATE" +"%m"`
YEAR=`date --date="$DATE" +"%Y"`
if [[ $MONTH == "01" ]]
then
  YEAR=$(( $YEAR - 1 ))
fi
PREDDAY=`date --date="$DATE -${DAYOFWEEK}days" +"%F"`
#PREDDAY="2012-01-15"
WEEK=`$GETWEEK $PREDDAY`

# Files and directories we're going to use.
THIS_UPSETDIR=$UPSETDIR/${YEAR}/week${WEEK}
OUTFILE=$THIS_UPSETDIR/ingame.${DATE}.txt

$INGAMELOG $THIS_UPSETDIR $DATE $OUTFILE.bak #2> /dev/null
if [[ $? -eq 0 ]]
then
  mv $OUTFILE.bak $OUTFILE
fi
