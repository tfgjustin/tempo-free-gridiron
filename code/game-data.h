#ifndef GAME_DATA_H
#define GAME_DATA_H

#include <string>

using namespace std;

// A 'unit' in this case refers to either Offense or Defense
class UnitData {
 public:
  UnitData() {
    clear();
  }
  UnitData(const UnitData& other)
    : points_for_(other.points_for_), points_against_(other.points_against_),
      num_plays_(other.num_plays_), yards_for_(other.yards_for_),
      yards_against_(other.yards_against_),  time_in_secs_(other.time_in_secs_),
      is_normalized_(other.is_normalized_), game_count_(other.game_count_)
  {
  }
  // Mutators
  void set_points_for(float pf) { points_for_ = pf; }
  void set_points_against(float pa) { points_against_ = pa; }
  void set_num_plays(float np) { num_plays_ = np; }
  void set_yards_for(float yf) { yards_for_ = yf; }
  void set_yards_against(float ya) { yards_against_ = ya; }
  void set_time_in_secs(float tis) { time_in_secs_ = tis; }
  void set_is_normalized(bool in) { is_normalized_ = in; }
  void set_game_count(float gc) { game_count_ = gc; }

  // Accessors
  float points_for() const { return points_for_; }
  float points_against() const { return points_against_; }
  float num_plays() const { return num_plays_; }
  float yards_for() const { return yards_for_; }
  float yards_against() const { return yards_against_; }
  float time_in_secs() const { return time_in_secs_; }
  bool is_normalized() const { return is_normalized_; }
  float game_count() const { return game_count_; }

  // Helper functions
  void clear();
  void normalize_efficiency();
  void normalize_pergame();
  void add(const UnitData& other);
  void decay(float factor);
  void points_multipliers(float pf_mult, float pa_mult);
 private:
  float points_for_;
  float points_against_;
  float num_plays_;
  float yards_for_;
  float yards_against_;
  float time_in_secs_;
  bool is_normalized_;
  float game_count_;
};

// All we care about for now is the week_num_ of the game, which week number,
// the number of points this team scored, the points they allowed, and who
// they played.
class GameData {
 public:
  GameData() {
    clear();
  }
  GameData(const GameData& other)
    : game_id_(other.game_id_), team_id_(other.team_id_), opp_id_(other.opp_id_),
      week_num_(other.week_num_), team_(other.team_),
      is_normalized_(other.is_normalized_), is_neutral_(other.is_neutral_),
      is_bowl_(other.is_bowl_) {}

  // Mutators
  void set_game_id(const string& gid) { game_id_ = gid; }
  void set_team_id(long tid) { team_id_ = tid; }
  void set_opp_id(long oid) { opp_id_ = oid; }
  void set_week_num(long wn) { week_num_ = wn; }
  void set_is_normalized(bool in) { is_normalized_ = in; }
  void set_is_neutral(bool in) { is_neutral_ = in; }
  void set_is_bowl(bool ib) { is_bowl_ = ib; }

  // Accessors
  string game_id() const { return game_id_; }
  long team_id() const { return team_id_; }
  long opp_id() const { return opp_id_; }
  long week_num() const { return week_num_; }
  bool is_normalized() const { return is_normalized_; }
  bool is_neutral() const { return is_neutral_; }
  bool is_bowl() const { return is_bowl_; }
  const UnitData& team() const { return team_; }
  UnitData* mutable_team() { return &team_; }

  // Helper functions
  void clear();
  void normalize_efficiency();
  void normalize_pergame();
  void add(const GameData& other);
  void decay(float factor);
  void points_multipliers(float pf_mult, float pa_mult);
 private:
  string game_id_;
  long team_id_;
  long opp_id_;
  long week_num_;  // Weeks since the start of the epoch
  UnitData team_;
  bool is_normalized_;
  bool is_neutral_;
  bool is_bowl_;
};

#endif  // GAME_DATA_H
