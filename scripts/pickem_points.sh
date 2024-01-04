#!/bin/bash

#set -x

DATE=$1
OUTFILE=$2
if [[ -z $OUTFILE ]]
then
  echo "No date and outfile given. Exiting."
  exit 1
fi

if [[ ! -f $OUTFILE ]]
then
  echo "Cannot find outfile $OUTFILE. Exiting."
  exit 1
fi

BASEDIR=$(pwd)
OUTPUTDIR=$BASEDIR/output
SCRIPTDIR=$BASEDIR/scripts
WEBDIR=$BASEDIR/public_html

PICKEM=$SCRIPTDIR/pickem_games.pl
FORMAT=$SCRIPTDIR/pickem_format.pl
PRETTYPRINT=$SCRIPTDIR/prettyprint.pl

#OUTFILE=$WEBDIR/all.pickem.$DATE.txt
RBAPICKS=$WEBDIR/rba.pickem.$DATE.txt
TFGPICKS=$WEBDIR/tfg.pickem.$DATE.txt

RBA_PREDICT="$OUTPUTDIR/rba.predict.$DATE.out"
TFG_PREDICT="$OUTPUTDIR/tfg.predict.$DATE.out"

GIDS=`cat $OUTFILE | cut -d' ' -f1 | sort `
$PRETTYPRINT $RBA_PREDICT | grep --fixed-strings "$GIDS" | sort | uniq |\
 cut -d' ' -f2- | sort -k 5 -n | grep -n ^ | tr ':' ' ' | sort -rn | $FORMAT > $RBAPICKS
$PRETTYPRINT $TFG_PREDICT | grep --fixed-strings "$GIDS" | sort | uniq |\
 cut -d' ' -f2- | sort -k 5 -n | grep -n ^ | tr ':' ' ' | sort -rn | $FORMAT > $TFGPICKS
