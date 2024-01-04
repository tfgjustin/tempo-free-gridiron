#!/bin/bash

BASEDIR=$(pwd)
SCRIPTDIR=${BASEDIR}/scripts
DONBEST=${SCRIPTDIR}/download_donbest_day.sh
ODDSSHARK=${SCRIPTDIR}/download_oddsshark_all.sh

now=$(date +"%Y%m%dT%H%M")
today=${now%T*}
month=$( echo $today | cut -c5-6)
season=$( echo $today | cut -c1-4)

if [[ "${month}" == "01" ]]
then
  season=$(( ${season} - 1 ))
fi

LOGFILE=${BASEDIR}/odds/logs/odds-dl.${now}.log

#if [[ -x ${DONBEST} ]]
#then
#  ${DONBEST} ${today} >> ${LOGFILE} 2>&1
#fi

if [[ -x ${ODDSSHARK} ]]
then
  ${ODDSSHARK} ${now} >> ${LOGFILE} 2>&1
fi
