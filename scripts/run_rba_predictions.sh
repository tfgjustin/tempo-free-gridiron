#!/bin/bash

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date +"%F"`
fi
BASEDIR=$(pwd)
CODEDIR=$BASEDIR/rba
DATADIR=$BASEDIR/data
INPUTDIR=$BASEDIR/input
SCRIPTDIR=$BASEDIR/scripts
WEBDIR=$BASEDIR/public_html

PREDICT=$CODEDIR/ncaa.py
ID2NAME=$DATADIR/id2name.txt
SUMMARY_FILE=$INPUTDIR/summaries.csv
PREDICT_FILE=$INPUTDIR/to_predict.csv

ERRFILE=rba.$DATE.err
SVN_PREDICTFILE=output/rba.predict.$DATE.out
SVN_RANKINGFILE=output/rba.ranking.$DATE.out
HUMAN_RANKFILE=$WEBDIR/rba.humanrank.$DATE.out
HUMAN_OUTFILE=$WEBDIR/rba.human.$DATE.out
HUMAN_ERRFILE=$WEBDIR/rba.human.$DATE.err

if [[ -f $SVN_PREDICTFILE ]]
then
  if [[ -z $2 || $2 != "force" ]]
  then
    echo "SVN prediction file $SVN_PREDICTFILE already exists."
    exit 0
  fi
fi

DAY_OF_WEEK=`date --date="$DATE" +"%w"`
SAT_DAYS=$(( 6 - $DAY_OF_WEEK ))
SAT_DATE=`date --date="$DATE +${SAT_DAYS}days" +"%Y%m%d"`
OVERALL_WEEK=`grep ,${SAT_DATE}, $SUMMARY_FILE | cut -d',' -f1 | sort | uniq`
OVERALL_WEEK=1012

cd $BASEDIR
time python -m cProfile -o profile.dat $PREDICT $SUMMARY_FILE $SVN_RANKINGFILE $OVERALL_WEEK "cpu" 1 $ID2NAME >\
 $SVN_PREDICTFILE  2> $ERRFILE
if [[ $? -ne 0 ]]
then
  echo "Error running RBA prediction code $PREDICT; see $ERRFILE"
  exit 1
fi

$PREDICT $SUMMARY_FILE $HUMAN_RANKFILE $OVERALL_WEEK "human" 0 $ID2NAME >\
 $HUMAN_OUTFILE  2> $HUMAN_ERRFILE
if [[ $? -ne 0 ]]
then
  echo "Error running human-readable RBA prediction code $PREDICT; see $HUMAN_ERRFILE"
  exit 1
fi

# Only panic about the output file size if 
if [[ -s $PREDICT_FILE ]]
then
  if [[ ! -s $SVN_PREDICTFILE ]]
  then
    echo "Error running RBA prediction code $PREDICT; zero-sized output file"
    echo "See $ERRFILE for details"
    exit 1
  fi
fi
rm -f $ERRFILE

#svn add $SVN_PREDICTFILE $SVN_RANKINGFILE > /dev/null 2>&1
#if [[ $? -ne 0 ]]
#then
#  echo "Error adding $SVN_PREDICTFILE $SVN_RANKINGFILE to SVN"
#  exit 1
#fi
#svn commit -m "Added RBA prediction output files from $DATE to SVN" \
# $SVN_PREDICTFILE $SVN_RANKINGFILE > /dev/null 2>&1
#if [[ $? -ne 0 ]]
#then
#  echo "Error commiting $SVN_PREDICTFILE $SVN_RANKINGFILE to SVN"
#  exit 1
#fi
#rm -f $SVN_ERRFILE
#exit 0
