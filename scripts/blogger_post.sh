#!/bin/bash

BASEDIR=$(pwd)
SCRIPTDIR=${BASEDIR}/scripts
BLOGGER_POST=${SCRIPTDIR}/blogger_post.py

FILE=$1

if [[ -z $FILE ]]
then
  echo "No file specified."
  exit 1
fi

if [[ ! -f $FILE ]]
then
  echo "Could not find file $FILE"
  exit 1
fi

if [[ ! -x $BLOGGER_POST ]]
then
  echo "File $BLOGGER_POST is not executable."
  exit 1
fi

POSTTITLE=`grep POSTTITLE $FILE | cut -d'|' -f2`
POSTTAGS=`grep POSTTAGS $FILE | cut -d'|' -f2`
if [[ -z $POSTTITLE ]]
then
  echo "Could not find title in blog post file $FILE."
  exit 1
fi
if [[ -z $POSTTAGS ]]
then
  echo "Could not find tags in blog post file $FILE."
  exit 1
fi

POSTTIME=`grep POSTTIME $FILE | cut -d'|' -f2`

$BLOGGER_POST --post_labels="$POSTTAGS" --post_title="$POSTTITLE" --post_file=$FILE \
  --post_time="$POSTTIME"
