#!/bin/bash

BASEDIR=$(pwd)
SCRIPTDIR=$BASEDIR/scripts
PAGEDIR=$BASEDIR/pages

UPLOAD=$SCRIPTDIR/blogger_page.sh

if [[ ! -x $UPLOAD ]]
then
  echo "Could not find upload script $UPLOAD"
  exit 1
fi

CURRTIME=$1
if [[ -z $CURRTIME ]]
then
  CURRTIME=`date +"%s"`
fi

for f in $(find -L $PAGEDIR -name '*.html' | sort)
do
  pagetime=$(basename $f | cut -d'.' -f1)
  if [[ -z "$pagetime" || $pagetime -gt $CURRTIME ]]
  then
    continue
  fi
  $UPLOAD $f
  if [[ $? -ne 0 ]]
  then
    echo "Could not upload $f"
    exit 1
  else
    mv ${f} ${f}.bak
  fi
done
