#!/bin/bash

# Directories and files for which we know the names ahead of time.
BASEDIR=$(pwd)
SCRIPTDIR=$BASEDIR/scripts
OUTPUTDIR=$BASEDIR/output
UPSETDIR=$BASEDIR/upsets
WEBDIR=$BASEDIR/public_html

GETWEEK=$SCRIPTDIR/get_week.sh
PROJECT=$SCRIPTDIR/upset_projection.pl

GREEN_LIGHT=$UPSETDIR/collect

#if [[ ! -f $GREEN_LIGHT ]]
#then
#  exit 0
#fi

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date --date="-8hours" +"%F"`
fi
FORCE=$2
if [[ ! -z $FORCE && $FORCE == "force" ]]
then
  FORCE=1
else
  FORCE=0
fi
#echo "force: $FORCE"

DAYOFWEEK=`date --date="$DATE" +"%w"`
NAMEOFDAY=`date --date="$DATE" +"%A"`
MONTH=`date --date="$DATE" +"%m"`
YEAR=`date --date="$DATE" +"%Y"`
if [[ $MONTH == "01" ]]
then
  YEAR=$(( $YEAR - 1 ))
fi
PREDDAY=`date --date="$DATE -${DAYOFWEEK}days" +"%F"`
WEEK=`$GETWEEK $PREDDAY`

# Files and directories we're going to use.
TFGPRED=$OUTPUTDIR/tfg.predict.${PREDDAY}.out
RBAPRED=$OUTPUTDIR/rba.predict.${PREDDAY}.out

THIS_UPSETDIR=$UPSETDIR/${YEAR}/week${WEEK}/${DAYOFWEEK}

if [[ ! -f $TFGPRED ]]
then
  echo "No TFG prediction file for $PREDDAY: $TFGPRED"
  exit 1
fi

if [[ ! -f $RBAPRED ]]
then
  echo "No RBA prediction file for $PREDDAY: $RBAPRED"
  exit 1
fi

#for csv in `find -L $THIS_UPSETDIR -name 'foxsports.*.csv' | sort`
for csv in `find -L $THIS_UPSETDIR -name 'cbssports.*.csv' | sort`
do
  tfgfile=${csv%csv}tfg
  rbafile=${csv%csv}rba
  errfile=`basename ${csv%csv}`
  if [[ ! -f $rbafile || $FORCE -eq 1 ]]
  then
    $PROJECT $RBAPRED $csv > $rbafile 2> /tmp/ncaa/rba.${errfile}err
    if [[ $? -ne 0 ]]
    then
      echo "Error converting $csv -> $rbafile"
    fi
  fi
  if [[ ! -f $tfgfile || $FORCE -eq 1 ]]
  then
    $PROJECT $TFGPRED $csv > $tfgfile 2> /tmp/ncaa/tfg.${errfile}err
    if [[ $? -ne 0 ]]
    then
      echo "Error converting $csv -> $tfgfile"
    fi
  fi
done
