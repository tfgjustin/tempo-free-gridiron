#!/usr/bin/python3

import csv
import sys
import tempo_free as tf

def is_valid_name(row):
  for k in ['Abbreviation', 'Name']:
    if k not in row or not row[k]:
      return False
  return True


def rename_teams(mainfile, namefile, outfile):
  name_map = dict()
  tf.load_oddsshark_names(name_map)
  with open(mainfile, 'r') as infile:
    reader = csv.DictReader(infile, delimiter='\t')
    with open(outfile, 'w') as outf:
      writer = csv.DictWriter(outf, fieldnames=reader.fieldnames, delimiter='\t')
      writer.writeheader()
      for row in reader:
        abbr = row['TeamOrGame']
        if ':' in abbr:
          t1,t2 = abbr.split(':', maxsplit=1)
          t1n = name_map.get(t1)
          t2n = name_map.get(t2)
          if t1n is None:
            print('Miss %s' % t1)
          if t2n is None:
            print('Miss %s' % t2)
          else:
            row['TeamOrGame'] = ':'.join(sorted([t1n, t2n]))
        elif abbr in name_map:
          row['TeamOrGame'] = name_map[abbr]
        elif abbr != 'Game':
          print('Miss %s' % abbr)
        writer.writerow(row)


def main(argv):
  if len(argv) != 3:
    print('Usage: %s <main_tsv> <out_tsv>' % (argv[0]))
    sys.exit(1)
  rename_teams(argv[1], None, argv[2])


if __name__ == '__main__':
  main(sys.argv)
