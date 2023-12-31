#include <utility>
#include <time.h>
#include <vector>
#include <string>
#include <map>
#include <set>

#include <math.h>
#include <stdlib.h>
#include <string.h>

#include "tempo-free.h"
#include "utillog.h"

using namespace std;

namespace {

typedef pair<int, int> WinLossRecord;

float point_weight_factor = 1.0;
float yard_weight_factor = 0.0;

// The minimum number of scores we need in a bucket to make it
// worthwhile
const int min_scores_for_bucket = 100;
const int min_scores_for_stats = 600;
const int min_margins_for_stats = min_scores_for_stats / 2;
const int score_search_radius = 2;
const int max_season_weeks = 30;
const float default_py_exp_ = 2.7;
const float default_age_factor = 0.965;
const long seconds_per_game = 15 * 60 * 2 * 2;

const char kNeutralSite[] = "NEUTRAL";

inline float log5winpct(float home, float away) {
  return ((home - (home * away)) / ((home + away - (2 * home * away))));
}

inline float pythag_winpct(float pf, float pa, float py_exp) {
  return (1.0 / (1.0 + powf(pa / pf, py_exp)));
}

inline float get_points_for(const UnitData& team) {
  float pf = (team.points_for() * point_weight_factor)
             + (team.yards_for() * yard_weight_factor);
//  printf(" PF %7.3f TPF %7.3f PWF %5.3f TYF %7.3f YWF %5.3f\n",
//         pf, team.points_for(), point_weight_factor, team.yards_for(),
//         yard_weight_factor);
//TODO: Remove this hack
  return pf;// 1.13;
}

inline float get_points_against(const UnitData& team) {
  float pa = (team.points_against() * point_weight_factor)
           + (team.yards_against() * yard_weight_factor);
//  printf(" PA %7.3f TPA %7.3f PWF %5.3f TYA %7.3f YWF %5.3f\n",
//         pa, team.points_against(), point_weight_factor, team.yards_against(),
//         yard_weight_factor);
//TODO: Remove this hack
  return pa;// 1.13;
}

void clear_perteam_games(PerTeamGameData* ptgd) {
  if (!ptgd) return;
  for (PerTeamGameData::iterator it = ptgd->begin();
       it != ptgd->end();
       ++it) {
    TeamGames& tg = it->second;
    for (unsigned int i = 0; i < tg.size(); ++i)
      delete tg[i];
  }
  ptgd->clear();
}

long date_to_week_num(const string& date) {
  struct tm tm;
  tm.tm_sec = tm.tm_min = tm.tm_hour = 0;
  tm.tm_year = strtol(date.substr(0, 4).c_str(), NULL, 10) - 1900;
  tm.tm_mon = strtol(date.substr(4, 2).c_str(), NULL, 10) - 1;
  tm.tm_mday = strtol(date.substr(6, 2).c_str(), NULL, 10);
  // 967003200 is the official start time of the TFG era
  return (mktime(&tm) - 967003200) / (7 * 24 * 3600);
}

long is_bowl_game(const string& date) {
  const char* month = date.substr(4, 2).c_str();
  if (!strncmp(month, "01", 2)) {
    return true;
  } else if (strncmp(month, "12", 2)) {
    return false;
  } else {
    long day = strtol(date.substr(6, 2).c_str(), NULL, 10);
    return day >= 15;
  }
}

WinLossRecord get_win_loss_record(const TeamGames& games) {
  WinLossRecord record(0, 0);
  int max_week = 0;
  for (int i = 0; i < games.size(); ++i) {
    if (games[i]->week_num() > max_week)
      max_week = games[i]->week_num();
  }
  for (int i = 0; i < games.size(); ++i) {
    if ((max_week - games[i]->week_num()) > max_season_weeks)
      continue;
    if (games[i]->team().points_for() > games[i]->team().points_against())
      record.first++;
    else
      record.second++;
  }
  return record;
}

}  // namespace

////////////////////////////////////////////////////////////////////////////////
/////////////////////////////// Member Functions ///////////////////////////////
////////////////////////////////////////////////////////////////////////////////
TempoFree::TempoFree()
  : dirty_(false), points_freq_(max_points, 0), total_points_(0),
    margin_freq_(max_points, 0), total_margins_(0),
    error_buckets_(num_error_buckets, PointsCount(max_points, 0)),
    perbucket_count_(num_error_buckets, 0),
    total_errors_(0),  py_exp_(default_py_exp_), age_factor_(default_age_factor),
    point_weight_factor_(1.0), yard_weight_factor_(0.0), cutoff_age_(175),
    num_adjust_iterations_(2)
{
  adjust_factors_.insert(make_pair("090", 1.0550));
  adjust_factors_.insert(make_pair("091", 1.0415));
  adjust_factors_.insert(make_pair("100", 1.0375));
  adjust_factors_.insert(make_pair("101", 1.0475));
  adjust_factors_.insert(make_pair("110", 1.0175));
  adjust_factors_.insert(make_pair("111", 1.0000));
}

