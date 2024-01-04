#!/bin/bash

# Directories and files for which we know the names ahead of time.
BASEDIR=$(pwd)
SCRIPTDIR=$BASEDIR/scripts
UPSETDIR=$BASEDIR/upsets
WEBDIR=$BASEDIR/public_html

GETWEEK=$SCRIPTDIR/get_week.sh
UPDATE_BLOG=$SCRIPTDIR/update_in_game_blog.py

GREEN_LIGHT=$UPSETDIR/collect

ORDERING="ACC=9
American_Athletic=4
Big_Ten=7
Big_XII=10
Conference_USA=3
Independents=6
Mid_American=1
Mountain_West=5
Pac_12=8
SEC=11
Sun_Belt=2"

if [[ ! -f $GREEN_LIGHT ]]
then
  exit 0
fi
BASE_POST_TIME=`stat -c "%y" $GREEN_LIGHT  | cut -d' ' -f2,3 | tr ' ' '.' | cut -d'.' -f1,3 | tr -d '.'`

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date --date="-9hours" +"%F"`
fi
BASE_INGAME_HTML=$2
if [[ -z $BASE_INGAME_HTML ]]
then
  BASE_INGAME_HTML=$WEBDIR/ingame.${DATE}
fi

dir=`dirname $BASE_INGAME_HTML`
base=`basename $BASE_INGAME_HTML`
base="${base}*"
files=`find -L $dir -name $base*`
if [[ -z $files ]]
then
  exit 0
fi

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

confs=""
for f in $files
do
  basen=`basename $f`
  conf=`echo $basen | cut -d'.' -f3 | tr '-' '_'`
  if [[ -z $confs ]]
  then
    confs=$conf
  else
    confs="$confs,$conf"
  fi
done

sorted=""
conflist=`echo $confs | tr ',' ' ' | tr '-' '_'`
for c in $conflist
do
  v=`echo "$ORDERING" | grep $c | cut -d'=' -f2`
  sorted="$sorted $c=$v"
done

delays=""
for c in $conflist
do
  v=`echo "$sorted" | tr ' ' '\n' | sort -n -t = -k 2 | grep -n $c | cut -d':' -f1`
  v=`expr $v - 2`
  delays="$delays $c=$v"
done

for f in $files
do
  basen=`basename $f`
  conf=`echo $basen | cut -d'.' -f3 | tr '_' ' '`
  escconf=`echo $conf | tr ' ' '_' | tr '-' '_'`
  TITLE="Week $WEEK: $NAMEOFDAY In-Game Win Probabilities, $conf"

  if [[ ! -s $f ]]
  then
    echo "In-game HTML either missing or empty: $f"
    continue
  fi
  if [[ -f ${f}.noupdate ]]
  then
    continue
  fi
  delay=`echo "$delays" | tr ' ' '\n' | grep $escconf | cut -d'=' -f2`
  if [[ -z $delay ]]
  then
    delay=0
  fi

  POST_TIME=`date --date="$BASE_POST_TIME +${delay}mins" +"%T%z"`
  $UPDATE_BLOG --update_file=$f --game_day=$DATE \
    --post_time="$POST_TIME" --post_title="$TITLE" \
    --post_label="$conf" >> /tmp/ncaa/blogger.$$.out 2>&1
  sleep 1
done
