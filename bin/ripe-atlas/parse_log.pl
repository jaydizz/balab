#!/usr/bin/perl 

use strict;
use warnings;

use 5.26.1;
my $asn;

while (<>) {
  if ($_ =~ /AS (\d+)\s+(\d+) hits/) {
    $asn->{$1} += $2;
  }
}

foreach my $as ( sort { $asn->{$a} <=> $asn->{$b} } keys %$asn ) {
  say "$as: $asn->{$as}";
}
