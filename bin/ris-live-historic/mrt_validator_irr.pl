#!/usr/bin/perl 

use strict;
use warnings;


use LWP::Simple;
use PerlIO::gzip;
use Net::MRT;
use Net::Patricia;

use Net::Validator qw( :all );
use Local::Logger qw( logger_no_newline );
use Storable qw (retrieve);
use Data::Dumper;
use 5.26.1;


$Net::MRT::USE_RFC4760 = -1; #For Compatibility with older MRT-Formats.

my $file = shift or die("Need file");
my $VERBOSE = shift or 0;

#open ($Net::Validator::INV_LOG, '>', "/tmp/invalids");
$Net::Validator::LOG_INVALIDS = 0;

my $count = { 
  valid     => 0,
  valid_ls  => 0,
  valid_impl=> 0,
  invalid   => 0,
  not_found => 0,
  total          => 0,
};
my ($year, $month, $day);

if ( $file =~ /(20\d{2})-(\d{2})-(\d{2})-irrv4\.storable/ ) {
  ($year, $month, $day) = ($1, $2, $3);
} else {
  exit(0);
} 

my $pt_v4 = retrieve $file or die("Could not load v4 trie");
$file =~ s/irrv4/irrv6/;
my $pt_v6 = retrieve $file;

my $url = "http://data.ris.ripe.net/rrc00/$year.$month/bview.$year$month$day.0800.gz";

$LWP::Simple::ua->show_progress($VERBOSE);
my $archive = get($url);
exit(0) unless  ($archive); 
open my $mrt, "<:gzip", \$archive or die $!;


while (my $dd = Net::MRT::mrt_read_next($mrt)) 
{
  if ( $dd->{type} == 13 && ( $dd->{subtype} == 2 || $dd->{subtype} == 4 ) ) 
  {
    next if is_invalid_prefix($dd->{prefix}); #Sometimes there is craaaap in the routes.
    foreach my $entry ( $dd->{entries}->@* ) 
    {
      my $origin_as = $entry->{AS_PATH}[-1];
      if ( ref $origin_as ) #Sometime the last entry of the AS-Path is an array, since as BGP-Speaker can append its own AS multiple times to the path. 
      { 
        next;
        #$origin_as = @{$entry->{entries}{AS_PATH}[-1]} [-1];
      }
      $count->{total}++;
      
        add_hashes( validate_irr( $dd->{prefix}, $origin_as, $pt_v4, $pt_v6)); 
        
    }
  }
  if (!($count->{total} % 1000) ) 
  {
    logger_no_newline("Processed $count->{total} routes") if $VERBOSE;
  }
}

print "\n" if $VERBOSE;;
my $header = "#";
my $line = "$year-$month-$day,";
foreach my $key (sort keys %$count) {
  next if $key eq "total";
  $header = $header . "$key,";
  $line = $line . sprintf("%.3f", $count->{$key}/$count->{total}*100) . "," ;
}
#say $header;
say $line;

sub add_hashes {
  my $hash = shift;
  foreach my $key (keys %$hash) {
    $count->{$key} = $count->{$key} + $hash->{$key};
  }
} 

sub is_invalid_prefix {
  my $prefix = shift;
  return ( $prefix eq "::" );
}
