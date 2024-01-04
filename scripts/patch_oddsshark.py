#!/usr/bin/python3

import csv
import sys

_COLUMNS = [
  'Season', 'Week', 'Date', 'GameID', 'LineType', 'TeamOrGame', 'LineValue',
  'LinePrice', 'TotalProb', 'DidWin'
]

def make_key(row):
  for part in ['GameID', 'LineType', 'TeamOrGame']:
    if part not in row or not row[part]:
      return None
  return ':'.join([row['GameID'], row['LineType'], row['TeamOrGame']])


def is_valid_patch(original, updated):
  for k,v in original.items():
    if v != '_' and updated[k] == '_':
      return False
  return True


def read_patch(filename):
  outdict = dict()
  with open(filename, 'r') as infile:
    reader = csv.DictReader(infile, delimiter='\t')
    for row in reader:
      k = make_key(row)
      # print('PTCH %s' % k)
      if not k:
        # print('BOOT %s' % k)
        continue
      outdict[k] = row
  return outdict


def patch(mainfile, patch_data, outfile):
  used_patches = set()
  game_id_to_info = dict()
  with open(mainfile, 'r') as infile:
    reader = csv.DictReader(infile, delimiter='\t')
    with open(outfile, 'w') as outf:
      writer = csv.DictWriter(outf, fieldnames=reader.fieldnames, delimiter='\t')
      writer.writeheader()
      for row in reader:
        game_id_to_info[row['GameID']] = dict({
          'Season': row['Season'], 'Week': row['Week'], 'Date': row['Date']
        })
        row_key = make_key(row)
        if row_key and row_key in patch_data:
          # print('USED %s' % row_key)
          used_patches.add(row_key)
          for k,v in patch_data[row_key].items():
            row[k] = v
        # else:
        #   print('SKIP %s' % row_key)
        writer.writerow(row)
      # print('Used %d of %d patches' % (len(used_patches), len(patch_data)))
      for row_key,row_values in patch_data.items():
        if row_key in used_patches:
          print('Already patched row: %s' % row_key)
          continue
        game_id, line_type, team_or_game = row_key.split(':', maxsplit=2)
        if game_id not in game_id_to_info:
          # print('Unknown game ID: %s' % game_id, file=sys.stderr)
          continue
        outdict = {k: '' for k in _COLUMNS}
        for k,v in game_id_to_info[game_id].items():
          outdict[k] = v
        for k,v in row_values.items():
          outdict[k] = v
        writer.writerow(outdict)


def main(argv):
  if len(argv) != 4:
    print('Usage: %s <main_tsv> <patch_tsv> <out_tsv>' % (argv[0]))
    sys.exit(1)
  patch_data = read_patch(argv[2])
  patch(argv[1], patch_data, argv[3])


if __name__ == '__main__':
  main(sys.argv)
