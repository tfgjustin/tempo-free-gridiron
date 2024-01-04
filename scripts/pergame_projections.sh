#!/bin/bash

BASEDIR=$(pwd)
DATADIR=$BASEDIR/data
INPUTDIR=$BASEDIR/input
OUTPUTDIR=$BASEDIR/output
SCRIPTDIR=$BASEDIR/scripts
WEBDIR=$BASEDIR/public_html

SUMMARY=$INPUTDIR/summaries.csv
PREDICT=$SCRIPTDIR/multiple_html.pl
GETWEEK=$SCRIPTDIR/get_week.sh

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date +"%F"`
fi

function GetSystemFile {
  SYSTEM=$1
  FILETYPE=$2
  local FILE=`find -L $OUTPUTDIR -name '*.out' | grep /$SYSTEM.$FILETYPE.$DATE | sort | tail -1`
  if [[ -z $FILE ]]
  then
    echo "Error finding output file for $SYSTEM $FILETYPE $DATE."
    exit 1
  fi
  DATE=`basename $FILE | cut -d'.' -f3`
  FILTER=`echo $DATE | grep ^20[01][0-9]-[01][0-9]-[0-3][0-9]$`
  if [[ -z $FILTER ]]
  then
    echo "Invalid file date: $DATE"
    exit 1
  fi
  echo $FILE
}

TFG_PREDICT=$(GetSystemFile "tfg" "predict")
TFG_RANKING=$(GetSystemFile "tfg" "ranking")
RBA_PREDICT=$(GetSystemFile "rba" "predict")
RBA_RANKING=$(GetSystemFile "rba" "ranking")

PARAMS="$TFG_PREDICT $TFG_RANKING $RBA_PREDICT $RBA_RANKING"

CURR_WEEK=`$GETWEEK $DATE`
if [[ -z $CURR_WEEK ]]
then
  echo "Could not get current week from $DATE"
  exit 1
fi

# We do two pages of predictions:
# 1) Saturday games
# 2) All pre-Saturday games
# For the first one, we do it 6-$DAYOFWEEK days in the future, and the output
# file is for that date.
# For the second one, we do it in the range [$DAYOFWEEK, 5-$DAYOFWEEK], and
# the output file is for the current date.
DAYOFWEEK=`date +"%w" --date="$DATE"`
if [[ $DAYOFWEEK -lt 6 ]]
then
  # We're not doing this run on a Saturday. Figure out all the dates.
  CURRDATE=`date +"%Y%m%d" --date="$DATE"`
  DAYSAHEAD=$(( 5 - $DAYOFWEEK ))
  for d in `seq 0 $DAYSAHEAD`
  do
    THISDATE=`date --date="$DATE +${d}days" +"%Y%m%d"`
    c=`grep -c ,${THISDATE}, $SUMMARY`
    if [[ $c -eq 0 ]]
    then
      continue
    fi
    POSTTIME=`date --date="$THISDATE 16:30" +"%FT%T%::z"`
    THISDAYNAME=`date --date="$DATE +${d}days" +"%A"`
    OUTFILE=$WEBDIR/predict.$DATE.$THISDAYNAME.html
    TITLE="Week $CURR_WEEK: $THISDAYNAME Predictions"
    TAGS="predictions"
    $PREDICT $THISDATE $THISDATE $POSTTIME $PARAMS "$TITLE" "$TAGS" > $OUTFILE
    if [[ $? -ne 0 ]]
    then
      echo "Error running predictions for $THISDATE"
      exit 1
    fi
    # If outfile is 0-sized, then there are no games scheduled.
    if [[ -z $OUTFILE ]]
    then
      echo "0-sized output for $THISDATE games."
      rm -f $OUTFILE
    fi
  done
fi

DAYSAHEAD=$(( 6 - $DAYOFWEEK ))
SATURDAY=`date --date="$DATE +${DAYSAHEAD}days" +"%Y%m%d"`
POSTTIME=`date --date="$SATURDAY 11:35" +"%FT%T%::z"`
OUTFILE=$WEBDIR/predict.$DATE.Saturday.html
TITLE="Week $CURR_WEEK: Saturday Predictions"
TAGS="predictions"
$PREDICT $SATURDAY $SATURDAY $POSTTIME $PARAMS "$TITLE" "$TAGS" > $OUTFILE
if [[ $? -ne 0 ]]
then
  echo "Error running Saturday predictions for $SATURDAY"
  exit 1
fi
# If outfile is 0-sized, then there are no games scheduled.
if [[ -z $OUTFILE ]]
then
  echo "0-sized output for Saturday games."
  rm -f $OUTFILE
fi
exit 0
