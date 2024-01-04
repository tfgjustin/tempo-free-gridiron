#!/bin/bash

BASEDIR=$(pwd)
SCRIPTDIR=$BASEDIR/scripts
WEBDIR=$BASEDIR/public_html

UPLOAD=$SCRIPTDIR/blogger_post.sh

if [[ ! -x $UPLOAD ]]
then
  echo "Could not find upload script $UPLOAD"
  exit 1
fi

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date +"%F"`
fi

#GREPARG=""
#if [[ `whoami` != "eddie" ]]
#then
#  GREPARG="-v"
#fi
#
#for f in `find -L $WEBDIR -name '*.html' | grep $DATE | grep $GREPARG /rba | grep -v /ingame | sort`
for f in `find -L $WEBDIR -name '*.html' | grep $DATE | grep -v /ingame | sort`
do
  if [[ ! -s $f ]]
  then
    continue
  fi
  $UPLOAD $f
  if [[ $? -ne 0 ]]
  then
    echo "Could not upload $f"
    exit 1
  fi
done
