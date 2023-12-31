#include <string>
#include <vector>
#include <map>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include "tempo-free.h"
#include "utillog.h"

typedef map<int, vector<string> > WeekToDataMap;

namespace {

enum SummaryCols {
  WEEK        = 0,
  DATE        = 1,
  GAME_ID     = 2,
  SITE        = 3,
  NUM_POSS    = 4,
  TEAM1_ID    = 5,
  TEAM1_NAME  = 6,
  TEAM1_SCORE = 7,
  TEAM2_ID    = 8,
  TEAM2_NAME  = 9,
  TEAM2_SCORE = 10,
  NUM_COLS
};

bool extract_input(const string& line, vector<char*>* items, string* game_id,
                   string* stadium, int* homeid, int* awayid, int* week)
{
  if (!items || !game_id || !homeid || !awayid || !week) {
    fprintf(stderr, "Bad parameters\n");
    return false;
  }

  bool rc = false;
  char buf[1536];
  do {
    strncpy(buf, line.c_str(), line.size());
    buf[line.size()] = '\0';
    SplitCSV(buf, items);
    if (items->size() < NUM_COLS)
      break;
    if (!items->at(GAME_ID))
      break;
    *game_id = items->at(GAME_ID);

    if (!items->at(TEAM1_ID) || !items->at(TEAM2_ID))
      break;
    if (!items->at(TEAM1_NAME) || !items->at(TEAM2_NAME))
      break;
    if (!items->at(SITE))
      break;
    *stadium = items->at(SITE);
    char* q;
    int h = strtol(items->at(TEAM1_ID), &q, 10);
    if (items->at(TEAM1_ID) == q)
      break;
    int a = strtol(items->at(TEAM2_ID), &q, 10);
    if (items->at(TEAM2_ID) == q)
      break;
    int w = strtol(items->at(WEEK), &q, 10);
    if (items->at(WEEK) == q)
      break;
    if (!strcmp(items->at(SITE), "NEUTRAL")) {
      *homeid = h;
      *awayid = a;
    } else if (!strcmp(items->at(SITE), items->at(TEAM1_NAME))) {
      *homeid = h;
      *awayid = a;
    } else if (!strcmp(items->at(SITE), items->at(TEAM2_NAME))) {
      *homeid = a;
      *awayid = h;
    }
    *week = w;
    rc = true;
  } while (0);

  return rc;
}

void predict_games(const string& tag, TempoFree* tf,
                   const vector<string>& to_predict) {
  if (!tf || to_predict.empty())
    return;
  vector<char*> items;
  string game_id;
  string stadium;
  int home_id;
  int away_id;
  int week;
  for (int i = 0; i < static_cast<int>(to_predict.size()); ++i) {
    if (!extract_input(to_predict[i], &items, &game_id, &stadium,
                       &home_id, &away_id, &week)) {
      continue;
    }
    vector<int> scores = tf->predict(stadium, game_id.substr(0, 8),
                                     home_id, away_id);
    if (scores.size() < 2) {
      fprintf(stdout, "Missing results for %d vs %d\n", home_id, away_id);
      continue;
    }
    bool is_neutral = false;
    if (stadium == "NEUTRAL")
      is_neutral = true;
    printf("PREDICT,%s,%s,%d,%5d,%2d,%5d,%2d", tag.c_str(),
           game_id.c_str(), is_neutral, home_id, scores[0], away_id, scores[1]);
    if (scores.size() > 3) {
      printf(",%4d", scores[2]);
      if (scores.size() >= 5) {
        printf(",%4d,%4d", scores[3], scores[4]);
        if (scores.size() >= 6) {
          printf(",%3d", scores[5]);
        }
      }
    }
    printf("\n");
  }
}

bool load_file(char* fname, vector<string>* data) {
  if (!fname || !*fname || !data)
    return false;

  data->clear();
  char buf[BUFSIZ];
  FILE* fp = fopen(fname, "r");
  if (!fp)
    return false;
  while (fgets(buf, BUFSIZ, fp)) {
    char* p = strrchr(buf, '\n');
    if (p) *p = '\0';
    p = strrchr(buf, '\r');
    if (p) *p = '\0';
    data->push_back(buf);
  }
  fclose(fp);
  return true;
}

void split_games_to_weeks(const vector<string>& games, WeekToDataMap* week2games)
{
  if (!week2games)
    return;

  char *q;
  for (unsigned int i = 0; i < games.size(); ++i) {
    string wbuf(games[i].substr(0, games[i].find(',')));
    int week = strtol(wbuf.c_str(), &q, 10);
    if (q == wbuf.c_str()) {
      continue;
    }
    WeekToDataMap::iterator it = week2games->find(week);
    if (it == week2games->end()) {
      vector<string> week_g;
      week_g.push_back(games[i]);
      if (!week2games->insert(make_pair(week, week_g)).second) {
        fprintf(stderr, "Error creating vector for week %d\n", week);
      }
    } else {
      it->second.push_back(games[i]);
    }
  }
}

void usage(char* progname) {
  fprintf(stderr, "\n");
  fprintf(stderr, "%s -s <summary_file> -t <to_predict> ", progname);
  fprintf(stderr, "[-e <exponent>] [-w <week_age_factor>\n");
  fprintf(stderr, "[-b <bowl_decay_factor] [-p <point_weight_factor>]\n");
  fprintf(stderr,"\t[-y <yard_weight_factor>] ");
  fprintf(stderr, "[-c <cutoff_age] [-n <num_adjustments>]\n");
  fprintf(stderr, "\n");
  exit(EXIT_FAILURE);
}

}  // namespace

