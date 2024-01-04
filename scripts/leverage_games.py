#!/usr/bin/python

import csv
import math
import operator
import re
import sys

WIN='y'
CFP_Y=WIN
LOSS='n'
CFP_N=LOSS

ID_NAME = 'data/id2name.txt'
NAMES = 'data/names.txt'

def is_important_game(before, after):
  if after > (before * 2):
    return True
  if after - before > 0.01:
    return True
  if (1 - after) < ((1 - before) / 2):
    return True
  return False
 

if len(sys.argv) != 5:
  print 'Usage: %s <team_id> <simulation_file> <predict_csv> <ranking_csv>' % (sys.argv[0])
  sys.exit(1)

name2id = dict()
with open(ID_NAME, 'rb') as idfile:
  reader = csv.reader(idfile)
  for row in reader:
    name2id[row[1]] = row[0]

id2name = dict()
with open(NAMES, 'rb') as namefile:
  reader = csv.reader(namefile)
  for row in reader:
    if row[0] not in name2id:
      continue
    id2name[name2id[row[0]]] = row[1]

GAMES = []
MADE = []
MISSED = []
scenarios = []
with open(sys.argv[2], 'rb') as csvfile:
  reader = csv.reader(csvfile, delimiter=',')
  for row in reader:
    if row[0] == 'RemainGames':
      GAMES = row[12:]
    elif row[0] == 'SeasonResult':
      scenarios.append(','.join([row[0]] + row[2:6] + row[12:]))
      missed = True
      for pos in xrange(2, 6):
        if row[pos] == sys.argv[1]:
          missed = False
          MADE.append(row[12:])
          break
      if missed:
        MISSED.append(row[12:])

homeodds = dict()
with open(sys.argv[3], 'rb') as csvfile:
  reader = csv.reader(csvfile, delimiter=',')
  for row in reader:
    if row[0] != 'PREDICT':
      continue
    if row[1] != 'ALLDONE':
      continue
    gid = row[2]
    odds = float(row[8]) / 1000
    homeodds[gid] = odds

max_week = 0
ranking = dict()
with open(sys.argv[4], 'rb') as csvfile:
  reader = csv.reader(csvfile, delimiter=',')
  for row in reader:
    if row[0] != 'RANKING':
      continue
    if int(row[1]) > max_week:
      ranking = dict()
    ranking[row[2]] = float(row[3])

pattern = re.compile(r'\D')

COUNTS = dict()
for game_num in xrange(0, len(GAMES)):
  gid = GAMES[game_num]
  if pattern.findall(gid.replace('-', '')):
    # Conference Championship
    continue
  COUNTS[gid] = dict()
  home_tid = gid[9:13]
  for season in MADE:
    # For each season in which this team made the playoffs ...
    winner = season[game_num][:4]
    if winner == home_tid:
      # ... if the home team was the winner of the game ...
      if WIN not in COUNTS[gid]:
        COUNTS[gid][WIN] = dict()
      # ... increment (gameID)(win=y)(cfp=y)
      if CFP_Y in COUNTS[gid][WIN]:
        COUNTS[gid][WIN][CFP_Y] += 1
      else:
        COUNTS[gid][WIN][CFP_Y] = 1
    else:
      # ... if the home team was the loser of the game ...
      if LOSS not in COUNTS[gid]:
        COUNTS[gid][LOSS] = dict()
      # ... increment (gameID)(win=n)(cfp=y)
      if CFP_Y in COUNTS[gid][LOSS]:
        COUNTS[gid][LOSS][CFP_Y] += 1
      else:
        COUNTS[gid][LOSS][CFP_Y] = 1
  for season in MISSED:
    winner = season[game_num][:4]
    if winner == home_tid:
      if WIN not in COUNTS[gid]:
        COUNTS[gid][WIN] = dict()
      if LOSS in COUNTS[gid][WIN]:
        COUNTS[gid][WIN][CFP_N] += 1
      else:
        COUNTS[gid][WIN][CFP_N] = 1
    else:
      if LOSS not in COUNTS[gid]:
        COUNTS[gid][LOSS] = dict()
      if CFP_N in COUNTS[gid][LOSS]:
        COUNTS[gid][LOSS][CFP_N] += 1
      else:
        COUNTS[gid][LOSS][CFP_N] = 1

for gid,stats in COUNTS.iteritems():
  if WIN not in stats:
    stats[WIN] = dict()
  if CFP_Y not in stats[WIN]:
    stats[WIN][CFP_Y] = 0
  if CFP_N not in stats[WIN]:
    stats[WIN][CFP_N] = 0
  if LOSS not in stats:
    stats[LOSS] = dict()
  if CFP_Y not in stats[LOSS]:
    stats[LOSS][CFP_Y] = 0
  if CFP_N not in stats[LOSS]:
    stats[LOSS][CFP_N] = 0

