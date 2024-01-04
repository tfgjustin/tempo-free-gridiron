#!/bin/bash

USER_AGENT='User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/76.0.3809.132 Safari/537.36'

BASEDIR="$(pwd)"
SCRIPTDIR="${BASEDIR}/scripts"
PRINT_LINES="${SCRIPTDIR}/print_oddsshark_lines.py"
PRINT_GAME="${SCRIPTDIR}/print_oddsshark_game.py"
GET_GAMES="${SCRIPTDIR}/download_oddsshark_games.sh"
PATCH_ODDS="${SCRIPTDIR}/patch_oddsshark.py"
RENAME_ODDS="${SCRIPTDIR}/rename_oddsshark.py"
ODDSDIR="${BASEDIR}/odds/oddsshark"
CSVDIR="${ODDSDIR}/csv"
HTMLDIR="${ODDSDIR}/html"
JSONDIR="${ODDSDIR}/json"

# Input files are of the pattern
# "${JSONDIR}/${current_season}/${current_season}-${week}.json.$1"

if [[ $# -lt 1 ]]
then
  echo "Usage: $0 <timestamp>"
  exit 1
fi

input_pattern="${JSONDIR}/*/*.json.$1"

current_season=$( date --date="$1" +"%Y" )
month=$( date --date="$1" +"%m" )
if [[ "${month}" == "01" ]]
then
  current_season=$(( $current_season - 1 ))
fi

mkdir -p "${CSVDIR}/${current_season}"
lines_tsv="${CSVDIR}/${current_season}/raw_lines.tsv.$1"
game_urls="${CSVDIR}/${current_season}/games.urls.$1"
events_tsv="${CSVDIR}/${current_season}/raw_events.tsv.$1"
raw_results_tsv="${CSVDIR}/${current_season}/raw_results.tsv.$1"
results_tsv="${CSVDIR}/${current_season}/results.tsv.$1"

# Print lines, per-game URLs, results, and events
${PRINT_LINES} "${lines_tsv}" "${game_urls}" "${raw_results_tsv}" "${events_tsv}" ${input_pattern}

# exit 0

# Rename the team names in the results
${RENAME_ODDS} "${raw_results_tsv}" "${results_tsv}"

# Get the files that we'll need to patch in
${GET_GAMES} "${game_urls}" "$1"

# Now parse all the HTML files
# ./scripts/print_oddsshark_game.py /dev/stdout odds/oddsshark/html/2019/*.html
patch_tsv="${CSVDIR}/${current_season}/patch.tsv.$1"
html_pattern="${HTMLDIR}/${current_season}/*.html.$1"
if compgen -G "${html_pattern}" > /dev/null
then
  ${PRINT_GAME} "${patch_tsv}" ${html_pattern}
#else
#  echo "No HTML files to process"
fi
touch "${patch_tsv}"

# Now merge the patched TSV with the main output
# ./scripts/patch_oddshark.py <main_tsv> <patch_tsv> <out_tsv>
merged_tsv="${CSVDIR}/${current_season}/merged.tsv.$1"
${PATCH_ODDS} "${lines_tsv}" "${patch_tsv}" "${merged_tsv}"

all_lines_tsv="${CSVDIR}/${current_season}/all_lines.tsv.$1"
${RENAME_ODDS} "${merged_tsv}" "${all_lines_tsv}"
