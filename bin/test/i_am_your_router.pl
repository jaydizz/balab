#!/usr/bin/perl 

use strict;
use warnings;
use Net::Patricia;
use NetAddr::IP;
use 5.10.0;
use Storable;
use Time::HiRes qw(gettimeofday tv_interval);

my $ptv4 = retrieve('../../stash/irr-patricia-v4.storable');
my $ptv6 = retrieve('../../stash/irr-patricia-v6.storable');

my $prefix = shift or die("We needs arguments");
my $asn    = shift;

if ( !($asn =~ /AS/) ) {
  $asn = "AS$asn";
}
check_prefix($prefix, $asn);

while (1) {
  say "Enter prefix";
  my $prefix = <>;
  say "Enter ASN";
  my $asn = <>;
  
  chomp($prefix);
  chomp($asn);
  if ( !($asn =~ /AS/) ) {
    $asn = "AS$asn";
  }
  check_prefix($prefix, $asn);
}

#check_prefix('136.156.0.0/16', 'AS786');

sub check_prefix {
  my $prefix = shift;
  my $asn = shift;
  my $t0 = [gettimeofday];

      
  my $match;

  if ( (index $prefix, ":")  > 0) {
    $match = $ptv6->match_string($prefix); 
  } else {
    $match = $ptv4->match_string($prefix); 
  }

  $prefix =~ /.*\/(\d+)/;
  my $prefix_length = $1;

  
  if ( $match ) {
  $DB::single = 1;
    if ( $match->{$asn}) {
      if ( $match->{length} == $prefix_length ) {
        say "Prefix $match->{prefix} matches exactly";
      } else {
        say "Prefix ist covered by less specific $match->{prefix}";
      }
    } else {
      say "Invalid! Possible ASs:";
      foreach my $as ( keys %$match ) {
        print "$as ";
      }
      print "\n";
    }
  } else {
   say "not found!";
  }
  
  my $duration = tv_interval ( $t0, [gettimeofday]);
  say "duration: Found after $duration";
}
