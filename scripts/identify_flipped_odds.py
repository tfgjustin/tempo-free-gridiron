#!/usr/bin/python3

from collections import defaultdict
from datetime import date, timedelta

import betlib
import csv
import sys


def _date_from_string(game_date):
    return date(int(game_date[0:4]), int(game_date[4:6]), int(game_date[6:8]))


def sunday_before(game_date):
    date_stamp = _date_from_string(game_date)
    day_of_game = date_stamp.isoweekday() % 7
    if not day_of_game:
        return game_date
    date_stamp -= timedelta(days=day_of_game)
    return str(
        (date_stamp.year * 10000) + (date_stamp.month * 100) + date_stamp.day
    )


class FlipOddsDetector(object):
    _BLOCKLIST_TAG = 'OddsFlip'

    def __init__(self):
        self._blocklist_file = None
        # List of dictionaries
        self._cached_blocklist = list()
        self._fieldnames = ['GameID', 'LineDate', 'BlockReason']
        # [line_id][timestamp] = line_value
        self._all_lines = defaultdict(dict)
        # The line key which is opposite this one
        self._opposite_key = dict()
        # [line_key] = [list of times]
        self._blocked_lines = dict()

    def load_blocklist(self, blocklist_file):
        self._blocklist_file = blocklist_file
        with open(self._blocklist_file, 'r') as infile:
            reader = csv.DictReader(infile, delimiter='\t')
            if reader.fieldnames:
                self._fieldnames = reader.fieldnames
            for row in reader:
                if not self._is_valid_blocklist_row(row):
                    continue
                if row.get('BlockReason', '') != FlipOddsDetector._BLOCKLIST_TAG:
                    self._cached_blocklist.append(row)

    def load_lines(self, lines_files):
        key_pairs = defaultdict(set)
        for line_file in lines_files:
            parts = line_file.split('.')
            timestamp = parts[-1]
            with open(line_file, 'r') as infile:
                reader = csv.DictReader(infile, delimiter='\t')
                for row in reader:
                    if not self._is_valid_line_row(row):
                        continue
                    # If the date of the game is before the Sunday before the game, ignore it.
                    first_model = sunday_before(row['Date'])
                    if timestamp < first_model or timestamp > row['Date']:
                        continue
                    line_index = self._make_line_index(row)
                    line_key = self._make_line_key(row)
                    line_value = '%s:%s' % (row['LineValue'], row['LinePrice'])
                    self._all_lines[line_key][timestamp] = line_value
                    key_pairs[line_index].add(line_key)
        for pairs in key_pairs.values():
            if len(pairs) != 2:
                print('Mismatched pair: [%s]' % ', '.join(pairs), file=sys.stderr)
                continue
            pair_list = list(pairs)
            self._opposite_key[pair_list[0]] = pair_list[1]
            self._opposite_key[pair_list[1]] = pair_list[0]

    def identify_flips(self):
        for line_key in sorted(self._all_lines.keys()):
            if line_key not in self._opposite_key:
                continue
            _, _, line_type, _ = line_key.split(':', maxsplit=3)
            if line_type == betlib.MONEYLINE:
                self._identify_moneyline_errors(line_key)
            elif line_type == betlib.SPREAD:
                self._identify_spread_errors(line_key)

    def write_blocklist(self):
        if self._blocklist_file is None:
            return
        flips = self._get_relevant_flips()
        seen = defaultdict(set)
        with open(self._blocklist_file, 'w') as outfile:
            writer = csv.DictWriter(outfile, fieldnames=self._fieldnames, delimiter='\t')
            writer.writeheader()
            for row in self._cached_blocklist:
                writer.writerow(row)
            for game_id, timed_lines in flips.items():
                out_dict = dict()
                out_dict['GameID'] = game_id
                out_dict['BlockReason'] = FlipOddsDetector._BLOCKLIST_TAG
                times_seen = seen.get(game_id, set())
                for timestamp in sorted(timed_lines.keys()):
                    if timestamp in times_seen:
                        continue
                    times_seen.add(timestamp)
                    out_dict['LineDate'] = timestamp
                    writer.writerow(out_dict)
                seen[out_dict['GameID']] = times_seen

    def _identify_moneyline_errors(self, line_key):
        opp_key = self._opposite_key[line_key]
        line_values = self._all_lines[line_key]
        opp_values = self._all_lines[opp_key]
        flip_times = list()
        times = sorted(line_values.keys())
        last_line = self._moneyline_odds(line_values[times[0]])
        last_opp = self._moneyline_odds(opp_values[times[0]])
        for t in times[1:]:
            this_line = self._moneyline_odds(line_values[t])
            this_opp = self._moneyline_odds(opp_values[t])
            if this_line is not None and last_line is not None and last_opp is not None:
                this_diff = abs(this_line - last_line)
                opp_diff = abs(this_line - last_opp)
                if opp_diff < this_diff:
                    flip_times.append(t)
            last_line = this_line
            last_opp = this_opp
        if flip_times:
            self._blocked_lines[line_key] = flip_times

    def _identify_spread_errors(self, line_key):
        opp_key = self._opposite_key[line_key]
        line_values = self._all_lines[line_key]
        opp_values = self._all_lines[opp_key]
        flip_times = list()
        times = sorted(line_values.keys())
        last_line = self._spread_value(line_values[times[0]])
        last_opp = self._spread_value(opp_values[times[0]])
        for t in times[1:]:
            this_line = self._spread_value(line_values[t])
            this_opp = self._spread_value(opp_values[t])
            if this_line is not None and last_line is not None and last_opp is not None:
                this_diff = abs(this_line - last_line)
                opp_diff = abs(this_line - last_opp)
                if opp_diff < this_diff:
                    flip_times.append(t)
            last_line = this_line
            last_opp = this_opp
        if flip_times:
            self._blocked_lines[line_key] = flip_times

    def _get_relevant_flips(self):
        # [GameID][timestamp] = [lines]
        blocked_by_game = defaultdict(dict)
        for line_key, flip_times in self._blocked_lines.items():
            game_id, _ = line_key.split(':', maxsplit=1)
            for t in flip_times:
                lines = blocked_by_game[game_id].get(t, list())
                lines.append(line_key)
                blocked_by_game[game_id][t] = lines
        games_to_delete = set()
        for game_id, flip_times in blocked_by_game.items():
            times_to_delete = set()
            for t, line_keys in flip_times.items():
                # If only one line flipped for this game, then there was, by
                # definition, nothing on the other side of the flip.
                if len(line_keys) == 1:
                    times_to_delete.add(t)
            for t in times_to_delete:
                del flip_times[t]
            # Clear out any unused flips
            if not len(flip_times):
                games_to_delete.add(game_id)
        for game_id in games_to_delete:
            del blocked_by_game[game_id]
        return blocked_by_game

    @staticmethod
    def _moneyline_odds(line_value):
        moneyline = line_value.split(':')[1]
        if moneyline == '_':
            return None
        return betlib.lineToOdds(moneyline)

    @staticmethod
    def _spread_value(line_value):
        spread = line_value.split(':')[0]
        if spread == '_':
            return None
        return betlib.lineToOdds(spread)

    @staticmethod
    def _make_line_key(row):
        return '%s:%s:%s:%s' % (row['GameID'], row['Date'], row['LineType'], row['TeamOrGame'])

    @staticmethod
    def _make_line_index(row):
        return '%s:%s:%s' % (row['GameID'], row['Date'], row['LineType'])

    @staticmethod
    def _is_valid_blocklist_row(blocklist_row):
        for h in ['GameID', 'LineDate', 'BlockReason']:
            if h not in blocklist_row or not blocklist_row[h]:
                return False
        return True

    @staticmethod
    def _is_valid_line_row(line_row):
        for h in ['GameID', 'Date', 'LineType', 'TeamOrGame', 'LineValue', 'LinePrice']:
            if h not in line_row or not line_row[h]:
                return False
        return line_row['LineType'] == betlib.MONEYLINE or line_row['LineType'] == betlib.SPREAD


def main(argv):
    if len(argv) < 3:
        print('Usage: %s <blocklist_tsv> <lines0> [lines1 ...]' % (argv[0]))
        sys.exit(1)
    detector = FlipOddsDetector()
    detector.load_blocklist(argv[1])
    detector.load_lines(argv[2:])
    detector.identify_flips()
    detector.write_blocklist()
    sys.exit(0)


if __name__ == '__main__':
    main(sys.argv)
