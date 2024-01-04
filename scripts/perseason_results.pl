#!/usr/bin/perl -w

use POSIX;
use strict;

my %games;
while(<STDIN>) {
  next unless(/UNDOG_STRAIGHT/);
  chomp;
  s/\-/\ /g;
  @_ = split;
  my $date = $_[0];
  my $result = $_[3];
  if ($date =~ /(\d{4})(\d{2})(\d{2})/) {
    my $yr = $1 - 1900;
    my $mo = $2 - 1;
    my $da = $3;
    my $t = POSIX::mktime(0, 0, 0, $da, $mo, $yr);
    my @lt = localtime($t);
    my $week_of_year = strftime "%U", @lt;
    if ($mo == 0) {
      $yr = $1 - 1901;
      $week_of_year += 53;
    }
    if ($week_of_year > 51) {
      $week_of_year = 51;
    }
    $games{$yr}{$week_of_year}{$result} += 1;
  }
}

my $start_value = 20000;
my $MINWEEK = 45;
my $MAXWEEK = 53;
my $WIN_FACTOR = 200. / 100;
my $MAX_PER_GAME = 0.25;
my $MAX_MONEYBET = 2000;
my $TRAVEL = 140 + 60;
#my $TRAVEL = 0;
my @WINTAGS = qw( UNDOG_STRAIGHTUP_RIGHT );
my @LOSSTAGS = qw( UNDOG_STRAIGHTUP_BEATSPREAD UNDOG_STRAIGHTUP_LOSSSPREAD UNDOG_STRAIGHTUP_TIESPREAD );
my @TIETAGS = qw( );
#my @WINTAGS = qw( UNDOG_STRAIGHTUP_RIGHT );
#my @LOSSTAGS = qw( UNDOG_STRAIGHTUP_LOSSSPREAD FAVOR_COVERSPREAD_LOSSSPREAD FAVOR_COVERSPREAD_WRONG );
#my @TIETAGS = qw( UNDOG_STRAIGHTUP_TIESPREAD FAVOR_COVERSPREAD_TIESPREAD );

my $total_net = 0;
my $current_value = $start_value;
foreach my $year (sort { $a <=> $b } keys %games) {
  my $year_href = $games{$year};
  my $svalue = $current_value;
  my $current_value = $start_value;
  my $raw_winnings = 0;
  my $total_net_winnings = 0;
  my $total_losses = 0;
  printf "Year WK #G #R #W #T PerGameBet Current\$  Winnings  NetWin\$\$    Losses   GetBack"
         . " NewCurr\$\$\n";
  foreach my $week (sort { $a <=> $b } keys %$year_href) {
    next if ($week < $MINWEEK or $week > $MAXWEEK);
    my $week_href = $$year_href{$week};
    my $num_games = 0;
    foreach my $result (keys %$week_href) {
      $num_games += $$week_href{$result};
    }
    my $pergame_bet = 1.0 / $num_games;
    if ($pergame_bet > $MAX_PER_GAME) {
      $pergame_bet = $MAX_PER_GAME;
    }
    my $numright = 0;
    foreach my $right (@WINTAGS) {
      if (defined($$week_href{$right})) {
        $numright += $$week_href{$right};
      }
    }
    my $numwrong = 0;
    foreach my $wrong (@LOSSTAGS) {
      if (defined($$week_href{$wrong})) {
        $numwrong += $$week_href{$wrong};
      }
    }
    my $numtie = 0;
    foreach my $tie (@TIETAGS) {
      if (defined($$week_href{$tie})) {
        $numtie += $$week_href{$tie};
      }
    }
    my $pergame_moneybet = sprintf "%.2f", $pergame_bet * $current_value;
    if ($pergame_moneybet > $MAX_MONEYBET) {
      $pergame_moneybet = $MAX_MONEYBET;
    }
    my $pgmb = int($pergame_moneybet);
    my $nfs = int($pgmb / 50);
    $pergame_moneybet = sprintf "%.2f", $nfs * 50;
    my $winnings = $pergame_moneybet * $numright * $WIN_FACTOR;
    $raw_winnings += ($winnings - ($pergame_moneybet * $numright));
    my $losses = $pergame_moneybet * $numwrong;
    $total_losses += $losses;
    my $getback = $pergame_moneybet * $numtie;
    my $net_winnings = $winnings - ($pergame_moneybet * $numright) - $TRAVEL;
    $total_net_winnings += $net_winnings;
    my $leftover = sprintf "%.2f", $current_value - ($num_games * $pergame_moneybet);
    my $new_current_value = $leftover + $winnings + $getback;
    printf "%3d %2d %2d %2d %2d %2d %9.2f %9.2f %9.2f %9.2f %9.2f %9.2f %9.2f\n",
           $year + 1900, $week, $num_games, $numright, $numwrong, $numtie,
	   $pergame_moneybet, $current_value, $winnings, $net_winnings, $losses, $getback,
	   $new_current_value;
    $current_value = $new_current_value - $TRAVEL;
  }
  printf "%4s %7s %9s %5s %9s %9s %9s\n", "Year", "StartVal", "FinalVal", "Ratio",
         "RawIncome", "NetWin\$\$", "RawLosses";
  printf "%4d %7.2f %9.2f %5.2f %9.2f %9.2f %9.2f %9.2f\n", $year + 1900,
         $svalue, $current_value, $current_value / $svalue,
	 $raw_winnings, $total_net_winnings, $total_losses,
	 $total_net_winnings - $total_losses;
  print "\n\n";
  $total_net += $total_net_winnings - $total_losses;
}
printf "TOTAL NET %9.2f\n", $total_net;
