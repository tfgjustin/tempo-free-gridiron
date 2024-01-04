#!/usr/bin/python3

import betlib
import sys

def main(argv):
  if len(argv) != 2:
    print('Usage: %s <line>' % (argv[0]))
    sys.exit(1)
  val = betlib.lineToOdds(argv[1])
  print('%.8f' % (val))

if __name__ == '__main__':
  main(sys.argv)
