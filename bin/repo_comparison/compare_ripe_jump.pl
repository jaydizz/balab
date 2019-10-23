#!/usr/bin/perl 

use warnings;
use strict;
use 5.26.1;
my $new_roas = "/mount/storage/db/historic/rpki/ripencc.tal/2019/09/12/roas.csv";
my $old_roas = "/mount/storage/db/historic/rpki/ripencc.tal/2019/09/11/roas.csv";

my @diffs = `diff $old_roas  $new_roas`;
chomp(@diffs);

@diffs = grep { />.*/ } @diffs;


my $asns;

foreach my $line (@diffs) {
  my ($tmp, $asn, $prefix) = split /,/, $line;
  $asns->{$asn}++;
  say "$prefix" if ($asn eq "AS8551");
}

foreach my $as (sort { $asns->{$b} <=> $asns->{$a} } keys %$asns ) {
   say "$as ->  $asns->{$as}";
}

