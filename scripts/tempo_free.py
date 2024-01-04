#!/usr/bin/python

import csv
import os

_PY_EXP = 2.66

_YEAR_TO_WEEK = {
  2000:   14,
  2001:   67,
  2002:  123,
  2003:  175,
  2004:  227,
  2005:  280,
  2006:  332,
  2007:  384,
  2008:  437,
  2009:  489,
  2010:  541,
  2011:  593,
  2012:  645,
  2013:  696,
  2014:  748,
  2015:  800,
  2016:  852,
  2017:  906,
  2018:  958,
  2019:  1010
}

_YEARS = sorted(_YEAR_TO_WEEK.keys())
_CURRENT_SEASON = _YEARS[-1]
_DATADIR = 'data'
_INPUTDIR = 'input'
_ID2NAME = os.path.join(_DATADIR, 'id2name.txt')
_ID2TWITTER = os.path.join(_DATADIR, 'id2twitter.csv')
_NAMEMAP = os.path.join(_DATADIR, 'names.txt')
_FULLNAMEMAP = os.path.join(_DATADIR, 'full_names.txt')
_CONFFILE = os.path.join(_DATADIR, 'conferences.txt')
_SUMMARYFILE = os.path.join(_INPUTDIR, 'summaries.csv')
_LEADFILE = os.path.join(_DATADIR, 'leads.txt')
_POSITIONFILE = os.path.join(_DATADIR, 'field_position.csv')
_COLORFILE = os.path.join(_DATADIR, 'teamColors.txt')
_ODDSSHARK_NAMES = os.path.join(_DATADIR, 'oddsshark2ncaa_names.tsv')

def load_id_to_name(id_to_name):
  with open(_ID2NAME, 'r') as infile:
    reader = csv.reader(infile)
    for row in reader:
      id_to_name[row[0]] = row[1]

def load_name_to_id(name_to_id):
  id_to_name = dict()
  load_id_to_name(id_to_name)
  for k,v in id_to_name.items():
    name_to_id[v] = k

def load_oddsshark_names(names):
  with open(_ODDSSHARK_NAMES, 'r') as infile:
    reader = csv.reader(infile, delimiter='\t')
    for row in reader:
      names[row[0]] = row[1]

def load_short_names(ncaa_to_name, name_to_ncaa=None):
  with open(_NAMEMAP, 'r') as infile:
    reader = csv.reader(infile)
    for row in reader:
      if ncaa_to_name is not None:
        ncaa_to_name[row[0]] = row[1]
      if name_to_ncaa is not None:
        name_to_ncaa[row[1]] = row[0]

def load_results(results):
  with open(_SUMMARYFILE, 'r') as infile:
    for line in infile:
      parts = line.strip().split(',')
      results[parts[2]] = parts

def pythag(offense, defense, exponent=_PY_EXP):
  return 1.0 / (1.0 + ((defense / offense) ** exponent))

def log5(team_a, team_b):
  num = team_a - (team_a * team_b)
  den = team_a + team_b - (2 * team_a * team_b)
  return num / den
