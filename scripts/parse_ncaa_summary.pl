#!/usr/bin/perl 
#===============================================================================
#
#         FILE: parse_ncaa_summary.pl
#
#        USAGE: ./parse_ncaa_summary.pl <output_dir> [summary.0.html] ... [summary.N.html]
#
#  DESCRIPTION: Parse the per-team summary files from NCAA.org and figure out
#               which json files we need to download from NCAA.com. Download
#               those files.
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

my $BASE_URL = "http://www.ncaa.com/sites/default/files/data/game/football/fbs";
my $USERAGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_4) "
  . "AppleWebKit/536.30.1 (KHTML, like Gecko) Version/6.0.5 Safari/536.30.1";
my @HEADERS = (
   'User-Agent' => $USERAGENT,
   'Accept' => 'image/gif, image/x-xbitmap, image/jpeg, 
        image/pjpeg, image/png, */*',
   'Accept-Charset' => 'iso-8859-1,*,utf-8',
   'Accept-Language' => 'en-US',
);
my @JSONS = qw( boxscore.json scoringSummary.json teamStats.json pbp.json gameinfo.json );

sub url_to_files($$$$);
sub check_and_download($$);

my $output_directory = shift(@ARGV);

exit 1 if (!defined($output_directory) or ! -d $output_directory or !@ARGV);
my %boxscore_urls;
foreach my $fname (@ARGV) {
  my $tid = undef;
  if ($fname =~ /.*\/(\d{4}).summary.html$/) {
    $tid = $1;
  } else {
    warn "Invalid file name: $fname";
    next;
  }
  open my $fh, "<", $fname or do {
    warn "Error opening $fname for reading: $!";
    next;
  };
  while (<$fh>) {
    if (/.*<a href="http:\/\/www.ncaa.com\/game\/football\/fbs\/(.+)#boxscore".*/) {
      my $base = $1;
      $base =~ s/\(//g;
      $base =~ s/\)//g;
      if (!defined($boxscore_urls{$base})) {
        $boxscore_urls{$base} = $tid;
      } else {
        $boxscore_urls{$base} .= ":$tid";
      }
    }
  }
  close $fh;
}

my @allurls;
foreach my $url (keys %boxscore_urls) {
  my ($t1, $t2) = split(/:/, $boxscore_urls{$url});
  if (defined($t2)) {
    if ($t1 < $t2) {
      url_to_files($t1, $t2, $url, \@allurls);
    } else {
      url_to_files($t2, $t1, $url, \@allurls);
    }
  }
}
my $browser = LWP::UserAgent->new;
my $total_bytes = 0;
foreach my $pair (@allurls) {
  $total_bytes += check_and_download($browser, $pair);
}
print "Downloaded $total_bytes\n" if ($total_bytes);
exit 0;

sub url_to_files($$$$) {
  my $t1 = shift;
  my $t2 = shift;
  my $url = shift;
  my $aref = shift;
  my $outpath = substr($url, 0, 10);
  $outpath =~ s/\//_/g;
  foreach my $json (@JSONS) {
    my $outfile = sprintf "%s/%s_%d_%d_%s", $output_directory, $outpath, $t1, $t2, $json;
    my $inurl = $BASE_URL . "/" . $url . "/" . $json;
    my $p = join('|', $outfile, $inurl);
    push(@$aref, $p);
  }
}

sub check_and_download($$) {
  my $useragent = shift;
  my $pair = shift;
  my ($outpath, $inurl) = split(/\|/, $pair);
  if (!defined($inurl)) {
    warn "Invalid outpath/URL pair: \"$pair\"";
    return 0;
  }
  if (-f $outpath) {
#    print STDERR "EXISTS $outpath\n";
    return 0;
  }
  open my $outfh, ">", $outpath or do {
    warn "Error opening $outpath for writing: $!";
    return 0;
  };
  my $response = $useragent->get($inurl, @HEADERS);
  my $status_line = $response->status_line;
  if (!$response->is_success) {
    print STDERR "URL: $inurl\n  Status: $status_line\n";
    close $outfh;
    unlink $outpath;
    return 0;
  }
  print $outfh $response->content;
  close $outfh;
  return length($response->content);
}
