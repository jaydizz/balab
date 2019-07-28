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
check_prefix($prefix, $asn);

#while (1) {
#  say "Enter prefix";
#  my $prefix = <>;
#  say "Enter ASN";
#  my $asn = <>;
#  if ( !($asn =~ /AS/) ) {
#    $asn = "AS$asn";
#  }
#  check_prefix($prefix, $asn);
#}

#check_prefix('136.156.0.0/16', 'AS786');

sub check_prefix {
  my $prefix = shift;
  my $asn = shift;
  my $start = time;
  if ($stash->{direct}->{$prefix}->{$asn}) {
    say "valid, exact match";
  } elsif ($stash->{expanded}->{$prefix}->{$asn}) {
    say "valid, covered by less specific";
  } else {
    say "invalid. Possible origin-asns:";
    foreach (sort keys %{ $stash->{direct}->{$prefix} }) {
      say "$_";
    }
  }
  my $duration = time - $start;
  say "duration: Found after $duration";
}
