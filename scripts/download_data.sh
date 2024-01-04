#!/bin/bash

USERAGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_4) AppleWebKit/536.30.1 (KHTML, like Gecko) Version/6.0.5 Safari/536.30.1"
BASEDIR=$(pwd)
DATADIR=$BASEDIR/data
LOGFILE=/tmp/download.$$.log

# Which file are we downloading?
URLFILE=`find -L $DATADIR -name urls.txt | sort | tail -1`
if [[ -z $URLFILE ]]
then
  echo "Error finding urls.txt file in $DATADIR"
  exit 1
fi
URLDIR=`dirname $URLFILE`
if [[ ! -d $URLDIR/current ]]
then
  echo "No such directory: $URLDIR/current"
  exit 1
fi
cd $URLDIR/current
wget -U "${USERAGENT}" -q -i $URLFILE
if [[ $? -ne 0 ]]
then
  echo "Error fetching URLs in $URLFILE"
  exit 1
fi
rm -f $LOGFILE ; touch $LOGFILE
for f in *.csv *.html
do
  if [[ ! -f ${f}.1 ]]
  then
    continue
  fi
  origsize=`stat --format="%s" $f 2> /dev/null`
  newsize=`stat --format="%s" ${f}.1 2> /dev/null`
  if [[ -z $origsize ]]
  then
    echo "Error getting size of $f"
    exit 1
  fi
  if [[ -z $newsize ]]
  then
    echo "Error getting size of ${f}.1"
    exit 1
  fi
  if [[ $origsize -le $newsize ]]
  then
    continue
  fi
  # The new file is larger than the old one. Update the file.
  mv ${f}.1 $f
  echo $f >> $LOGFILE
done
numupdated=`cat $LOGFILE | wc -l`
if [[ -z $numupdated ]]
then
  echo "Error finding number of files updated."
  exit 1
fi
if [[ $numupdated -eq 0 ]]
then
  exit 0
fi
# Dump the files into SVN
SVNOUT=/tmp/svn.$$.out
SVNERR=/tmp/svn.$$.err
svn commit -m "Updated files for `date`" `cat $LOGFILE` > $SVNOUT 2> $SVNERR
if [[ $? -ne 0 ]]
then
  echo "Error updating $numupdated data files. See $SVNOUT and $SVNERR"
  exit 1
fi
rm -f $SVNOUT $SVNERR $LOGFILE
exit 0
