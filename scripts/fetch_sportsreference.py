#!/usr/bin/python3

from sportsreference.ncaaf.boxscore import Boxscore
from sportsreference.ncaaf.conferences import Conferences
from sportsreference.ncaaf.schedule import Schedule
from sportsreference.ncaaf.teams import Teams

#game_data = Boxscore('2018-01-08-georgia')
#print(game_data.home_points)  # Prints 23
#print(game_data.away_points)  # Prints 26

#conferences = Conferences(year=2019)
# Prints a dictionary where each key is the conference abbreviation and
# each value is a dictionary containing the full conference name as well as
# another dictionary of all teams in the conference, including name and
# abbreviation for each team.
#print(conferences.conferences)
#print()
#print(conferences.team_conference)

def PrintGame(g):
  print(g.date)
  print(g.dataframe)

# LATech 2019 schedule
latech_schedule = Schedule('louisiana-tech', year=2019)
for game in latech_schedule:
  print(game.dataframe)  # Prints the date the game was played

alabama_schedule = Schedule('alabama', year=2018)
for game in alabama_schedule:
  PrintGame(game)


#teams = Teams()
#for team in teams:
#  print(team.name)  # Prints the team's name
