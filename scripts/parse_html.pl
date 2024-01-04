#!/usr/bin/perl 

use HTML::Parser;
use strict;
use warnings;

#my %IGNORE_TAGS = ( "br" => 1, "hr" => 1, "img" => 1, "ul" => 1);
my %IGNORE_TAGS;

my $infile = shift(@ARGV);
exit 1 if (!defined($infile) or ! -f $infile);

my $indent_level = 0;
my %start_count;
my %end_count;

sub end_handler {
  my ($self, $tagname) = @_;
  return if (defined($IGNORE_TAGS{$tagname}));
  my $i = " " x (1 * --$indent_level);
  print $i . "END $tagname\n";
  $end_count{$tagname} += 1;
}

sub text_handler {
  my ($self, $is_cdata, $dtext) = @_;
  return if $is_cdata;
  my $i = " " x (1 * $indent_level);
  if ($dtext =~ /^\s*(.*)\s*$/) {
    print $i . "TEXTM \"$1\"\n" if (length($1));
  } else {
    print $i . "TEXTR \"$dtext\"\n" if (length($dtext));
  }
}

sub start_handler {
  my ($self, $tagname, $attr, $attrseq, $origtext) = @_;
  return if (defined($IGNORE_TAGS{$tagname}));
  my $i = " " x (2 * $indent_level++);
  print $i . "START $tagname $origtext\n";
  $start_count{$tagname} += 1;
  if ($origtext =~ /.*\/\s*>$/) {
    end_handler $self, $tagname
  }
}

my $parser = HTML::Parser->new(api_version => 3);
$parser->handler(start => \&start_handler, "self,tagname,attr,attrseq,text");
$parser->handler(end => \&end_handler, "self,tagname");
$parser->handler(text => \&text_handler, "self,is_cdata,dtext");
print "===\n";
$parser->parse_file($infile);
print "===\n";
foreach my $t (sort { $start_count{$b} <=> $start_count{$a} } keys %start_count) {
  my $s = $start_count{$t};
  my $e = $end_count{$t};
  $e = 0 if (!defined($e));
  printf "%10s %5d %5d %s\n", $t, $s, $e, ($s == $e) ? "" : "ERROR";
}
