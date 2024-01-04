#!/bin/bash

BASEDIR=$(pwd)
INPUTDIR=$BASEDIR/input
SCRIPTDIR=$BASEDIR/scripts
WEBDIR=$BASEDIR/public_html
DATE=

if [[ $# -eq 0 ]]
then
  DATE=`date +"%F"`
elif [[ $# -eq 1 ]]
then
  DATE=$1
else
  echo "Error getting date information."
  exit 1
fi

$SCRIPTDIR/post_to_blogger.sh $DATE
if [[ $? -ne 0 ]]
then
  echo "Error uploading all files."
  exit 1
fi
