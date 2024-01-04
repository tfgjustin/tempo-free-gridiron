#!/bin/bash

BASEDIR=$(pwd)
DATADIR=$BASEDIR/data
SCRIPTDIR=$BASEDIR/scripts
WGET=`which wget`
SVN=`which svn`
USERAGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_4) AppleWebKit/536.30.1 (KHTML, like Gecko) Version/6.0.5 Safari/536.30.1"

if [[ -z $WGET ]]
then
  echo "Error finding wget on this system";
  exit 1
fi

if [[ -z $SVN ]]
then
  echo "Error finding subversion on this system";
  exit 1
fi

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date +"%F"`
fi

YEAR=${DATE%%-*}
MONTH=`echo $DATE | cut -d'-' -f2`
if [[ $MONTH == "01" ]]
then
  YEAR=$(( $YEAR - 1 ))
fi

YEARDIR=$DATADIR/$YEAR
if [[ ! -d $YEARDIR ]]
then
  echo "Could not find year directory: $YEARDIR"
  exit 1
fi

CURRDIR=$YEARDIR/current
if [[ ! -d $CURRDIR ]]
then
  echo "Could not find current directory: $CURRDIR"
  exit 1
fi

URLS=$YEARDIR/urls.txt
if [[ ! -f $URLS ]]
then
  echo "Could not find file with URLs: $URLS"
  exit 1
fi

OUTFILE=$YEARDIR/wget.$DATE.out
ERRFILE=$YEARDIR/wget.$DATE.err
cd $CURRDIR
$WGET --user-agent="$USERAGENT" -nv -N -i $URLS > $OUTFILE 2> $ERRFILE
if [[ $? -ne 0 ]]
then
  echo "Error running \"$WGET --user-agent=\"$USERAGENT\" -nv -N -i $URLS\"; see $OUTFILE and $ERRFILE"
  exit 1
fi

UPDATES=$YEARDIR/updates.$DATE.out
$SVN status | grep ^M | gawk '{print $2}' | sort > $UPDATES
if [[ ! -s $UPDATES ]]
then
  echo "No updates found"
  exit 1
fi

SVNOUT=$YEARDIR/svnlog.$DATE.out
SVNERR=$YEARDIR/svnlog.$DATE.err
$SVN commit -m "Updated html files on $DATE" `cat $UPDATES` > $SVNOUT 2> $SVNERR
if [[ $? -ne 0 ]]
then
  echo "Error commiting new HTML files on $DATE"
  exit 1
fi
exit 0
