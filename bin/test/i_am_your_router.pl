#!/usr/bin/perl 

use strict;
use warnings;
use 5.10.0;
use Storable;

my $stash;

$stash = retrieve('../../stash/route-objects.storable');
 
my %stash = %$stash;

my $prefix = shift or die("We needs arguments");
my $asn    = shift;

if ( !($asn =~ /AS/) ) {
  $asn = "AS$asn";
}

my $start = time;
if ($stash{$prefix}->{$asn}) {
  say "valid";
} else {
  say "invalid. Possible origin-asns:";
  foreach (sort keys %{ $stash{$prefix} }) {
    say "$_";
  }
}

my $duration = time - $start;
say "duration: Found after $duration";
