#!/usr/bin/python3

import betlib
import csv
import json
import math
import sys

_BASE_URL = 'https://www.oddsshark.com'
_OTHER = { 'home': 'away', 'away': 'home' }
_FIELDS = ['Season', 'Week', 'Date', 'GameID', 'LineType', 'TeamOrGame',
           'LineValue', 'LinePrice', 'TotalProb', 'DidWin']
_EID_KEY = 'event_id'
_WEEK_KEY = 'week'


def abbr_key(team):
  return '%s_abbreviation' % team


def concat_team_names(game):
  return '%s:%s' % (game[abbr_key('home')], game[abbr_key('away')])


def get_total(game):
  sum = 0
  for team in _OTHER.keys():
    score_key = '%s_score' % team
    if score_key not in game or game[score_key] is None:
      return None
    sum += int(game[score_key])
  if sum == 0:
    return None
  return sum


def get_did_win(game, team, line_type, value=None):
  them = _OTHER[team]
  us_score_key = '%s_score' % team
  them_score_key = '%s_score' % them
  if us_score_key not in game or game[us_score_key] is None:
    return False
  if them_score_key not in game or game[them_score_key] is None:
    return False
  us_score = int(game[us_score_key])
  them_score = int(game[them_score_key])
  if line_type == betlib.MONEYLINE:
    return us_score > them_score
  elif line_type == betlib.SPREAD and value and value != '_':
    return (us_score + float(value)) > them_score
  elif line_type == betlib.OVER:
    total = game.get('total', None)
    if total:
      return (us_score + them_score) > float(total)
  elif line_type == betlib.UNDER:
    total = game.get('total', None)
    if total:
      return (us_score + them_score) < float(total)
  return False


def this_team_margin(game, team):
  total = get_total(game)
  if total is None:
    return None
  them = _OTHER[team]
  us_score_key = '%s_score' % team
  them_score_key = '%s_score' % them
  if us_score_key not in game or game[us_score_key] is None:
    return None
  if them_score_key not in game or game[them_score_key] is None:
    return None
  us_score = int(game[us_score_key])
  them_score = int(game[them_score_key])
  return us_score - them_score


def get_total_odds(game, linetype, teams=['away', 'home']):
  sum = 0.0
  for t in teams:
    k = '%s_%s' % (t, linetype)
    if k not in game or not game[k]:
      return '_'
    sum += betlib.lineToOdds(game[k])
  return '%.3f' % sum


def print_spread_stats(filename, link, date, season, game, team,
                       total_spread_odds, outtsv, game_urls, results_writer):
  spread_key = '%s_spread' % team
  spread = game.get(spread_key, '_')
  spread_price_key = '%s_spread_price' % team
  spread_price = game.get(spread_price_key, '_')
  if spread == '_' or spread_price == '_':
    if len(link) > 1:
      print('FILE %s: No spread for game %s; try patching in from\n%s%s' % (
            filename, game[_EID_KEY], _BASE_URL, link),
            file=game_urls)
    else:
      print('FILE %s: No spread for game %s and no game file' % (filename, game[_EID_KEY]),
            file=sys.stdout)
  outdict = dict({k:'_' for k in _FIELDS})
  outdict['Date'] = date
  outdict['Season'] = season
  outdict['DidWin'] = get_did_win(game, team, 'Spread', value=spread)
  outdict['Week'] = game[_WEEK_KEY]
  if outdict['Week'] == 'P':
    outdict['Week'] = '99'
  outdict['GameID'] = game[_EID_KEY]
  outdict['LineType'] = 'Spread'
  outdict['TeamOrGame'] = game[abbr_key(team)]
  outdict['LineValue'] = spread
  outdict['LinePrice'] = spread_price
  outdict['TotalProb'] = total_spread_odds
  outtsv.writerow(outdict)


def print_ml_stats(filename, link, date, season, game, team, total_ml_odds,
                   outtsv, game_urls, results_writer):
  line_key = '%s_money_line' % team
  line_price = '_'
  if line_key in game and game[line_key]:
    line_price = game[line_key]
  elif len(link) > 1:
    print('FILE %s: No moneyline for game %s; try patching in from\n%s%s' % (
          filename, game[_EID_KEY], _BASE_URL, link),
          file=game_urls)
    return
  else:
    print('FILE %s: No moneyline or individual page for game %s' % (filename, game[_EID_KEY]),
          file=sys.stderr)
    return
  outdict = dict({k:'_' for k in _FIELDS})
  outdict['Date'] = date
  outdict['Season'] = season
  outdict['DidWin'] = get_did_win(game, team, 'Money')
  outdict['Week'] = game[_WEEK_KEY]
  if outdict['Week'] == 'P':
    outdict['Week'] = '99'
  outdict['GameID'] = game[_EID_KEY]
  outdict['LineType'] = 'Money'
  outdict['TeamOrGame'] = game[abbr_key(team)]
  outdict['LinePrice'] = line_price
  outdict['TotalProb'] = total_ml_odds
  outtsv.writerow(outdict)
  # results_writer.writerow(['GameID', 'LineType', 'TeamOrGame', 'Outcome' ])
  margin = this_team_margin(game, team)
  if margin is not None:
    results_writer.writerow(
      [game[_EID_KEY], 'Money', outdict['TeamOrGame'], margin > 0]
    )
    results_writer.writerow(
      [game[_EID_KEY], 'Spread', outdict['TeamOrGame'], margin]
    )


