#!/usr/bin/python
#
# team.py - keeps up with a team's statistics
#
# Author:  epettis@google.com (Eddie Pettis)

import allconferences
import constants

from average import Average
from regression import Regression

class Team (object):
    def __init__(self, id, name):
        self._name = name
        self._id = id
        self._real_wins = 0
        self._real_losses = 0
        self._ranking_wins = 0
        self._ranking_losses = 0
        self._predicted_wins = 0
        self._predicted_losses = 0
        self._ranking = -1
        self._strength = 0.001
        if allconferences.all_conferences.has_key(id):
            self._conference = allconferences.all_conferences[id]
        else:
            self._conference = "????"

        # Relevant statistics
        self._offense_score = Regression()
        self._defense_score = Regression()
        self._num_plays = Average()

        # Opponent information
        self.opponents = []

    def __cmp__(self, other):
        return cmp(other.ranking_win_percentage(),
                   self.ranking_win_percentage())

    def __str__(self):
        return '%03d %20s  %.3f  %.3f   %4.3f*x+%4.3f  '\
               '%4.3f*x+%4.3f  %4.2f  LUCK: %.3f PRED: %4d-%4d ' \
               'ACT: %4d-%4d' % \
               (self._ranking, self._name, self.ranking_win_percentage(),
                self.strength(),
                self._offense_score.slope(), self._offense_score.intercept(),
                self._defense_score.slope(), self._defense_score.intercept(),
                self._num_plays.mean(), self.luck(), self.predicted_wins(),
                self.predicted_losses(), self.real_wins(), self.real_losses())

    def csv(self, weeknum=0):
        """
        Returns printable csv string in jmoore's format.

        From jmoore:
        RANKING,WeekNum,TeamID,WinPct,SOS,OffensePts,DefensePts,Pace
        E.g.,
        RANKING,575,1630,0.07143,0.50477,9.9,23.5,83.7
        """
        outstr = 'RANKING,%d,%d,%.5f,%.5f,%.1f,%.1f,%.1f\n' % \
                 (weeknum, self._id, self.ranking_win_percentage(),
                  self.strength_of_schedule(),
                  self.offense_score().Compute(0.5)*100,
                  self.defense_score().Compute(0.5)*100,
                  self.num_plays().mean())
        return outstr

    def conference(self):
        return self._conference

    def defense_score(self):
        return self._defense_score

    def id(self):
        return self._id

    def luck(self):
        """Identifies how lucky a team is, estimated by mispredictions.

        Luck is the difference between the number of games the team won
        and the number it should have won.  Teams with high luck have
        outperformed expectations.  Teams with low luck have underperformed
        expectations.  This may also be a way to identify which conferences are
        harder to pick than others.

        predicted_wins is the number of games we expect this team to win over
        the course of the entire data set.  This should be approximately the
        same as real_wins in the ideal case.  However, teams that are unlucky
        will lose some games that they shouldn't.  Therefore, real_wins will
        become less than predicted_wins.  Lucky teams will have more real_wins
        than predicted_wins, which should be represented as high luck.
        """
        return float(self.real_wins()) - self.predicted_wins()

    def name(self):
        return self._name

    def num_plays(self):
        return self._num_plays

    def offense_score(self):
        return self._offense_score

    def passing_defense(self):
        return self._passing_defense

    def passing_offense(self):
        return self._passing_offense

    def passing_plays(self):
        return self._passing_plays

    def penalties(self):
        return self._penalties

    def predicted_losses(self):
        return self._predicted_losses

    def predicted_win_percentage(self):
        if self.predicted_wins() + self.predicted_losses() > 0:
            win_pct = float(self.predicted_wins()) / \
                      float(self.predicted_wins() + self.predicted_losses())
        else:
            win_pct = 0.0
        return win_pct

    def predicted_wins(self):
        return self._predicted_wins

    def ranking_win_percentage(self):
        if self.ranking_wins() + self.ranking_losses() > 0:
            win_pct = float(self.ranking_wins()) / \
                      float(self.ranking_wins() + self.ranking_losses())
        else:
            win_pct = 0.0
        return win_pct

    def ranking_wins(self):
        return self._ranking_wins

    def ranking_losses(self):
        return self._ranking_losses

    def real_losses(self):
        return self._real_losses

    def real_win_percentage(self):
        if self.real_wins() + self.real_losses() > 0:
            win_pct = float(self.real_wins()) / \
                      float(self.real_wins() + self.real_losses())
        else:
            win_pct = 0
        return win_pct

    def real_wins(self):
        return self._real_wins

    def rushing_defense(self):
        return self._rushing_defense

    def rushing_offense(self):
        return self._rushing_offense

    def rushing_plays(self):
        return self._rushing_plays

    def set_ranking(self, ranking):
        self._ranking = ranking

    def strength(self):
        """
        Estimates the strength of this opponent in [0,1.0].

        This is one of the few heuristic portions of the algorithm.  It
        attempts to approximate the strength of an opponent by performing
        a weighted average of its own winning percentage and the strength
        of its schedule.  Hence, a team with an excellent winning percentage
        can be muted if it plays weak opponents *Penn State cough*.  Please
        note that this is a valid probability measure in the close range
        [0.0, 1.0].

        We may later tune this heuristic to maximize success rate at picking
        past games.
        """
        return self._strength

    def strength_of_schedule(self):
        """Computes opponents' winning percentages."""

        wins = 0
        losses = 0
        for opponent in self.opponents:
            wins += float(opponent.real_wins())
            losses += float(opponent.real_losses())

        if wins + losses == 0:
            return 0.0

        percentage = wins / (wins + losses)
        return percentage

    def takeaways(self):
        return self._takeaways

    def turnovers(self):
        return self._turnovers

    def RankingReset(self):
        """Resets all predictions for rankings."""
        self._ranking_wins = 0
        self._ranking_losses = 0

    def AddPredictedWin(self, confidence):
        self._predicted_wins += confidence
        self._predicted_losses += (1.0 - confidence)

    def AddPredictedLoss(self, confidence):
        self._predicted_wins += (1.0 - confidence)
        self._predicted_losses += confidence

    def AddRankingWin(self, odds):
        self._ranking_wins += odds
        self._ranking_losses += (1 - odds)

    def AddRankingLoss(self):
        self._ranking_losses += 1

    def AddRealWin(self):
        self._real_wins += 1

    def AddRealLoss(self):
        self._real_losses += 1

    def PreProcess(self, game):
        """Parse csv dictionary and preprocess this team's statistics."""

        # Extract important variables from CSV
        if game.away_team_id() == self._id:
            self._name = game.away_team_name()
            opponent = game.home_team()
            new_offense_score = game.away_score()
            new_defense_score = game.home_score()
        elif game.home_team_id() == self._id:
            self._name = game.home_team_name()
            opponent = game.away_team()
            new_offense_score = game.home_score()
            new_defense_score = game.away_score()
        new_plays = game.num_plays()

        # Check important variables for sensical results
        if new_plays < 1:
            return

        # Compute wins and losses
        if new_offense_score > new_defense_score:
            self.AddRealWin()
        else:
            self.AddRealLoss()

        # Retain opponents for strength of schedule
        self.opponents.append(opponent)

    def Update(self):
        """Forces all statistics to update."""
        self._offense_score.Update()
        self._defense_score.Update()


    def UpdateStatistics(self, game):
        """Parse csv dictionary and update this team's statistics."""

        # Has this game actually been played, yet?  If not, we don't accumulate
        # the statistics because they're bogus.
        if not game.played():
            return

        week = game.week()

        # Extract important variables from CSV
        if game.away_team_id() == self._id:
            self._name = game.away_team_name()
            new_offense_score = game.away_score()
            new_defense_score = game.home_score()
            opponent_strength = game.home_team().strength()
            self.opponents.append(game.home_team())
        elif game.home_team_id() == self._id:
            self._name = game.home_team_name()
            new_offense_score = game.home_score()
            new_defense_score = game.away_score()
            opponent_strength = game.away_team().strength()
            self.opponents.append(game.away_team())

        new_plays = game.num_plays()

        if new_offense_score > new_defense_score:
            self.AddRealWin()
        elif new_offense_score < new_defense_score:
            self.AddRealLoss()
        else:
            pass  # We just drop ties rather than deal with them right now

        # Import necessary variables into classes.  All scores are done in
        # points per play.
        self._offense_score.Append((week, opponent_strength,
                                    new_offense_score/new_plays))
        self._defense_score.Append((week, opponent_strength,
                                    new_defense_score/new_plays))
        self._num_plays.Append(new_plays)

        self.UpdateStrength()

        # Recompute regression analyses
        if week > constants.MIN_WEEKS_FOR_WLS:
            self._offense_score.Update()
            self._defense_score.Update()

    def UpdateStrength(self):
        """Updates computationally intensive operation once per loop."""

        if self._real_wins + self._real_losses < 4:
            self._strength = 0.001
            return

        raw_offense = self.offense_score().Compute(constants.RANKING_HEURISTIC)
        if raw_offense < 0:
            raw_offense = 0
        offense = (raw_offense) ** float(constants.STRENGTH_HEURISTIC)
        raw_defense = self.defense_score().Compute(constants.RANKING_HEURISTIC)
        if raw_defense < 0:
            raw_defense = 0
        defense = (raw_defense) ** float(constants.STRENGTH_HEURISTIC)
        num = offense
        den = offense + defense
        if den <= 0:
            self._strength = 0.0
        else:
            self._strength = offense / (offense + defense)
