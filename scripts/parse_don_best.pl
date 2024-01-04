#!/usr/bin/perl 

use POSIX;
use TempoFree;
use strict;
use warnings;

my %MONTHS = ("January" => 1, "August" => 8, "September" => 9,
              "October" => 10, "November" => 11, "December" => 12);
my %DAY_OF_WEEK = ("Sunday" => 0, "Monday" => 1, "Tuesday" => 2, "Wednesday" => 3,
                   "Thursday" => 4, "Friday" => 5, "Saturday" => 6);

sub parse_one_file($);
sub convert_to_odds($);
sub trim($);

sub deduce_year($$$) {
  my $month = shift;
  my $day = shift;
  my $day_of_week = shift;
  # Try years 2013 - 2008, going in reverse. Calculate which day of the week
  # that month/day/day-of-week would occur, and see if it matches.
  my $year = undef;
  foreach my $i (0..5) {
    $year = 2013 - $i;
    my $t = POSIX::mktime(0, 0, 12, $day, $month - 1, $year - 1900);
    my @parts = localtime($t);
    last if ($parts[6] == $day_of_week);
    $year = undef;
  }
  if (!defined($year)) {
    print STDERR "Could not get year for $month $day, $day_of_week";
    return -1;
  }
  return sprintf "%4d%02d%02d", $year, $month, $day;
}

sub strings_to_date($$$) {
  my $month = shift;
  my $day = shift;
  my $day_of_week = shift;
  $month = $MONTHS{$month};
  return -1 if !defined($month);
  $day_of_week = $DAY_OF_WEEK{$day_of_week};
  return -1 if !defined($day_of_week);
  return deduce_year($month, $day, $day_of_week);
}

# {game_id}{house}[odd_money,even_money]
my %gamedata;
foreach my $filename (@ARGV) {
  parse_one_file($filename);
}

foreach my $gid (sort keys %gamedata) {
  my $href = $gamedata{$gid};
  my $open_a = $$href{"Open"};
  printf "%s,Open,%s,%.3f,%s,%.3f", $gid, $$open_a[0], convert_to_odds($$open_a[0]),
         $$open_a[1], convert_to_odds($$open_a[1]);
  foreach my $h (sort keys %$href) {
    next if ($h eq "Open");
    my $aref = $$href{$h};
    printf ",%s,%d,%.3f,%d,%.3f", $h, $$aref[0], convert_to_odds($$aref[0]),
           $$aref[1], convert_to_odds($$aref[1]);
  }
  print "\n";
}

