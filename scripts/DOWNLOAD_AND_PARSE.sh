#!/bin/bash

BASEDIR=$(pwd)
SCRIPTDIR=$BASEDIR/scripts

DATE=$1
VERBOSE=$2
if [[ -z $DATE ]]
then
  DATE=`date +"%F"`
fi

SHELL=/bin/bash
if [[ ! -x $VERBOSE ]]
then
  SHELL="/bin/bash -x"
fi

#$SHELL $SCRIPTDIR/fetch_current_data.sh
$SHELL $SCRIPTDIR/parse_cfbstats_data.sh
if [[ $? -ne 0 ]]
then
  echo "Error fetching current data."
  exit 1
fi

#$SHELL $SCRIPTDIR/make_summary.sh $DATE
#if [[ $? -ne 0 ]]
#then
#  echo "Error making summary files."
#  exit 1
#fi
exit 0
