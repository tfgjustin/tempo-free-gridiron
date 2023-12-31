#ifndef TEMPO_FREE_H
#define TEMPO_FREE_H

#include <utility>
#include <time.h>
#include <vector>
#include <string>
#include <map>
#include <set>

#include <stdio.h>
#include <math.h>

#include "game-data.h"

using namespace std;

// Set of strings containing per-drive info.
typedef vector<string> Drives;
// Mapping of game ID to drives
typedef map<string, Drives> PerGameDrives;
// For each team, keep an array of data about them.
typedef vector<GameData*> TeamGames;
// The overall mapping of numeric TEAM_ID to their per-game data
typedef map<long, TeamGames> PerTeamGameData;
// For each team, what is its average game?
typedef map<long, GameData> PerTeamAverages;
// Map a team ID to their Pythagorean Winning PCT
typedef map<long, float> TeamWinPct;
// Home team and away team stats
typedef pair<GameData*, GameData*> HomeAwayData;
// Maps a unique game identifier to home and away data
typedef map<string, HomeAwayData> PerGameData;
// A final score pair and the odds of it happening
typedef pair<int, int> PointsPair;
typedef map<string, PointsPair> Predictions;
// Buckets for each score and frequency
typedef vector<int> PointsCount;
typedef vector<float> PointsFreq;
// The ScoreProbs is a 2-D array that maps a score to a probability of
// that score happening.
typedef vector<PointsFreq> ScoreProbs;
// For each bucket, what is the final point distribution?
typedef vector<PointsCount> PointsBuckets;
// For a given date spec, what are the adjustment factors?
typedef map<string, float> DateAdjustMap;
// Maps a team ID to the name
typedef map<long, string> TeamNameMap;

// What's the most number of points we expect a team to score?
static const int max_points = 85;
static const int bucket_size = 3;
static const int num_error_buckets = max_points / bucket_size;

// CSV-split a line; inserts a NULL value if a field is empty
//static
int SplitCSV(char* line, vector<char*>* items);

class TempoFree {
  public:
    TempoFree();
    virtual ~TempoFree();

    int data(const vector<string>& summaries, const PerGameDrives& drives);

    // The second method, predict(), will take the names of two teams, as
    // well as the date of the game, and the location of the stadium
    // they will play in. It should then return a int[] with two
    // elements, the first of which is the home team score and the
    // second of which is the away team score.
    vector<int> predict(const string& stadium, const string& date,
                        int homeid, int awayid);

    void clear_prediction_cache() {
      raw_predictions_.clear();
      raw_winpct_.clear();
      raw_num_plays_.clear();
    }

    void set_py_exp(float p_exp) { py_exp_ = p_exp; }
    void set_age_factor(float af) { age_factor_ = af; }
    void set_bowl_factor(float bf) { bowl_factor_ = bf; }
    void set_point_weight_factor(float pwf) { point_weight_factor_ = pwf; }
    void set_yard_weight_factor(float ywf) { yard_weight_factor_ = ywf; }
    void set_cutoff_weeks(int ca) { cutoff_age_ = ca; }
    void set_num_adjust_iterations(int nai) { num_adjust_iterations_ = nai; }

    void freshen_stats(long curr_week);

    void PrintTeamStats(const int week_num) const;

  protected:

    // Parse one game summary.  Pass in a pointer to the vector of
    // columns so we don't take the hit for constructing and destructing
    // a vector for each summary.
    void parse_one_summary(const string& summary, const PerGameDrives& drives,
                           vector<char*>* columns);

    // Fill a home and away game summary from the provided column data.
    // Return true on success.
    bool fill_summaries(GameData* home, GameData* away,
                        vector<char*>* columns);

    // Add a summary to the global data model
    void add_summary(PerTeamGameData* ptgd, long team_id, GameData* gdata);

    // Add a final score the tally of final scores we have
    void add_final_score(int score) {
      points_freq_[score] += 1;
      total_points_++;
    }

    void add_final_margin(int margin) {
      if (!margin)
        return;
      margin_freq_[margin] += 1;
      total_margins_++;
    }

    // We were off on a prediction.  How much?
    void add_prediction_error(int predict, int actual);

    void add_score_errors(const string& date, int home_id,
                          int home_score, int away_score) {
      char gid[128];
      snprintf(gid, 128, "%s:%d", date.c_str(), home_id);
      Predictions::iterator it = raw_predictions_.find(gid);
      if (it == raw_predictions_.end()) {
        return;
      }

      add_prediction_error(it->second.first, home_score);
      add_prediction_error(it->second.second, away_score);
    }

