#!/usr/bin/perl 
#
# Usage: transform_cfbstats_to_sql.pl <year> <directory_with_cfbstats_data>
#
# E.g.,
#
# ./transform_cfbstats_to_sql.pl 2014 ~/Dropbox/2014 > 2014data.sql
#
# Then load the resulting file with the INSERT statements into your database.
#
# Before you load the data you'll need to create your MySQL database from the
# cfbstats_schema.sql file.

use DBI;
use File::Spec;
use Text::CSV;
use Time::HiRes qw(gettimeofday);
use strict;
use warnings;

# We need the database password because we need to connect to the database in
# order to get the correct escaping.
my $DBNAME = '__dbname__';
my $DBUSER = '__dbuser__';
my $DBPASS = '__dbpass__';
# Keep the number reasonable enough so no one INSERT overwhelms the backend.
my $ROWS_PER_INSERT = 500;

# Mapping of [order]:[filename] => databaseTable
# The database tables are in the cfbstats_schema.sql 
# The [order] is so we insert everything in the correct order.
my %FILE_TO_TABLE = (
  "00:conference.csv" => "conferences",
  "01:team.csv" => "teams",
  "02:stadium.csv" => "stadiums",
  "03:player.csv" => "players",
  "04:game.csv" => "games",
  "05:game-statistics.csv" => "gameStatistics",
  "06:play.csv" => "plays",
  "07:drive.csv" => "drives",
  "08:kickoff.csv" => "kickoffs",
  "09:kickoff-return.csv" => "kickoffReturns",
  "10:pass.csv" => "passes",
  "11:reception.csv" => "receptions",
  "12:rush.csv" => "rushes",
  "13:punt.csv" => "punts",
  "14:punt-return.csv" => "puntReturns",
  "15:team-game-statistics.csv" => "teamGameStatistics",
  "16:player-game-statistics.csv" => "playerGameStatistics"
);

my $season = shift(@ARGV);
my $directory = shift(@ARGV);
if (!defined($directory) or ! -d $directory) {
  die "Usage: $0 <season> <base_directory>\n";
}

my $QUOTE_FUNC = DBI->connect("DBI:mysql:database=$DBNAME", $DBUSER, $DBPASS) or die "Cannot connect to DBH";

# Iterate over all the tables we'd like to update
foreach my $fkey (sort { $a cmp $b } keys %FILE_TO_TABLE) {
  my ($priority, $fname) = split(/:/, $fkey);
  my $full_fname = File::Spec->catpath(undef, $directory, $fname);
  print "-- $fkey\n";
  # Keep track of how long it takes to parse each file.
  my $start_time = gettimeofday();
  printf STDERR "%-30s ... ", $fkey;
  # Create a new CSV parser. One interesting failure mode of CSV parsing in perl
  # is that if the parser fails because of a wonky row, it refuses to parse
  # anything after that. This, at least, limits the damage to one file.
  my $CSV_PARSER = Text::CSV->new() or die "Cannot use CSV: " . Text::CSV->error_diag();
  open my $fh, "<", $full_fname;
  my @datarows;
  while (my $row = $CSV_PARSER->getline($fh)) {
    my @final = ( $season );
    # The first entry in each row in the CFBStats files will always be an
    # integer. If we see something that's a letter then we know we're seeing a
    # column header.
    if ($row->[0] =~ /[A-Za-z]/) {
      printf "-- Invalid row ID: '%s'\n", $row->[0];
      next;
    }
    # Go through each item in the parsed row and (a) remove the carriage returns
    # (should only happen at the end of lines) and (b) translate any empty
    # values in the CSV to NULL database values (instead of empty strings).
    foreach my $idx (0..$#$row) {
      my $val = $row->[$idx];
      $val =~ s/\r//g;
      $val = $QUOTE_FUNC->quote($val);
      $val = 'NULL' if (!length($val) or $val eq "''");
      push(@final, $val);
    }
    push(@datarows, "\n(" . join(',', @final) . ")");
  }
  close $fh;
  if (!@datarows) {
    # Whoops, no data in this file. Move on.
    print "-- No data for $fkey in $full_fname\n";
    print STDERR " No data for $fkey in $full_fname\n";
    next;
  }
  # Batch inserts into groups of -- at most -- $ROWS_PER_INSERT -- rows per
  # insert.
  my $start_idx = 0;
  while ($start_idx < $#datarows) {
    my $end_idx = $start_idx + $ROWS_PER_INSERT - 1;
    $end_idx = $#datarows if ($end_idx > $#datarows);
    print "INSERT IGNORE INTO " . $FILE_TO_TABLE{$fkey} . " VALUES";
    print join(',', @datarows[$start_idx .. $end_idx]) . ";\n";
    $start_idx += $ROWS_PER_INSERT;
  }
  # Print some stats as to how many rows we parsed, how long it took to parse
  # them, and the rate at which we parsed them.
  my $runtime = gettimeofday() - $start_time;
  printf STDERR "%8d rows in %6.3f sec @ %6.3f sec/1000 rows\n",
    scalar(@datarows), $runtime, 1000 * $runtime / scalar(@datarows);
}
