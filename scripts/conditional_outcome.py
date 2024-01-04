#!/usr/bin/python3

import sys

def probability(infile, outcome):
  outcome = ',' + outcome + ','
  total = 0.
  success = 0.
  with open(infile, 'r') as inf:
    for line in inf:
      total += 1
      if outcome in line:
        success += 1
  return success / total

def main(argv):
  if len(argv) != 4:
    print('Usage: %s <full> <partial> <outcome>' % (argv[0]))
    sys.exit(1)
  full_prob = probability(argv[1], argv[3])
  cond_prob = probability(argv[2], argv[3])
  print('Outcome: %s Full: %.6f Cond: %.6f Ratio: %6.3f' % (argv[3],
        full_prob, cond_prob, cond_prob / full_prob))

if __name__ == '__main__':
  main(sys.argv)
