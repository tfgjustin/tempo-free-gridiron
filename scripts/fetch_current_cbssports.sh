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
PARSE_CBSSPORTS=$SCRIPTDIR/parse_cbssports_scores_2013.pl

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
URLWEEK=$WEEK
if [[ $DAYOFWEEK -le 1 ]]
then
  URLWEEK=$(( $WEEK - 1 ))
fi
if [[ $URLWEEK -gt 16 ]]
then
  URLWEEK=16
fi

THIS_UPSETDIR=$UPSETDIR/${YEAR}/week${WEEK}/$DAYOFWEEK/$HOUR

CBSSPORTS_URL="http://www.cbssports.com/collegefootball/scoreboard/FBS/${YEAR}/week${URLWEEK}"

mkdir -p $THIS_UPSETDIR
if [[ ! -d $THIS_UPSETDIR ]]
then
  echo "Failed to create directory $THIS_UPSETDIR"
  exit 1
fi
OUTHTML=$THIS_UPSETDIR/cbssports.${NOW}.html
OUTCSV=$THIS_UPSETDIR/cbssports.${NOW}.csv
OUTLOG=$THIS_UPSETDIR/cbssports.${NOW}.log

$WGET --no-cache --user-agent="$USERAGENT" -q -O $OUTHTML $CBSSPORTS_URL
if [[ $? -ne 0 ]]
then
  echo "Error fetching $CBSSPORTS_URL"
  exit 1
fi

$PARSE_CBSSPORTS $OUTHTML $OUTCSV $OUTLOG 2> /dev/null
if [[ $? -ne 0 ]]
then
  echo "Error parsing $OUTHTML and writing to $OUTCSV"
  exit 1
fi
exit 0