TempoFree::~TempoFree() {
  clear_perteam_games(&raw_perteam_games_);
  clear_perteam_games(&adj_perteam_games_);
}

int TempoFree::data(const vector<string>& summaries, const PerGameDrives& drives) {
  vector<char*> columns;
  for (int i = 0; i < static_cast<int>(summaries.size()); ++i) {
    parse_one_summary(summaries[i], drives, &columns);
  }

  dirty_ = true;

  point_weight_factor = point_weight_factor_;
  yard_weight_factor = yard_weight_factor_;
//  printf(" WEIGHT PWF=%5.3f YWF=%5.3f\n", point_weight_factor, yard_weight_factor);

  return 0;
}

vector<int> TempoFree::predict(const string& stadium, const string& date,
                               int homeid, int awayid) {
  bool is_neutral = true;
  char gid[128];
  int home_score, away_score;
  int num_plays;
  float winpct;
  vector<int> results;

  snprintf(gid, 128, "%s:%d", date.substr(0, 8).c_str(), homeid);

  if (stadium != kNeutralSite) {
    is_neutral = false;
  }

  freshen_stats(date_to_week_num(date));
  Predictions::iterator it = raw_predictions_.find(gid);
  DateAdjustMap::iterator wit = raw_winpct_.find(gid);
  DateAdjustMap::iterator pit = raw_num_plays_.find(gid);
  if (it == raw_predictions_.end() || wit == raw_winpct_.end()
      || pit == raw_num_plays_.end()) {
    // Get the two team's full data
    PerTeamAverages::iterator h_it = adj_averages_.find(homeid);
    PerTeamAverages::iterator a_it = adj_averages_.find(awayid);
    GameData *home = NULL, *away = NULL;
    if (h_it == adj_averages_.end()) {
      home = &adj_average_team_;
    } else {
      home = &h_it->second;
    }
    if (a_it == adj_averages_.end()) {
      away = &adj_average_team_;
    } else {
      away = &a_it->second;
    }
    if (!home->team().points_for() && !away->team().points_for()) {
      // We have no adjusted average data yet. Fall back on the braindead default.
      results.push_back(17);
      results.push_back(10);
      results.push_back(624);
      results.push_back(160);
      results.push_back(500);
      results.push_back(500);
    }

    int hs = 0, as = 0;
    raw_prediction(date, is_neutral, &h_it->second, &a_it->second,
                   &hs, &as, &winpct, &num_plays);
    if ((hs < 0) || (as < 0)) {
      s_log(S_WARNING, "Invalid raw prediction %d at %d [ %d , %d ]\n",
            homeid, awayid, hs, as);
      results.push_back(-1);
      results.push_back(-1);
      results.push_back(-1000);
      results.push_back(-1);
      results.push_back(-1);
      results.push_back(-1);
      return results;
    }
    home_score = hs;
    away_score = as;
    results.push_back(home_score);
    results.push_back(away_score);
    if ((winpct > .5000) && (results[0] < results[1])) {
      s_log(S_DEBUG, "SWAP GID=%s WinPct=%.4f HS=%d AS=%d\n",
            gid, winpct, home_score, away_score);
      int tmp = results[0];
      results[0] = results[1];
      results[1] = tmp;
    } else if ((winpct < .5000) && (results[0] > results[1])) {
      s_log(S_DEBUG, "SWAP GID=%s WinPct=%.4f HS=%d AS=%d\n",
            gid, winpct, home_score, away_score);
      int tmp = results[0];
      results[0] = results[1];
      results[1] = tmp;
    }
    if ((results[0] / 100) == (results[1] / 100)) {
      if (winpct > .5000) {
        results[0] += 99;
        results[1] -= 99;
      } else {
        results[0] -= 99;
        results[1] += 99;
      }
    }
    home_score = results[0] / 100;
    away_score = results[1] / 100;
    results.push_back(static_cast<int>(1000 * winpct));
  
    // Stash the raw prediction here
    raw_predictions_.insert(make_pair(gid, make_pair(home_score, away_score)));
    raw_winpct_.insert(make_pair(gid, winpct));
    raw_num_plays_.insert(make_pair(gid, static_cast<float>(num_plays)));
  } else {
    home_score = it->second.first;
    away_score = it->second.second;
    winpct = wit->second;
    num_plays = static_cast<int>(pit->second);
    results.push_back(home_score);
    results.push_back(away_score);
    results.push_back(static_cast<int>(1000 * winpct));
  }
  results.push_back(num_plays);
  int best_home = home_score;
  int best_away = away_score;
//  best_prediction(winpct, home_score, away_score, &best_home, &best_away);
//  if (home_score > away_score) {
//    if (best_home < best_away) {
//      s_log(S_NOTICE, "Game %s flipped! [ %2d %2d ] => [ %2d %2d ] %.3f\n",
//            gid, home_score, away_score, best_home, best_away, winpct);
//      best_home = home_score;
//      best_away = away_score;
//    }
//  } else {
//    if (best_home > best_away) {
//      s_log(S_NOTICE, "Game %s flipped! [ %2d %2d ] => [ %2d %2d ] %.3f\n",
//            gid, home_score, away_score, best_home, best_away, winpct);
//      best_home = home_score;
//      best_away = away_score;
//    }
//  }
  results[0] = best_home;
  results[1] = best_away;

  TeamWinPct::iterator hsos_it = sos_.find(homeid);
  TeamWinPct::iterator asos_it = sos_.find(awayid);
  if ((hsos_it == sos_.end()) || (asos_it == sos_.end())) {
    results.push_back(-1);
    results.push_back(-1);
  } else {
    results.push_back(static_cast<int>(hsos_it->second * 1000));
    results.push_back(static_cast<int>(asos_it->second * 1000));
  }
  results.push_back(num_plays);

  return results;
}

