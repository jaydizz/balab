#!/usr/bin/perl 

use strict;
use warnings;
use lib '../../lib';

use Local::Logger qw( :all);
use Net::DBWalker qw( process_irr process_roas);

use Storable qw(store dclone);
use Data::Dumper;
use 5.10.0;


our $VERSION = "1.0";

$Net::DBWalker::VERBOSE = 0;

my $output_dir = '/mount/storage/stash/historic';
my $file = shift;



#my @rpki_files = qw(./rpki/apnic-arin.tal/2015/11/11/roas.csv); 

############################################################################
#######################  MAIN ##############################################
############################################################################


my ($year, $month, $day);
if ( $file =~ /current_(2019)_(\d{2})_(\d{2})*/ ){
  ($year, $month, $day) = ($1 ,$2, $3);
} else {
  exit(0);
}

my $pt_rpki = process_roas($file);
store $pt_rpki->{v4}, "$output_dir//$year-$month-$day-rpkiv4.storable";
store $pt_rpki->{v6}, "$output_dir//$year-$month-$day-rpkiv6.storable";

exit(0);
############################################################################
#######################  END OF MAIN  ######################################
############################################################################
