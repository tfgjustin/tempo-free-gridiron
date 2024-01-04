#!/bin/bash

BASEDIR="$(pwd)"
OUTDIR="${BASEDIR}/odds/oddsshark/html"

if [[ $# -ne 2 ]]
then
  echo "Usage: $0 <url_file> <timestamp>"
  exit 1
fi

if [[ ! -f "$1" ]]
then
  echo "No such URL file: $1"
  exit 1
fi

ts=$( date --date="$2" +"%s" )
year=$( date --date="$2" +"%Y")
month=$( date --date="$2" +"%m" )
season=${year}
if [[ $month == "01" ]]
then
  season=$(( ${season} - 1 ))
fi

mkdir -p "${OUTDIR}/${season}"
for URL in $( grep ^https "$1" | sort | uniq)
do
  echo "${URL}"
  outfile="${OUTDIR}/${season}/$(basename ${URL}).html.$2"
  if [[ -s "${outfile}" ]]
  then
    echo "Skipping already-downloaded ${URL}"
    continue
  fi
  curl --progress-bar "${URL}" \
    -H 'authority: www.oddsshark.com' \
    -H 'cache-control: max-age=0' \
    -H 'upgrade-insecure-requests: 1' \
    -H 'user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.132 Safari/537.36' \
    -H 'sec-fetch-mode: navigate' \
    -H 'sec-fetch-user: ?1' \
    -H 'accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3' \
    -H 'sec-fetch-site: none' \
    -H 'accept-encoding: gzip, deflate, br' \
    -H 'accept-language: en-US,en;q=0.9' \
    -H 'cookie: has_js=1; _hjid=618b076d-7ce1-4315-998e-e0d3f4fa7598; Display=american; OddsType=moneyline; geo_code=US-VA' \
    -H 'dnt: 1' \
    -H "if-none-match: W/\"${ts}-0-gzip\"" \
    --compressed \
    -o "${outfile}"
  sleep 10
done

