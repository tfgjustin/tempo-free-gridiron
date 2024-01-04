#!/bin/bash

# Directories and files for which we know the names ahead of time.
BASEDIR=$(pwd)
DATADIR=$BASEDIR/data
SCRIPTDIR=$BASEDIR/scripts
OUTPUTDIR=$BASEDIR/output
WEBDIR=$BASEDIR/public_html

GETWEEK=$SCRIPTDIR/get_week.sh
STREAKS=$SCRIPTDIR/winning_streak.pl
PARSE_YAHOO=$SCRIPTDIR/parse_yahoo_score.pl
YAHOO_IDS=$DATADIR/yahoo2ncaa.txt

DAYOFWEEK=`date --date="-8hours" +"%w"`
HOUR=`date +"%H"`
PREDDAY=`date --date="-${DAYOFWEEK}days" +"%F"`
NOW=`date +"%s"`
WEEK=`$GETWEEK $PREDDAY`

# Files and directories we're going to use.
TFGPRED=$OUTPUTDIR/tfg.predict.${PREDDAY}.out
RBAPRED=$OUTPUTDIR/rba.predict.${PREDDAY}.out
TFGHTML=$WEBDIR/tfg.current.html
RBAHTML=$WEBDIR/rba.current.html

$STREAKS output/tfg.predict.2012-01-15.out  | grep ,2011, | grep -v ,2011,[123], | sort -n -t , -k 4 | head

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
