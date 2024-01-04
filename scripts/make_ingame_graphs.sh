#!/bin/bash

# Directories and files for which we know the names ahead of time.
BASEDIR=$(pwd)
DATADIR=$BASEDIR/data
SCRIPTDIR=$BASEDIR/scripts
OUTPUTDIR=$BASEDIR/output
UPSETDIR=$BASEDIR/upsets
WEBDIR=$BASEDIR/public_html

GETWEEK=$SCRIPTDIR/get_week.sh
PROJECT=$SCRIPTDIR/upset_projection.pl
#INGAME=$SCRIPTDIR/in_game.pl
INGAME=$SCRIPTDIR/in_game_js.pl

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
BASEOUTHTML=$2
if [[ -z $OUTHTML ]]
then
  BASEOUTHTML=$WEBDIR/ingame.${DATE}
fi

DAYOFWEEK=`date --date="$DATE" +"%w"`
NAMEOFDAY=`date --date="$DATE" +"%A"`
MONTH=`date --date="$DATE" +"%m"`
YEAR=`date --date="$DATE" +"%Y"`
BLOGYEAR=$YEAR
if [[ $MONTH == "01" ]]
then
  YEAR=$(( $YEAR - 1 ))
fi
PREDDAY=`date --date="$DATE -${DAYOFWEEK}days" +"%F"`
WEEK=`$GETWEEK $PREDDAY`

#MONDAY=`date --date="$DATE +1day" +"%F"`
#TUESDAY=`date --date="$DATE +2day" +"%F"`
#WEDNESDAY=`date --date="$DATE +3day" +"%F"`
#THURSDAY=`date --date="$DATE +4day" +"%F"`
#WEEK=`$GET_WEEK $DATE`
#SATURDAY=`$GET_SATURDAY $DATE`
#
#MONDAY_YEAR=`echo $MONDAY | cut -d'-' -f1`
#MONDAY_MONTH=`echo $MONDAY | cut -d'-' -f2`
#
#TUESDAY_YEAR=`echo $TUESDAY | cut -d'-' -f1`
#TUESDAY_MONTH=`echo $TUESDAY | cut -d'-' -f2`
#
#WEDNESDAY_YEAR=`echo $WEDNESDAY | cut -d'-' -f1`
#WEDNESDAY_MONTH=`echo $WEDNESDAY | cut -d'-' -f2`
#
#THURSDAY_YEAR=`echo $THURSDAY | cut -d'-' -f1`
#THURSDAY_MONTH=`echo $THURSDAY | cut -d'-' -f2`
#
#YEAR=`echo $SATURDAY | dd bs=1 count=4 2> /dev/null`
#MONTH=`echo $SATURDAY | dd bs=1 count=2 skip=4 2> /dev/null`
#
#BLOGURL="http://blog.tempo-free-gridiron.com"

# Files and directories we're going to use.
TFGPRED=$OUTPUTDIR/tfg.predict.${PREDDAY}.out
RBAPRED=$OUTPUTDIR/rba.predict.${PREDDAY}.out
INGAME_LOG=$UPSETDIR/${YEAR}/week${WEEK}/ingame.${DATE}.txt

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

if [[ ! -f $INGAME_LOG ]]
then
  echo "Could not find in-game log $INGAME_LOG"
  exit 1
fi

CONFS=`grep $BLOGYEAR $DATADIR/conferences.csv | cut -d',' -f4 | grep -v ^FCS$ | sort | uniq | tr ' ' '_'`

for conf in $CONFS
do
  OUTHTML=${BASEOUTHTML}.${conf}.html
  rm -f ${OUTHTML}.noupdate
  unescaped_conf=`echo $conf | tr '_' ' '`
  $INGAME $INGAME_LOG $DATE "$unescaped_conf" > $OUTHTML.bak 2> /dev/null
  if [[ $? -eq 0 ]]
  then
    numgames=`grep "Found " ${OUTHTML}.bak | grep " games" | gawk '{print $3}'`
    if [[ ! -z $numgames && $numgames -gt 0 ]]
    then
      curr_checksum=`grep CHECKSUM ${OUTHTML} | cut -d'|' -f2`
      new_checksum=`grep CHECKSUM ${OUTHTML}.bak | cut -d'|' -f2`
      if [[ -n $curr_checksum && -n $new_checksum && $curr_checksum == $new_checksum ]]
      then
        rm -f ${OUTHTML}.bak
        touch ${OUTHTML}.noupdate
        echo -n "x" >> /tmp/update.log
      else
        mv $OUTHTML.bak $OUTHTML
        echo -n "O" >> /tmp/update.log
      fi
    else
      rm -f $OUTHTML.bak
    fi
  fi
done