int main(int argc, char** argv) {
  if (argc < 3) {
    usage(argv[0]);
  }

  vector<string> games;
  vector<string> to_predict;
  string games_file;
  string predict_file;
  float exponent = -1;
  float week_age_factor = -1;
  float bowl_factor = -1;
  float point_weight_factor = -1;
  float yard_weight_factor = -1;
  int num_adjustments = -1;
  int cutoff_weeks = -1;
  char c;
  opterr = 0;
  FILE* log_stream = stderr;
  while ((c = getopt(argc, argv, "s:t:e:w:p:y:c:a:l:b:")) > 0) {
    switch (c) {
      case 's':
        if (NULL == optarg || !(*optarg) || !load_file(optarg, &games)) {
          fprintf(stderr, "Error loading game data file.\n");
          usage(argv[0]);
        }
        break;
      case 't':
        if (NULL == optarg || !(*optarg) || !load_file(optarg, &to_predict)) {
          fprintf(stderr, "Error loading to-predict data file.\n");
          usage(argv[0]);
        }
        break;
      case 'e':
        if (NULL == optarg || !(*optarg)) {
          fprintf(stderr, "Invalid or missing exponent value.\n");
          usage(argv[0]);
        } else {
          char* q;
          exponent = strtof(optarg, &q);
          if (q == optarg || *q) {
            fprintf(stderr, "Invalid exponent: %s\n", optarg);
            usage(argv[0]);
          }
        }
        break;
      case 'b':
        if (NULL == optarg || !(*optarg)) {
          fprintf(stderr, "Invalid or missing bowl-decay value.\n");
          usage(argv[0]);
        } else {
          char* q;
          bowl_factor = strtof(optarg, &q);
          if (q == optarg || *q || bowl_factor <= 0 || bowl_factor > 1) {
            fprintf(stderr, "Invalid bowl decay factor: %s %f '%02x'\n", optarg, bowl_factor, *q);
            usage(argv[0]);
          }
        }
        break;
      case 'w':
        if (NULL == optarg || !(*optarg)) {
          fprintf(stderr, "Invalid or missing week-aging value.\n");
          usage(argv[0]);
        } else {
          char* q;
          week_age_factor = strtof(optarg, &q);
          if (q == optarg || *q || week_age_factor <= 0 || week_age_factor > 1) {
            fprintf(stderr, "Invalid week age_factor: %s %f '%02x'\n", optarg, week_age_factor, *q);
            usage(argv[0]);
          }
        }
        break;
      case 'p':
        if (NULL == optarg || !(*optarg)) {
          fprintf(stderr, "Invalid or missing point-weight value.\n");
          usage(argv[0]);
        } else {
          char* q;
          point_weight_factor = strtof(optarg, &q);
          if (q == optarg || *q || point_weight_factor <= 0
              || point_weight_factor > 1) {
            fprintf(stderr, "Invalid point weight factor: %s\n", optarg);
            usage(argv[0]);
          }
        }
        break;
      case 'y':
        if (NULL == optarg || !(*optarg)) {
          fprintf(stderr, "Invalid or missing yard-weight value.\n");
          usage(argv[0]);
        } else {
          char* q;
          yard_weight_factor = strtof(optarg, &q);
          if (q == optarg || *q || yard_weight_factor < 0
              || yard_weight_factor > 1) {
            fprintf(stderr, "Invalid yard weight factor: %s\n", optarg);
            usage(argv[0]);
          }
        }
        break;
      case 'c':
        if (NULL == optarg || !(*optarg)) {
          fprintf(stderr, "Invalid or missing week cutoff value.\n");
          usage(argv[0]);
        } else {
          char* q;
          cutoff_weeks = strtol(optarg, &q, 10);
          if (q == optarg || *q || cutoff_weeks <= 0) {
            fprintf(stderr, "Invalid cutoff weeks: %s %d '%02x'\n", optarg, cutoff_weeks, *q);
            usage(argv[0]);
          }
        }
        break;
      case 'a':
        if (NULL == optarg || !(*optarg)) {
          fprintf(stderr, "Invalid or missing number of asjustments value.\n");
          usage(argv[0]);
        } else {
          char* q;
          num_adjustments = strtol(optarg, &q, 10);
          if (q == optarg || *q || num_adjustments <= 0) {
            fprintf(stderr, "Invalid adjustment iterations: %s %d '%02x'\n", optarg, num_adjustments, *q);
            usage(argv[0]);
          }
        }
        break;
      case 'l':
        if (NULL == optarg || !(*optarg)) {
          fprintf(stderr, "Invalid or missing logfile value.\n");
          usage(argv[0]);
        }
        {
          FILE* fp = fopen(optarg, "a");
          if (NULL == fp) {
            fprintf(stderr, "Error opening logfile %s\n", optarg);
            usage(argv[0]);
          }
          log_stream = fp;
        }
        break;
      default:
        fprintf(stderr, "Invalid argument: %c\n", c);
        usage(argv[0]);
    }
  }
  set_log_stream(log_stream);
  set_log_level(S_DEBUG);
  WeekToDataMap week2games;
  split_games_to_weeks(games, &week2games);

  TempoFree* tf = new TempoFree;
  if (exponent > 0) {
    tf->set_py_exp(exponent);
  }
  if (week_age_factor > 0) {
    tf->set_age_factor(week_age_factor);
  }
  if (bowl_factor > 0) {
    tf->set_bowl_factor(bowl_factor);
  }
  if (point_weight_factor > 0) {
    tf->set_point_weight_factor(point_weight_factor);
  }
  if (yard_weight_factor > 0) {
    tf->set_yard_weight_factor(yard_weight_factor);
  }
  if (cutoff_weeks > 0) {
    tf->set_cutoff_weeks(cutoff_weeks);
  }
  if (num_adjustments > 0) {
    tf->set_num_adjust_iterations(num_adjustments);
  }

//  const int min_season_diff = 30;
  int last_week = week2games.begin()->first;
  PerGameDrives drives;
  for (WeekToDataMap::iterator w2g_it = week2games.begin();
       w2g_it != week2games.end();
       ++w2g_it) {
//    if ((w2g_it->first - last_week) > min_season_diff)
//    if (w2g_it->first > 150)
    tf->PrintTeamStats(last_week);
    predict_games("PARTIAL", tf, w2g_it->second);
    tf->data(w2g_it->second, drives);
    last_week = w2g_it->first;
  }
//  tf->print_adjusted_gamelog();
  tf->freshen_stats(last_week);
  tf->PrintTeamStats(last_week);
  tf->clear_prediction_cache();
  predict_games("ALLDONE", tf, to_predict);
  fflush(stdout);
  fflush(stderr);
  delete tf;
  if (log_stream != stderr)
    fclose(log_stream);

  return 0;
}
