#!/usr/bin/python3

import betlib
import csv
import sys

_OUT_FIELDS = ['GameID', 'LineType', 'TeamOrGame', 'Kelly']

def make_key(row):
  _FIELDS = ['Date', 'TeamOrGame']
  for f in _FIELDS:
    if f not in row or not row[f]:
      return None
  return '%s-%s' % (row['Date'], row['TeamOrGame'])

def is_money_line(row):
  if 'LineType' not in row:
    return False
  return row['LineType'] == 'Money'


def load_system(system_file):
  outdict = dict()
  with open(system_file, 'r') as infile:
    reader = csv.DictReader(infile, delimiter='\t')
    for row in reader:
      row_key = make_key(row)
      if not row_key:
        continue
      outdict[row_key] = row
  return outdict


def calculate_kelly(row_key, odds_row, system_row):
  if 'LinePrice' not in odds_row or not odds_row['LinePrice']:
    return None
  if odds_row['LinePrice'] == '_' or odds_row['LinePrice'] == '0':
    return None
  kelly_val = betlib.kellyCriterion(float(system_row['WinProb']),
                                    line=int(odds_row['LinePrice']))
  if kelly_val < 0:
    return 0
  return kelly_val


def write_row(odds_row, kelly_val, writer):
  outdict = dict()
  for k in _OUT_FIELDS:
    if k in odds_row:
      outdict[k] = odds_row[k]
  outdict['Kelly'] = '%.4f' % kelly_val
  writer.writerow(outdict)


def make_kelly(odds_file, system_file, out_file):
  system_dict = load_system(system_file)
  with open(odds_file, 'r') as inf:
    reader = csv.DictReader(inf, delimiter='\t')
    with open(out_file, 'w') as outf:
      writer = csv.DictWriter(outf, fieldnames=_OUT_FIELDS, delimiter='\t')
      writer.writeheader()
      for row in reader:
        if not is_money_line(row):
          continue
        row_key = make_key(row)
        if not row_key or row_key not in system_dict:
          continue
        kelly_val = calculate_kelly(row_key, row, system_dict[row_key])
        if not kelly_val:
          continue
        write_row(row, kelly_val, writer)


def main(argv):
  if len(argv) != 4:
    print('Usage: %s <odds_tsv> <system_tsv> <out_tsv>' % (argv[0]))
    sys.exit(1)
  make_kelly(argv[1], argv[2], argv[3])


if __name__ == '__main__':
  main(sys.argv)
