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
    self._printer = pprint.PrettyPrinter(indent=2)
    self._in_books = False
    self._books = list()
    self._in_title = False
    self._titles = dict()
    self._in_teams_counter = 0
    self._op_key = None
    self._titles = dict()
    # [op-bar-XX] = teams
    self._in_team = False
    self._teams = dict()
    self._team_idx = -1
    self._book_idx = -1

  def read_and_parse(self):
    with open(self._filename, 'r') as infile:
      data = infile.read()
    self.feed(data)

  def handle_starttag(self, tag, attrs):
    if tag == 'img' and self._in_books:
      for k,v in attrs:
        if k == 'alt':
          self._books.append(v)
    elif tag == 'div':
      if self._in_teams_counter > 0:
        self._in_teams_counter += 1
      for k,v in attrs:
        if k == 'class':
          if v.startswith('op-book-header'):
            self._in_books = True
          elif v == 'op-team-data-wrapper futures':
            self._in_teams_counter = 1
          elif v.startswith('op-separator-bar op-left op-bar-'):
            self._op_key = v.split(' ')[-1]
            self._teams[self._op_key] = list()
          elif v.startswith('op-team football op-'):
            self._in_team = True
          elif v.startswith('op-separator-bar op-right futures op-bar-'):
            self._op_key = v.split(' ')[-1]
            self._team_idx = -1
          elif v.startswith('op-item-row-wrapper futures futures-item-row-wrapper '):
            self._team_idx += 1
            self._book_idx = -1
          elif v.startswith('op-item op-future-item '):
            self._book_idx += 1
          elif v == 'op-slider-navigation':
            self._book_idx = -1
            self._team_idx = -1
    elif tag == 'span':
      if self._in_teams_counter > 0:
        self._in_title = True

  def handle_endtag(self, tag):
    if tag == 'div':
      if self._in_teams_counter > 0:
        self._in_teams_counter -= 1
      if self._in_books:
        self._in_books = False
      elif self._in_team:
        self._in_team = False
    elif tag == 'span':
      if self._in_title:
        self._in_title = False

  def handle_data(self, data):
    if self._in_team:
      self._teams[self._op_key].append(data.strip().replace(' ', '_'))
    if self._in_title:
      title = data.strip()
      parts = title.split()
      title = '_'.join(parts[3:-1])
      self._titles[self._op_key] = title
    if self._team_idx >= 0 and self._book_idx >= 0:
      print('%-20s\t%-30s\t%-10s\t%8s\t%.6f' % (
             self._titles[self._op_key],
             self._teams[self._op_key][self._team_idx],
             self._books[self._book_idx], data.strip(),
             betlib.lineToOdds(data.strip())))


def main(argv):
  if len(argv) < 3:
    print('\nUsage: %s <output_file> <infile0> [<infile1> ... <infileN>]' % (
          argv[0]))
    sys.exit(1)
  with open(argv[1], 'w') as outfile:
    tsvwriter = csv.DictWriter(outfile, fieldnames=_FIELDS, delimiter='\t')
    tsvwriter.writeheader()
    for f in argv[2:]:
      parser = OddsSharkParser(f, tsvwriter)
      parser.read_and_parse()
  return


if __name__ == '__main__':
  main(sys.argv)
