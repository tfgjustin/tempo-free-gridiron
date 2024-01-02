#!/usr/bin/python
#
# ncaa.py - predicts NCAA football game outcomes with startling accuracy
#
# Author:  epettis@google.com (Eddie Pettis)

import allteams
import constants
import csv
import string
import sys

from average import Average
from game import Game
from gamedb import GameDB
from gaussian import Gaussian
from team import Team
from teamdb import TeamDB

from scipy import interpolate

def min_error(x, options):
    """Computes the nearest number to x among available options."""
    min_delta = 10**12
    min_option = -1
    
    for i in options:
        delta = abs(x - i)
        if delta < min_delta:
            min_delta = delta
            min_option = i

    return min_option

def build_all_teams(id2name=None):
    """Builds the ID number to team name mapping to match with Justin."""

    if not id2name:
        return

    allteams.all_teams = {}
    f = open(id2name, 'r')
    lines = f.readlines()
    f.close()

    for line in lines:
        (num, name) = line.strip().split(',')
        allteams.all_teams[int(num)] = name


class Predictor (object):
    """
    Reads data from a CSV file and constructs database of information
    necessary to produce game predictions.
    """
    def __init__(self, csvfile):
        self._nonconf_home_field_advantage = Average()
        self._nonconf_away_field_penalty = Average()
        self._conf_home_field_advantage = Average()
        self._conf_away_field_penalty = Average()
        self._home_field_factor = 1.0

        self._gamedb = GameDB(csvfile)
        self._teamdb = TeamDB(csvfile)
        self._gamedb.Link(self._teamdb)

    def ComputeRankings(self):
        """Output ordered rankings for all teams."""
        self._teams.sort()
        for rank, team in enumerate(self._teams):
            team.set_ranking(rank+1)

    def OutputRankings(self, filename, weeknum=0, human_readable=0):
        """Output rankings to text file."""
        lines = []
        self.ComputeRankings()
        for team in self._teams:
            if human_readable == 0:
                lines.append(team.csv(weeknum=weeknum))
            else:
                lines.append('%s\n' % team)

        f = open(filename, 'a')
        f.writelines(lines)
        f.close()

    def MatchTeam(self, team_id, team_name):
        """Returns team name if it exists, otherwise creates a new one."""
        return self._teamdb.Get(team_id)

    def MLE(self, score):
        """Compute maximum likelihood estimator near the score."""
        td_score = round(score/7)*7
        lower = td_score - 4
        middle = td_score - 1
        upper = td_score + 3

        options = [lower, middle, td_score, upper]
        final_score = min_error(score, options)

        if final_score < 0:
            final_score = 0

        return final_score

    def PredictAll(self, report_teams=[]):
        """Predicts the outcome of all games between all teams."""

        self._teams = self._teamdb.Teams()

        # Clear any pre-existing rankings.
        for team in self._teams:
            team.RankingReset()

        for (i, home) in enumerate(self._teams):
            for (j, away) in enumerate(self._teams):
                if i == j:
                    continue

                (home_score, away_score, confidence, num_plays) = \
                             self.Predict(home, away, allow_ties=1,
                                          neutral_site=1, rankings=1)

                if home_score > away_score:
                    home.AddRankingWin(confidence)
                    away.AddRankingWin(1 - confidence)
                elif home_score < away_score:
                    home.AddRankingWin(1 - confidence)
                    away.AddRankingWin(confidence)
                else:
                    # It is theoretically possible to tie in a true toss-up.
                    pass

                location = 'vs'

                if home.name() in report_teams or \
                       away.name() in report_teams:
                    print '%20s %2d -%s- %20s %2d  (%.1f%%)' % \
                          (away.name(), away_score, location,
                           home.name(), home_score,
                           confidence*100)

    def PredictWeek(self, start_date, end_date, human_readable=0):
        """Predict all games in a given time span."""

        for game in self._games:
            if game.date() >= start_date and game.date() <= end_date:
                (home_score, away_score, confidence, num_plays) = \
                             self.Predict(game.home_team(),
                                          game.away_team(),
                                          neutral_site=game.is_neutral_site())
                if human_readable == 0:
                    print 'PREDICT,ALLDONE,%s,%d,%d,%d,%d,%d,%d,%d' % \
                          (game.game_id(), game.is_neutral_site(),
                           game.home_team().id(), home_score,
                           game.away_team().id(), away_score, confidence*1000,
                           num_plays)
                else:
                    if game.is_neutral_site():
                        location = 'vs'
                    else:
                        location = 'at'
                    print "%20s %3d  -%s-  %20s %3d   (%.1f%%)" % \
                          (game.away_team_name(),
                           away_score, location,
                           game.home_team_name(),
                           home_score, confidence*100)

    def PredictPastWeek(self, week_number, predict_week, human_readable=0):
        """
        This function measures predictor accuracy by running the algorithm
        against a past week.  We already know the outcome, so we predict
        the score and then compare the results to the known results.
        """

        correct = 0
        incorrect = 0
        expected = 0

        games = self._gamedb.Get(week_number)
        if (len(games) == 0):
            return (correct, incorrect, expected)

        for game in games:

            home = self._teamdb.Get(game.home_team_id())
            away = self._teamdb.Get(game.away_team_id())
    
            (predicted_home, predicted_away, confidence, num_plays) = \
                self.Predict(home, away)

            if week_number >= predict_week:
                status = 'ALLDONE'
            else:
                status = 'PARTIAL'

            if human_readable == 0:
                print 'PREDICT,%s,%s,%d,%d,%d,%d,%d,%d,%d' % \
                    (status, game.game_id(), game.is_neutral_site(),
                     game.home_team().id(), predicted_home,
                     game.away_team().id(), predicted_away, confidence*1000,
                     num_plays)
            else:
                if game.is_neutral_site():
                    location = 'vs'
                else:
                    location = 'at'
                    print "%20s %3d  -%s-  %20s %3d   (%.1f%%)" % \
                        (game.away_team_name(),
                         predicted_away, location,
                         game.home_team_name(),
                         predicted_home, confidence*100)

            if not game.played():
                continue

            if (predicted_home > predicted_away and \
                game.home_score() > game.away_score()) or \
               (predicted_away > predicted_home and \
                game.away_score() > game.home_score()):
                correct += 1
            else:
                incorrect += 1

            expected += confidence

        return (correct, incorrect, expected)

    def Predict(self, home, away, allow_ties=0, neutral_site=0, rankings=0):
        """
        Predicts the outcome of a game between two teams.  This is the most
        important part of the entire algorithm.  Everything else is filler.
        """

        home_strength = home.strength()
        away_strength = away.strength()

        # Estimate points per play.  These are automatically scaled inside
        # the classes.
        home_offense_score = home.offense_score().Compute(away_strength,
                                                          nslope=rankings)
        home_defense_score = home.defense_score().Compute(away_strength,
                                                          pslope=rankings)
        if home.conference() == away.conference():
            hfa = self._conf_home_field_advantage
            afp = self._conf_away_field_penalty
        else:
            hfa = self._nonconf_home_field_advantage
            afp = self._nonconf_away_field_penalty
        home_field_advantage = hfa.mean() * self._home_field_factor

        away_offense_score = away.offense_score().Compute(home_strength,
                                                          nslope=rankings)
        away_defense_score = away.defense_score().Compute(home_strength,
                                                          pslope=rankings)
        away_field_penalty = afp.mean() * self._home_field_factor

        if neutral_site != 0:
            home_field_advantage = 0
            away_field_penalty = 0

        # Compute probability distribution for number of plays per game.
        num_plays = (home.num_plays().mean() + away.num_plays().mean()) / 2

        # Estimate probability of this outcome occurring
        A = home_strength
        B = away_strength

        confidence = (A - A*B) / (A + B - 2*A*B)
        if confidence < 0.5:
            confidence = 1 - confidence

        # Compute average points/play and then multiply by expected number
        # of plays.
        home_score = ((home_offense_score + away_defense_score) / 2 + \
                      home_field_advantage) * num_plays
        away_score = ((away_offense_score + home_defense_score) / 2 +
                      away_field_penalty) * num_plays

        home_score_MLE = self.MLE(home_score)
        away_score_MLE = self.MLE(away_score)

        # Resolve ties if we do not allow them.
        if home_score_MLE == away_score_MLE and allow_ties == 0:
            if home_score > away_score:
                home_score_MLE = home_score_MLE + 1
            else:
                away_score_MLE = away_score_MLE + 1

        home_score = home_score_MLE
        away_score = away_score_MLE

        return (home_score, away_score, confidence, num_plays)

    def ProcessHomeFieldAdvantage(self, game):
        """Aggregate statistics for home field advantage."""

        # Aggregate statistics for home team.  Scores are already points/play.
        home_team = game.home_team()
        home_points = home_team.offense_score().mean()

        # Aggregate statistics for away team.  Scores are already points/play.
        away_team = game.away_team()
        away_points = away_team.offense_score().mean()

        # Single game statistics for both teams.
        game_home_points = game.home_score()
        game_away_points = game.away_score()
        game_num_plays = game.num_plays()
        if not game_num_plays:
          return

        # Compute deviation from mean for each team
        home_team_delta = (game_home_points/game_num_plays) - home_points
        away_team_delta = (game_away_points/game_num_plays) - away_points

        if home_team.conference() == away_team.conference():
            self._conf_home_field_advantage.Append(home_team_delta)
            self._conf_away_field_penalty.Append(away_team_delta)
        else:
            self._nonconf_home_field_advantage.Append(home_team_delta)
            self._nonconf_away_field_penalty.Append(away_team_delta)

    def PreProcessWeek(self, week_number):
        """Update the teams' data for this week without calculated values.

        This calculation is necessary because we require a few weeks before
        computing some values like strength.
        """

        games = self._gamedb.Get(week_number)
        if (len(games) == 0): return

        for game in games:
            home = self._teamdb.Get(game.home_team_id())
            away = self._teamdb.Get(game.away_team_id())
            home.PreProcess(game)
            away.PreProcess(game)

    def UpdateWeek(self, week_number):
        """Update statistics based on this week's results."""

        games = self._gamedb.Get(week_number)
        if (len(games) == 0):
            self._home_field_factor = 1.0
            return

        for game in games:
            home = self._teamdb.Get(game.home_team_id())
            away = self._teamdb.Get(game.away_team_id())
            home.UpdateStatistics(game)
            away.UpdateStatistics(game)
            self.ProcessHomeFieldAdvantage(game)

        self._home_field_factor = self._home_field_factor * \
            constants.HOME_FIELD_WEEKLY_DERATING

