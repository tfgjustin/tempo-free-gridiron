#!/bin/bash

BASEDIR=$(pwd)
SCRIPTDIR=$BASEDIR/scripts
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

$SCRIPTDIR/DOWNLOAD_AND_PARSE.sh $DATE
if [[ $? -ne 0 ]]
then
  echo "Error running download-and-parse script."
  exit 1
fi

sh -x $SCRIPTDIR/PREDICTIONS.sh $DATE
if [[ $? -ne 0 ]]
then
  echo "Error running predictions."
  exit 1
fi

sh -x $SCRIPTDIR/POST_PREDICTIONS.sh $DATE
if [[ $? -ne 0 ]]
then
  echo "Error running post-prediction script(s)."
  exit 1
fi
