#!/bin/bash

BASEDIR=$(pwd)
PARSE_HTML=$BASEDIR/scripts/parse_yahoo_score.pl
SCORE_GAMES=$BASEDIR/scripts/scoreMyResults.pl
YAHOO_MAP=$BASEDIR/data/yahoo2ncaa.txt
USERAGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_4) AppleWebKit/536.30.1 (KHTML, like Gecko) Version/6.0.5 Safari/536.30.1"

PREDICTED=$1

if [[ -z $PREDICTED || ! -f $PREDICTED ]]
then
  echo "Usage: $0 <predictions>"
  exit 1
fi

if [ ! -x $PARSE_HTML ]
then
  echo "Cannot find HTML parser $PARSE_HTML"
  exit 1
fi

if [ ! -x $SCORE_GAMES ]
then
  echo "Cannot find game scorer $SCORE_GAMES"
  exit 1
fi

wget --user-agent="$USERAGENT" -q -O /tmp/scores.$$.html http://rivals.yahoo.com/ncaa/football/scoreboard
if [ $? -ne 0 ]
then
  echo "Error downloading scores"
  exit 1
fi

$PARSE_HTML $YAHOO_MAP /tmp/scores.$$.html 2> /dev/null > /tmp/results.$$.csv
if [ $? -ne 0 ]
then
  echo "Error parsing Yahoo! HTML"
  exit 1
fi
$SCORE_GAMES /tmp/results.$$.csv $PREDICTED 2> /dev/null | grep ^WK
if [ $? -ne 0 ]
then
  echo "Error scoring my results running $SCORE_GAMES (1)"
  exit 1
fi
$SCORE_GAMES /tmp/results.$$.csv $PREDICTED 2> /dev/null | grep "S 0 "
if [ $? -ne 0 ]
then
  echo "Error scoring my results running $SCORE_GAMES (2)"
  exit 1
fi
rm -f /tmp/results.$$.csv /tmp/scores.$$.html
