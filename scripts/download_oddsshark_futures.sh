#!/bin/bash

USER_AGENT='User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.132 Safari/537.36'

daytime=$(date +"%Y%m%dT%H%M")

BASEDIR=$(pwd)
OUTDIR=${BASEDIR}/odds/oddsshark/futures

datespec=$( date +"%Y%m%dT%H%M" )
curl "https://www.oddsshark.com/ncaaf/odds/futures" \
  -H "${USER_AGENT}" \
  --compressed \
  -o ${OUTDIR}/futures.html.${datespec}