METRIC = dict()
num_wins = len(MADE)
num_losses = len(MISSED)
num_sims = num_wins + num_losses

print '# Team %s #Made: %4d #Missed: %4d' % (sys.argv[1], num_wins, num_losses)

pct_overall = (1.0 * num_wins) / num_sims

leverage = dict()
should_home_win = dict()
for gid,stats in COUNTS.iteritems():
  home_pct = 0.5
  if gid in homeodds:
    home_pct = homeodds[gid]
  else:
    print 'Game %s not in prediction file' % gid
    continue
  abs_effect = 0.0
  abs_exp_effect = 0.0
  num_game_wins = stats[WIN][WIN] + stats[WIN][LOSS]
  pct_with_home_win = (1.0 * stats[WIN][WIN]) / num_game_wins
  abs_exp_effect = abs(pct_with_home_win - pct_overall) * home_pct
  abs_effect += math.fabs(pct_overall - pct_with_home_win)
  num_game_loss = stats[LOSS][WIN] + stats[LOSS][LOSS]
  pct_with_home_loss = (1.0 * stats[LOSS][WIN]) / num_game_loss
  abs_effect += math.fabs(pct_overall - pct_with_home_loss)
  abs_exp_effect += abs(pct_with_home_loss - pct_overall) * (1 - home_pct)
  print 'Game %s %s %.4f %.4f %.4f %.4f %.4f' % (sys.argv[1], gid, pct_overall,
    pct_with_home_win, pct_with_home_loss, abs_effect, abs_exp_effect)
  leverage[gid] = abs_exp_effect
  should_home_win[gid] = False
  if pct_with_home_win > pct_overall:
    should_home_win[gid] = True

games = []
all_scenarios = scenarios
for gid,effect in sorted(leverage.items(), key=operator.itemgetter(1), reverse=True):
  if gid not in should_home_win:
    print 'GID %s not in should_home_win' % (gid)
    continue
  home_id = gid[9:13]
  away_id = gid[14:18]
  desired = None
  if should_home_win[gid]:
    desired = ',' + home_id + 'd' + away_id + ','
  else:
    desired = ',' + away_id + 'd' + home_id + ','
  scenarios = filter(lambda v: desired in v, scenarios)
  if len(scenarios) < 100:
#    print 'Not enough scenarios with %s' % (desired)
    break
#  print desired + ': ' + str(len(scenarios))
  games.append(gid)

remain_scenarios = all_scenarios
team_id = ',' + sys.argv[1] + ','
last_odds = pct_overall
print 'Team %s %-18s %5.1f %s' % (sys.argv[1], id2name[sys.argv[1]], 100 * pct_overall, '-'*45)
for gid in sorted(games):
  date = gid[0:8]
  home_id = gid[9:13]
  away_id = gid[14:18]
  desired = None
  readable = None
  if should_home_win[gid]:
    desired = ',' + home_id + 'd' + away_id + ','
    readable = '%-20s def %-20s' % (id2name[home_id], id2name[away_id])
  else:
    desired = ',' + away_id + 'd' + home_id + ','
    readable = '%-20s def %-20s' % (id2name[away_id], id2name[home_id])
  remain_scenarios = filter(lambda v: desired in v, remain_scenarios)
  num_success = len(filter(lambda v: team_id in v, remain_scenarios))
  odds = float(num_success) / len(remain_scenarios)
  if is_important_game(last_odds, odds):
    print 'Team %s %s %5.1f %s' % (sys.argv[1], gid, 100 * odds, readable)
  last_odds = odds

 

#for gid in GAMES:
#  if num_wins > 0 and key in win_contrib:
#    # What percentage of the wins did they contribute to?
#    win_contrib[key] /= (1.0 * num_wins)
#    v = ((1 - win_contrib[key]) ** 2)
#    METRIC[key] = v
#  else:
#    METRIC[key] = 1
#  if num_losses > 0 and key in loss_contrib:
#    loss_contrib[key] /= (1.0 * num_losses)
#    v = ((1 - loss_contrib[key]) ** 2)
#    if key in METRIC:
#      METRIC[key] += v
#    else:
#      METRIC[key] = v
#  else:
#    METRIC[key] += 1
#  if key in METRIC:
#    METRIC[key] **= (1. / 2)
#    METRIC[key] = 1 - METRIC[key]
#
#home_winners = sorted(METRIC.items(), key=operator.itemgetter(1), reverse=True)
#c=0
#for home_winner in home_winners:
#  print '%14s %.5f' % (home_winner[0], home_winner[1])
#  if c >= 2000:
#    break
#  c += 1