def print_total_stats(filename, link, date, season, game, side, total_ml_odds,
                      outtsv, game_urls, results_writer):
  line_key = '%s_price' % side.lower()
  line_price = '_'
  if line_key in game and game[line_key]:
    line_price = game[line_key]
  elif len(link) > 1:
    print('FILE %s: No totals for game %s; try patching in from\n%s%s [%d]' % (
          filename, game[_EID_KEY], _BASE_URL, link, len(link)),
          file=game_urls)
    return
  else:
#    print('FILE %s: No totals or individual page for game %s [%d]' % (filename, game[_EID_KEY], len(link)),
#          file=sys.stderr)
    return
  line_value = game.get('total', '_')
  if not line_value:
    line_value = '_'
  team_names = concat_team_names(game)
  outdict = dict({k:'_' for k in _FIELDS})
  outdict['Date'] = date
  outdict['Season'] = season
  outdict['DidWin'] = get_did_win(game, 'home', side)
  outdict['Week'] = game[_WEEK_KEY]
  if outdict['Week'] == 'P':
    outdict['Week'] = '99'
  outdict['GameID'] = game[_EID_KEY]
  outdict['LineType'] = side
  # TODO: Update this to be the name-sorted teams concatenated with ':'
  outdict['TeamOrGame'] = team_names
  outdict['LineValue'] = line_value
  outdict['LinePrice'] = line_price
  outdict['TotalProb'] = total_ml_odds
  outtsv.writerow(outdict)
  # results_writer.writerow(['GameID', 'LineType', 'TeamOrGame', 'Outcome' ])
  total = get_total(game)
  if total is not None:
    results_writer.writerow([game[_EID_KEY], 'Total', team_names, total ])


def print_stats(filename, game, team, total_odds, outtsv, game_urls,
                results_writer):
  matchup_key = 'matchup_link'
  link = ''
  if matchup_key in game:
    link = game[matchup_key]
  date_key = 'event_date'
  for h in [_WEEK_KEY, _EID_KEY, date_key, abbr_key(team)]:
    if h not in game or not game[h]:
      print('%s: Missing %s in game %s data; try loading from\n%s%s' % (
            filename, h, game[_EID_KEY], _BASE_URL, link),
            file=sys.stderr)
      return
  date,time,season = betlib.getDateTimeSeason(game[date_key])
  print_ml_stats(filename, link, date, season, game, team,
                 total_odds['money_line'], outtsv, game_urls, results_writer)
  print_spread_stats(filename, link, date, season, game, team,
                     total_odds['spread'], outtsv, game_urls, results_writer)


def print_event(game, date, time, events_tsv):
  # [ 'GameID', 'DateTime', 'Home', 'Away' ]
  game_id = game.get('event_id')
  date_time = date + 'T' + time
  home_team = game[abbr_key('home')]
  away_team = game[abbr_key('away')]
  events_tsv.writerow([game_id, date_time, home_team, away_team])


def print_file(filename, outtsv, game_urls, results_tsv, events_tsv):
  with open(filename, 'r') as f:
    try:
      data = json.load(f)
    except:
      print('Failed to parse JSON in %s' % (filename), file=sys.stderr)
      return
    for game in data:
      date,time,season = betlib.getDateTimeSeason(game['event_date'])
      print_event(game, date, time, events_tsv)
      total_odds = dict()
      total_odds['money_line'] = get_total_odds(game, 'money_line')
      total_odds['spread'] = get_total_odds(game, 'spread_price')
      total_odds['totals'] = get_total_odds(game, 'price', teams=['over', 'under'])
      print_stats(filename, game, 'home', total_odds, outtsv, game_urls,
                  results_tsv)
      print_stats(filename, game, 'away', total_odds, outtsv, game_urls,
                  results_tsv)
      print_total_stats(filename, '/', date, season, game, betlib.OVER,
                        total_odds['spread'], outtsv, game_urls, results_tsv)
      print_total_stats(filename, '/', date, season, game, betlib.UNDER,
                        total_odds['spread'], outtsv, game_urls, results_tsv)


def main(argv):
  if len(argv) < 6:
    print('Usage: %s <rawlinestsv> <game_urls> <resultstsv> <events_tsv> <json0> [<json1> ... <jsonN>]' % (argv[0]))
    sys.exit(1)
  with open(argv[1], 'w') as outfile:
    tsvwriter = csv.DictWriter(outfile, fieldnames=_FIELDS, delimiter='\t')
    tsvwriter.writeheader()
    with open(argv[2], 'w') as games_url_file:
      with open(argv[3], 'w') as results_file:
        results_writer = csv.writer(results_file, delimiter='\t')
        results_writer.writerow(['GameID', 'LineType', 'TeamOrGame', 'Outcome' ])
        with open(argv[4], 'w') as events_file:
          events_writer = csv.writer(events_file, delimiter='\t')
          events_writer.writerow(['GameID', 'DateTime', 'Home', 'Away', 'Location'])
          for f in argv[5:]:
            print_file(f, tsvwriter, games_url_file, results_writer, events_writer)


if __name__ == '__main__':
  main(sys.argv)
