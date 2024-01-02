#!/usr/bin/python
#
# game.py - contains all information about a single game
#
# Author:  epettis@google.com (Eddie Pettis)

import allteams
from team import Team

class Game (object):
    """
    Contains all information about a single game.
    """
    def __init__(self, csv_entry):
        self._week = int(csv_entry['Week'])
        self._date = int(csv_entry['Date'])
        self._game_id = str(csv_entry['GameID'])
        self._site = str(csv_entry['Site'])
        self._num_plays = float(csv_entry['NumPoss'])
        self._home_team_id = int(csv_entry['HomeID'])
        self._home_team_name = str(csv_entry['HomeName'])
        self._home_score = float(csv_entry['HomeScore'])
        self._away_team_id = int(csv_entry['AwayID'])
        self._away_team_name = str(csv_entry['AwayName'])
        self._away_score = float(csv_entry['AwayScore'])
        self._home_yards = float(csv_entry['HomeYards'])
        self._away_yards = float(csv_entry['AwayYards'])
        self._home_passing = float(csv_entry['HomePass'])
        self._away_passing = float(csv_entry['AwayPass'])
        self._home_rushing = float(csv_entry['HomeRush'])
        self._away_rushing = float(csv_entry['AwayRush'])
        self._home_turnovers = float(csv_entry['HomeTOs'])
        self._away_turnovers = float(csv_entry['AwayTOs'])
        self._home_penalties = float(csv_entry['HomePen'])
        self._away_penalties = float(csv_entry['AwayPen'])
        self._home_pass_plays = float(csv_entry['HomePassPlays'])
        self._away_pass_plays = float(csv_entry['AwayPassPlays'])
        self._home_run_plays = float(csv_entry['HomeRunPlays'])
        self._away_run_plays = float(csv_entry['AwayRunPlays'])

        self._home_team = None
        self._away_team = None

    def __str__(self):
        retstr = '%d %d %s %d ' \
                 '%d %s %d ' \
                 '%d %s %d ' % \
                 (self._week, self._date, self._game_id, self._num_plays,
                  self._home_team_id, self._home_team_name, self._home_score,
                  self._away_team_id, self._away_team_name, self._away_score)
        return retstr

    def played(self):
        "Returns whether the game has been played already or not."
        return (self._num_plays > 0)

    def week(self):
        return self._week

    def date(self):
        return self._date

    def game_id(self):
        return self._game_id

    def num_plays(self):
        return self._num_plays

    def home_team_id(self):
        return self._home_team_id

    def home_team_name(self):
        return self._home_team_name

    def home_passing(self):
        return self._home_passing

    def home_passing_plays(self):
        return self._home_passing_plays

    def home_penalties(self):
        return self._home_penalties

    def home_rushing(self):
        return self._home_rushing

    def home_rushing_plays(self):
        return self._home_rushing_plays

    def home_score(self):
        return self._home_score

    def home_turnovers(self):
        return self._home_turnovers

    def home_takeaways(self):
        return self._away_turnovers

    def away_team_id(self):
        return self._away_team_id

    def away_team_name(self):
        return self._away_team_name

    def away_passing(self):
        return self._away_passing

    def away_passing_plays(self):
        return self._away_passing_plays

    def away_penalties(self):
        return self._away_penalties

    def away_rushing(self):
        return self._away_rushing

    def away_rushing_plays(self):
        return self._away_rushing_plays

    def away_score(self):
        return self._away_score

    def away_turnovers(self):
        return self._away_turnovers

    def away_takeaways(self):
        return self._home_turnovers

    def set_home_team(self, team):
        self._home_team = team

    def home_team(self):
        return self._home_team

    def set_away_team(self, team):
        self._away_team = team

    def away_team(self):
        return self._away_team

    def is_neutral_site(self):
        if self._site == "NEUTRAL":
            return 1
        else:
            return 0
