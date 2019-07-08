#!/usr/bin/perl 

=head1 NAME
Luke Databasewalker

=head1 ABSTRACT

Tool to walk over IRR-Databases and extract route-objects. Builds a giant perl-hashmap to be loaded into RAM to be able to compute validity of Routing-Updates in Realtime. 

=head1 SYNOPSIS

./luke_dbwalker.pl -i <directory> -o <stash>

If no arguments are given, ../db and ../stash will be used

=cut

use strict;
use warnings;
use Getopt::Std;
use Storable;
use 5.10.0;

my %opts;
getopts( 'i:o:d', \%opts ) or usage();

my $input_dir  = $opts{i} || '../db/*';
my $output_file = $opts{o} || '../stash/route-objects.storable';
my $debug_flag = $opts{d} || undef;


my @files = glob($input_dir);
my %stash;
my $stash = \%stash;

foreach my $file (@files) {
  say "Processing file: $file";
  my $start = time;
  my $counter = 0;
 
  open( my $FH, '<', $file ) or die "could not open file $file";
  #Temporary Variables to hold matches.
  my $prefix;
  my $origin_as;
  my $routeobject_found;
  
  while (<$FH>) { 
    #if ($_ =~ /route:\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d+)/) { 
    if ($_ =~ /route[6:]+\s+([\d:\.\/a-f]+)/) { 
    
      $prefix = $1;
      $routeobject_found = 1;
    } 
    if ( $routeobject_found && $_ =~ /origin:\s+(AS\d+)/ ) {
      $origin_as = $1;
      $stash{$prefix}->{$origin_as} = 1 ;
      $routeobject_found = 0;
      if ($debug_flag) {
        say "found $prefix : $origin_as";
      }
      $counter++;
    }

    if ($counter > 50 && $debug_flag) {
      last;
    }
  }
  close ($FH);
  my $duration = time - $start;
  say "Done. It took $duration seconds to find $counter prefixes";
}

store ($stash, "$output_file");
