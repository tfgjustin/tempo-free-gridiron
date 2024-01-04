#!/usr/bin/python3

import csv
import math
import operator
import sys

from collections import defaultdict
from operator import itemgetter

BIN_FACTOR=25

def broad_category(parts):
  return parts[1]

def category(parts):
  return ','.join(parts[0:2])


def bin_pred(value):
  return math.floor(value * BIN_FACTOR)


def unbin_pred(value):
  return min(float(value + 0.5) / BIN_FACTOR, 1.0)


def load_truth(infile, categories, data):
  for row in infile:
    parts = row.strip().split(',')
    categories.add(category(parts))
    categories.add(broad_category(parts))
    data.add(','.join(parts[0:3]))


def load_predictions(infile, categories, truth, right, wrong, brier_err, counts):
  for row in infile:
    parts = row.strip().split(',')
    c = category(parts)
    if c not in categories:
      continue
    b = broad_category(parts)
    if b not in categories:
      continue
    p = ','.join(parts[0:3])
    v = float(parts[-1])
    if v < 0.01:
      continue
    p_bin = bin_pred(v)
    # TODO: Right/wrong categories
    if p in truth:
      right[p_bin] += 1
      wrong[p_bin] += 0
      brier[c] += ((1 - v) ** 2)
      brier[b] += ((1 - v) ** 2)
    else:
      right[p_bin] += 0
      wrong[p_bin] += 1
      brier[c] += (v ** 2)
      brier[b] += (v ** 2)
    counts[c] += 1
    counts[b] += 1


def calibrate(right, wrong, brier, counts):
  for k,v in right.items():
    total = v
    total += wrong[k]
    print('%.3f %.3f %3d' % (unbin_pred(k), float(v) / total, total))
  # TODO: Make sure we count everything correctly
  for category,score in brier.items():
    if category not in counts or not counts[category]:
      print('ERROR: No counts for category %s' % (category))
      continue
    print('%-25s %.6f %6d' % (category, score / counts[category], counts[category]))


if len(sys.argv) < 3:
  print('Usage: %s <truth_file> <predict_file0> [... <predict_fileN>]' % (sys.argv[0]))
  sys.exit(1)

categories = set()
truth_data = set()
with open(sys.argv[1], 'r') as truth_file:
  load_truth(truth_file, categories, truth_data)

right = defaultdict(int)
wrong = defaultdict(int)
brier = defaultdict(float)
counts = defaultdict(int)
for f in sys.argv[2:]:
  with open(f, 'r') as pred_file:
    load_predictions(pred_file, categories, truth_data, right, wrong, brier, counts)

calibrate(right, wrong, brier, counts)

sys.exit(0)
