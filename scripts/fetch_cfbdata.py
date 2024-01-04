#!/usr/bin/python3

import csv
import datetime
import json
import os
import requests
import time

_CACHE_DIR='/tmp/'
_BASE_URL='https://api.collegefootballdata.com'
_HEADERS = {'accept': 'application/json'}
_MAX_CACHE_AGE_SECS = 3600  # One hour
_EPOCH_START_TIME = datetime.datetime(2000, 8, 23, 0, 0, 0)
_NORMALIZE_TIME = datetime.timedelta(hours=8)
_CFBDATA_IDS_CSV = 'data/cfbdata_ids.csv'
_ID2NAME_TXT = 'data/id2name.txt'
_NCAA_CONFERENCES = 'data/conferences.csv'
_SEASON = '2019'


def IsCacheValid(path):
  try:
    statinfo = os.stat(path)
    return statinfo.st_mtime + _MAX_CACHE_AGE_SECS > time.time()
  except:
    return False


def MakeFilename(path, args):
  encoded = '-'.join(['%s=%s' % (k, args[k]) for k in sorted(args.keys())])
  safe_path = path.replace('/', '_')
  return _CACHE_DIR + safe_path + '-' + encoded + '.json'


def FetchData(path, args):
  cache_output = MakeFilename(path, args)
  url = _BASE_URL + path
  req = requests.get(url=url, headers=_HEADERS, params=args)
  if req.status_code != requests.codes.ok:
    req.raise_for_status()
  WriteCache(path, args, req.text)
  return req.text


def LoadCache(path, args):
  filename = MakeFilename(path, args)
  print('Checking filename %s' % (filename))
  if not IsCacheValid(filename):
    print('Cache %s is either missing or has timed out' % (filename))
    return None
  data = None
  try:
    with open(filename, 'r') as infile:
      data = infile.read()
    print('Read %d bytes from %s' % (len(data), filename))
  except:
    print('No such file %s' % (filename))
  return data


def WriteCache(path, args, data):
  filename = MakeFilename(path, args)
  print('Writing %d bytes to %s' % (len(data), filename))
  with open(filename, 'w') as outfile:
    outfile.write(data)


def IsMissingParams(path, params, required_params):
  missing = []
  for p in required_params:
    if p not in params:
      missing.append(p)
  if missing:
    print('Request %s is missing params [%s]' % (path, ', '.join(missing)))
    return True
  return False


def Get(path, params, required_params):
  if IsMissingParams(path, params, required_params):
    return None
  data = LoadCache(path, params)
  if data is None:
    data = FetchData(path, params)
    if data is None:
      return None
  return json.loads(data)


# Need to get both regular and postseason games
def GetGames(params):
  return Get('/games', params, ['year', 'seasonType'])


def GetGamesTeams(params):
  return Get('/games/teams', params, ['year', 'seasonType', 'week'])


def GetDrives(params):
  return Get('/drives', params, ['year', 'seasonType'])


def DateToWeek(date_str):
  try:
    dt = datetime.datetime.strptime(date_str, '%Y-%m-%dT%H:%M:%S.000Z')
  except:
    print('Invalid timestamp: %s' % (date_str))
    return None
#  print(dt)
  td = dt - _EPOCH_START_TIME - _NORMALIZE_TIME
  return int(td.days / 7)


def StartTimeToDate(date_str):
  try:
    dt = datetime.datetime.strptime(date_str, '%Y-%m-%dT%H:%M:%S.000Z')
  except:
    print('Invalid timestamp: %s' % (date_str))
    return None
  norm_date = dt - _NORMALIZE_TIME
#  print(norm_date)
  return norm_date.strftime('%Y%m%d')


def LoadIdentifiers(id2name, name2id):
  with open(_CFBDATA_IDS_CSV, 'r') as infile:
    csvreader = csv.reader(infile)
    for row in csvreader:
      identifier = row[0]
      name = row[1]
      id2name[identifier] = name
      name2id[name] = identifier


def LoadNcaaIdentifiers(id2name, name2id):
  with open(_ID2NAME_TXT, 'r') as infile:
    csvreader = csv.reader(infile)
    for row in csvreader:
      identifier = row[0]
      name = row[1]
      id2name[identifier] = name
      name2id[name] = identifier


