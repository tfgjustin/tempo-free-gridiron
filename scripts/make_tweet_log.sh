#!/bin/bash

# Directories and files for which we know the names ahead of time.
BASEDIR=$(pwd)
DATADIR=$BASEDIR/data
OUTPUTDIR=$BASEDIR/output
SCRIPTDIR=$BASEDIR/scripts
UPSETDIR=$BASEDIR/upsets

BLOGPOSTS=$DATADIR/blogposts.txt
GETWEEK=$SCRIPTDIR/get_week.sh
TWEETLOG=$SCRIPTDIR/make_tweet_log.pl

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date --date="-8hours" +"%F"`
fi

DAYOFWEEK=`date --date="$DATE" +"%w"`
NAMEOFDAYOFWEEK=`date --date="$DATE" +"%A" | tr '[A-Z]' '[a-z]'`
NAMEOFDAY=`date --date="$DATE" +"%A"`
MONTH=`date --date="$DATE" +"%m"`
YEAR=`date --date="$DATE" +"%Y"`
if [[ $MONTH == "01" ]]
then
  YEAR=$(( $YEAR - 1 ))
fi
PREDDAY=`date --date="$DATE -${DAYOFWEEK}days" +"%F"`
WEEK=`$GETWEEK $PREDDAY`

PARTIALURL="/$YEAR/$MONTH/week-${WEEK}-${NAMEOFDAYOFWEEK}-in-game"

# Files and directories we're going to use.
TFGPRED=$OUTPUTDIR/tfg.predict.${PREDDAY}.out
RBAPRED=$OUTPUTDIR/rba.predict.${PREDDAY}.out
THIS_UPSETDIR=$UPSETDIR/${YEAR}/week${WEEK}
INGAMELOG=$THIS_UPSETDIR/ingame.${DATE}.txt
OUTFILE=$THIS_UPSETDIR/tweetlog.${DATE}.txt

# ./scripts/make_tweet_log.pl /2014/09/week-3-thursday-in-game output/tfg.predict.2012-08-26.out output/rba.predict.2012-08-26.out upsets/2012/week1/ingame.2012-09-01.txt 0.txt 1.txt

$TWEETLOG "${PARTIALURL}" $TFGPRED $RBAPRED $INGAMELOG $OUTFILE $OUTFILE.bak 2> /tmp/ncaa/tweetlog.$$.err
if [[ $? -eq 0 ]]
then
  mv $OUTFILE.bak $OUTFILE
fi