my $odd_remain = undef;
my $odd_open = undef;
my $odd_t1 = undef;
sub parse_one_file($) {
  my $f = shift;
  my %cols_to_names;
  my $date = undef;
  my $filedate = undef;
  if ($f =~ /.*(\d{8})\.html$/) {
    $filedate = $1;
  } else {
    return;
  }
  open(PARSE, "w3m -dump -cols 500 -T text/html $f|") or die "Error with file $f: $!";
  while(<PARSE>) {
    chomp;
    s/[^[:ascii:]]//g;
    s/FINAL//g;
    # Sample header:
    # COLLEGE FOOTBALL - Friday, November 4th
    if (/^COLLEGE FOOTBALL\s-\s(\w+), (\w+) (\d+)\w{2}\s.*$/) {
      $date = strings_to_date($2, $3, $1);
      if ($date < 0) {
        print "No date: $_\n";
      }
      next;
    }
    next unless defined($date);
    if (/ Rot /) {
      my ($rot, $opener, $team, $time, @places) = split;
      next unless (@places);
#      print "\n=== Places\n";
      my $c = 0;
      foreach my $i (0..$#places) {
        next unless ($places[$i] =~ /\S/);
        $cols_to_names{$i} = $places[$i];
#        print "col[$c] = \"$cols_to_names{$i}\"\n";
        ++$c;
      }
#      printf "Found %d places\n", scalar(keys %cols_to_names);
      next;
    }
    next unless (/[A-Za-z0-9]/);
    if (/(\d+)\s+(\S+)\s{2,}(\w+)(.*)\s+\d{1,2}:\d{2}\s\w{2}(.*)/) {
      my $r = $1;
      $odd_open = $2;
      my $t1 = $3;
      my $other = $4;
      $odd_remain = $5;
      $t1 .= $other if ($other =~ /\S/);
      $odd_t1 = trim($t1);
      my $ths = join(" ", unpack("C*", $t1));
#      print "\n===\n";
#      print "Rot   = $r\n";
#      print "Open  = $open\n";
#      print "Team  = $t1 ascii(\"$ths\")\n";
#      print " etc  = $other\n";
#      @odd_lines = split(/\s+/, $remain);
#      my $c = 0;
#      foreach my $l_index (0..$#lines) {
#        next unless ($lines[$l_index] =~ /\S/);
#        my $house = $cols_to_names{$c++};
#        $house = "unknown" if (!defined($house));
#        next if ($house eq "SC" or $lines[$l_index] eq "-");
#        printf " Line[\"%-20s = \"%s\" %.3f\n",  $house . "\"]", $lines[$l_index], convert_to_odds($lines[$l_index]);
#      }
#      print "Lines = $remain\n";
    } elsif (/(\d+)\s+(\S+)\s{2,}(\w+)(.*?)\s{2,}(\S.*)/) {
#      print "Even line: \"$_\"\n";
      next if (!defined($odd_open) or !defined($odd_t1) or !defined($odd_remain));
      my $r = $1;
      my $even_open = $2;
      my $t1 = $3;
      my $other = $4;
      my $even_remain = $5;
      $t1 .= $other if ($other =~ /\S/);
      my $even_t1 = trim($t1);
#      my $ths = join(" ", unpack("C*", $t1));
#      print "\n===\n";
#      print "Date  = $date\n";
#      print "Rot   = $r\n";
#      print "Open  = $open\n";
#      print "Team  = $t1 ascii(\"$ths\")\n";
#      print " etc  = $other\n";
      my @odd_lines = split(/\s+/, $odd_remain);
      my @even_lines = split(/\s+/, $even_remain);
      my $c = 0;
      my $game_id = "$date,$odd_t1,$even_t1";
      my @o = ($odd_open, $even_open, $filedate);
      my $a = $gamedata{$game_id}{"Open"};
      if (defined($a)) {
        my $house = "Open";
        if ($$a[0] eq $o[0] and $$a[1] eq $o[1]) {
          print "DUP $game_id $house SAME\n";
        } else {
          if (($$a[0] eq "-" or $$a[1] eq "-") and $o[0] ne "-" and $o[1] ne "-") {
            $gamedata{$game_id}{$house} = \@o;
            print "DUP $game_id $house DIFF NOWGOOD\n";
          } elsif ($o[2] > $$a[2]) {
            $gamedata{$game_id}{$house} = \@o;
            print "DUP $game_id $house DIFF NEWDATA $$a[0] $$a[1] $$a[2] $o[0] $o[1] $o[2]\n";
          } else {
            print "DUP $game_id $house DIFF NOMATTER $$a[0] $$a[1] $o[0] $o[1]\n";
          }
        }
      }
      $gamedata{$game_id}{"Open"} = \@o;
      foreach my $l_index (0..$#odd_lines) {
        last if ($l_index > $#odd_lines or $l_index > $#even_lines);
        next unless ($odd_lines[$l_index] =~ /\S/ and $even_lines[$l_index] =~ /\S/);
        my $house = $cols_to_names{$c++};
        $house = "unknown" if (!defined($house));
        next if ($house eq "SC" or $odd_lines[$l_index] eq "-" or $even_lines[$l_index] eq "-");
        my @l = ($odd_lines[$l_index], $even_lines[$l_index], $filedate);
        my $aref = $gamedata{$game_id}{$house};
        if (defined($aref)) {
          if ($$aref[0] == $l[0] and $$aref[1] == $l[1]) {
            print "DUP $game_id $house SAME\n";
          } else {
            if (($$aref[0] eq "-" or $$aref[1] eq "-") and $l[0] ne "-" and $l[1] ne "-") {
              $gamedata{$game_id}{$house} = \@l;
              print "DUP $game_id $house DIFF NOWGOOD\n";
            } elsif ($l[2] > $$aref[2]) {
              $gamedata{$game_id}{$house} = \@l;
              print "DUP $game_id $house DIFF NEWDATA $$aref[0] $$aref[1] $$aref[2] $l[0] $l[1] $l[2]\n";
            } else {
              print "DUP $game_id $house DIFF NOMATTER $$aref[0] $$aref[1] $l[0] $l[1]\n";
            }
          }
        } else {
          $gamedata{$game_id}{$house} = \@l;
        }
#        printf ",%s,%s,%.3f,%s,%.3f", $house, $odd_lines[$l_index], convert_to_odds($odd_lines[$l_index]),
#               $even_lines[$l_index], convert_to_odds($even_lines[$l_index]);
#        printf " Line[\"%-20s = \"%s\" %.3f\n",  $house . "\"]", $lines[$l_index], convert_to_odds($lines[$l_index]);
      }
#      print "\n";
      $odd_open = undef;
      $odd_t1 = undef;
      $odd_remain = undef;
#      print "Lines = \"$remain\"\n";
#    } else {
#      print "Unparseable: \"$_\"\n";
    }
  }
  close(PARSE);
}

sub convert_to_odds($) {
  my $v = shift;
  return -1 if ($v eq "-");
  return 0.5 if ($v eq "PK");
  return -1 if (abs($v) < 100);
  if ($v < 0) {
    $v *= -1;
    return $v / ($v + 100);
  } else {
    return 100 / ($v + 100);
  }
}

sub trim($) {
  my $s = shift;
  $s =~ s/^\s*//g;
  $s =~ s/\s*$//g;
  return $s;
}

