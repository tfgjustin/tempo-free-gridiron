#!/bin/bash

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date +"%F"`
fi

DAY_OF_WEEK=`date --date="$DATE" +"%w"`
SATURDAY=$(( 6 - $DAY_OF_WEEK ))
THIS_SATURDAY=`date --date="$DATE +${SATURDAY}days" +"%Y%m%d"`
echo "$THIS_SATURDAY"
