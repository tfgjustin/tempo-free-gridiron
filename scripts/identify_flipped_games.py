#!/usr/bin/python3

from collections import defaultdict

import csv
import sys


class FlipDetector(object):
    _BLOCKLIST_TAG = 'HomeAwayFlip'

    def __init__(self):
        self._blocklist_file = None
        # List of dictionaries
        self._cached_blocklist = list()
        self._fieldnames = ['GameID', 'LineDate', 'BlockReason']
        # [game_id:game_date][home:away] = [list of times]
        self._all_events = defaultdict(dict)
        # [game_id] = [list of times]
        self._blocked_events = dict()

    def load_blocklist(self, blocklist_file):
        self._blocklist_file = blocklist_file
        with open(self._blocklist_file, 'r') as infile:
            reader = csv.DictReader(infile, delimiter='\t')
            if reader.fieldnames:
                self._fieldnames = reader.fieldnames
            for row in reader:
                if not self._is_valid_blocklist_row(row):
                    continue
                if row.get('BlockReason', '') != FlipDetector._BLOCKLIST_TAG:
                    self._cached_blocklist.append(row)

    def load_events(self, events_files):
        for event_file in events_files:
            parts = event_file.split('.')
            timestamp = parts[-1]
            with open(event_file, 'r') as infile:
                reader = csv.DictReader(infile, delimiter='\t')
                for row in reader:
                    if not self._is_valid_event_row(row):
                        continue
                    game_key = '%s:%s' % (row['GameID'], row['DateTime'].split('T')[0])
                    team_key = '%s:%s' % (row['Home'], row['Away'])
                    game_times = self._all_events[game_key].get(team_key, list())
                    game_times.append(timestamp)
                    self._all_events[game_key][team_key] = game_times

    def identify_events(self):
        for game_key, game_times in self._all_events.items():
            if len(game_times) == 1:
                continue
            min_time_count = 10000  # Arbitrarily large
            min_key = None
            for k, v in game_times.items():
                if len(v) < min_time_count:
                    min_key = k
                    min_time_count = len(v)
            self._blocked_events[game_key] = game_times[min_key]

    def write_blocklist(self):
        if self._blocklist_file is None:
            return
        with open(self._blocklist_file, 'w') as outfile:
            writer = csv.DictWriter(outfile, fieldnames=self._fieldnames, delimiter='\t')
            writer.writeheader()
            for row in self._cached_blocklist:
                writer.writerow(row)
            for k, v in self._blocked_events.items():
                out_dict = dict()
                out_dict['GameID'] = k.split(':')[0]
                out_dict['BlockReason'] = FlipDetector._BLOCKLIST_TAG
                for timestamp in v:
                    out_dict['LineDate'] = timestamp
                    writer.writerow(out_dict)

    @staticmethod
    def _is_valid_blocklist_row(blocklist_row):
        for h in ['GameID', 'LineDate', 'BlockReason']:
            if h not in blocklist_row or not blocklist_row[h]:
                return False
        return True

    @staticmethod
    def _is_valid_event_row(event_row):
        for h in ['GameID', 'DateTime', 'Home', 'Away']:
            if h not in event_row or not event_row[h]:
                return False
        return True


def main(argv):
    if len(argv) < 3:
        print('Usage: %s <blocklist_tsv> <events0> [events1 ...]' % (argv[0]))
        sys.exit(1)
    detector = FlipDetector()
    detector.load_blocklist(argv[1])
    detector.load_events(argv[2:])
    detector.identify_events()
    detector.write_blocklist()
    sys.exit(0)


if __name__ == '__main__':
    main(sys.argv)
