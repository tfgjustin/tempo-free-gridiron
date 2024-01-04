#!/bin/bash

export RBAPOINTS=445
export TFGPOINTS=477

BASEDIR=$(pwd)
SCRIPTDIR=$BASEDIR/scripts
OUTPUTDIR=$BASEDIR/output

PICKEM=$SCRIPTDIR/pickem_games.pl
FORMAT=$SCRIPTDIR/pickem_format.pl
PRETTYPRINT=$SCRIPTDIR/prettyprint.pl
GETWEEK=$SCRIPTDIR/get_week.sh

DATE=$1
if [[ -z $DATE ]]
then
  DATE=`date +"%F"`
fi

CURRDATE=`echo $DATE | tr -d '-'`

WEEK=`$GETWEEK $DATE`

RBAPREDICT=$OUTPUTDIR/rba.predict.$DATE.out
RBARANKING=$OUTPUTDIR/rba.ranking.$DATE.out
TFGPREDICT=$OUTPUTDIR/tfg.predict.$DATE.out
TFGRANKING=$OUTPUTDIR/tfg.ranking.$DATE.out

RBAOUTPUT=$OUTPUTDIR/rba.forecast.$DATE.out
TFGOUTPUT=$OUTPUTDIR/tfg.forecast.$DATE.out

INPUTFILES="$TFGPREDICT $TFGRANKING $RBAPREDICT $RBARANKING"

rm -f $OUTPUTDIR/pickem.*.out

DATES="small:20111001 large:20111008 small:20111015 small:20111022 small:20111029 large:20111105 small:20111112 small:20111119 small:20111126 large:20111203"

for i in $DATES
do
  size=`echo $i | cut -d':' -f1`
  d=`echo $i | cut -d':' -f2`
  if [[ $d -lt $CURRDATE ]]
  then
    echo "Skipping $d"
    continue
  fi
  $PICKEM $size $d $d $INPUTFILES 2> /dev/null > $OUTPUTDIR/pickem.${d}.out
done

export week=$(( $WEEK - 1 ))
(echo "$week $RBAPOINTS" &&
for i in $OUTPUTDIR/pickem.2011*.out
do
  week=$(( $week + 1 ))
  bn=`basename $i | cut -d'.' -f2`
  echo -n "$week "
  GIDS=`cat $i | cut -d' ' -f1`
  $PRETTYPRINT $OUTPUTDIR/rba.predict.$DATE.out | grep -F "$GIDS" | sort | uniq |\
     cut -d' ' -f2- | sort -k 5 -n | grep -n ^ | tr ':' ' ' | sort -k 4 | $FORMAT |\
     perl -ne 'chomp;@_ = split; printf "%.2f\n", $_[0] * $_[5];' | ~/bin/sum_num

done)  |\
 perl -e '$cv=0;while(<STDIN>){chomp;@_ = split; printf "%d %.2f\n", $_[0], $cv + $_[1]; $cv += $_[1];}' >\
 $RBAOUTPUT

export week=$(( $WEEK - 1 ))
(echo "$week $TFGPOINTS" &&
for i in $OUTPUTDIR/pickem.2011*out
do
  week=$(( $week + 1 ))
  bn=`basename $i | cut -d'.' -f2`
  echo -n "$week "
  GIDS=`cat $i | cut -d' ' -f1`
  $PRETTYPRINT $OUTPUTDIR/tfg.predict.$DATE.out | grep -F "$GIDS" | sort | uniq |\
     cut -d' ' -f2- | sort -k 5 -n | grep -n ^ | tr ':' ' ' | sort -k 4 | $FORMAT |\
     perl -ne 'chomp;@_ = split; printf "%.2f\n", $_[0] * $_[5];' | ~/bin/sum_num
done)  |\
 perl -e '$cv=0;while(<STDIN>){chomp;@_ = split; printf "%d %.2f\n", $_[0], $cv + $_[1]; $cv += $_[1];}' >\
 $TFGOUTPUT

cat > $OUTPUTDIR/projections.$DATE.gplot << __EOF__
set terminal postscript color
set size 0.6,0.6
set output "$OUTPUTDIR/projections.$DATE.ps"
set xrange[3:14]
set xtics 4,2,14
set yrange[0:675]
set ytics 75
set key top left
set grid xtics ytics
set xlabel "Week"
set ylabel "Points"
plot '$OUTPUTDIR/tfg.points.$DATE.out' title "TFG" w l lw 2 lc 3 lt 1, \
  '$OUTPUTDIR/tfg.forecast.$DATE.out' notitle w l lw 2 lc 3 lt 2, \
  '$OUTPUTDIR/rba.points.$DATE.out' title "RBA" w l lw 2 lc 1 lt 1, \
  '$OUTPUTDIR/rba.forecast.$DATE.out' notitle w l lw 2 lc 1 lt 2
__EOF__

gnuplot $OUTPUTDIR/projections.$DATE.gplot
if [[ $? -ne 0 ]]
then
  echo "Error running gnuplot"
  exit 1
fi

convert -rotate 90 -density 300 -size 423x297 -resize 423x297 $OUTPUTDIR/projections.$DATE.ps $OUTPUTDIR/projections.$DATE.png
if [[ $? -ne 0 ]]
then
  echo "Error running convert"
  exit 1
fi
