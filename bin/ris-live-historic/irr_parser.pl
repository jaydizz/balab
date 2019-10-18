#!/usr/bin/perl 

=head1 NAME

Luke Databasewalker

=head1 ABSTRACT

This tools walks all historicly saved irrs and creates patricia tries from each of them. 

=head1 SYNOPSIS

  ./luke_dbwalker.pl [OPTIONS]

  OPTIONS:
    i    - /path/to/Irr/files     [ ../db/irr/  ]
    p    - /path/to/rPki/files    [ ../db/irr/ ]
    o    - /path/to/Output/dir    [ ../stash/   ]
    b    - 
            Process IRR-dB-files  [ true ]
    r    - 
            Process RPKI-files    [ true ]
    d    -  
            debug. Gets _really_ chatty.
   

=cut

use strict;
use warnings;
use lib '../../lib';

use Local::Logger qw( :all);
use Net::DBWalker qw( process_irr process_roas);

use Getopt::Std;
use Storable qw(store dclone);
use Data::Dumper;
use 5.10.0;

my %opts;
getopts( 'fi:o:db:r:p:', \%opts ) or usage();

our $VERSION = "1.0";

$Net::DBWalker::VERBOSE = 0;

my $irr_dir  = '../../db/irr/old/';
my $output_dir = '../../stash/historic/irr/';
my $DEBUG = undef;
my $force = 0;

my $date = shift or die ("Need date");;

my $year;
my $month;
my $day;

if ($date =~ /2019_(\d{2})_(\d{2})-00/) {
  $year = 2019;
  $month = $1;
  $day   = $2;
} else {
  die ("No valid date given");
}  

# Input sanitation.

exit(0) if (-e "$output_dir//$year-$month-$day-irrv4.storable" );

my @irr_files = `find $irr_dir`;
chomp @irr_files;
# Remove directories and sh scripts and limit to files from a certain date.
@irr_files = grep { -f $_ } @irr_files;
@irr_files = grep {!/\.sh/} @irr_files;
@irr_files = grep {/$date/} @irr_files;

warn("Too few files for $date") if scalar @irr_files < 3;
############################################################################
#######################  MAIN ##############################################
############################################################################

#print_intro_header();
#
#
#  Process RPKI shizzle.
#
#
#



# We only process every 10th file. These are soo many!

#print_header("IRR"); 
#logger("Processing " .  " files");

 
  
my $pt_irr = process_irr(\@irr_files);
#logger("Storing Files"); 
store $pt_irr->{v4}, "$output_dir//$year-$month-$day-irrv4.storable" unless $DEBUG;
store $pt_irr->{v6}, "$output_dir//$year-$month-$day-irrv6.storable" unless $DEBUG;

print "$year-$month-$day\t\t\t" . $pt_irr->{size}->{v4} . "\t\t\t" . $pt_irr->{size}->{v6} . "\n";

#logger("...DONE...", 'green');


exit(0);
############################################################################
#######################  END OF MAIN  ######################################
############################################################################

sub print_intro_header {
  my $db = shift;
  my $time = get_formated_time(); 
  my $msg =<<"EOF";

                    ____
                  (xXXXX|xx======---(-
                  /     |
                 /    XX|
                /xxx XXX|     LUKE DBWALKER PARSES IN LESS THAN TWO PARSECS.
               /xxx X   |
              / ________|
      __ ____/_|_|_______\\_
  ###|=||________|_________|_
      ~~   |==| __  _  __   /|~~~~~~~~~-------------_______
           |==| ||(( ||()| | |XXXXXXXX|                    >
      __   |==| ~~__~__~~__ \\|_________-------------~~~~~~~
  ###|=||~~~~~~~~|_______  |"
      ~~ ~~~~\\~|~|       /~
              \\ ~~~~~~~~~
               \\xxx X   |
                \\xxx XXX|
                 \\    XX|                
                  \\     |                Version: $VERSION.
                  (xXXXX|xx======---(-   Github: https://git.io/fjQD5
                    ~~~~                   
Graphic stolen from http://www.ascii-art.de/ascii/s/starwars.txt
By Phil Powell

EOF
  print $msg;
}

sub print_header {
  my $db = shift;
  my $time = get_formated_time(); 
  my $msg =<<"EOF";
$time========================================
$time         Now Processing $db 
$time========================================
EOF
  print $msg;
}

