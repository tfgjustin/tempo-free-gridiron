#!/bin/bash

BASEDIR=$(pwd)
SCRIPTDIR=$BASEDIR/scripts
TWEETSDIR=$BASEDIR/tweets

TWEET=$SCRIPTDIR/send_tweet.py

if [[ ! -x $TWEET ]]
then
  echo "Could not find tweet script $TWEET"
  exit 1
fi

CURRTIME=
if [[ -z $CURRTIME ]]
then
  CURRTIME=`date +"%s"`
fi

for f in $(find -L $TWEETSDIR -name '*.txt' | sort)
do
  account=$(basename $f | cut -d'.' -f1)
  if [[ -z "$account" ]]
  then
    continue
  fi
  if [[ "$account" -ne "odds" && "$account" -ne "main" && "$account" -ne "when" ]]
  then
    continue
  fi
  tweettime=$(basename $f | cut -d'.' -f2)
  if [[ -z "$tweettime" ]]
  then
    continue
  fi
  if [[ $tweettime -gt $CURRTIME ]]
  then
    break
  fi
  chars=$(cat $f | wc -c)
  if [[ $chars -gt 270 ]]
  then
    continue
  fi
  $TWEET $account "$(cat $f)"
  if [[ $? -ne 0 ]]
  then
    echo "Could not tweet $f"
    exit 1
  else
    mv $f ${f}.bak
  fi
done
