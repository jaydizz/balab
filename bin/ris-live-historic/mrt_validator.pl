#!/usr/bin/perl 

use strict;
use warnings;


use LWP::Simple;
use PerlIO::gzip;
use Net::MRT;
use Net::Patricia;
use Storable qw (retrieve);

use 5.26.1;


$Net::MRT::USE_RFC4760 = -1; #For Compatibility with older MRT-Formats.

#my @roa_files = glob("/mount/storage/stash/historic/";

#foreach my $file (@roas) {
my $file = shift or die("Need file");
  my ($year, $month, $day);
  
  if ( $file =~ /(20\d{2})-(\d{2})-(\d{2})-rpkiv4\.storable/ ) {
    ($year, $month, $day) = ($1, $2, $3);
  } else {
    exit(0);
  } 
  
  my $pt_v4 = retrieve $file or die("Could not load v4 trie");
  $file =~ s/rpkiv4/rpkiv6/;
  my $pt_v6 = retrieve $file;
  
  my $url = "http://data.ris.ripe.net/rrc00/$year.$month/bview.$year$month$day.0800.gz";
  
  $LWP::Simple::ua->show_progress(1);
  my $archive = get($url);
  open my $mrt, "<:gzip", \$archive or die $!;
  while (my $dd = Net::MRT::mrt_read_next($mrt)) {
      if ( $dd->{type} == 13 && ( $dd->{subtype} == 2 || $dd->{subtype} == 4 ) ) {
        say "$dd->{prefix} is in table";
      }
  }
#}




