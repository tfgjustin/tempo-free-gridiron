#!/bin/bash

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date +"%F"`
fi
BASEDIR=$(pwd)
CODEDIR=$BASEDIR/code
DATADIR=$BASEDIR/data
INPUTDIR=$BASEDIR/input

PREDICT=$CODEDIR/predict
SUMMARY_FILE=$INPUTDIR/summaries.csv
PREDICT_FILE=$INPUTDIR/to_predict.csv

# Old version (pre-2010/10/01)
# E=2.7 W=0.971 P=0.960 Y=0.006
# Updated (post-2010/10/01)
# E=2.5 W=0.974 P=0.985 Y=0.004
# Updated (post-2013/08/25)
# E=2.66 W=0.960 P=0.985 Y=0.004
EXPONENT=2.66
WEEK_DECAY=0.960
BOWL_DECAY=1.000
POINT_WEIGHT=0.985
YARD_WEIGHT=0.004

OUTFILE=tfg.$DATE.out
ERRFILE=tfg.$DATE.err
SVN_OUTFILE=output/$OUTFILE
SVN_ERRFILE=output/$ERRFILE
SVN_PREDICTFILE=output/tfg.predict.$DATE.out
SVN_RANKINGFILE=output/tfg.ranking.$DATE.out

if [[ -f $SVN_PREDICTFILE ]]
then
  echo "SVN Prediction file $SVN_PREDICTFILE already exists."
  if [[ "x$2" != "xforce" ]]
  then
    exit 0
  else
    echo "'force' specified; continuing anyways"
  fi
fi

cd $BASEDIR
time $PREDICT -s $SUMMARY_FILE -t $PREDICT_FILE -e $EXPONENT  -w $WEEK_DECAY \
 -b $BOWL_DECAY -p $POINT_WEIGHT -y $YARD_WEIGHT > $SVN_OUTFILE 2> $SVN_ERRFILE

if [[ $? -ne 0 ]]
then
  echo "Error running TFG prediction code $PREDICT"
  exit 1
fi
if [[ ! -s $SVN_OUTFILE ]]
then
  echo "Error running TFG prediction code $PREDICT; zero-sized output file"
  exit 1
fi

ln -s $OUTFILE $SVN_PREDICTFILE
if [[ $? -ne 0 ]]
then
  echo "Error linking $SVN_PREDICTFILE to $OUTFILE"
  exit 1
fi
ln -s $OUTFILE $SVN_RANKINGFILE
if [[ $? -ne 0 ]]
then
  echo "Error linking $SVN_RANKINGFILE to $OUTFILE"
  exit 1
fi
exit 0
svn add $SVN_PREDICTFILE $SVN_RANKINGFILE $SVN_OUTFILE > /dev/null 2>&1
if [[ $? -ne 0 ]]
then
  echo "Error adding $SVN_PREDICTFILE $SVN_RANKINGFILE $SVN_OUTFILE to SVN"
  exit 1
fi
svn commit -m "Added TFG prediction output files from $DATE to SVN" \
 $SVN_PREDICTFILE $SVN_RANKINGFILE $SVN_OUTFILE > /dev/null 2>&1
if [[ $? -ne 0 ]]
then
  echo "Error commiting $SVN_PREDICTFILE $SVN_RANKINGFILE $SVN_OUTFILE to SVN"
  exit 1
fi
rm -f $SVN_ERRFILE
exit 0
