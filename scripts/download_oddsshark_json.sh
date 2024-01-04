#!/bin/bash

USER_AGENT='User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.132 Safari/537.36'

BASEDIR="$(pwd)"
SCRIPTDIR="${BASEDIR}/scripts"
GET_GAME="${SCRIPTDIR}/download_oddsshark_game.sh"
ODDSDIR="${BASEDIR}/odds/oddsshark"
JSONDIR="${ODDSDIR}/json"

if [[ $# -lt 2 ]]
then
  echo "Usage: $0 <timestamp> <timespec0> [<timespec1> ... <timespec2>]"
  exit 1
fi

# Move the current timestamp out of the way
daytime=$1
shift
idx=0
declare -a jsonfiles
for timespec in $*
do
  year=$(echo "${timespec}" | cut -d':' -f1)
  weeks=$(echo "${timespec}" | cut -d':' -f2)
  # This is to make sure everything is well-formed
  if [[ -z "${weeks}" || "${year}" == "${weeks}" ]]
  then
    continue
  fi
  mkdir -p "${JSONDIR}/${year}"
  for week in $(echo ${weeks} | tr ',' ' ')
  do
    outfile="${JSONDIR}/${year}/${year}-${week}.json.${daytime}"
    msec=$(date +"%s%N" | cut -c1-13)
    st=$(( 59 - $(( $( echo $msec | cut -c13) * 2 )) ))
    curl "https://io.oddsshark.com/scores/football/ncaaf/${year}/${week}?_=${msec}" \
      -H 'Sec-Fetch-Mode: cors' \
      -H 'Referer: https://www.oddsshark.com/ncaaf/scores' \
      -H 'Origin: https://www.oddsshark.com' \
      -H "${USER_AGENT}" \
      --compressed \
      -o "${outfile}"
    echo $st
    sleep $st
    jsonfiles[idx]=${outfile}
    idx=$(( $idx + 1 ))
  done
done
