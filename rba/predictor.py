#!/usr/bin/python
#
# predictor.py - container for actual prediction algorithm.  Accepts a set of
#                games and teams and outputs scores for each game.
#
# Author:  epettis@google.com (Eddie Pettis)
#
# This class only really works if you process the games in weekly order.  The
# basic usage is:
#
# # Import team information and game information from CSV
# p = Predictor(teams, games)
# for i in range(0, max_week):
#   p.PredictWeek(i)
#
# p.PredictAll()
# p.ComputeRankings()

from gaussian import Gaussian

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

class Predictor (object):
    """
    Reads data from a CSV file and constructs database of information
    necessary to produce game predictions.
    """
    def __init__(self, teams):
        self._teams = teams

        self._home_field_advantage = Gaussian()
        self._away_field_penalty = Gaussian()

    def AddGame(self, game):
        """Add the results of this game to each team's statistics."""
        if not game.played():
            return

        home_team = game.home_team()
        away_team = game.away_team()
        home_team.UpdateStatistics(game)
        away_team.UpdateStatistics(game)

        # Increment home field advantage
        home_ppp = float(game.home_score()) / float(game.num_plays())
        away_ppp = float(game.away_score()) / float(game.num_plays())
        d_home = home_ppp - home_team.offense_score().mean()
        d_away = away_ppp - away_team.offense_score().mean()
        self._home_field_advantage.Append(d_home)
        self._away_field_penalty.Append(d_away)

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

    def Predict(self, game, allow_ties=0, neutral_site=0):
        """
        Predicts the outcome of a game between two teams.  This is the most
        important part of the entire algorithm.  Everything else is filler.
        """

        home = game.home_team()
        away = game.away_team()

        home_strength = home.strength()
        away_strength = away.strength()

        # Compute probability distribution for number of plays per game.
        #
        # TODO(epettis):  Should this be weighted by strength?
        num_plays = (home.num_plays().mean() + away.num_plays().mean()) / 2

        if game.is_neutral_site() or neutral_site != 0:
            home_field_advantage = 0
            away_field_penalty = 0
        else:
            home_field_advantage = self._home_field_advantage.mean() * num_plays
            away_field_penalty = self._away_field_penalty.mean() * num_plays

        # Estimate points per play.  These are automatically scaled inside
        # the classes.
        home_offense = home.offense_score().Compute(away_strength) * num_plays
        away_defense = away.defense_score().Compute(home_strength) * num_plays
        home_score = (home_offense + away_defense) / 2 + home_field_advantage

#        print 'HOME  %20s:  (%.2f + %.2f)/2 + %.2f = %.2f' % \
#              (home.name(), home_offense, away_defense, home_field_advantage, home_score)

        away_offense = away.offense_score().Compute(home_strength) * num_plays
        home_defense = home.defense_score().Compute(away_strength) * num_plays
        away_score = (away_offense + home_defense) / 2 + away_field_penalty
#        print 'AWAY %20s:  (%.2f + %.2f)/2 + %.2f = %.2f' % \
#              (away.name(), away_offense, home_defense, away_field_penalty, away_score)

        # Estimate probability of this outcome occurring
        A = home.strength()
        B = away.strength()

        if (A + B - 2*A*B) == 0:
            confidence = 0.5
        else:
            confidence = (A - A*B) / (A + B - 2*A*B)
            if confidence < 0.5:
                confidence = 1 - confidence

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

        return (home_score, away_score, confidence)

    def PreProcess(self, game):
        """Preprocesses statistics from a game outcome."""

        (home_team, away_team) = self.SetTeams(game)

        # Preprocess wins and losses because we will need these later
        home_team.PreProcess(game)
        away_team.PreProcess(game)

    def ProcessGame(self, game):
        """Updates a team's statistics from a game outcome."""

        # Get relevant teams, creating them if necessary.
        home_team = self.MatchTeam(game.home_team_id(), game.home_team_name())
        away_team = self.MatchTeam(game.away_team_id(), game.away_team_name())

        # Update team's probabilities based on new data.
        home_team.UpdateStatistics(game)
        away_team.UpdateStatistics(game)

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

        # Compute deviation from mean for each team
        home_team_delta = (game_home_points/game_num_plays) - home_points
        away_team_delta = (game_away_points/game_num_plays) - away_points

        self._home_field_advantage.Append(home_team_delta)
        self._away_field_penalty.Append(away_team_delta)
