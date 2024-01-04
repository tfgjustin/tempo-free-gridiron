#!/usr/bin/perl 
#===============================================================================
#
#         FILE: fetch_ncaa_summary.pl
#
#        USAGE: ./fetch_ncaa_summary.pl  <output_directory>
#
#  DESCRIPTION: Download the per-team summary files.
#
#      OPTIONS: ---
# REQUIREMENTS: ---
#         BUGS: ---
#        NOTES: ---
#       AUTHOR: YOUR NAME (), 
# ORGANIZATION: 
#      VERSION: 1.0
#      CREATED: 09/02/2013 02:43:45 PM
#     REVISION: ---
#===============================================================================

use LWP::UserAgent;
use TempoFree;
use strict;
use warnings;

my $BASE_URL = "http://stats.ncaa.org/player/game_by_game?"
  . "game_sport_year_ctl_id=11520&org_id=%d&stats_player_seq=-100";
my $USERAGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_4) "
  . "AppleWebKit/536.30.1 (KHTML, like Gecko) Version/6.0.5 Safari/536.30.1";
my @HEADERS = (
   'User-Agent' => $USERAGENT,
   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, 
        image/pjpeg, image/png, */*',
   'Accept-Charset' => 'iso-8859-1,*,utf-8',
   'Accept-Language' => 'en-US',
);

sub check_and_download($$);

my $output_directory = shift(@ARGV);

exit 1 if (!defined($output_directory) or ! -d $output_directory);

my %id2name;
my %id2conf;
my %conf2teams;
my %is_bcs;
LoadConferences(\%id2name, \%id2conf, \%conf2teams, \%is_bcs);

my @ids = @ARGV;
@ids = keys %id2conf if (!@ARGV);
#print join(' ', @ids) . "\n"; exit 1;
my @allurls;
foreach my $tid (@ids) {
  next if ($id2conf{$tid} eq "FCS");
  my $url = sprintf $BASE_URL, $tid - 1000;
  my $outpath = sprintf "%s/%d.summary.html", $output_directory, $tid;
  push(@allurls, join('|', $outpath, $url));
}

my $browser = LWP::UserAgent->new;
my $total_bytes = 0;
foreach my $pair (@allurls) {
  $total_bytes += check_and_download($browser, $pair);
}
print "Downloaded $total_bytes\n" if ($total_bytes);
exit 0;

sub check_and_download($$) {
  my $useragent = shift;
  my $pair = shift;
  my ($outpath, $inurl) = split(/\|/, $pair);
  if (!defined($inurl)) {
    warn "Invalid outpath/URL pair: \"$pair\"";
    return 0;
  }
  my $tmpoutpath = $outpath . ".tmp";
  open my $outfh, ">", $tmpoutpath or do {
    warn "Error opening $tmpoutpath for writing: $!";
    return 0;
  };
  my $response = $useragent->get($inurl, @HEADERS);
  my $status_line = $response->status_line;
  if (!$response->is_success) {
    print STDERR "URL: $inurl\n  Status: $status_line\n";
    close $outfh;
    unlink $tmpoutpath;
    return 0;
  }
  print $outfh $response->content;
  close $outfh;
  rename $tmpoutpath, $outpath;
  return length($response->content);
}
