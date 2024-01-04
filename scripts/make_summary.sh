#!/bin/bash

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date +"%F"`
fi
BASEDIR=$(pwd)
DATADIR=$BASEDIR/data
SCRIPTDIR=$BASEDIR/scripts
GAME_BY_GAME=$SCRIPTDIR/parse_game_by_game.pl
MAKE_GAMELOG=$SCRIPTDIR/make_gamelog.sh
MAKE_SUMMARIES=$SCRIPTDIR/merge_gamelog_with_offense.pl
WHITELIST=$SCRIPTDIR/whitelist.pl
TEMP_SUMMARIES=/tmp/summaries.${DATE}.$$.csv
SUMMARIES=summaries.csv
TOPREDICT=to_predict.csv
SVN_SUMMARIES=input/summaries.csv
SVN_TOPREDICT=input/to_predict.csv
FINAL_SUMMARIES=$BASEDIR/$SVN_SUMMARIES
FINAL_TOPREDICT=$BASEDIR/$SVN_TOPREDICT
WHITELIST_FILE=$BASEDIR/input/whitelist.csv

cd $BASEDIR
for datadir in $DATADIR/20[01][0-9]
do
  if [[ ! -d $datadir ]]
  then
    continue
  fi
  input_gamelog=`find -L $datadir -name 'DIV*B.csv'`
  if [[ -z $input_gamelog ]]
  then
    input_gamelog=`find -L $datadir -name 'DIV*1.csv'`
    if [[ -z $input_gamelog ]]
    then
      input_gamelog=`find -L $datadir -name 'fbs.csv'`
      if [[ -z $input_gamelog ]]
      then
        echo "Could not find gamelog in $datadir"
        exit 1
      fi
    fi
  fi

  if [[ -f $datadir/$SUMMARIES && -s $datadir/$SUMMARIES && $datadir/$SUMMARIES -nt $input_gamelog ]]
  then
    continue
  fi
  YEAR=${datadir##*/}
  ALL_OFFENSE_FILES=/tmp/all_offense.${DATE}.${YEAR}.txt
  TEMP_OFFENSE=/tmp/offense.${DATE}.${YEAR}.csv
  SORT_OFFENSE=/tmp/offense.sorted.${DATE}.${YEAR}.csv
  find -L $datadir -name '*teamoff.html' | sort > $ALL_OFFENSE_FILES
  if [[ -s $ALL_OFFENSE_FILES ]]
  then
    cat $ALL_OFFENSE_FILES | $GAME_BY_GAME > $TEMP_OFFENSE 2> /dev/null
    if [[ $? -ne 0 ]]
    then
      echo "Error running $GAME_BY_GAME; temporary results in $TEMP_OFFENSE"
      echo "List of input files in $ALL_OFFENSE_FILES"
      exit 1
    fi
    if [[ ! -s $TEMP_OFFENSE ]]
    then
      echo "Error runnings $GAME_BY_GAME; output file $TEMP_OFFENSE is empty"
      echo "List of input files in $ALL_OFFENSE_FILES";
      exit 1
    fi
    cat $TEMP_OFFENSE | sort -n > $SORT_OFFENSE
  else
    month=`echo $DATE | cut -d'-' -f2`
    if [[ $month != "08" ]]
    then
      echo "Could not find any teamoff.html files in $DATADIR"
      exit 1
    else
      touch $SORT_OFFENSE
    fi
  fi
  rm -f $TEMP_OFFENSE $ALL_OFFENSE_FILES
  
  TEMP_GAMELOG=/tmp/gamelog.${DATE}.${YEAR}.csv
  SORT_GAMELOG=/tmp/gamelog.sorted.${DATE}.csv
  $MAKE_GAMELOG $input_gamelog > $TEMP_GAMELOG
  if [[ $? -ne 0 ]]
  then
    echo "Error running $MAKE_GAMELOG; temporary results in $TEMP_GAMELOG"
    exit 1
  fi
  if [[ ! -s $TEMP_GAMELOG ]]
  then
    echo "Error running $MAKE_GAMELOG; output file $TEMP_GAMELOG is empty"
    exit 1
  fi
  cat $TEMP_GAMELOG | sort -n > $SORT_GAMELOG
  rm -f $TEMP_GAMELOG
  
  $MAKE_SUMMARIES $SORT_OFFENSE $SORT_GAMELOG > $datadir/$SUMMARIES
  if [[ $? -ne 0 ]]
  then
    echo "Error running $MAKE_SUMMARIES from $SORT_OFFENSE and $SORT_GAMELOG"
    echo "Temporary output in $datadir/SUMMARIES"
    exit 1
  fi
  if [[ ! -s $datadir/$SUMMARIES ]]
  then
    echo "Error running $MAKE_SUMMARIES from $SORT_OFFENSE and $SORT_GAMELOG"
    echo "Empty output in $datadir/$SUMMARIES"
    exit 1
  fi
  rm -f $SORT_GAMELOG $SORT_OFFENSE
done

cat $DATADIR/20[01][0-9]/$SUMMARIES | sort -n | uniq > $TEMP_SUMMARIES

$WHITELIST $TEMP_SUMMARIES $WHITELIST_FILE $DATE | sort -n > $FINAL_SUMMARIES
if [[ $? -ne 0 ]]
then
  echo "Error running $WHITELIST; input in $TEMP_SUMMARIES"
  exit 1
fi
if [[ ! -s $FINAL_SUMMARIES ]]
then
  echo "Somehow ended up with an empty summaries file."
  exit 1
fi
rm -f $TEMP_SUMMARIES

grep 0,0,0,0 $FINAL_SUMMARIES > $FINAL_TOPREDICT
svn commit -m "Automatic update of input files by `pwd`/$0 on $DATE" $SVN_SUMMARIES $SVN_TOPREDICT > /dev/null 2>&1
if [[ $? -ne 0 ]]
then
  echo "Error running subversion commit of $FINAL_SUMMARIES and $FINAL_TOPREDICT"
  exit 1
fi
exit 0
