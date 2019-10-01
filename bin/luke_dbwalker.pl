#!/usr/bin/perl 

=head1 NAME

Luke Databasewalker

=head1 ABSTRACT

This Tool is used to walk over different routing databases and generates a patricia trie for route validation. The tool can parse IRR-Files in RPSL-format and PRKI-Roas as exported by routinator3000 inr vrps format. 
The Patricia Trie holds IP-objects. On Match, a hashref is returned, holding validation-data.

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
use lib '../lib';

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

my $irr_dir  = $opts{i} || '../db/irr_test/';
my $irr_flag = defined $opts{b} ? $opts{b} : 1;
say $irr_flag;
my $rpki_flag = defined $opts{r} ? $opts{r} : 1;
my $rpki_dir  = $opts{p} || '../db/rpki/';
my $output_dir = $opts{o} || '../stash/';
my $DEBUG = $opts{d} || undef;
my $force      = $opts{f} || 0;
my $output_files = {
  rpki_out_v4    => "$output_dir/rpki-patricia-v4.storable",
  rpki_out_v6    => "$output_dir/rpki-patricia-v6.storable",
  irr_out_v4    => "$output_dir/irr-patricia-v4.storable",
  irr_out_v6    => "$output_dir/irr-patricia-v6.storable",
};  


my $pt_irr;
my $pt_rpki;



my @irr_files = glob("$irr_dir*");
my @rpki_files = glob("$rpki_dir*");

# Remove directories and sh scripts.
@irr_files = grep { -f $_ } @irr_files;
@irr_files = grep {!/\.sh/} @irr_files;
@irr_files = grep {!/\.gz/} @irr_files;
@rpki_files = grep { -f $_ } @rpki_files;
@rpki_files = grep {!/\.sh/} @rpki_files;

############################################################################
#######################  MAIN ##############################################
############################################################################

print_intro_header();
#
# Iterating over all routing-dbs and parsing for route-objects.
# This populates the stashes for v4 and v6.
#
if ($irr_flag) {
  if ( $#irr_files < 3 && !$force ) {
    die "Found less than three irrs. Use Force. Aborting."
  };

  print_header("IRR");
  $pt_irr = process_irr(\@irr_files);  
  store $pt_irr->{v4}, $output_files->{'irr_out_v4'} unless $DEBUG;
  store $pt_irr->{v6}, $output_files->{'irr_out_v6'} unless $DEBUG;
}

#
#
#  Process RPKI shizzle.
#
#
#

if ($rpki_flag) {
  print_header("RPKI"); 
  $pt_rpki = process_roas(\@rpki_files);
  store $pt_rpki->{v4}, $output_files->{'rpki_out_v4'} unless $DEBUG;
  store $pt_rpki->{v6}, $output_files->{'rpki_out_v6'} unless $DEBUG;
}


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

