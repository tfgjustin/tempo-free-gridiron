#!/usr/bin/python
#
# constants.py - contains various heuristic constants
#
# Author:  epettis@google.com (Eddie Pettis)

# Opponent rating for rankings
RANKING_HEURISTIC = 0.5

# Used for pythagorean expectation
STRENGTH_HEURISTIC = 2.3

# Exponential weighting factor
HISTORY_HEURISTIC = 0.985

# Minimum weeks required to perform weighted least squares
MIN_WEEKS_FOR_WLS = 5

# Weeks before executing.  Must be > MIN_WEEKS_FOR_WLS
MIN_WEEKS_REQUIRED = 6

# Home field is more important at the start of the season.  This constant
# is multiplied by home field advantage each week to reduce the effect.
#
# 1.0 disables this effect.
HOME_FIELD_WEEKLY_DERATING = 1.0
