#!/usr/bin/python
#
# gamedb.py - Database to interact with game data by week number.
#
# This "database" is basically a global store for all game data.  The basic
# idea is that the runner script interfaces with the TeamDB through the week
# number rather than passing around tons of state.  This simplified interface
# should enable us to pull in all the data when the CSV file is loaded and
# perform incremental updates on each week.
#
# Author:  Eddie Pettis (pettis.eddie@gmail.com)

import csv

from game import *

class GameDB (object):
    def __init__(self, csvfile):
        """Read contents of CSV input file and initialize games.
        """
        self._weeks = {}

        f = open(csvfile, 'r')
        headers = f.readline().strip('#\n').split(',')
        reader = csv.DictReader(f, fieldnames=headers, delimiter=',')

        for row in reader:
            week_num = int(row['Week'])
            if not self._weeks.has_key(week_num):
                self._weeks[week_num] = []
            self._weeks[week_num].append(Game(row))

        f.close()

    def Link(self, teamdb):
        """Links games with the participating teams.

        We need to know which teams are playing in each game.  To do this, we
        iterate through each game and match the participanting IDs with the
        teamdb and link the raw data structure.
        """
        for week in self._weeks:
            for game in self._weeks[week]:
                game.set_home_team(teamdb.Get(game.home_team_id()))
                game.set_away_team(teamdb.Get(game.away_team_id()))

    def Get(self, week_num):
        if not self._weeks.has_key(week_num): return []
        return self._weeks[week_num]
