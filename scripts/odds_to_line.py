#!/usr/bin/python3

import sys

def main(argv):
  if len(argv) != 2:
    print('Usage: %s <line>' % (argv[0]))
    sys.exit(1)
  val = None
  try:
    val = float(argv[1])
  except:
    sys.exit(1)
  if val < 0.5:
    val = int((100. / val) - 100.0)
  else:
    val = int((100. * val) / (val - 1));
  print('%d' % (val))

if __name__ == '__main__':
  main(sys.argv)
