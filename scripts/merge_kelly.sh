#!/bin/bash -e

BASEDIR="$(pwd)"
ODDSDIR="${BASEDIR}/odds"

if [[ $# -ne 1 ]]
then
  echo "Usage: $0 <timestamp>"
  exit 1
fi

d=${1%T*}
season=$(date --date="${d}" +"%Y")
month=$(date --date="${d}" +"%m")
if [[ "${month}" == "01" ]]
then
  season=$(( $season - 1 ))
fi

if ! compgen -G "${ODDSDIR}/sp/csv/${season}/sp.*.kelly.tsv.$1" > /dev/null
then
  echo "Not found: '${ODDSDIR}/sp/csv/${season}/sp.*.kelly.tsv.$1'"
  exit 1
fi

head -n 1 ${ODDSDIR}/sp/csv/${season}/sp.*.kelly.tsv.$1 | grep ^G | \
  head -1 > ${ODDSDIR}/sp/csv/${season}/sp.kelly.tsv.$1
cat ${ODDSDIR}/sp/csv/${season}/sp.*.kelly.tsv.$1 | grep -v ^G | \
  sort >> ${ODDSDIR}/sp/csv/${season}/sp.kelly.tsv.$1
