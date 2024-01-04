#!/usr/bin/perl -w
#
# Selects the game of the week based on output from interesting_games.pl
# Assumes column format of
#
# [GameID] [Interest] [Closeness] [Goodness] [Excitement] [BCSCount]

my $GAMES_PER_BIN = 4;

sub usage() {
  print STDERR "\n";
  print STDERR "$0 <summaryfile>\n";
  print STDERR "\n";
  exit 1;
}

my $summary = shift(@ARGV);
usage() if (!defined($summary));
my $gpb = shift(@ARGV);
if (defined($gpb)) {
  $GAMES_PER_BIN = $gpb;
}

my %games;
open(SUMMARY, "$summary") or die "Cannot open summary $summary: $!";
while(<SUMMARY>) {
  chomp;
  next unless(/^[0-9]+,/);
  @_ = split(/,/);
  my $gid = $_[2];
  my $home = $_[6];
  my $away = $_[9];
#  print STDERR "\$_[3] \"$_[3]\" home \"$home\" away \"$away\"\n";
  my $at_vs = ($_[3] eq $home) ? "at" : "vs";

  $home =~ s/\s/_/g;
  $away =~ s/\s/_/g;
  $games{$gid} = sprintf "%-30s %s %-30s", $away, $at_vs, $home;
}
close(SUMMARY);

my %bins;
my %interest;
while(<STDIN>) {
  chomp;
  my @d = split;
  my $gid = shift(@d);
  my $bin = pop(@d);
  $bins{$bin}{$gid} = \@d;
  $interest{$gid} = $d[0];
}
exit if (!(keys %interest));

my @most_to_least = sort { $interest{$b} <=> $interest{$a} } keys %interest;
my $most_interesting = $most_to_least[0];

my $leftover = 0;
foreach my $bin_num (0..2) {
  my $bin_href = $bins{$bin_num};
  my $num_this_bin = 0;
  if (!defined($bin_href)) {
    $leftover += $GAMES_PER_BIN;
    next;
  }
  my $from_this_bin = 0;
  foreach my $gid (@most_to_least) {
    next unless defined($$bin_href{$gid});
    my $game_data = $games{$gid};
    if (!defined($game_data)) {
      warn "Invalid game ID: $gid";
      next;
    }
    my $aref = $$bin_href{$gid};
    if ($gid eq $most_interesting) {
      printf "%s %s %s %d GOTW\n", $gid, $game_data, join(' ', @$aref), $bin_num;
    } else {
      printf "%s %s %s %d\n", $gid, $game_data, join(' ', @$aref), $bin_num;
      $from_this_bin++;
    }
    last if ($from_this_bin == ($leftover + $GAMES_PER_BIN));
  }
  $from_this_bin -= $GAMES_PER_BIN;
  $leftover -= $from_this_bin;
}
