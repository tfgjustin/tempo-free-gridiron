#!/usr/bin/python

import json
import sys

def load_file(filename):
  data = None
  with open(filename, 'r') as myfile:
    data = myfile.read()
  return data

def find_json(data):
  start_idx = data.find('window.espn.scoreboardData')
  if start_idx is None or start_idx < 0:
    return None
  open_idx = data[start_idx:].find('{')
  if open_idx is None or open_idx < 0:
    return None
  start_idx += open_idx
  end_idx = data[start_idx:].find('};')
  if end_idx is None or end_idx < 0:
    return None
  end_idx += start_idx + 1
  return data[start_idx:end_idx]

def print_game(game):
  print game.keys()
  if 'competitors' not in game:
    print 'No competitor in game'
    return
  print 'Status: ',
  print json.dumps(game['status'], sort_keys=True, indent=2)
#  print game['status']
  if 'situation' in game:
    print 'Situation: ',
    print json.dumps(game['situation'], sort_keys=True, indent=2)
#    print game['situation']
  for team in game['competitors']:
    print team['id']
    if 'winner' in team:
      print team['winner']
    if 'score' in team:
      print team['score']
    if 'linescores' in team:
      print team['linescores']
    print

def print_games(parsed_json):
  print parsed_json.keys()
  if 'events' not in parsed_json:
    print 'No events in JSON'
    return
  events = parsed_json['events']
  for event in events:
    if 'competitions' not in event:
      print 'No competitions in event'
      continue
    for game in event['competitions']:
      print_game(game)

def main(argv):
  if len(argv) != 3:
    print 'Usage: %s <html_file> <out_file>' % (argv[0])
    return 1
  data = load_file(argv[1])
  if data is None:
    print 'Error loading data from %s' % (argv[1])
    return 1
  json_data = find_json(data)
  if json_data is None:
    print 'Could not get JSON data from %s' % (argv[1])
    return 1
  parsed_json = json.loads(json_data)
  if parsed_json is None:
    print 'Error parsing JSON data from %s' % (argv[1])
    return 1
  print_games(parsed_json)
  print json.dumps(parsed_json, sort_keys=True, indent=2)
  return 0

if __name__ == '__main__':
  sys.exit(main(sys.argv))