void TempoFree::PrintTeamStats(const int week_num) const {
  s_log(S_INFO, "IS_DIRTY %d\n", dirty_);
  s_log(S_INFO, "PF=%5.2f PA=%5.2f YPH=%5.2f\n",
        get_points_for(adj_average_team_.team()),
        get_points_against(adj_average_team_.team()),
        adj_average_team_.team().num_plays());
  for (TeamWinPct::const_iterator win_it = win_pcts_.begin();
       win_it != win_pcts_.end();
       ++win_it) {
    TeamWinPct::const_iterator sos_it = sos_.find(win_it->first);
    if (sos_it == sos_.end()) {
      s_log(S_WARNING, "ERROR: No SOS for team %ld\n", win_it->first);
      continue;
    }
    TeamNameMap::const_iterator id2name = team_id_to_name_.find(win_it->first);
    if (id2name == team_id_to_name_.end()) {
      s_log(S_WARNING, "ERROR: No name for team %ld\n", win_it->first);
      continue;
    }
    PerTeamGameData::const_iterator ptgd_it = adj_perteam_games_.find(win_it->first);
    if (ptgd_it == adj_perteam_games_.end()) {
      s_log(S_WARNING, "ERROR: No per-game data for %s\n",
            id2name->second.c_str());
      continue;
    }
    if (ptgd_it->second.size() < 4) {
      s_log(S_DEBUG, "WARNING: Too few games for %s: %d\n",
            id2name->second.c_str(),
            static_cast<int>(ptgd_it->second.size()));
      continue;
    }
    PerTeamGameData::const_iterator raw_ptgd_it;
    raw_ptgd_it = raw_perteam_games_.find(win_it->first);
    if (raw_ptgd_it == raw_perteam_games_.end()) {
      s_log(S_WARNING, "ERROR: No raw per-game data for %s\n",
            id2name->second.c_str());
      continue;
    }
    PerTeamAverages::const_iterator pta_it = adj_averages_.find(win_it->first);
    if (pta_it == adj_averages_.end()) {
      s_log(S_WARNING, "No averages for %s (?)\n", id2name->second.c_str());
      continue;
    }
    WinLossRecord record = get_win_loss_record(raw_ptgd_it->second);
    const UnitData& ud = pta_it->second.team();
    fprintf(stdout, "RANKING,%d,%ld,%.5f,%.5f,%.1f,%.1f,%.1f,%.1f,%.1f,%.1f,%d,%d,%.1f\n",
            week_num, id2name->first, win_it->second, sos_it->second,
            get_points_for(ud), get_points_against(ud), ud.points_for(),
            ud.points_against(), ud.yards_for(), ud.yards_against(),
            record.first, record.second, ud.num_plays() * 2);
  }
}

// The summary columns we care about, indexed from 0
enum SummaryCols {
  WEEKNUM      = 0,
  DATE         = 1,
  GAME_ID      = 2,  // Unique identifier for this game (a string)
  SITE         = 3,
  NUM_POSS     = 4,
  HOME_ID      = 5,  // Unique identifier of the home team
  HOME_NAME    = 6,
  HOMESCORE    = 7,
  VISITOR_ID   = 8,  // Unique identifier of the visiting team
  VISITOR_NAME = 9,
  VISITORSCORE = 10,
  HOMEYARDS    = 11,
  VISITORYARDS = 12,
  NUM_COLUMNS  = 13  // Max number of columns in this line
};

