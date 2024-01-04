#!/usr/bin/perl -w

use strict;

sub parse_team_names($);
sub parse_odds_file($);
sub parse_team($);
sub parse_line($);
sub datetime_replacement($);

my %MONTHS = ( 'August' => 8, 'September' => 9, 'October' => 10,
               'November' => 11, 'December' => 12, 'January' => 1 );

if (scalar(@ARGV) != 2) {
  print "\n";
  print "Usage: $0 <teamNameMap> <oddsHtml>\n";
  print "\n";
  exit 1;
}

my $teamname = shift(@ARGV);
my $oddsname = shift(@ARGV);

my %code2name;
my %code2number;
parse_team_names($teamname);

my $curr_away = undef;
my $curr_home = undef;
my $curr_date = undef;
parse_odds_file($oddsname);

sub parse_team_names($) {
  my $fname = shift;
  open(TEAMS, "$fname") or die "Can't open teams file $fname: $!";
  while(<TEAMS>) {
    chomp;
    @_ = split(/,/);
    my $code = $_[0];
    my $number = $_[1];
    my $name = $_[2];
    $code2name{$code} = $name;
    $code2number{$code} = $number;
  }
  close(TEAMS);
}

sub parse_odds_file($) {
  my $fname = shift;
  open(ODDS, "$fname") or die "Can't open odds file $fname: $!";
  while(<ODDS>) {
    chomp;
    if (/class=\"teams ncaaf\"/) {
      $curr_away = undef;
      $curr_home = undef;
    } elsif (/class=\"team\"/) {
      parse_team($_);
    } elsif (/class=\"\w+-line\"/) {
      parse_line($_);
    } elsif (/<h4>\w+\s(\w+)\s(\d+),\s(\d+)<\/h4>/) {
      my $dt = datetime_replacement($1);
      if (!defined($dt)) {
        warn "Could not convert '$1' to a DateTime";
        next;
      }
      $curr_date = sprintf "%4d%02d%02d", $3, $dt, $2;
    }
  }
  close(ODDS);
}

sub parse_line($) {
  my $ok = 1;
  if (!defined($curr_away)) {
    warn "No away team";
    $ok = 0;
  }
  if (!defined($curr_home)) {
    warn "No home team";
    $ok = 0;
  }
  if (!$ok) { return; }
  local $_ = shift;
  my $spread = undef;
  if (/line\">-(\d+)(\&frac12){0,1}/) {
    $spread = $1;
    if (defined($2)) {
      $spread += .5;
    }
  } else {
    die "Cannot extract spread from \"$_\"";
  }
  my ($favorite, $underdog);
  if (/class=\"top-line\"/) {
    $favorite = $curr_away;
    $underdog = $curr_home;
  } elsif (/class=\"bottom-line\"/) {
    $favorite = $curr_home;
    $underdog = $curr_away;
  } else {
    die "Unknown favorite: \"$_\"";
  }

  print "$curr_date-$curr_home-$curr_away,$favorite,$underdog,$spread\n";
}

sub parse_team($) {
  local $_ = shift;
  if (/<span>at<\/span>/) {
    if (defined($curr_away)) {
      die "Whuh?  Skipped a home team somewhere";
    }
    if (/a href=\".*\/([a-z]{3})\">.*<\/a>/) {
      if (!defined($code2number{$1})) {
        die "No team for code $1";
      }
      $curr_away = $code2number{$1};
    } else {
      die "Cannot extract away team from \"$_\"";
    }
  } else {
    if (!defined($curr_away)) {
      die "Whuh?  Skipped an away team somewhere";
    }
    if (/a href=\".*\/([a-z]{3})\">.*<\/a>/) {
      if (!defined($code2number{$1})) {
        die "No team for code $1";
      }
      $curr_home = $code2number{$1};
    } else {
      die "Cannot extract away team from \"$_\"";
    }
  }
}

sub datetime_replacement($) {
  my $m = shift;
  return $MONTHS{$m};
}
