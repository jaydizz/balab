#!/usr/bin/perl 

=head1 NAME
Luke Databasewalker

=head1 ABSTRACT

Tool to walk over IRR-Databases and extract route-objects. Builds a giant perl-hashmap to be loaded into RAM to be able to compute validity of Routing-Updates in Realtime. 
Can additionally process vrps-data as exported by routinator.
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
getopts( 'i:o:d:b:r', \%opts ) or usage();

my $irr_dir  = $opts{i} || '../db/irr/*';
my $irr_flag = $opts{b} ||  1;
my $rpki_flag = $opts{r} || 1;
my $rpki_dir  = $opts{p} || '../db/rpki/*';
my $output_dir = $opts{o} || '../stash/';
my $debug_flag = $opts{d} || undef;

my $rpki_out_v4 = "$output_dir/rpki-patricia-v4.storable";
my $rpki_out_v6 = "$output_dir/rpki-patricia-v6.storable";

my $irr_out_v4 = "$output_dir/irr-patricia-v4.storable";
my $irr_out_v6 = "$output_dir/irr-patricia-v6.storable";

# Patricia Tree for lookup.
my $pt_irr_v4 = new Net::Patricia;
my $pt_irr_v6 = new Net::Patricia AF_INET6;

my $pt_rpki_v4 = new Net::Patricia;
my $pt_rpki_v6 = new Net::Patricia AF_INET6;

# Hashrefs for route-collection. Will be written into the trie.
my $stash_irr_v4;
my $stash_irr_v6;

my $stash_rpki_v4;
my $stash_rpki_v6;

my @irr_files = glob($irr_dir);
my @rpki_files = glob($rpki_dir);

#
# Iterating over all routing-dbs and parsing for route-objects.
# This populates the stashes for v4 and v6.
#
if ($irr_flag) {
  foreach my $file (@irr_files) {
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
          $stash_irr_v4->{$prefix}->{length} = $mask;
          $stash_irr_v4->{$prefix}->{$1} = 1;
          $stash_irr_v4->{$prefix}->{prefix} = $prefix;
        } else {
          $stash_irr_v6->{$prefix}->{length} = $mask;
          $stash_irr_v6->{$prefix}->{$1} = 1;
          $stash_irr_v6->{$prefix}->{prefix} = $prefix;
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
  # Now we write the stash_irr into a Patricia Trie. This is neccessary, because we have to store multiple
  # AS's as userdata. Storing the same prefix with different userdata directly into the Patricia Trie
  # just overwrites the old node. 
  #

  foreach my $prefix ( keys %$stash_irr_v4 ) {
    $pt_irr_v4->add_string($prefix, $stash_irr_v4->{$prefix});
  }
  foreach my $prefix ( keys %$stash_irr_v6 ) {
    $pt_irr_v6->add_string($prefix, $stash_irr_v6->{$prefix});
  }


  store ($pt_irr_v4, "$irr_out_v4");
  store ($pt_irr_v6, "$irr_out_v6");
}

if ($rpki_flag) {
  say "Now walking over rpki dir";
  
  #Preocess each rpki-file
  foreach my $file (@rpki_files) {
    say "Processing $file";
    open (my $FH, '<', $file);
    my $header = <$FH>; # stripping the header. 
    
    
    while (<$FH>) {
      my ($origin_as, $prefix, $max_length) = split /,/, $_;
      
      if ( (index $prefix, ":") > 0) {#v6
        $stash_rpki_v6->{$prefix}->{$origin_as}->{max_length} = $max_length;
        $stash_rpki_v6->{$prefix}->{prefix} = $prefix;
      } else { 
        $stash_rpki_v4->{$prefix}->{$origin_as}->{max_length} = $max_length;
        $stash_rpki_v4->{$prefix}->{prefix} = $prefix;
      }
    } 
  } 
  
  # Contruct the tree
  foreach my $prefix ( sort keys %$stash_rpki_v4 ) {
    eval {
      $pt_rpki_v4->add_string($prefix, $stash_rpki_v4->{$prefix});
    }; if ($@) {
      die "FUCK! $prefix, $stash_rpki_v4->{$prefix}";
    }
  }
  foreach my $prefix ( keys %$stash_rpki_v6 ) {
    $pt_rpki_v6->add_string($prefix, $stash_rpki_v6->{$prefix});
  }


  store ($pt_rpki_v4, "$rpki_out_v4");
  store ($pt_rpki_v6, "$rpki_out_v6");
} 
