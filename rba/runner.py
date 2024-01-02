#!/usr/bin/python
#
# runner.py - skeleton to execute the various pieces of the algorithm.
#
# Author:  Eddie Pettis (epettis@google.com)

import allteams
import constants
import csv
import sys

from game import Game
from predictor import Predictor
from team import Team

class Runner (object):
    def __init__ (self):
        self._teams = {}
        self._games = {}

        self._correct = 0
        self._incorrect = 0
        self._predicted_correct = 0

    def InitializeTeams(self, historical=0):
        """Creates classes based on a list of teams in all_teams."""
        all_teams = allteams.all_teams
        for i, team_id in enumerate(all_teams):
            if (not historical and (team_id < 19990000)) or historical:
                self._teams[team_id] = Team(team_id, all_teams[team_id])
                print 'Importing %s (%d)' % (all_teams[team_id], team_id)

    def ReadCSV(self, csvfile):
        f = open(csvfile, 'r')
        headers = f.readline().strip('#\n').split(',')
        reader = csv.DictReader(f, fieldnames=headers, delimiter=',')
        csvfile_dicts = []
        for row in reader:
            csvfile_dicts.append(row)
        f.close()

        # Convert CSV data into games.
        for row in csvfile_dicts:
            g = Game(row)

            # Attach teams to game class.
            (home_team, away_team) = self.SetTeams(g)
            if (home_team is None) or (away_team is None):
                continue

            week_id = g.week()
            if not self._games.has_key(week_id):
                self._games[week_id] = []
            self._games[week_id].append(g)

    def MatchTeam(self, team_id):
        """Returns team name if it exists, otherwise creates a new one."""

        # Team doesn't exist, as far as we are concerned.  Don't predict the
        # game.
        if not allteams.all_teams.has_key(team_id):
            return None
        return self._teams[team_id]

    def SetTeams(self, game):
        """Attaches teams to games."""

        # Get relevant teams, creating them if necessary.
        home_team = self.MatchTeam(game.home_team_id())
        away_team = self.MatchTeam(game.away_team_id())

        if (home_team is None) or (away_team is None):
            return (None, None)

        game.set_home_team(home_team)
        game.set_away_team(away_team)

        return (home_team, away_team)

    def EvaluatePrediction(self, home_score, away_score, confidence, game):
        """Identifies if the pick was correct or not."""

        if not game.played():
            return

        if home_score > away_score:
            game.home_team().AddPredictedWin(confidence)
            game.away_team().AddPredictedLoss(confidence)
        elif home_score < away_score:
            game.home_team().AddPredictedLoss(confidence)
            game.away_team().AddPredictedWin(confidence)

        self._predicted_correct += confidence

        if home_score > away_score and game.home_score() > game.away_score():
            self._correct += 1
        elif home_score < away_score and game.home_score() < game.away_score():
            self._correct += 1
        elif home_score > away_score and game.home_score() < game.away_score():
            self._incorrect += 1
        elif home_score < away_score and game.home_score() > game.away_score():
            self._incorrect += 1

    def ReportPredictions(self):
        """Prints current prediction status to screen."""
        print 'Prediction record: %d - %d' % (self._correct, self._incorrect)
        (accuracy, predicted_accuracy) = self.Accuracy()
        print 'Accuracy: %.2f%%  (expected %.2f%%)' % (accuracy,
                                                       predicted_accuracy)

    def Accuracy(self):
        total = self._incorrect + self._correct
        if total > 1:
            accuracy = float(self._correct) / float(total) * 100
            predicted_accuracy = float(self._predicted_correct) / \
                float(total) * 100
        else:
            accuracy = 0
            predicted_accuracy = 0
        return (accuracy, predicted_accuracy)

    def OutputGame(self, game, home_score, away_score, confidence,
                   filename=None, human_readable=0):
        if game.played():
            game_type = 'PARTIAL,PREDICT'
        else:
            game_type = 'ALLDONE,PREDICT'

        if human_readable == 0:
            outstr = '%s,%s,%d,%d,%d,%d,%d,%d' % \
                (game_type, game.game_id(), game.is_neutral_site(),
                 game.home_team().id(), home_score,
                 game.away_team().id(), away_score, confidence*1000)
        else:
            if game.is_neutral_site():
                location = 'vs'
            else:
                location = 'at'
            outstr = "%s  %20s %3d  -%s-  %20s %3d   (%.1f%%)" % \
                (game.game_id(),
                 game.away_team_name(),
                 away_score, location,
                 game.home_team_name(),
                 home_score, confidence*100)

        if filename:
            f = open(filename, 'a')
            f.write(outstr + '\n')
            f.close()
        else:
            print outstr

    def ComputeRankings(self):
        """Output ordered rankings for all teams."""

        def CreateGame(home, away):
            csv_entry = {}
            csv_entry['Week'] = "999"
            csv_entry['Date'] = "20110131"
            csv_entry['GameID'] = "0"
            csv_entry['Site'] = "NEUTRAL"
            csv_entry['NumPoss'] = "0"
            csv_entry['HomeID'] = home.id()
            csv_entry['HomeScore'] = "0"
            csv_entry['AwayID'] = away.id()
            csv_entry['AwayScore'] = "0"
            csv_entry['AwayScore'] = "0"
            csv_entry['AwayScore'] = "0"
            csv_entry['HomeYards'] = "0"
            csv_entry['AwayYards'] = "0"
            csv_entry['HomePass'] = "0"
            csv_entry['AwayPass'] = "0"
            csv_entry['HomeRush'] = "0"
            csv_entry['AwayRush'] = "0"
            csv_entry['HomeTOs'] = "0"
            csv_entry['AwayTOs'] = "0"
            csv_entry['HomePen'] = "0"
            csv_entry['AwayPen'] = "0"
            csv_entry['HomePassPlays'] = "0"
            csv_entry['AwayPassPlays'] = "0"
            csv_entry['HomeRunPlays'] = "0"
            csv_entry['AwayRunPlays'] = "0"
            game = Game(csv_entry)
            game.set_home_team(home)
            game.set_away_team(away)
            return game
        
        team_list = []
        for k, v in self._teams.iteritems():
            team_list.append(v)

        # Perform a round robin tournament between all the teams
        for i in range(len(team_list)):
            for j in range(len(team_list)):
                home = team_list[i]
                away = team_list[j]

                game = CreateGame(home, away)

                (home_score, away_score, confidence) = \
                    self._predictor.Predict(game, allow_ties=1)
                if home_score > away_score:
                    home.AddRankingWin(confidence)
                    away.AddRankingWin(1 - confidence)
                elif away_score > home_score:
                    home.AddRankingWin(1 - confidence)
                    away.AddRankingWin(confidence)

        team_list.sort()
        for rank, team in enumerate(team_list):
            team.set_ranking(rank+1)

    def OutputRankings(self, filename=None, human_readable=0):
        """Output rankings to text file."""
        lines = []
        self.ComputeRankings()
        team_list = []
        for k, v in self._teams.iteritems():
            team_list.append(v)
        team_list.sort()
        for team in team_list:
            if human_readable == 0:
                lines.append(team.csv())
            else:
                lines.append('%s\n' % team)

        if filename:
            f = open(filename, 'w')
            f.writelines(lines)
            f.close()
        else:
            for line in lines:
                print '%s' % line.strip()

    def Run(self, game_file, human_readable=0):
        """
        Iterates through all weeks of the data set, incrementally inserting the
        new data into the predictor and then making that week's picks.
        """

        self._predictor = Predictor(self._teams)
        weeks = []
        for w in self._games.iterkeys():
            weeks.append(w)
        weeks.sort()
        for week_id in weeks:

            # Predict the games
            if week_id > constants.MIN_WEEKS_REQUIRED:
                for game in self._games[week_id]:
                    (home_score, away_score, confidence) = \
                        self._predictor.Predict(game, allow_ties=0)
                    self.EvaluatePrediction(home_score, away_score, confidence,
                                            game)
                    self.OutputGame(game, home_score, away_score,
                                    confidence, filename=game_file,
                                    human_readable=human_readable)
                print "SUMMARY AFTER WEEK %d" % week_id
                self.ReportPredictions()
            else:
                # Still need to tally the predictions for the game for luck
                for game in self._games[week_id]:
                    if game.home_score() > game.away_score():
                        game.home_team().AddPredictedWin(1.0)
                        game.away_team().AddPredictedLoss(0.0)
                    elif game.home_score() < game.away_score():
                        game.home_team().AddPredictedLoss(1.0)
                        game.away_team().AddPredictedWin(0.0)

            # Append the data for future analyses
            for game in self._games[week_id]:
                self._predictor.AddGame(game)



if __name__ == "__main__":
    summary_file = '../data/summary.2010-07-29.csv'

    summary_file = sys.argv[1]
    game_file = sys.argv[2]
    ranking_file = sys.argv[3]
    human_readable = int(sys.argv[4])
    historical = int(sys.argv[5])

    f = open(game_file, 'w')
    f.close()
    f = open(ranking_file, 'w')
    f.close()

    r = Runner()
    r.InitializeTeams(historical)
    r.ReadCSV(summary_file)
    r.Run(game_file=game_file, human_readable=human_readable)
    r.OutputRankings(ranking_file, human_readable=human_readable)
    r.ReportPredictions()
