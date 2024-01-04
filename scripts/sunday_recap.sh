#!/bin/bash

BASEDIR=$(pwd)
OUTPUTDIR=$BASEDIR/output
SCRIPTDIR=$BASEDIR/scripts
WEBDIR=$BASEDIR/public_html

GETWEEK=$SCRIPTDIR/get_week.sh
SUNDAY_RECAP=$SCRIPTDIR/sunday_recap.pl

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date +"%F"`
fi

LAST_DATE=`date --date="$DATE -1week" +"%F"`
LAST_MATCHUP=$WEBDIR/matchups.$LAST_DATE.html
OUTFILE=$WEBDIR/recap.$DATE.html
WEEK_START=$LAST_DATE
WEEK_END=`date --date="$LAST_DATE +6days" +"%F"`

LAST_WEEKNUM=`$GETWEEK $LAST_DATE`

if [[ $LAST_WEEKNUM -ge 52 ]]
then
  echo "Last week was last season. Skipping."
  exit 0
fi

GIDMAP=`grep -F "COIN
SHOOT
GOTW
UFIO" $LAST_MATCHUP | gawk '{print $2 ":" $3}' | tr '\n' ',' | sed -e s/,$//g`

TFG_FILES="$OUTPUTDIR/tfg.predict.$LAST_DATE.out $OUTPUTDIR/tfg.ranking.$LAST_DATE.out"
RBA_FILES="$OUTPUTDIR/rba.predict.$LAST_DATE.out $OUTPUTDIR/rba.ranking.$LAST_DATE.out"

$SUNDAY_RECAP $LAST_WEEKNUM $WEEK_START $WEEK_END $TFG_FILES $RBA_FILES $GIDMAP > $OUTFILE
