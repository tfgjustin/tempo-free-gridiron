#!/usr/bin/python3

import betlib
import csv
import json
import math
import sys


_FIELDS = ['GameID', 'Date', 'Total', 'OverPrice', 'UnderPrice', 'HomeSpread',
    'HomeSpreadPrice', 'AwaySpreadPrice', 'RegulationTotal', 'RegulationHomeLead',
    'HadOT', 'OTTotal', 'OTHomeLead'
]


def get_score_breakdown(segments):
  reg_home_points = 0
  reg_away_points = 0
  ot_away_points = 0
  ot_home_points = 0
  for segment in segments:
    if 'OT' != segment.get('segment', ''):
      reg_home_points += int(segment.get('home_points', 0))
      reg_away_points += int(segment.get('away_points', 0))
    else:
      ot_home_points += int(segment.get('home_points', 0))
      ot_away_points += int(segment.get('away_points', 0))
  return reg_home_points,reg_away_points,ot_home_points,ot_away_points


def game_has_results(game):
  segments = game.get('segments', [])
  if not segments:
    print('No results for %s' % game_id)
    return False
  for segment in segments:
    if 'OT' == segment.get('segment', ''):
      continue
    v = segment.get('home_points')
    if v is None:
      return False
    v = segment.get('away_points')
    if v is None:
      return False
  return True

def print_one_game(game, outtsv):
  # print(game)
  if not game_has_results(game):
    return
  outdict = {k: '' for k in _FIELDS}
  game_id = game.get('event_id')
  date,time,season = betlib.getDateTimeSeason(game['event_date'])
  segments = game.get('segments', [])
  if not segments:
    print('No results for %s' % game_id)
    return
  reg_home_points,reg_away_points,ot_home_points,ot_away_points = get_score_breakdown(segments)
  outdict['GameID'] = game_id
  outdict['Date'] = date
  outdict['Total'] = game.get('total', '')
  outdict['OverPrice'] = game.get('over_price', '')
  outdict['UnderPrice'] = game.get('under_price', '')
  outdict['HomeSpread'] = game.get('home_spread', '')
  outdict['HomeSpreadPrice'] = game.get('home_spread_price', '')
  outdict['AwaySpreadPrice'] = game.get('away_spread_price', '')
  outdict['RegulationTotal'] = reg_home_points + reg_away_points
  outdict['RegulationHomeLead'] = reg_home_points - reg_away_points
  outdict['HadOT'] = ot_home_points > 0 or ot_away_points > 0
  if outdict['HadOT']:
    outdict['OTTotal'] = outdict['RegulationTotal'] + ot_home_points + ot_away_points
    outdict['OTHomeLead'] = ot_home_points - ot_away_points
  outtsv.writerow(outdict)


def print_file(filename, outtsv):
  with open(filename, 'r') as f:
    try:
      data = json.load(f)
    except:
      print('Failed to parse JSON in %s' % (filename), file=sys.stderr)
      return
    for game in data:
      print_one_game(game, outtsv)
      continue
      date,time,season = betlib.getDateTimeSeason(game['event_date'])
      total_odds = dict()
      total_odds['spread'] = get_total_odds(game, 'spread_price')
      total_odds['totals'] = get_total_odds(game, 'price', teams=['over', 'under'])
      print_stats(filename, game, 'home', total_odds, outtsv)
      print_stats(filename, game, 'away', total_odds, outtsv)
      print_total_stats(filename, '/', date, season, game, betlib.OVER,
                        total_odds['spread'], outtsv)
      print_total_stats(filename, '/', date, season, game, betlib.UNDER,
                        total_odds['spread'], outtsv)


def main(argv):
  if len(argv) < 3:
    print('Usage: %s <out_tsv> <json0> [<json1> ... <jsonN>]' % (argv[0]))
    sys.exit(1)
  with open(argv[1], 'w') as outfile:
    tsvwriter = csv.DictWriter(outfile, fieldnames=_FIELDS, delimiter='\t')
    tsvwriter.writeheader()
    for f in argv[2:]:
      print_file(f, tsvwriter)


if __name__ == '__main__':
  main(sys.argv)