void TempoFree::parse_one_summary(const string& summary,
                                  const PerGameDrives& drives,
                                  vector<char*>* columns) {
  if (!columns || summary.empty())
    return;

  char buf[2048];
  strncpy(buf, summary.c_str(), summary.length());
  buf[summary.length()] = '\0';
  SplitCSV(buf, columns);
  PerGameDrives::const_iterator drive_iter = drives.find(columns->at(GAME_ID));
  const Drives* drive = NULL;
  if (drive_iter != drives.end()) {
    drive = &(drive_iter->second);
  }
  GameData *home_team = new GameData;
  GameData *away_team = new GameData;
  if (fill_summaries(home_team, away_team, columns)) {
    add_summary(&raw_perteam_games_, away_team->opp_id(), home_team);
    add_summary(&raw_perteam_games_, home_team->opp_id(), away_team);
    all_games_[columns->at(GAME_ID)] = make_pair(home_team, away_team);
  } else {
    delete home_team;
    delete away_team;
  }
}

bool TempoFree::fill_summaries(GameData* home, GameData* away,
                               vector<char*>* columns) {
  if (!home || !away || !columns)
    return false;

  if (columns->size() < NUM_COLUMNS)
    return false;
  long home_id, away_id;
  long num_plays;
  double home_score, away_score;
  double home_yards, away_yards;
  if (!columns->at(HOME_ID) || !columns->at(VISITOR_ID)
      || !columns->at(HOMESCORE) || !columns->at(VISITORSCORE)
      || !columns->at(GAME_ID) || !columns->at(NUM_POSS)
      || !columns->at(SITE) || !columns->at(HOMEYARDS)
      || !columns->at(VISITORYARDS)) {
    return false;
  }
  char* q;
  home_id = strtol(columns->at(HOME_ID), &q, 10);
  if (columns->at(HOME_ID) == q)
    return false;
  away_id = strtol(columns->at(VISITOR_ID), &q, 10);
  if (columns->at(VISITOR_ID) == q)
    return false;
  num_plays = strtol(columns->at(NUM_POSS), &q, 10);
  if (columns->at(NUM_POSS) == q)
    return false;

  home_score = strtod(columns->at(HOMESCORE), &q);
  if (columns->at(HOMESCORE) == q)
    return false;
  away_score = strtod(columns->at(VISITORSCORE), &q);
  if (columns->at(VISITORSCORE) == q)
    return false;

  home_yards = strtod(columns->at(HOMEYARDS), &q);
  if (columns->at(HOMEYARDS) == q)
    return false;
  away_yards = strtod(columns->at(VISITORYARDS), &q);
  if (columns->at(VISITORYARDS) == q)
    return false;

  if (!num_plays || (!home_score && !away_score))
    return false;

  // Run a prediction to fill out the predictions map for this game
  predict(columns->at(SITE), columns->at(GAME_ID), home_id, away_id);

  bool is_neutral = false;
  if (!strcmp(kNeutralSite, columns->at(SITE)))
    is_neutral = true;
  bool is_bowl = is_bowl_game(columns->at(GAME_ID));

  home->set_is_neutral(is_neutral);
  home->set_is_bowl(is_bowl);
  home->set_game_id(columns->at(GAME_ID));
  home->set_week_num(date_to_week_num(home->game_id()));
  home->set_team_id(home_id);
  home->set_opp_id(away_id);
  away->set_is_neutral(is_neutral);
  away->set_is_bowl(is_bowl);
  away->set_game_id(columns->at(GAME_ID));
  away->set_week_num(date_to_week_num(away->game_id()));
  away->set_team_id(away_id);
  away->set_opp_id(home_id);
  home->mutable_team()->set_points_for(home_score);
  home->mutable_team()->set_points_against(away_score);
  away->mutable_team()->set_points_for(away_score);
  away->mutable_team()->set_points_against(home_score);
  home->mutable_team()->set_yards_for(home_yards);
  home->mutable_team()->set_yards_against(away_yards);
  away->mutable_team()->set_yards_for(away_yards);
  away->mutable_team()->set_yards_against(home_yards);
  add_final_score(home_score);
  add_final_score(away_score);
  add_score_errors(home->game_id().substr(0, 8), home->team_id(),
                   home_score, away_score);
  add_final_margin(abs(home_score - away_score));
  home->mutable_team()->set_num_plays(num_plays);
  away->mutable_team()->set_num_plays(num_plays);
  home->mutable_team()->set_time_in_secs(seconds_per_game);
  away->mutable_team()->set_time_in_secs(seconds_per_game);
  home->mutable_team()->set_game_count(1.0);
  away->mutable_team()->set_game_count(1.0);

  set_team_name(home_id, columns->at(HOME_NAME));
  set_team_name(away_id, columns->at(VISITOR_NAME));

  return true;
}

void TempoFree::add_summary(PerTeamGameData* ptgd, long team_id,
                            GameData* gdata) {
  if (!ptgd || !gdata)
    return;

  PerTeamGameData::iterator it = ptgd->find(team_id);
  if (it == ptgd->end()) {
    vector<GameData*> gdata_vec;
    gdata_vec.push_back(gdata);
    ptgd->insert(make_pair(team_id, gdata_vec));
  } else {
    it->second.push_back(gdata);
  }
}

