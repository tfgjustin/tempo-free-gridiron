#!/usr/bin/python

import math
import sys

MONEYLINE = 'Money'
SPREAD = 'Spread'
TOTAL = 'Total'
OVER = 'Over'
UNDER = 'Under'
VALID_BET_TYPES = set([ MONEYLINE, SPREAD, OVER, UNDER, TOTAL ])

def isValidBetType(bet_type):
  return bet_type is not None and bet_type in VALID_BET_TYPES

def lineToOdds(line):
  line = float(line)
  if line < 0:
    return line / (line - 100.0)
  else:
    return 100. / (line + 100.)

def oddsToLine(odds):
  if odds <= 1e-8:
    return sys.maxsize
  elif (1.0 - odds) <= 1e-8:
    return -sys.maxsize - 1
  if odds < 0.5:
    # This will be positive
    return (100 / odds) - 100
  else:
    # This will be negative
    return (100 * odds) / (odds - 1)

def betReturn(line):
  line = float(line)
  if line > 0:
    return line / 100.0
  else:
    return 100.0 / -line

def kellyCriterionLine(probWin, line):
  probLoss = 1 - probWin
  br = betReturn(line)
  k = ((probWin * (br + 1)) - 1) / br
  if k < 0:
    return 0
  return k

def kellyCriterionImpliedOdds(probWin, impliedOdds):
  line = oddsToLine(impliedOdds)
  return kellyCriterionLine(probWin, line)

def kellyCriterion(probWin, line=None, impliedOdds=None):
  if line is None:
    if impliedOdds is None:
      return None
    return kellyCriterionImpliedOdds(probWin, impliedOdds)
  elif impliedOdds is not None:
    # Both are None (??)
    return None
  else:
    return kellyCriterionLine(probWin, line)

def getDateTimeSeason(date_str):
  # Input: YYYY-mm-DD HH:MM:SS
  # E.g.,
  # 2014-11-04 15:30:00
  # 2015-01-08 20:00:00
  # Return: YYYYmmDD,YYYY
  # E.g.,
  # 20141104,2014
  # 20150108,2015
  date = date_str[:10].replace('-', '')
  time = date_str[11:16].replace(':', '')
  season = math.floor((int(date) - 200) / 10000)
  return date,time,str(season)

def dateToSeasonWeek(date):
  # Input: YYYY-mm-DD[ HH:MM:SS]
  return '1'
