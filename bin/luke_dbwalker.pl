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
use NetAddr::IP;
use 5.10.0;

my %opts;
getopts( 'i:o:d', \%opts ) or usage();

my $input_dir  = $opts{i} || '../db/*';
my $output_file = $opts{o} || '../stash/route-objects.storable';
my $debug_flag = $opts{d} || undef;


my @files = glob($input_dir);
my $stash;

foreach my $file (@files) {
  say "Processing file: $file";
  my $start = time;
  my $counter = 0;
 
  open( my $FH, '<', $file ) or die "could not open file $file";
  #Temporary Variables to hold matches.
  my $net_addr; #everything before the /
  my $mask;     #everything after the /
  my $origin_as;
  my $routeobject_found;
  my $prefix;
  
  
  while (<$FH>) { 
    #if ($_ =~ /route:\s+(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\/\d+)/) { 
    if ($_ =~ /route[6:]+\s+([\d:\.a-f]+)\/(\d+)/) { 
       
      $net_addr = $1;
      $mask = $2;
      $prefix = "$1/$2";
      $routeobject_found = 1;
    } 
    if ( $routeobject_found && $_ =~ /origin:\s+(AS\d+)/ ) {
      $origin_as = $1;
      $stash->{direct}->{$prefix}->{$origin_as} = 1 ;
      
      #If we found a prefix shorter than /24
      # we expand it, to make lookup for longer prefixes easier.
      # Split it in all possible smaller prefixes.  
      if ( $mask < 24 ) {  
        if ($debug_flag) {
          say "expanding prefix $prefix";
        }
        my $cidr = NetAddr::IP->new($prefix);
      
        # We split it up until there are only /24's left.
        for (; $mask <= 24; $mask++) { 
          my $split_ref;
          
          #Handle possible NetAddr::IP Excetions 
          eval {
            $split_ref = $cidr->splitref($mask);
          };
          if ($@) {
            warn "NetAddr::IP Excetption: $@ at:\n $prefix split into $mask";
            last;
          }
            
          #Push them all in the hashref
          foreach my $prefix ( @{ $split_ref } ) {
            $stash->{expanded}->{$prefix}->{$origin_as} = 1;
          }
        }
      }

      $routeobject_found = 0;
    
      if ($debug_flag) {
        say "found $prefix : $origin_as";
      }
      $counter++;
      ($mask, $origin_as, $prefix) = undef; 
      
      #Add some verbosity
      if (($counter % 1000 ) == 0) {
        last if $debug_flag;
        my $duration = time - $start;
        say "processed $counter prefixes in $duration seconds";
    }
    
    }

  }
  close ($FH);
  my $duration = time - $start;
  say "Done. It took $duration seconds to find $counter prefixes";
}

store ($stash, "$output_file");