def main():
    inputfile = str(sys.argv[1])
    outputfile = str(sys.argv[2])
    currentweek = int(sys.argv[3])
    forhumans = str(sys.argv[4])
    weeklyranking = int(sys.argv[5])
    try:
        id2name = str(sys.argv[6])
    except:
        pass
    build_all_teams(id2name)

    if forhumans.lower() == 'human':
        human_readable = 1
    else:
        human_readable = 0

    # For convenience, let's just delete the old ranking file.
    f = open(outputfile, 'w')
    f.close()

    predictor = Predictor(inputfile)

    # We need to run a minimum number of weeks to initialize our data set.
    for week_number in range(0, constants.MIN_WEEKS_REQUIRED):
        predictor.PreProcessWeek(week_number)
    for week_number in range(0, constants.MIN_WEEKS_REQUIRED):
        predictor.UpdateWeek(week_number)

    # How would we have performed if we had run this every week?
    correct = 0
    incorrect = 0
    expected = 0
    for week_number in range(constants.MIN_WEEKS_REQUIRED, 1500):
        (week_correct, week_incorrect, week_expected) = \
            predictor.PredictPastWeek(week_number, currentweek,
                                      human_readable=human_readable)

        correct += week_correct
        incorrect += week_incorrect
        expected += week_expected

        if (week_correct > 0 or week_incorrect > 0) and human_readable == 1:
            print "Week %d:  %d-%d  (expected: %.1f)" % \
                (week_number, correct, incorrect, expected)

        if week_number < currentweek:
            predictor.UpdateWeek(week_number)

        if (week_correct > 0 or week_incorrect > 0) and weeklyranking == 1:
            predictor.PredictAll()
            predictor.ComputeRankings()
            predictor.OutputRankings(outputfile, weeknum=week_number,
                                     human_readable=human_readable)

    predictor.PredictAll()
    predictor.ComputeRankings()
    predictor.OutputRankings(outputfile, weeknum=currentweek,
                             human_readable=human_readable)

    if human_readable == 1:
        print 'MULTI-YEAR PREDICTION ACCURACY:  %d-%d  (%.3f)  ' \
              'EXPECTED:  %d (%.1f%%)' % (correct, incorrect, \
                                 correct / ((correct + incorrect)*1.0),
                                 expected,
                                 expected / ((correct + incorrect)*1.0)*100)

if __name__ == "__main__":
    main()
