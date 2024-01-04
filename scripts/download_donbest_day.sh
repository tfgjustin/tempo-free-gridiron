#!/bin/bash

BASEDIR=$(pwd)
OUTDIR=${BASEDIR}/odds/donbest/html

if [[ $# -eq 0 ]]
then
  echo "Usage: $0 <date0> [<date1> ... <dateN>]"
  exit 1
fi


for d in $*
do
  for t in spreads money-lines totals
  do
    echo "${d} ${t}"
    curl -o ${OUTDIR}/${d}-${t}.html --progress-bar \
      "http://www.donbest.com/ncaaf/odds/${t}/${d}.html"
    sleep 15
  done
done