void TempoFree::add_prediction_error(int predict, int actual) {
  if (total_points_ < min_scores_for_stats)
    return;

  int bucket_num = predict / bucket_size;
  if (bucket_num >= num_error_buckets)
    return;

  error_buckets_[bucket_num][actual]++;
  perbucket_count_[bucket_num]++;
  total_errors_++;
}

void TempoFree::freshen_stats(long week_num) {
  if (!dirty_) {
    s_log(S_DEBUG, "No new stats on week %ld; skipping.\n", week_num);
    return;
  }

  calculate_raw_efficiencies(week_num);
  calculate_adj_efficiencies(week_num);
  calculate_pythagorean();
  calculate_sos(week_num);
  dirty_ = false;
}

void TempoFree::calculate_raw_efficiencies(long week_num) {
  float pre_normal_points = 0, pre_normal_plays = 0;
  for (PerGameData::iterator it = all_games_.begin();
       it != all_games_.end();
       ++it) {
    GameData* h_gd = it->second.first;
    GameData* a_gd = it->second.second;
    float remove_pa_adv = date_to_factor(it->first);
    float remove_pf_adv = 2 - remove_pa_adv;
    if (!h_gd->is_normalized()) {
      pre_normal_points += h_gd->team().points_for();
      pre_normal_plays += h_gd->team().num_plays();
      s_log(S_DLOOP, "NORMAL HOME %s\n", it->first.c_str());
      // Remove the home team's advantage from its offense and the
      // visitor's disadvantage w.r.t. the defense.
      if (!h_gd->is_neutral())
        h_gd->points_multipliers(remove_pf_adv, remove_pa_adv);
      else
        s_log(S_DLOOP, "Not adjusting home team for %s\n", it->first.c_str());
      h_gd->normalize_efficiency();
    }
    if (!a_gd->is_normalized()) {
      pre_normal_points += a_gd->team().points_for();
      pre_normal_plays += a_gd->team().num_plays();
      s_log(S_DLOOP, "NORMAL AWAY %s\n", it->first.c_str());
      // Do the opposite for the visitors
      if (!a_gd->is_neutral())
        a_gd->points_multipliers(remove_pa_adv, remove_pf_adv);
      else
        s_log(S_DLOOP, "Not adjusting away team for %s\n", it->first.c_str());
      a_gd->normalize_efficiency();
    }
  }
  calculate_averages(&raw_perteam_games_, &raw_averages_, &raw_average_team_, week_num);
  s_log(S_INFO, "RAW0 Week %3ld PreNormPts %8.1f PreNormPlays %8.1f PreNormPPH %5.2f\n",
        week_num, pre_normal_points, pre_normal_plays,
        pre_normal_plays ?  pre_normal_points / (pre_normal_plays / 100) : 0.0);
  s_log(S_INFO, "RAW0 Week %3ld AvgFor %5.2f AvgAga %5.2f AvgPlay %5.1f ",
        week_num, raw_average_team_.team().points_for(),
        raw_average_team_.team().points_against(),
        raw_average_team_.team().num_plays());
}

void TempoFree::calculate_averages(PerTeamGameData* perteam_games,
                                   PerTeamAverages* averages,
                                   GameData* average_team,
                                   long week_num) {
  averages->clear();
  average_team->clear();
  for (PerTeamGameData::iterator it = perteam_games->begin();
       it != perteam_games->end();
       ++it) {
    GameData avg;
    long tid = it->first;
    const TeamGames& games = it->second;
    for (unsigned int i = 0; i < games.size(); ++i) {
      long game_week = date_to_week_num(games.at(i)->game_id());
      if ((week_num - game_week) > cutoff_age_) {
        continue;
      }
      avg.add(*(games[i]));
      average_team->add(*(games[i]));
    }
    avg.normalize_pergame();
    averages->insert(make_pair(tid, avg));
  }
  average_team->normalize_pergame();
}

