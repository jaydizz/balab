#!/usr/bin/perl

use strict;
use warnings;

use 5.26.1;

my @files = `find /mount/storage/stash/repo_compare/*invalids`;
chomp(@files);
my $bad_source = {};

foreach my $file (@files) {
  
  open ( my $FH, '<', $file);
  while ( <$FH> ) {
    my ($source, $count) = split /,/, $_;
    $bad_source->{$source} = 0 unless $bad_source->{$source};
    $bad_source->{$source} = $bad_source->{$source} + $count;
  }
}

foreach my $source (sort { $bad_source->{$b} <=> $bad_source->{$a} } keys %$bad_source ) {
    say "$source & $bad_source->{$source} &   &   &  \\\\" unless $bad_source->{$source} < 10;
}
foreach my $source (sort { $bad_source->{$a} <=> $bad_source->{$b} } keys %$bad_source ) {
    say "whois $source" unless $bad_source->{$source} < 10;
}

