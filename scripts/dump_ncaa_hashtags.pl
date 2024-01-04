#!/usr/bin/perl 

use JSON;
use TempoFree;
use strict;
use warnings;

my $JSON_ID_FILE = 'data/json2ncaa.csv';

sub load_json_ids();
sub load_json($$$);
sub get_home_away_ids($);

sub process_json_gameinfo($$);

my %json2ncaa;
load_json_ids();
exit 1 if (!defined(keys %json2ncaa));

my %hashtags;
foreach my $f (@ARGV) {
  my $ftype = 0;
  my $gid = undef;
  if ($f =~ /(\d{4})_(\d{2})_(\d{2})_\d{4}_\d{4}/) {
    $gid = $1 . $2 . $3;
  } else {
    warn "Invalid filename: $f";
    next;
  }
  if ($f !~ /_gameinfo.json$/) {
    next;
  }
  load_json($gid, $f, $ftype);
}
foreach my $offid (keys %gamedata) {
  my $href = $gamedata{$offid};
  next if (!defined($href));
  if (!is_fully_processed($href)) {
    warn "Missing some data for $offid";
    next;
  }
  print_offense_stats($offid, $href);
}
#print Dumper %gamedata;

sub load_json_ids() {
  open my $fh, "<", $JSON_ID_FILE or die "Error opening JSON ID file $JSON_ID_FILE: $!";
  while (<$fh>) {
    next if (/^#/);
    chomp;
    @_ = split(/,/);
    next unless (scalar(@_) >= 2);
    $json2ncaa{$_[0]} = $_[1];
  }
  close $fh;
}

sub load_json($$$) {
  my $gid = shift;
  my $filename = shift;
  my $filetype = shift;
  if (! -f $filename) {
    warn "No such file: $filename";
    return;
  }
  open my $fh, "<", $filename or do {
    warn "Error opening $filename for reading: $!";
    return;
  };
  my $raw_json = do { local $/; <$fh>};
  close $fh;
  my $json_data = decode_json($raw_json);
  process_json_gameinfo($json_data);
}

sub get_home_away_ids($) {
  my $json_data = shift;
  my ($home_id, $away_id) = (undef, undef);
  my $meta_href = $$json_data{'meta'};
  return (undef, undef) if (!defined($meta_href));
  my $teams_aref = $$meta_href{'teams'};
  return (undef, undef) if (!defined($teams_aref));
  return (undef, undef) if (scalar(@$teams_aref) != 2);
  my $success = 1;
  foreach my $href (@$teams_aref) {
    my $tid = $$href{'id'};
    my $ishome = $$href{'homeTeam'};
    my $seoName = $$href{'seoName'};
    if (!defined($tid) or !defined($ishome) or !defined($seoName)) {
      $success = 0;
      next;
    }
    my $tfgid = $json2ncaa{$tid};
    if (!defined($tfgid)) {
      printf STDERR "NoTFGID %4d SeoName %s\n", $tid, $seoName;
      $success = 0;
      next;
    }
    if ($ishome eq "true") {
      $home_id = $tfgid;
    } else {
      $away_id = $tfgid;
    }
  }
  if ($success) {
    return ($home_id, $away_id);
  } else {
    return (undef, undef);
  }
}

sub process_json_gameinfo($$) {
  my $gid = shift;
  my $json_data = shift;
  my ($home_id, $away_id) = get_home_away_ids($json_data);
  return if (!defined($home_id) or !defined($away_id));
  my $tables_aref = $$json_data{'tables'};
  return if (!defined($tables_aref));
  foreach my $table_href (@$tables_aref) {
    my $table_id = $$table_href{'id'};
    next if (!defined($table_id));
    my $side = undef;
    my $table_type = undef;
    if ($table_id =~ /^(.+)_(\w+)$/) {
      $table_type = $1;
      $side = $2;
    } else {
      next;
    }
    my $c = $BOXSCORE_CALLBACKS{$table_type};
    next if (!defined($c));
    my $key = sprintf "%s-%4d", $gid, ($side eq "home") ? $home_id : $away_id;
    $c->($key, $table_href);
  }
}

# - NumPoints    Scoring ~> last visiting/home score
# - TDs          Scoring ~> quarter ~> summary ~> scoreType==TD
sub process_json_scoringSummary($$) {
  my $gid = shift;
  my $json_data = shift;
  my ($home_id, $away_id) = get_home_away_ids($json_data);
  return if (!defined($home_id) or !defined($away_id));
  my $home_off_id = "$gid-$home_id";
  my $away_off_id = "$gid-$away_id";
  $gamedata{$home_off_id}{$NumPoints} = 0;
  $gamedata{$away_off_id}{$NumPoints} = 0;
  $gamedata{$home_off_id}{$TDs} = 0;
  $gamedata{$away_off_id}{$TDs} = 0;
  my %tds;
  my %points;
  my $periods_aref = $$json_data{'periods'};
  return if (!defined($periods_aref));
  foreach my $period_href (@$periods_aref) {
    my $summary_aref = $$period_href{'summary'};
    next if (!defined($summary_aref));
    foreach my $score_href (@$summary_aref) {
      my $team_id = $$score_href{'teamId'};
      my $home_score = $$score_href{'homeScore'};
      my $away_score = $$score_href{'visitingScore'};
      next if (!defined($team_id) or !defined($home_score) or !defined($away_score));
      if (!defined($points{$home_id}) or $home_score > $points{$home_id}) {
        $points{$home_id} = $home_score;
      }
      if (!defined($points{$away_id}) or $away_score > $points{$away_id}) {
        $points{$away_id} = $away_score;
      }
      my $score_type = $$score_href{'scoreType'};
      next if (!defined($score_type) or $score_type ne "TD");
      $tds{$team_id} += 1;
    }
  }
  foreach my $id (keys %tds) {
    my $tfgid = $json2ncaa{$id};
    my $offid = "$gid-$tfgid";
    $gamedata{$offid}{$TDs} = $tds{$id};
  }
  $gamedata{$home_off_id}{$NumPoints} = $points{$home_id};
  $gamedata{$away_off_id}{$NumPoints} = $points{$away_id};
}

# - Fumbles      TeamStats ~> Fumbles: Number-Lost
# - IntRetYards  TeamStats ~> Interception Returns: Number-Yards
# - Num1stDowns  TeamStats ~> 1st Downs
# - NumPenalties TeamStats ~> Penalties: Number-Yards
sub process_json_teamStats($$) {
  my $gid = shift;
  my $json_data = shift;
  my ($home_id, $away_id) = get_home_away_ids($json_data);
  return if (!defined($home_id) or !defined($away_id));
  my $teams_aref = $$json_data{'teams'};
  return if (!defined($teams_aref));
  foreach my $teams_href (@$teams_aref) {
    my $id = $$teams_href{'teamId'};
    next if (!defined($id));
    my $tfgid = $json2ncaa{$id};
    next if (!defined($tfgid));
    my $offid = "$gid-$tfgid";
    my $stats_aref = $$teams_href{'stats'};
    next if (!defined($stats_aref));
    foreach my $stat_href (@$stats_aref) {
      my $stat_name = $$stat_href{'stat'};
      next if (!defined($stat_name));
      my $c = $TEAM_STATS_CALLBACKS{$stat_name};
      next if (!defined($c));
      $c->($offid, $stat_href);
    }
  }
}

sub is_fully_processed($) {
  my $href = shift;
  my $success = 1;
  foreach my $stat (@ALLSTATS) {
    if (!defined($$href{$stat})) {
      warn "Missing $stat";
      $success = 0;
    }
  }
  return $success;
}

sub print_offense_stats($$) {
  my $offid = shift;
  my $href = shift;
  my $total_yards = $$href{$KORetYards} + $$href{$PuntRetYards} + $$href{$IntRetYards}
     + $$href{$PassYards} + $$href{$RushYards};
  my $num_plays = $$href{$FGA} + $$href{$Punts} + $$href{$TDs} + 1;  # KO at start of half
  $num_plays += $$href{$PassPlays} + $$href{$RushPlays} + ($$href{$NumPenalties} / 2);
  my $score_plays = $$href{$FGM} + $$href{$TDs};
  printf "%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d\n", $offid, $$href{$NumPoints},
        $num_plays, $total_yards, $$href{$PassYards}, $$href{$RushYards},
        $$href{$NumIntercept}, $$href{$Fumbles}, $$href{$NumPenalties},
        $$href{$PassPlays}, $$href{$RushPlays}, $$href{$Num1stDowns},
        $score_plays;
}

sub parse_json_teamStats_first_downs($$) {
  my $offid = shift;
  my $stat_href = shift;
  $gamedata{$offid}{$Num1stDowns} = 0;
  my $data = $$stat_href{'data'};
  return if (!defined($data));
  $gamedata{$offid}{$Num1stDowns} = $data;
}

sub parse_json_teamStats_fumbles($$) {
  my $offid = shift;
  my $stat_href = shift;
  $gamedata{$offid}{$Fumbles} = 0;
  my $data = $$stat_href{'data'};
  return if (!defined($data));
  if ($data =~ /\d+-(\d+)/) {
    $gamedata{$offid}{$Fumbles} = $1;
  }
}

sub parse_json_teamStats_interceptions($$) {
  my $offid = shift;
  my $stat_href = shift;
  $gamedata{$offid}{$IntRetYards} = 0;
  my $data = $$stat_href{'data'};
  return if (!defined($data));
  if ($data =~ /\d+-(\d+)/) {
    $gamedata{$offid}{$IntRetYards} = $1;
  }
}

sub parse_json_teamStats_penalties($$) {
  my $offid = shift;
  my $stat_href = shift;
  $gamedata{$offid}{$NumPenalties} = 0;
  my $data = $$stat_href{'data'};
  return if (!defined($data));
  if ($data =~ /(\d+)-\d+/) {
    $gamedata{$offid}{$NumPenalties} = $1;
  }
}

sub parse_json_boxscore_kicking($$) {
  my $offid = shift;
  my $table_href = shift;
  $gamedata{$offid}{$FGA} = 0;
  $gamedata{$offid}{$FGM} = 0;
  my $idx = get_json_boxscore_header_index($table_href, "FG-FGA");
  return if ($idx < 0);
  my %retvals;
  get_json_boxscore_column_values($table_href, $idx, \%retvals);
  my $fga = 0;
  my $fgm = 0;
  foreach my $v (values %retvals) {
    my ($m, $a) = split(/\//, $v);
    next if (!defined($a));
    $fga += $a;
    $fgm += $m;
  }
  $gamedata{$offid}{$FGA} = $fga;
  $gamedata{$offid}{$FGM} = $fgm;
}

sub parse_json_boxscore_kick_returns($$) {
  my $offid = shift;
  my $table_href = shift;
  $gamedata{$offid}{$KORetYards} = 0;
  my $idx = get_json_boxscore_header_index($table_href, "YDS");
  return if ($idx < 0);
  my %retvals;
  get_json_boxscore_column_values($table_href, $idx, \%retvals);
  my $v = $retvals{'Total'};
  return if (!defined($v));
  $gamedata{$offid}{$KORetYards} = $v;
}

sub parse_json_boxscore_passing($$) {
  my $offid = shift;
  my $table_href = shift;
  $gamedata{$offid}{$PassYards} = 0;
  $gamedata{$offid}{$PassPlays} = 0;
  $gamedata{$offid}{$NumIntercept} = 0;
  my $att_idx = get_json_boxscore_header_index($table_href, "CP-ATT-INT");
  return if ($att_idx < 0);
  my $yds_idx = get_json_boxscore_header_index($table_href, "YDS");
  return if ($yds_idx < 0);
  my %att_retvals;
  get_json_boxscore_column_values($table_href, $att_idx, \%att_retvals);
  my $v = $att_retvals{'Total'};
  return if (!defined($v));
  if ($v =~ /\d+-(\d+)-(\d+)/) {
    $gamedata{$offid}{$PassPlays} = $1;
    $gamedata{$offid}{$NumIntercept} = $2;
  }
  my %yds_retvals;
  get_json_boxscore_column_values($table_href, $yds_idx, \%yds_retvals);
  $v = $yds_retvals{'Total'};
  return if (!defined($v));
  $gamedata{$offid}{$PassYards} = $v;
}

sub parse_json_boxscore_punt_returns($$) {
  my $offid = shift;
  my $table_href = shift;
  $gamedata{$offid}{$PuntRetYards} = 0;
  my $idx = get_json_boxscore_header_index($table_href, "YDS");
  return if ($idx < 0);
  my %retvals;
  get_json_boxscore_column_values($table_href, $idx, \%retvals);
  my $v = $retvals{'Total'};
  return if (!defined($v));
  $gamedata{$offid}{$PuntRetYards} = $v;
}

sub parse_json_boxscore_punting($$) {
  my $offid = shift;
  my $table_href = shift;
  $gamedata{$offid}{$Punts} = 0;
  my $idx = get_json_boxscore_header_index($table_href, "NO");
  return if ($idx < 0);
  my %retvals;
  get_json_boxscore_column_values($table_href, $idx, \%retvals);
  my $v = $retvals{'Total'};
  return if (!defined($v));
  $gamedata{$offid}{$Punts} = $v;
}

sub parse_json_boxscore_rushing($$) {
  my $offid = shift;
  my $table_href = shift;
  $gamedata{$offid}{$RushPlays} = 0;
  $gamedata{$offid}{$RushYards} = 0;
  my $att_idx = get_json_boxscore_header_index($table_href, "ATT");
  return if ($att_idx < 0);
  my $yds_idx = get_json_boxscore_header_index($table_href, "YDS");
  return if ($yds_idx < 0);
  my %att_retvals;
  get_json_boxscore_column_values($table_href, $att_idx, \%att_retvals);
  my $v = $att_retvals{'Total'};
  return if (!defined($v));
  $gamedata{$offid}{$RushPlays} = $v;
  my %yds_retvals;
  get_json_boxscore_column_values($table_href, $yds_idx, \%yds_retvals);
  $v = $yds_retvals{'Total'};
  return if (!defined($v));
  $gamedata{$offid}{$RushYards} = $v;
}

sub get_json_boxscore_header_index($$) {
  my $table_href = shift;
  my $index_name = shift;
  return -1 if (!defined($table_href));
  my $header_aref = $$table_href{'header'};
  return -1 if (!defined($header_aref));
  foreach my $idx (0..$#$header_aref) {
    my $display_href = $$header_aref[$idx];
    next if (!defined($display_href));
    my $v = $$display_href{'display'};
    next if (!defined($v));
    if ($v eq $index_name) {
      return $idx;
    }
  }
  return -1;
}

sub get_json_boxscore_column_values($$$) {
  my $table_href = shift;
  my $idx = shift;
  my $ret_href = shift;
  my $data_aref = $$table_href{'data'};
  return if (!defined($data_aref));
  foreach my $row_href (@$data_aref) {
    my $row_aref = $$row_href{'row'};
    next if (!defined($row_aref));
    my $row_data = $$row_aref[0]{'display'};
    next if (!defined($row_data));
    my $col_value = $$row_aref[$idx]{'display'};
    next if (!defined($col_value));
    $$ret_href{$row_data} = $col_value;
  }
}