void TempoFree::calculate_adj_efficiencies(long curr_week) {
  // Initially just use raw efficiencies for adjusted data.
  adj_averages_.clear();
  adj_averages_.insert(raw_averages_.begin(), raw_averages_.end());
  // At this point, all_games_ contains all the normalized efficiencies
  // for each game.  Go through and create new adjusted GameData.
  // See what happens when we do it twice
  float post_normal_points, post_normal_plays;
  for (int i = 0; i < num_adjust_iterations_; ++i) {
    post_normal_points = post_normal_plays = 0.0;
    clear_perteam_games(&adj_perteam_games_);
    for (PerGameData::iterator it = all_games_.begin();
         it != all_games_.end();
         ++it) {
      GameData* h_gd = it->second.first;
      GameData* a_gd = it->second.second;

      PerTeamAverages::iterator ha_it = adj_averages_.find(h_gd->team_id());
      if (ha_it == adj_averages_.end()) {
        continue;
      }
      PerTeamAverages::iterator aa_it = adj_averages_.find(a_gd->team_id());
      if (aa_it == adj_averages_.end()) {
        continue;
      }

      float weeks_since = curr_week - h_gd->week_num();
      if (static_cast<int>(weeks_since) >= cutoff_age_) {
        continue;
      }
      float factor = decay_factor(weeks_since, h_gd->is_bowl());

      GameData* home_adj = new GameData(*h_gd);
      GameData* away_adj = new GameData(*a_gd);
      s_log(S_DLOOP, "Week=%03ld Game=%s Neutral=%d%d Home=%ld Away=%ld Decay=%.6f\n",
            curr_week, home_adj->game_id().c_str(), home_adj->is_neutral(),
            away_adj->is_neutral(), home_adj->team_id(), away_adj->team_id(),
            factor);
      s_log(S_DLOOP, "  BEF HomeOff=%3.1f HomeDef=%3.1f AwayOff=%3.1f AwayDef=%3.1f\n",
            get_points_for(home_adj->team()), get_points_against(home_adj->team()),
            get_points_for(away_adj->team()), get_points_against(away_adj->team()));
      adjust_one_game(h_gd, &aa_it->second, home_adj);
      adjust_one_game(a_gd, &ha_it->second, away_adj);
      post_normal_points += home_adj->team().points_for();
      post_normal_points += away_adj->team().points_for();
      post_normal_plays += 100;
      s_log(S_DLOOP, "  AFT HomeOff=%3.1f HomeDef=%3.1f AwayOff=%3.1f AwayDef=%3.1f\n",
            get_points_for(home_adj->team()), get_points_against(home_adj->team()),
            get_points_for(away_adj->team()), get_points_against(away_adj->team()));
      if (factor <= 1.0) {
        s_log(S_DLOOP, "Week=%03ld Game=%s Neutral=%d%d Home=%ld Away=%ld Decay=%.6f\n",
              curr_week, home_adj->game_id().c_str(), home_adj->is_neutral(),
              away_adj->is_neutral(), home_adj->team_id(), away_adj->team_id(),
              factor);
        s_log(S_DLOOP, "  BEF HomeOff=%3.1f HomeDef=%3.1f AwayOff=%3.1f AwayDef=%3.1f\n",
              get_points_for(home_adj->team()), get_points_against(home_adj->team()),
              get_points_for(away_adj->team()), get_points_against(away_adj->team()));
        home_adj->decay(factor);
        away_adj->decay(factor);
        s_log(S_DLOOP, "  AFT HomeOff=%3.1f HomeDef=%3.1f AwayOff=%3.1f AwayDef=%3.1f\n",
              get_points_for(home_adj->team()), get_points_against(home_adj->team()),
              get_points_for(away_adj->team()), get_points_against(away_adj->team()));
      }
      add_summary(&adj_perteam_games_, away_adj->opp_id(), home_adj);
      add_summary(&adj_perteam_games_, home_adj->opp_id(), away_adj);
    }
    calculate_averages(&adj_perteam_games_, &adj_averages_, &adj_average_team_,
                       curr_week);
    s_log(S_INFO, "ADJ%d Week %3ld AvgFor %5.2f AvgAga %5.2f AvgPlay %5.1f "
          "PostPts %8.1f PostPlays %8.1f\n",
          i, curr_week, get_points_for(adj_average_team_.team()),
          get_points_against(adj_average_team_.team()),
          adj_average_team_.team().num_plays(), post_normal_points, post_normal_plays);
  }
}

void TempoFree::adjust_one_game(GameData* first_raw, GameData* second_adj,
                                GameData* first_adj) {
  adjust_one_unit(first_raw->mutable_team(), second_adj->mutable_team(),
                  raw_average_team_.mutable_team(), first_adj->mutable_team());
}

void TempoFree::adjust_one_unit(UnitData* first_raw, UnitData* second_adj,
                                UnitData* natl_avg, UnitData* first_adj) {
#define adjust_unit_factor(n , d) \
  if (second_adj->d()) { \
    first_adj->set_ ## n (( first_raw->n() * natl_avg->n() ) / second_adj->d()); \
  }
  adjust_unit_factor(points_for , points_against);
  adjust_unit_factor(points_against , points_for);
  adjust_unit_factor(yards_for , yards_against);
  adjust_unit_factor(yards_against , yards_for);
  adjust_unit_factor(num_plays , num_plays );
}

void TempoFree::calculate_pythagorean() {
  win_pcts_.clear();
  for (PerTeamAverages::iterator it = adj_averages_.begin();
       it != adj_averages_.end();
       ++it) {
    GameData& gd = it->second;
    float winpct;
    winpct = pythag_winpct(get_points_for(gd.team()), get_points_against(gd.team()),
                           py_exp_);
    win_pcts_.insert(make_pair(it->first, winpct));
  }
}

