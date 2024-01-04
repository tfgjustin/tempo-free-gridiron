#!/bin/bash

BASEDIR=$(pwd)
SCRIPTDIR=$BASEDIR/scripts
SHELL=/bin/bash

DATE=$1
VERBOSE=$2
if [[ -z $DATE ]]
then
  DATE=`date +"%F"`
fi

if [[ ! -z $VERBOSE ]]
then
  SHELL="/bin/bash -x"
fi

$SHELL $SCRIPTDIR/run_tfg_predictions.sh $DATE force
if [[ $? -ne 0 ]]
then
  echo "Error running TFG predictions."
  exit 1
fi

$SHELL $SCRIPTDIR/run_rba_predictions.sh $DATE force
if [[ $? -ne 0 ]]
then
  echo "Error running RBA predictions."
  exit 1
fi
