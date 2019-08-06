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
use Net::Patricia;
use 5.10.0;

my %opts;
getopts( 'i:o:d', \%opts ) or usage();

my $input_dir  = $opts{i} || '../db/irr/*';
my $output_dir = $opts{o} || '../stash/';
my $debug_flag = $opts{d} || undef;

my $outputv4 = "$output_dir/irr-patricia-v4.storable";
my $outputv6 = "$output_dir/irr-patricia-v6.storable";

# Patricia Tree for lookup.
my $ptv4 = new Net::Patricia;
my $ptv6 = new Net::Patricia AF_INET6;

# Hashrefs for route-collection. Will be written into the trie.
my $stash_v4;
my $stash_v6;

my @files = glob($input_dir);

#
# Iterating over all routing-dbs and parsing for route-objects.
# This populates the stashes for v4 and v6.
#

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
    #Handling ipv4 objects. 
    if ($_ =~ /route:\s+([\d\.]+)\/(\d+)/) { 
      $net_addr = $1;
      $mask = $2;
      $prefix = "$1/$2";
      $routeobject_found = 4;
    } 
    if ($_ =~ /route6:+\s+([\d:\.a-f]+)\/(\d+)/) { 
      $net_addr = $1;
      $mask = $2;
      $prefix = "$1/$2";
      $DB::single = 1;
      $routeobject_found = 6;
    } 
    if ( $routeobject_found && $_ =~ /origin:\s+(AS\d+)/ ) {
      if ($routeobject_found == 4) {
        $stash_v4->{$prefix}->{length} = $mask;
        $stash_v4->{$prefix}->{$1} = 1;
        $stash_v4->{$prefix}->{prefix} = $prefix;
      } else {
        $stash_v6->{$prefix}->{length} = $mask;
        $stash_v6->{$prefix}->{$1} = 1;
        $stash_v6->{$prefix}->{prefix} = $prefix;
      }
      
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
      $routeobject_found = 0;
    
    }
  }
  close ($FH);
  my $duration = time - $start;
  say "Done. It took $duration seconds to find $counter prefixes";
}

#
# Now we write the stash into a Patricia Trie. This is neccessary, because we have to store multiple
# AS's as userdata. Storing the same prefix with different userdata directly into the Patricia Trie
# just overwrites the old node. 
#

foreach my $prefix ( keys %$stash_v4 ) {
  $ptv4->add_string($prefix, $stash_v4->{$prefix});
}
foreach my $prefix ( keys %$stash_v6 ) {
  $ptv6->add_string($prefix, $stash_v6->{$prefix});
}


store ($ptv4, "$outputv4");
store ($ptv6, "$outputv6");
