#!/bin/bash

BASEDIR=$(pwd)
SCRIPTDIR=${BASEDIR}/scripts
BLOGGER_PAGE=${SCRIPTDIR}/blogger_page.py

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

if [[ ! -x $BLOGGER_PAGE ]]
then
  echo "File $BLOGGER_PAGE is not executable."
  exit 1
fi

PAGETIME=`grep PAGETIME $FILE | cut -d'|' -f2`
if [[ -z $PAGETIME ]]
then
  echo "Could not find time in blog page file $FILE."
  exit 1
fi
PAGETITLE=`grep PAGETITLE $FILE | cut -d'|' -f2`
if [[ -z $PAGETITLE ]]
then
  echo "Could not find title in blog page file $FILE."
  exit 1
fi
PAGEID=`grep PAGEID $FILE | cut -d'|' -f2`
if [[ -z $PAGEID ]]
then
  echo "Could not find ID in blog page file $FILE."
  exit 1
fi

$BLOGGER_PAGE --page_id="$PAGEID" --page_file="$FILE" --page_title="$PAGETITLE" \
  --page_time="$PAGETIME"