void TempoFree::calculate_sos(long curr_week) {
  sos_.clear();
  for (PerTeamGameData::const_iterator it = adj_perteam_games_.begin();
       it != adj_perteam_games_.end();
       ++it) {
    float opp_count = 0;
    float opp_off_eff = 0.0;
    float opp_def_eff = 0.0;
    const TeamGames& tg = it->second;
    for (int i = 0; i < tg.size(); ++i) {
      PerTeamAverages::const_iterator opp_it;
      float weeks_since = curr_week - tg.at(i)->week_num();
      if (static_cast<int>(weeks_since) > cutoff_age_) {
        continue;
      }
      opp_it  = adj_averages_.find(tg.at(i)->opp_id());
      if (opp_it == adj_averages_.end()) {
        continue;
      }
      float factor = decay_factor(weeks_since, tg.at(i)->is_bowl());
      opp_off_eff += (get_points_for(opp_it->second.team()) * factor);
      opp_def_eff += (get_points_against(opp_it->second.team()) * factor);
      opp_count += factor;
    }
    if (!opp_count)
      continue;
    opp_off_eff /= opp_count;
    opp_def_eff /= opp_count;
    float soswin = pythag_winpct(opp_off_eff, opp_def_eff, py_exp_);
    sos_.insert(make_pair(it->first, soswin));
  }
}

float TempoFree::decay_factor(int weeks_since, bool is_bowl) {
  float factor = powf(age_factor_, weeks_since);
  factor *= (is_bowl ? bowl_factor_ : 1.0);
  return factor;
}

// Get a raw prediction for a single game
void TempoFree::raw_prediction(const string& game_id, bool is_neutral,
                               const GameData* home, const GameData* away,
                               int* home_score, int* away_score,
                               float* winpct, int* plays) {
  float add_pf_adv = 1.0;
  if (!is_neutral) {
    add_pf_adv = date_to_factor(game_id);
  }
  float add_pa_adv = 2 - add_pf_adv;

  float home_off_eff = get_points_for(home->team()) * add_pf_adv;
  float home_def_eff = get_points_against(home->team()) * add_pa_adv;
  float home_win_pct = pythag_winpct(home_off_eff, home_def_eff, py_exp_);
  float away_off_eff = get_points_for(away->team()) * add_pa_adv;
  float away_def_eff = get_points_against(away->team()) * add_pf_adv;
  float away_win_pct = pythag_winpct(away_off_eff, away_def_eff, py_exp_);
  *winpct = log5winpct(home_win_pct, away_win_pct);

  float hs = home_off_eff + away_def_eff;
  float as = away_off_eff + home_def_eff;
  float pace = home->team().num_plays() + away->team().num_plays();
  hs *= (pace / 2);
  as *= (pace / 2);

  *home_score = static_cast<int>(hs);
  *away_score = static_cast<int>(as);
  *plays = static_cast<int>(pace);
  s_log(S_DLOOP, "Date %s AdjHOE %4.1f AdjAOE %4.1f HFAHOE %4.1f HFAAOE %4.1f "
        "AdjHDE %4.1f AdjADE %4.1f HFAHDE %4.1f HFAADE %4.1f\n",
        game_id.substr(0, 8).c_str(), get_points_for(home->team()),
        get_points_for(away->team()), home_off_eff, away_off_eff,
        get_points_against(home->team()), get_points_against(away->team()),
        home_def_eff, away_def_eff);
}

void TempoFree::best_prediction(float h_win, int raw_home, int raw_away,
                                int* best_home, int* best_away) {
  if ((total_errors_ < min_scores_for_stats)
      || (total_margins_ < min_margins_for_stats)
      || (raw_home >= max_points) || (raw_away >= max_points)
      || (perbucket_count_[raw_home / bucket_size] < min_scores_for_bucket)
      || (perbucket_count_[raw_away / bucket_size] < min_scores_for_bucket))
  {
    *best_home = raw_home;
    *best_away = raw_away;
    return;
  }
  PointsFreq home, away;
  apply_error_probs(raw_home, &home);
  apply_error_probs(raw_away, &away);
  apply_final_points_probs(raw_home, &home);
  apply_final_points_probs(raw_away, &away);
  ScoreProbs final_score_probs;
  calculate_final_score_probs(&home, &away, &final_score_probs, h_win);
  maximize_expectation(&final_score_probs, best_home, best_away);
}

// Given how off we've been before, and given a raw prediction for one
// team, see how far off we're likely to be this time.
void TempoFree::apply_error_probs(int raw_points, PointsFreq* points_probs) {
  do {
    points_probs->clear();
    points_probs->insert(points_probs->end(), max_points, 0);
    if (!total_errors_)
      break;
    int bucket = raw_points / bucket_size;
    if (bucket >= num_error_buckets)
      break;

    const PointsCount& pc = error_buckets_[bucket];
    float count = static_cast<float>(perbucket_count_[bucket]);
    if (count < min_scores_for_bucket)
      break;

    int min_range = raw_points - score_search_radius;
    int max_range = raw_points + score_search_radius;
    if (min_range < 0) min_range = 0;
    if (max_range >= max_points) max_range = max_points - 1;
    for (int i = min_range; i <= max_range; ++i) {
      if (pc[i] > 0) {
        (*points_probs)[i] = pc[i] / count;
      }
    }
    return;
  } while (0);
  (*points_probs)[raw_points] = 1.0;
}

