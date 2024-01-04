#!/bin/bash

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date +"%F"`
fi

DAY_OF_WEEK=`date --date="$DATE" +"%w"`
FIRST_DAY=$(( 2 - $DAY_OF_WEEK ))
NEXT_MONDAY=$(( 8 - $DAY_OF_WEEK ))
FIRST_DATE=`date --date="$DATE +${FIRST_DAY}days" +"%Y%m%d"`
LAST_DATE=`date --date="$DATE +${NEXT_MONDAY}days" +"%Y%m%d"`
echo "$FIRST_DATE $LAST_DATE"
