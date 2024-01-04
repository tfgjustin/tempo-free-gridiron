#!/usr/bin/python3

from scipy.stats import norm

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

def is_valid_row(row):
  if 'LineType' not in row:
    return False
  return row['LineType'] == betlib.OVER or row['LineType'] == betlib.UNDER


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

def calculate_prob_greater_than(line_value, pred_value, pred_dev):
  if line_value is None or line_value == '_':
    return 0
  if pred_value is None or pred_value == '_':
    return 0
  if pred_dev is None or pred_dev == '_':
    return 0
  # The predicted value is the predicted total points by the model, and the line
  # value is the Vegas odds for the over or under. The edge is the number of
  # points *above* the final total we expect. If the number is negative then we
  # expect that the final total will be less than the O/U; there's still a
  # chance that the final total will be *more* than the O/U point, but that
  # chance should be less than 50%.
  # What is returned, then, is the probability that the predicted value will be
  # greater than the O/U line.
  edge = (float(pred_value) - float(line_value))
  return norm.cdf(edge / (float(pred_dev)))

def calculate_kelly(row_key, odds_row, system_row):
  line_type = odds_row.get('LineType')
  if line_type is None:
    return None
  if line_type != betlib.OVER and line_type != betlib.UNDER:
    return None
  line_price = odds_row.get('LinePrice')
  if line_price is None or not line_price:
    return None
  if line_price == '_' or line_price == '0':
    return None
  pred_value = system_row.get(betlib.TOTAL)
  if not pred_value:
    return None
  win_prob = calculate_prob_greater_than(odds_row.get('LineValue'),
                                         pred_value, system_row.get('Dev'))
  if line_type == betlib.UNDER:
    # The "win prob" is the probability the total score will be greater than the
    # value in the line. But if the line is the under, then the probability the
    # total score will be *less* than the line value is (1-win_prob)
    win_prob = 1 - win_prob
  kelly_val = betlib.kellyCriterion(win_prob, line=int(line_price))
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
        if not is_valid_row(row):
          continue
        row_key = make_key(row)
        if not row_key:
          continue
        if row_key not in system_dict:
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
