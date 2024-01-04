#!/bin/bash

BASEDIR=$(pwd)
SCRIPTDIR=${BASEDIR}/scripts
ODDSDIR=${BASEDIR}/odds/oddsshark
GET_JSON=${SCRIPTDIR}/download_oddsshark_json.sh
PROCESS_JSON=${SCRIPTDIR}/process_oddsshark_json.sh
GET_FUTURES=${SCRIPTDIR}/download_oddsshark_futures.sh

if [[ ! -x ${GET_JSON} ]]
then
  echo "Could not find script ${GET_JSON}"
  exit 1
fi

if [[ ! -x ${GET_FUTURES} ]]
then
  echo "Could not find script ${GET_FUTURES}"
  exit 1
fi

now=$1
if [[ -z "${now}" ]]
then
  now=$( date +"%Y%m%dT%H%M" )
fi
now_ts=$( date +"%s" --date="${now}" )
today=${now%T*}
month=$( echo $today | cut -c5-6 )
season=$( echo $today | cut -c1-4 )

if [[ "${month}" == "01" ]]
then
  season=$(( ${season} - 1 ))
fi

WEEK_2_START=$(date --date="${season}-08-31 +$(( 9 - $(date --date="${season}-08-31" +"%u") ))days" +"%s")
days_since_start=$(( ($now_ts - $WEEK_2_START) / 86400))

weeks=$(( (${days_since_start} / 7) + 2 ))
if [[ ${now_ts} -lt ${WEEK_2_START} ]]
then
  weeks=1,2
elif [[ $weeks -eq 17 ]]
then
  weeks="16,P"
elif [[ $weeks -gt 17 ]]
then
  weeks="P"
elif [[ $(( ${days_since_start} % 7)) -le 2 ]]
then
  weeks="$(( ${weeks} - 1 )),${weeks},$(( ${weeks} + 1 ))"
else
  weeks="${weeks},$(( ${weeks} + 1 ))"
fi

# Download the JSON for the current timestamp
echo ${GET_JSON} "${now}" "${season}:${weeks}"

# Process the JSON that's been downloaded
echo ${PROCESS_JSON} "${now}"

echo ${GET_FUTURES}
