#!/bin/bash

set -x

BASEDIR=$(pwd)
SCRIPTDIR=$BASEDIR/scripts
WEBDIR=$BASEDIR/public_html

FETCH_YAHOO=$SCRIPTDIR/fetch_current_yahoo.sh
FETCH_FOXSPORTS=$SCRIPTDIR/fetch_current_foxsports.sh
FETCH_CBSSPORTS=$SCRIPTDIR/fetch_current_cbssports.sh
PROJECTIONS=$SCRIPTDIR/create_projections.sh
DETAILED=$SCRIPTDIR/detailed_results.sh
IN_GAME_LOG=$SCRIPTDIR/make_ingame_log.sh
IN_GAME_GRAPH=$SCRIPTDIR/make_ingame_graphs.sh
UPDATE_BLOG=$SCRIPTDIR/update_in_game_blog.sh
UPDATE_TWITTER=$SCRIPTDIR/make_tweet_log.sh

if [[ ! -f $BASEDIR/upsets/collect ]]
then
  exit 0
fi

FULLDATE=$1
if [[ -z $FULLDATE ]]
then
  FULLDATE=`date --date="-8hours" +"%F %T"`
fi
DATE=`echo $FULLDATE | cut -d' ' -f1`

# NOTE: This is broken because of the August 2013 revamp.
#$FETCH_YAHOO "$FULLDATE"
#if [[ $? -ne 0 ]]
#then
#  echo "Error fetching Yahoo data"
#  exit 1
#fi

$FETCH_CBSSPORTS "$FULLDATE"
if [[ $? -ne 0 ]]
then
  echo "Error fetching CBS sports data"
fi

$FETCH_FOXSPORTS "$FULLDATE"
if [[ $? -ne 0 ]]
then
  echo "Error fetching FOXSports data"
fi

$DETAILED "$FULLDATE"
if [[ $? -ne 0 ]]
then
  echo "Error creating detailed results (continuing)."
  # Do not exit since we really care about the in-game probabilities
fi

$PROJECTIONS $DATE
if [[ $? -ne 0 ]]
then
  echo "Error creating projection log."
  exit 1
fi

$IN_GAME_LOG $DATE
if [[ $? -ne 0 ]]
then
  echo "Error creating in-game log."
  exit 1
fi

BASE_INGAME_HTML=$WEBDIR/ingame.${DATE}
sh -x $IN_GAME_GRAPH $DATE $BASE_INGAME_HTML
if [[ $? -ne 0 ]]
then
  echo "Error creating in-game graph."
  exit 1
fi

#$UPDATE_BLOG $DATE $BASE_INGAME_HTML
#if [[ $? -ne 0 ]]
#then
#  echo "Failed to update blog"
#  exit 1
#fi
#
#$UPDATE_TWITTER $DATE
#if [[ $? -ne 0 ]]
#then
#  echo "Failed to update tweet log"
#  exit 1
#fi
