#!/usr/bin/python3
# Output format
# Season,Metric,Team,Odds,Line
#
# Metrics to output:
# Prob of making it ot the playoffs
# Prob of winning a conference
# Prob of winning X games

import betlib
import csv
import operator
import sys

from collections import defaultdict
from operator import itemgetter

def print_playoff_odds(infile, season):
  infile.seek(0)
  reader = csv.DictReader(infile)
  in_playoff_fields = []
  in_playoff_fields.extend([x for x in reader.fieldnames if '-Rank0' in x])
  if not in_playoff_fields:
    print('No playoff fields')
    return
  in_playoff_fields.sort()
  print(in_playoff_fields)
  rowcount = 0
  playoff_count = defaultdict(int)
  for row in reader:
    rowcount += 1
    for field in in_playoff_fields[0:4]:
      if row[field] == 'xxxx':
        continue
      team_id = row[field]
      playoff_count[team_id] += 1
  if not rowcount:
    print('No rows found')
    return
  for team_id,count in playoff_count.items():
    line = betlib.oddsToLine(float(count) / rowcount)
    print('%d,Playoff,%s,%.6f,%+d' % (season, team_id, float(count) / rowcount, line))


def print_conf_champ_odds(infile, season):
  infile.seek(0)
  reader = csv.DictReader(infile)
  conf_champ_fields = []
  conf_champ_fields.extend([x for x in reader.fieldnames if '-Champs-' in x])
  conf_champ_fields.sort()
  rowcount = 0
  # [conference][tema_id] => count
  champ_count = dict()
  for row in reader:
    rowcount += 1
    for conf_tag in conf_champ_fields:
      conf = '-'.join(conf_tag.split('-')[2:])
      if conf not in champ_count:
        champ_count[conf] = defaultdict(int)
      team_id = row[conf_tag]
      champ_count[conf][row[conf_tag]] += 1
  if not rowcount:
    return
  for conf,team_dict in champ_count.items():
    conf_printable = conf.replace(' ', '_')
    for team_id,count in team_dict.items():
      line = betlib.oddsToLine(float(count) / rowcount)
      print('%s,Champ-%s,%s,%.6f,%+d' % (season, conf_printable, team_id,
                                         float(count) / rowcount, line))


def print_win_gt_odds(infile, season):
  infile.seek(0)
  reader = csv.DictReader(infile)
  win_fields = []
  win_fields.extend([x for x in reader.fieldnames if '-Wins-' in x])
  win_fields.sort()
  win_counts = dict()
  rowcount = 0
  for row in reader:
    rowcount += 1
    for win_tag in win_fields:
      team_id = win_tag.split('-')[-1]
      if team_id not in win_counts:
        win_counts[team_id] = defaultdict(int)
      win_counts[team_id][int(row[win_tag])] += 1 
  if not rowcount:
    return
  for team_id,counts in win_counts.items():
    total_wins = 0
    for wins,count in sorted(counts.items(), key=itemgetter(0)):
      line = betlib.oddsToLine((rowcount - float(total_wins)) / rowcount)
      print('%s,AtOrOver-%02d,%s,%.6f,%+d' % (
        season, wins, team_id, (rowcount - float(total_wins)) / rowcount, line))
      total_wins += count
      line = betlib.oddsToLine(float(total_wins) / rowcount)
      print('%s,AtOrUnder-%02d,%s,%.6f,%+d' % (
        season, wins, team_id, (float(total_wins) / rowcount), line))



def get_season(infile):
  infile.seek(0)
  reader = csv.DictReader(infile)
  in_playoff = []
  in_playoff.extend([x for x in reader.fieldnames if 'Rank' in x])
  return int(in_playoff[0][0:4])


if len(sys.argv) != 2:
  print('Usage: %s <summary_file>' % (sys.argv[0]))
  sys.exit(1)

with open(sys.argv[1], 'r') as infile:
  season = get_season(infile)
  print_playoff_odds(infile, season)
  print_conf_champ_odds(infile, season)
  print_win_gt_odds(infile, season)
sys.exit(0)
