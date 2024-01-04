#!/usr/bin/python3

from html.parser import HTMLParser

_FIELDS = ['GameID', 'LineType', 'TeamOrGame', 'LineValue', 'LinePrice', 'TotalProb', 'DidWin']
_MLS_KEY = 'money_line_spread'

import betlib
import csv
import json
import math
import pprint
import sys

_BASE_URL = 'https://www.oddsshark.com'
_OTHER = { 'home': 'away', 'away': 'home' }
_EID_KEY = 'event_id'

def abbr_key(team):
  return '%s_abbreviation' % team


class OddsSharkParser(HTMLParser):
  def __init__(self, filename, outtsv):
    HTMLParser.__init__(self)
    self._filename = filename
    self._writer = outtsv
    self._in_js = False
    self._printer = pprint.PrettyPrinter(indent=2)

  def read_and_parse(self):
    with open(self._filename, 'r') as infile:
      data = infile.read()
    self.feed(data)

  def handle_starttag(self, tag, attrs):
    if tag != 'script':
      return
    for k,v in attrs:
      if k == 'id' and v == 'gc-data':
        self._in_js = True

  def handle_endtag(self, tag):
    if self._in_js and tag == 'script':
      self._in_js = False

  def handle_data(self, data):
    if not self._in_js:
      return
    try:
      json_ld = json.loads(data)
    except:
      print('error parsing json')
      return
    matchup = self._get_matchup(json_ld)
    book = self._get_book(json_ld)
    scoreboard = self._get_scoreboard(json_ld)
    if not matchup or matchup is None:
      print('%s json_ld has no matchup' % (self._filename), file=sys.stderr)
      return
    if not book or book is None:
      print('%s json_ld has no book' % (self._filename), file=sys.stderr)
      return
    if not scoreboard or scoreboard is None:
      print('%s json_ld has no scoreboard' % (self._filename), file=sys.stderr)
      return
    total_odds = dict()
    total_odds['money_line'] = self._get_total_odds(book, 'money_line')
    total_odds['spread'] = self._get_total_odds(book, 'spread_price')
    self._print_stats(matchup, book, scoreboard, 'home', total_odds)
    self._print_stats(matchup, book, scoreboard, 'away', total_odds)


  def _get_team_odds(self, book, team, line_type):
    # Get the+/- odds for one team and one line type
    if _MLS_KEY not in book or not book[_MLS_KEY]:
      print('No key %s in %s' % (_MLS_KEY, book))
      return '_'
    if team not in book[_MLS_KEY] or not book[_MLS_KEY][team]:
      print('No key %s in %s' % (team, book[_MLS_KEY]))
      return '_'
    team_odds = book[_MLS_KEY][team]
    if line_type not in team_odds or not team_odds[line_type]:
      return '_'
    return team_odds[line_type]


  def _get_total_odds(self, book, line_type):
    # Get the total implied odds for a line (i.e., see what the vig is)
    sum = 0.0
    for team in ['home', 'away']:
      odds = self._get_team_odds(book, team, line_type)
      if not odds or odds == '_':
        return '_'
      sum += betlib.lineToOdds(odds)
    return '%.3f' % sum


  def _get_gamedata(self, json_ld):
    # Get the root gamedata/gamecenter element
    if 'oddsshark_gamecenter' not in json_ld:
      print('x')
      return None
    return json_ld['oddsshark_gamecenter']


  def _get_matchup(self, json_ld):
    # Get the matchup data (away, home, place, etc)
    game_center = self._get_gamedata(json_ld)
    if not game_center:
      return None
    if 'matchup' not in game_center:
      print('y')
      return None
    return game_center['matchup']


  def _get_scoreboard(self, json_ld):
    # Get the current/final scoreboard
    game_center = self._get_gamedata(json_ld)
    if not game_center:
      return None
    if 'scoreboard' not in game_center or not game_center['scoreboard']:
      return None
    return game_center['scoreboard']


  def _get_book(self, json_ld, book_name='Opening'):
    # Get all the info from/about a given book for this game
    game_center = self._get_gamedata(json_ld)
    if not game_center:
      return None
    if 'odds' not in game_center or not game_center['odds']:
      return None
    odds = game_center['odds']
    if 'data' not in odds or not odds['data']:
      return None
    for book in odds['data']:
      if 'book' not in book or not 'book':
        continue
      book_info = book['book']
      if 'book_name' not in book_info or book_info['book_name'] != book_name:
        continue
      if 'Opening' != book_info['book_name']:
        print('Book: %s' % book_info['book_name'])
      return book
    return None

  def _print_ml_stats(self, matchup, odds, scoreboard, team, total_odds):
    outdict = {k:'_' for k in _FIELDS}
    # GameID,LineType,TeamOrGame,LinePrice,TotalProb,DidWin
    outdict['GameID'] = matchup[_EID_KEY]
    outdict['LineType'] = 'Money'
    outdict['TeamOrGame'] = matchup[abbr_key(team)]
    outdict['LinePrice'] = self._get_team_odds(odds, team, 'money_line')
    outdict['TotalProb'] = total_odds
    outdict['DidWin'] = self._get_did_win(scoreboard, team, 'Money')
    self._writer.writerow(outdict)

  def _print_spread_stats(self, matchup, odds, scoreboard, team, total_odds):
    outdict = {k:'_' for k in _FIELDS}
    # GameID,LineType,TeamOrGame,LinePrice,TotalProb,DidWin
    outdict['GameID'] = matchup[_EID_KEY]
    outdict['LineType'] = 'Spread'
    outdict['TeamOrGame'] = matchup[abbr_key(team)]
    outdict['LineValue'] = self._get_team_odds(odds, team, 'spread')
    outdict['LinePrice'] = self._get_team_odds(odds, team, 'spread_price')
    outdict['TotalProb'] = total_odds
    outdict['DidWin'] = self._get_did_win(scoreboard, team, 'Spread', value=outdict['LineValue'])
    self._writer.writerow(outdict)

  def _print_stats(self, matchup, odds, scoreboard, team, total_odds):
    # Write game stats to the TSV
    if abbr_key(team) not in matchup or not matchup[abbr_key(team)]:
      print('Missing %s in game %s data' % (abbr_key(team), matchup[_EID_KEY]),
            file=sys.stderr)
      return
    self._print_ml_stats(matchup, odds, scoreboard, team, total_odds['money_line'])
    self._print_spread_stats(matchup, odds, scoreboard, team, total_odds['spread'])

  def _get_did_win(self, scoreboard, team, line_type, value=None):
    # Find out if a team (home/away) won the bet(game)
    them = _OTHER[team]
    us_score_key = '%s_score' % team
    them_score_key = '%s_score' % them
    if 'data' not in scoreboard or not scoreboard['data']:
      return False
    game = scoreboard['data']
    if us_score_key not in game or game[us_score_key] is None:
      return False
    if them_score_key not in game or game[them_score_key] is None:
      return False
    us_score = int(game[us_score_key])
    them_score = int(game[them_score_key])
    if line_type == 'Money':
      return us_score > them_score
    elif line_type == 'Spread' and value and value != '_':
      return (us_score + float(value)) > them_score
    else:
      return False


def main(argv):
  if len(argv) < 3:
    print('\nUsage: %s <output_file> <infile0> [<infile1> ... <infileN>]' % (
          argv[0]))
    sys.exit(1)
  with open(argv[1], 'w') as outfile:
    tsvwriter = csv.DictWriter(outfile, fieldnames=_FIELDS, delimiter='\t')
    tsvwriter.writeheader()
    for f in argv[2:]:
      print(f)
      parser = OddsSharkParser(f, tsvwriter)
      parser.read_and_parse()
  return


if __name__ == '__main__':
  main(sys.argv)
