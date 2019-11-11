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

my $VERBOSE = shift or 0;



my $url = "http://data.ris.ripe.net/rrc00/latest-bview.gz";
$LWP::Simple::ua->show_progress(1);
my $archive = get($url);
exit(0) unless  ($archive);

open my $mrt, "<:gzip", \$archive or die $!;


while (my $decode = Net::MRT::mrt_read_next($mrt)) {
  if ( $decode->{type} == 13 && ( $decode->{subtype} == 2 || $decode->{subtype} == 4 ) ) {
    say Dumper $decode;
    exit(0);
  }
}

