#!/usr/bin/python3

import csv
import math
import operator
import sys

from collections import defaultdict
from operator import itemgetter

def load_game_ids(filename, game_ids):
  with open(filename, 'r') as infile:
    reader = csv.DictReader(infile)
    for row in reader:
      if 'GameID' not in row:
        print('Row missing GameID column')
        continue
      game_ids.add(row['GameID'])


def print_prediction(gid, row, do_swap, outfile):
  home_id = away_id = home_score = away_score = pct_home = None
  if do_swap:
    home_id = int(row['AwayTeamID']) + 1000
    home_score = float(row['PredAwayScore'])
    pct_home = 1000 - (10 * float(row['ProbHomeWins'].replace('%', '')))
    away_id = int(row['HomeTeamID']) + 1000
    away_score = float(row['PredHomeScore'])
  else:
    away_id = int(row['AwayTeamID']) + 1000
    away_score = float(row['PredAwayScore'])
    pct_home = int(10 * float(row['ProbHomeWins'].replace('%', '')))
    home_id = int(row['HomeTeamID']) + 1000
    home_score = float(row['PredHomeScore'])
  is_neutral = 0
  num_plays = 170
  # PREDICT,ALLDONE,20181201-1107-1674,0, 1107,25, 1674,30, 299, 165, 506,584
  print('PREDICT,ALLDONE,%s,%d,%5d,%2d,%5d,%2d,%4d,%4d' % (gid, is_neutral, home_id,
        home_score, away_id, away_score, pct_home, num_plays), file=outfile)


def transform_s_and_p(infilename, game_ids, outfilename):
  with open(infilename, 'r') as infile:
    with open(outfilename, 'w') as outfile:
      reader = csv.DictReader(infile)
      for row in reader:
        date = int(row['GameDate'])
        home_id = int(row['HomeTeamID'])
        away_id = int(row['AwayTeamID'])
        gid = '%d-%d-%d' % (date, 1000 + home_id, 1000 + away_id)
        if gid in game_ids:
          print_prediction(gid, row, False, outfile)
        else:
          gid = '%d-%d-%d' % (date, 1000 + away_id, 1000 + home_id)
          if gid in game_ids:
            print_predictions(gid, row, True, outfile)
          else:
            print('ERROR: Game (%d, %d, %d) not in summary' % (date,
                  1000 + home_id, 1000 + away_id))


if len(sys.argv) != 4:
  print('Usage: %s <summaries> <s_and_p_in> <s_and_p_out>' % (sys.argv[0]))
  sys.exit(1)

game_ids = set()
load_game_ids(sys.argv[1], game_ids)
transform_s_and_p(sys.argv[2], game_ids, sys.argv[3])