// Given a distribution of likely points, multiply each bucket by the
// likelihood that number of points will be at all
void TempoFree::apply_final_points_probs(int raw_points,
                                         PointsFreq* points_probs) {
  PointsFreq updated_probs(max_points, 0.0);
  float total_probs = 0.0;
  int min_range = raw_points - score_search_radius;
  int max_range = raw_points + score_search_radius;
  if (min_range < 0) min_range = 0;
  if (max_range >= max_points) max_range = max_points - 1;
  for (int i = min_range; i <= max_range; ++i) {
    // Has to happen at least once in 10000 times to count
    if ((*points_probs)[i] < 0.0001) {
      continue;
    }
    // Has to have happened at least once
    if (points_freq_[i] < 0.1) {
      continue;
    }
    float p = points_probs->at(i) * points_freq_[i] / total_points_;
    updated_probs[i] = p;
    total_probs += p;
  }
  for (int i = 0; i < max_points; ++i) {
    updated_probs[i] /= total_probs;
  }
  points_probs->swap(updated_probs);
}

// Given the likely distribution of points for both the home and away,
// calculate the pairwise probabily of each final score.
void TempoFree::calculate_final_score_probs(PointsFreq* home, PointsFreq* away,
                                            ScoreProbs* final_score_probs,
                                            float h_win) {
  ScoreProbs localprobs(max_points, PointsFreq(max_points, 0.0));
  float total_probs = 0;
  for (int h = 0; h < max_points; ++h) {
    for (int a = 0; a < max_points; ++a) {
      if (h == a)
        continue;
      float p = 0.0;
      if ((h > a) && (h_win > 0.5)) {
        p = home->at(h) * away->at(a) * h_win;
      } else if ((h < a) && (h_win < 0.5)) {
        p = home->at(h) * away->at(a) * (1.0 - h_win);
      }
      total_probs += p;
      localprobs[h][a] = p;
    }
  }
  for (int h = 0; h < max_points; ++h) {
    for (int a = 0; a < max_points; ++a) {
      localprobs[h][a] /= total_probs;
    }
  }
  final_score_probs->swap(localprobs);
}

// Maximize the expected number of points we'll earn for this game using
// the probability of each final score and the number of points we'll get
// for a prediction.
void TempoFree::maximize_expectation(ScoreProbs* final_score_probs,
                                     int* home_score, int* away_score) {
  int bhs = -1, bas = -1;
  float best_expp = 0;
  for (int h = 0; h < max_points; ++h) {
    for (int a = 0; a < max_points; ++a) {
      if (h == a)
        continue;
      float p = (*final_score_probs)[h][a];
      if (p > best_expp) {
        bhs = h;
        bas = a;
        best_expp = p;
      }
    }
  }
  *home_score = bhs;
  *away_score = bas;
}

float TempoFree::date_to_factor(const string& date) const {
  string d = date.substr(4, 2);
  int h = strtol(date.substr(6, 2).c_str(), NULL, 10);
  d += static_cast<char>('0' + (h / 16));
  DateAdjustMap::const_iterator it = adjust_factors_.find(d);
  if (it == adjust_factors_.end())
    return 1.0;
  else
    return it->second;
}

// CSV-split a line; inserts a NULL value if a field is empty
// Return the number of items found or, if bad parameters, -1
//static
int SplitCSV(char* line, vector<char*>* items) {
  if (!line || !items)
    return -1;

  char *q = strrchr(line, '\n');
  if (q) *q = '\0';
  q = strrchr(line, '\r');
  if (q) *q = '\0';

  items->clear();
  char* p = line;
  while ((*p != '\n') && (*p != '\0')) {
    if (*p == ',') {
      // An empty value.  Enter a NULL placeholder.
      items->push_back(NULL);
      ++p;
    } else if (*p == '"') {
      // A quoted value.  Look for the next '"' character
      *p++ = '\0';
      q = strchr(p, '"');
      items->push_back(p);
      if (q) {
        *q++ = '\0';
        // At this point, q should point to the concluding comma of the
        // quoted value.
        if (*q != ',')
          break;
        p = q + 1;
      } else {
        // Not sure what we found here.  A quotation that started but
        // isn't finished.  Bail.
        break;
      }
    } else {
      q = strchr(p, ',');
      if (q) {
        // q points to the end of the value.  Make it a terminating NULL
        // and insert p.
        *q = '\0';
        items->push_back(p);
        // Move one past the end of this value.
        p = q + 1;
      } else {
        // No more commas found.  This is the last part of the line.
        items->push_back(p);
        break;
      }
    }
  }

  return items->size();
}