    void set_team_name(long teamid, const string& name) {
      team_id_to_name_[teamid] = name;
    }

    // This function does two things:
    // 1) Normalizes all the data to per-100poss or per-half stats, and
    // 2) Eliminates the home field advantage/visitor's disadvantage
    void calculate_raw_efficiencies(long week_num);

    // Calculate the per-team and national averages
    void calculate_averages(PerTeamGameData* perteam_games,
                            PerTeamAverages* averages, GameData* average_team,
                            long curr_week);

    // Approximate the adjusted efficiencies
    void calculate_adj_efficiencies(long curr_week);

    // Adjust one game/unit
    void adjust_one_game(GameData* first_raw, GameData* second_adj,
                         GameData* first_adj);
    void adjust_one_unit(UnitData* first_raw, UnitData* second_adj,
                         UnitData* natl_avg, UnitData* first_adj);

    // Calculate pythagorean for all teams
    void calculate_pythagorean();
    void calculate_sos(long curr_week);

    // Figure out the decay factor given the age of the game and if it was
    // a bowl game.
    float decay_factor(int weeks_ago, bool is_bowl);

    // Get a raw prediction for a single game
    void raw_prediction(const string& game_id, bool is_neutral,
                        const GameData* home, const GameData* away,
                        int* home_score, int* away_score, float* winpct,
                        int* plays);

    void best_prediction(float h_win, int raw_home, int raw_away,
                         int* best_home, int* best_away);

    // Given how off we've been before, and given a raw prediction for one
    // team, see how far off we're likely to be this time.
    void apply_error_probs(int raw_points, PointsFreq* points_probs);

    // Given a distribution of likely points, multiply each bucket by the
    // likelihood that number of points will be at all
    void apply_final_points_probs(int raw_points, PointsFreq* points_probs);

    // Given the likely distribution of points for both the home and away,
    // calculate the pairwise probabily of each final score.
    void calculate_final_score_probs(PointsFreq* home, PointsFreq* away,
                                     ScoreProbs* final_score_probs, float h_win);

    // Given a set of final score pairs, what is the probabiliy that the
    // margin of victory will be 'X'?
    void calculate_final_margin_probs(ScoreProbs* final_score_probs);

    // Maximize the expected number of points we'll earn for this game using
    // the probability of each final score and the number of points we'll get
    // for a prediction.
    void maximize_expectation(ScoreProbs* final_score_probs,
                              int* home_score, int* away_score);

    // For a given date string (YYYYMMDD) what are the efficiency
    // adjustment factors?
    float date_to_factor(const string& date) const;
  private:
    // Have we added data since the last predictions?
    bool dirty_;

    TeamNameMap team_id_to_name_;

    // What are the most common scores and margins we see?
    PointsFreq points_freq_;
    int total_points_;
    PointsFreq margin_freq_;
    int total_margins_;

    // How often are we off by each amount?
    PointsBuckets error_buckets_;
    PointsCount perbucket_count_;
    int total_errors_;

    // Raw predictions
    Predictions raw_predictions_;
    DateAdjustMap raw_winpct_;
    DateAdjustMap raw_num_plays_;

    // (home, away) data for all games we've seen
    PerGameData all_games_;

    // What kind of stats does the average team put up?
    GameData raw_average_team_;
    GameData adj_average_team_;

    // The condensed version of all games (with raw and adjusted data)
    // NOTE: This is THE CANONICAL storage place for all the GameData
    // structs we allocate from the heap.
    // YOU MUST CLEAN THESE UP WHEN THIS OBJECT GOES AWAY!
    PerTeamGameData raw_perteam_games_;
    PerTeamGameData adj_perteam_games_;

    // Per-team average stats (raw and adjusted)
    PerTeamAverages raw_averages_;
    PerTeamAverages adj_averages_;

    // We use the per-team game summaries to calculate the pythagorean
    // winning percentages.
    TeamWinPct win_pcts_;
    TeamWinPct sos_;
    float py_exp_;
    float age_factor_;
    float bowl_factor_;
    float point_weight_factor_;
    float yard_weight_factor_;
    int cutoff_age_;
    int num_adjust_iterations_;

    // By what percent should we adjust the home and away efficiencies?
    DateAdjustMap adjust_factors_;
    DateAdjustMap home_advs_;
};

#endif  // TEMPO_FREE_H