def LookupName(team_name, name2id):
  if team_name not in name2id:
    print('TeamName %s UNKNOWN' % (team_name))
    return None
  return name2id[team_name]


def LookupId(team_id, id2name):
  if team_id not in id2name:
    print('TeamId %s UNKNOWN' % (team_id))
    return None
  return id2name[team_id]


def TeamHasNoConference(team_name, conference):
  _BAD_DATA = ('Liberty', 'New Mexico State')
  if team_name in _BAD_DATA:
    return False
  return conference is None


def GetSite(game, home_name):
  if 'neutral_site' in game and game['neutral_site']:
    return 'NEUTRAL'
  return home_name


def GetStat(game, homeAway, category):
  if 'teams' not in game:
#    print('No teams')
    return None
  for team in game['teams']:
    if 'homeAway' not in team or team['homeAway'] != homeAway:
#      print('No home/away match for %s' % (homeAway))
      continue
#    print('Home/away match')
    if 'stats' not in team:
#      print('No team stats')
      continue
    for stat in team['stats']:
      if 'category' not in stat or stat['category'] != category:
#        print('No category match')
        continue
      if 'stat' in stat:
        return stat['stat']
#      print('Stat is missing')
  return None


def PrintGame(game, stats, ncaa_id2name, cfb_name2id):
  if TeamHasNoConference(game['home_team'], game['home_conference']):
    print('No conference for %s' % (game['home_team']))
    return
  if TeamHasNoConference(game['away_team'], game['away_conference']):
    print('No conference for %s' % (game['away_team']))
    return
  home_id = LookupName(game['home_team'], cfb_name2id)
  away_id = LookupName(game['away_team'], cfb_name2id)
  if home_id is None or away_id is None:
    print('Names: Cannot find one of "%s" or "%s"' % (game['home_team'], game['away_team']))
    return
  ncaa_home_name = LookupName(home_id, ncaa_id2name)
  ncaa_away_name = LookupName(away_id, ncaa_id2name)
  if ncaa_home_name is None or ncaa_away_name is None:
    print('Ids: cannot find one of "%s" or "%s"' % (home_id, away_id))
    return
  site = GetSite(game, ncaa_home_name)
  game_id = '%s-%s-%s' % (StartTimeToDate(game['start_date']), home_id, away_id)
  homeTotalYards = GetStat(stats, 'home', 'totalYards')
  awayTotalYards = GetStat(stats, 'away', 'totalYards')
  game_line = '%d,%s,%s,%d,%s,%s,%s,%d,%d' % (0, home_id, ncaa_home_name,
    game['home_points'], away_id, ncaa_away_name, game['away_points'],
    int(homeTotalYards), int(awayTotalYards))
  print('%d,%s,%s,%s,%s' % (DateToWeek(game['start_date']), game_id[:8],
    game_id, site, game_line))
  print(game)
  print() 


def GetStatsForGame(game, games_teams):
  game_id = game['id']
  for game_stats in games_teams:
    if game_stats['id'] == game_id:
      return game_stats
  return None


#### Begin main
id2name = dict()
name2id = dict()
LoadIdentifiers(id2name, name2id)

ncaa_id2name = dict()
ncaa_name2id = dict()
LoadNcaaIdentifiers(ncaa_id2name, ncaa_name2id)

regular_games = GetGames({'year': _SEASON, 'seasonType': 'regular'})
regular_games_teams = GetGamesTeams(
    {'year': _SEASON, 'seasonType': 'regular', 'week': 1}
  )
postseason_games = GetGames({'year': _SEASON, 'seasonType': 'postseason'})
postseason_drives = GetDrives({'year': _SEASON, 'seasonType': 'postseason'})
postseason_games_teams = GetGamesTeams(
    {'year': _SEASON, 'seasonType': 'postseason', 'week': 1}
  )

for game in regular_games:
  stats = GetStatsForGame(game, regular_games_teams)
  if not stats:
    print('No stats for game %s' % (game['id']))
    continue
  PrintGame(game, stats, ncaa_id2name, name2id)

for game in postseason_games:
  stats = GetStatsForGame(game, postseason_games_teams)
  if not stats:
    print('No stats for game %s' % (game['id']))
    continue
  PrintGame(game, stats, ncaa_id2name, name2id)
