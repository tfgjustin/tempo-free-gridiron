#!/usr/bin/python3

import csv
import math
import sys


def transform_s_and_p(week_num, infilename, outfilename):
  with open(infilename, 'r') as infile:
    with open(outfilename, 'w') as outfile:
      reader = csv.DictReader(infile)
      for row in reader:
        team_id = int(row['Team Code']) + 1000
        win_pct = 0.500
        try:
          win_pct = float(row['WinProbVsMedian'].replace('%', '')) / 100
        except:
          pass
        default_sos = 0.500
        default_oeff = default_deff = 17.5
        default_pace = 170
        # RANKING,954,1811,0.36952,0.47611,12.1,14.8,11.4,14.0,220.0,265.7,1,4,157.1
        print('RANKING,%d,%d,%.5f,%.5f,%.1f,%.1f,%.1f' % (week_num, team_id,
              win_pct, default_sos, default_oeff, default_deff, default_pace),
              file=outfile)


if len(sys.argv) != 4:
  print('Usage: %s <week_num> <s_and_p_in> <s_and_p_out>' % (sys.argv[0]))
  sys.exit(1)

week_num=int(sys.argv[1])
transform_s_and_p(week_num, sys.argv[2], sys.argv[3])
