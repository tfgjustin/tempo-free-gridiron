#!/bin/bash

SYSTEM=$1
if [[ -z $SYSTEM ]]
then
  echo "Usage: $0 <tfg|rba|all> [<date>]"
  exit 1
fi

POSTTIME=
if [[ $SYSTEM == "tfg" ]]
then
  POSTTIME="11:00:00-0400"
elif [[ $SYSTEM == "rba" ]]
then
  POSTTIME="10:00:00-0400"
elif [[ $SYSTEM == "all" ]]
then
  POSTTIME="12:00:00-0400"
fi
if [[ -z $POSTTIME ]]
then
  echo "Invalid system name (must be tfg or rba or all): $SYSTEM"
  exit 1
fi

DATE=$2
if [[ -z $DATE ]]
then
  DATE=`date +"%F"`
fi
T25POSTDATE=`date --date="$DATE $POSTTIME +1day +30mins" +"%FT%T%::z"`
FULLPOSTDATE=`date --date="$DATE $POSTTIME +1day" +"%FT%T%::z"`

BASEDIR=$(pwd)
DATADIR=$BASEDIR/data
INPUTDIR=$BASEDIR/input
OUTPUTDIR=$BASEDIR/output
SCRIPTDIR=$BASEDIR/scripts
WEBDIR=$BASEDIR/public_html

SUMMARY=$INPUTDIR/summaries.csv
WEEKSCRIPT=$SCRIPTDIR/get_week.sh
TOP25SCRIPT=$SCRIPTDIR/top_25.pl
FULLSCRIPT=$SCRIPTDIR/html_rankings.pl

CURR_FILE=$OUTPUTDIR/$SYSTEM.ranking.$DATE.out
if [[ ! -f $CURR_FILE ]]
then
  echo "Error finding output file."
  exit 1
fi

CURR_WEEK=`$WEEKSCRIPT $DATE`
if [[ -z $CURR_WEEK ]]
then
  echo "$WEEKSCRIPT could not get week from $DATE"
  exit 1
fi

LAST_FILE=`find -L ${OUTPUTDIR} -name '*.out' | grep /$SYSTEM.rank | sort | grep -B 1 $CURR_FILE | tail -2 | head -1`
if [[ -z $LAST_FILE ]]
then
  echo "Error finding next-to-last output file (?)"
  exit 1
fi

if [[ $CURR_FILE == $LAST_FILE ]]
then
  echo "Current file ($CURR_FILE) == last file ($LAST_FILE)"
  exit 1
fi

TOP25FILE=$WEBDIR/${SYSTEM}.${DATE}.top25.html
FULLFILE=$WEBDIR/${SYSTEM}.${DATE}.total.html

$TOP25SCRIPT $CURR_FILE $LAST_FILE $CURR_WEEK $DATE $T25POSTDATE $SYSTEM > $TOP25FILE 2> /dev/null
if [[ $? -ne 0 ]]
then
  echo "Error generating top 25 ranking for $SYSTEM"
  exit 1
fi
if [[ ! -s $TOP25FILE ]]
then
  echo "Generated empty file for $SYSTEM top 25: $TOP25FILE"
  exit 1
fi
$FULLSCRIPT $CURR_FILE $LAST_FILE $CURR_WEEK $DATE $FULLPOSTDATE $SYSTEM > $FULLFILE 2> /dev/null
if [[ $? -ne 0 ]]
then
  echo "Error generating full ranking for $SYSTEM"
  exit 1
fi
if [[ ! -s $FULLFILE ]]
then
  echo "Generated empty file for $SYSTEM full rankings: $FULLFILE"
  exit 1
fi
exit 0
