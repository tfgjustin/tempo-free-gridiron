#include <string>

#include "game-data.h"

using namespace std;

void UnitData::clear() {
  points_for_ = 0;
  points_against_ = 0;
  num_plays_ = 0;
  yards_for_ = 0;
  yards_against_ = 0;
  time_in_secs_ = 0;
  is_normalized_ = false;
  game_count_ = 0;
}
void UnitData::normalize_efficiency() {
  if (is_normalized_)
    return;
  // We care about PTS/100Plays, YDS/100Plays, and Plays/Half
  points_for_ = (points_for_ / num_plays_) * 100;
  points_against_ = (points_against_ / num_plays_) * 100;
  yards_for_ = (yards_for_ / num_plays_) * 100;
  yards_against_ = (yards_against_ / num_plays_) * 100;
  num_plays_ = (num_plays_ / time_in_secs_) * 1800;
  time_in_secs_ = 1800;
  is_normalized_ = true;
}
void UnitData::normalize_pergame() {
  if (!game_count_)
    return;
  points_for_ /= game_count_;
  points_against_ /= game_count_;
  yards_for_ /= game_count_;
  yards_against_ /= game_count_;
  num_plays_ /= game_count_;
  time_in_secs_ /= game_count_;
  game_count_ = 1.0;
}
void UnitData::add(const UnitData& other) {
  points_for_ += other.points_for_;
  points_against_ += other.points_against_;
  num_plays_ += other.num_plays_;
  yards_for_ += other.yards_for_;
  yards_against_ += other.yards_against_;
  time_in_secs_ += other.time_in_secs_;
  is_normalized_ = false;
  game_count_ += other.game_count_;
}
void UnitData::decay(float factor) {
  points_for_ *= factor;
  points_against_ *= factor;
  num_plays_ *= factor;
  yards_for_ *= factor;
  yards_against_ *= factor;
  time_in_secs_ *= factor;
  game_count_ *= factor;
}
void UnitData::points_multipliers(float pf_mult, float pa_mult) {
  if (!is_normalized_)
    return;
  points_for_ *= pf_mult;
  points_against_ *= pa_mult;
  yards_for_ *= pf_mult;
  yards_against_ *= pa_mult;
}

void GameData::clear() {
  game_id_ = "";
  team_id_ = 0;
  opp_id_ = 0;
  week_num_ = 0;
  team_.clear();
  is_normalized_ = false;
  is_neutral_ = false;
}
void GameData::normalize_efficiency() {
  if (is_normalized_) {
    return;
  }
  team_.normalize_efficiency();
  is_normalized_ = true;
}
void GameData::normalize_pergame() {
  team_.normalize_pergame();
}
void GameData::add(const GameData& other) {
  team_.add(other.team_);
  is_normalized_ = false;
}
void GameData::decay(float factor) {
  team_.decay(factor);
}
void GameData::points_multipliers(float pf_mult, float pa_mult) {
  team_.points_multipliers(pf_mult, pa_mult);
}
