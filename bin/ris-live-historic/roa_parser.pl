#!/usr/bin/perl 

=head1 NAME

Luke Databasewalker

=head1 ABSTRACT


=head1 SYNOPSIS

  ./luke_dbwalker.pl [OPTIONS]

  OPTIONS:
    i    - /path/to/Irr/files     [ ../db/irr/  ]
    p    - /path/to/rPki/files    [ ../db/rpki/ ]
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

$Net::DBWalker::VERBOSE = 1;

my $rpki_dir  = $opts{p} || './mount/storage/db/historic/rpki';
my $output_dir = $opts{o} || '/mount/storage/stash/historic';
my $DEBUG = $opts{d} || undef;
my $force      = $opts{f} || 0;





#my @rpki_files = qw(./rpki/apnic-arin.tal/2015/11/11/roas.csv); 
my @rpki_files = `find $rpki_dir`;
chomp @rpki_files;
# Remove directories and sh scripts.
@rpki_files = grep { -f $_ } @rpki_files;
@rpki_files = grep {!/\.sh/} @rpki_files;
@rpki_files = grep {/roas\.csv/} @rpki_files;

############################################################################
#######################  MAIN ##############################################
############################################################################

print_intro_header();
#
#
#  Process RPKI shizzle.
#
#
#


# We only process every 10th file. These are soo many!

my $process_files  = { };
for (my $i = 0; $i < scalar @rpki_files/10; $i++) {
  my $file = $rpki_files[10*$i];
  $file =~ /^.*\/((?:\w|-|.)+tal)\/(20[0-9]+)\/(\d{2})\/(\d{2})/;
  my ($source, $year, $month, $day) = ($1, $2, $3, $4);

  my @files = grep { /$year\/$month\/$day\// } @rpki_files;

  $process_files->{"$year-$month-$day"}{filelist} = \@files;
  $process_files->{"$year-$month-$day"}{year} = $year;
  $process_files->{"$year-$month-$day"}{month} = $month;
  $process_files->{"$year-$month-$day"}{day} = $day;
  $DB::single = 1;
}
print_header("RPKI"); 
logger("Processing " .  " files");

my $format = {
  delimiter  => ',',
  origin_as  => 1,
  prefix     => 2,
  max_length => 3
};

open (my $STATS, '>' ,"$output_dir/stats/stats.txt") or die(" could not open $output_dir/stats/stats.txt");

foreach my $files_ref ( sort keys %$process_files ) {
  my $year = $process_files->{$files_ref}->{year};
  my $month = $process_files->{$files_ref}->{month};
  my $day = $process_files->{$files_ref}->{day};
  
  my $pt_rpki = process_roas($process_files->{$files_ref}{filelist}, $format);
  logger("Storing Files"); 
  store $pt_rpki->{v4}, "$output_dir//$year-$month-$day-rpkiv4.storable" unless $DEBUG;
  store $pt_rpki->{v6}, "$output_dir//$year-$month-$day-rpkiv6.storable" unless $DEBUG;
  
  print $STATS "$year-$month-$day\t\t\t" . $pt_rpki->{size}->{v4} . "\t\t\t" . $pt_rpki->{size}->{v6} . "\n";

  logger("...DONE...", 'green');
}

close $STATS;

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

