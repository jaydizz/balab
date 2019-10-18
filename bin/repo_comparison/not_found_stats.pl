#!/usr/bin/perl

use strict;
use warnings;

use 5.26.1;

my @files = `find /mount/storage/stash/repo_compare/*not_found`;
chomp(@files);
my $bad_asn = {};

foreach my $file (@files) {
  
  open ( my $FH, '<', $file);
  while ( <$FH> ) {
    my ($as, $count) = split /,/, $_;
    $bad_asn->{$as} = 0 unless $bad_asn->{$as};
    $bad_asn->{$as} = $bad_asn->{$as} + $count;
  }
}

foreach my $as (sort { $bad_asn->{$b} <=> $bad_asn->{$a} } keys %$bad_asn ) {
    say "$as & $bad_asn->{$as} &   &   &  \\\\" unless $bad_asn->{$as} < 10;
}
foreach my $as (sort { $bad_asn->{$a} <=> $bad_asn->{$b} } keys %$bad_asn ) {
    say "whois $as" unless $bad_asn->{$as} < 10;
}

