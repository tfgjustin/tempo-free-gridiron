#!/bin/bash

# We need a wget before we can do any of this.
WGET=`which wget`
if [[ -z $WGET ]]
then
  echo "Could not find wget"
  exit 1
fi
USERAGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_4) AppleWebKit/536.30.1 (KHTML, like Gecko) Version/6.0.5 Safari/536.30.1"

# Directories and files for which we know the names ahead of time.
BASEDIR=$(pwd)
DATADIR=$BASEDIR/data
SCRIPTDIR=$BASEDIR/scripts
OUTPUTDIR=$BASEDIR/output
UPSETDIR=$BASEDIR/upsets

GETWEEK=$SCRIPTDIR/get_week.sh
DETAILED=$SCRIPTDIR/detailed_results.pl
PARSE_YAHOO=$SCRIPTDIR/parse_yahoo_score.pl
YAHOO_IDS=$DATADIR/yahoo2ncaa.txt

GREEN_LIGHT=$UPSETDIR/collect

if [[ ! -f $GREEN_LIGHT ]]
then
  exit 0
fi

FULLDATE=$1
if [[ -z $FULLDATE ]]
then
  FULLDATE=`date --date="-8hours" +"%F %H"`
fi

YAHOO_URL="http://rivals.yahoo.com/ncaa/football/scoreboard"

DAYOFWEEK=`date --date="$FULLDATE" +"%w"`
HOUR=`date --date="$FULLDATE" +"%H"`
MONTH=`date --date="$FULLDATE" +"%m"`
YEAR=`date --date="$FULLDATE" +"%Y"`
if [[ $MONTH == "01" ]]
then
  YEAR=$(( $YEAR - 1 ))
fi
DATE=`echo $FULLDATE | cut -d' ' -f1`
PREDDAY=`date --date="$DATE -${DAYOFWEEK}days" +"%F"`
NOW=`date +"%s"`
WEEK=`$GETWEEK $PREDDAY`

THIS_UPSETDIR=$UPSETDIR/${YEAR}/week${WEEK}/$DAYOFWEEK/$HOUR

mkdir -p $THIS_UPSETDIR
if [[ ! -d $THIS_UPSETDIR ]]
then
  echo "Failed to create directory $THIS_UPSETDIR"
  exit 1
fi
OUTHTML=$THIS_UPSETDIR/yahoo.${NOW}.html
OUTCSV=$THIS_UPSETDIR/yahoo.${NOW}.csv

$WGET --user-agent="$USERAGENT" -q -O $OUTHTML $YAHOO_URL
if [[ $? -ne 0 ]]
then
  echo "Error fetching $YAHOO_URL"
  exit 1
fi

$PARSE_YAHOO $YAHOO_IDS $OUTHTML > $OUTCSV 2> /dev/null
if [[ $? -ne 0 ]]
then
  echo "Error parsing $OUTHTML and writing to $OUTCSV"
  exit 1
fi
exit 0
