#!/usr/bin/python
#
# teamdb.py - Database to interact with team data by team ID number.
#
# This "database" is basically a global store for all team data.  The basic
# idea is that the runner script interfaces with the TeamDB through the team
# ID number rather than passing around tons of state.  This simplified
# interface should enable us to pull in all the data when the CSV file is
# loaded and perform incremental updates on each week.
#
# Author:  Eddie Pettis (pettis.eddie@gmail.com)

import allteams
import csv

from team import *

class TeamDB (object):
    def __init__(self, csvfile):
        """Read contents of CSV input file and initialize teams.
        """
        self._teams = {}

        f = open(csvfile, 'r')
        headers = f.readline().strip('#\n').split(',')
        reader = csv.DictReader(f, fieldnames=headers, delimiter=',')

        for row in reader:
            home_id = int(row['HomeID'])
            home_name = str(row['HomeName'])
            away_id = int(row['AwayID'])
            away_name = str(row['AwayName'])
            if not self._teams.has_key(home_id):
                self._teams[home_id] = \
                    Team(home_id, home_name)
            if not self._teams.has_key(away_id):
                self._teams[away_id] = \
                    Team(away_id, away_name)

        f.close()

    def Get(self, id):
        return self._teams[id]

    def Teams(self):
        """Return a list of all the teams."""
        teams = []
        for (key, value) in self._teams.items():
            teams.append(value)
        return teams
