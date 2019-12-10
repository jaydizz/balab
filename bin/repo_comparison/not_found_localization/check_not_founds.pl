#!/usr/bin/perl 
use warnings;
use strict;
use 5.26.1;

use Net::Patricia;
use Storable qw( retrieve );

my $file = shift;

open (my $FH, '<', $file);

my $pt_v4 = retrieve("./pt_v4.storable");
my $pt_v6 = retrieve("./pt_v6.storable");

my $blame_orgs = {};

my $total = 0;
while ( <$FH> ) {
  chomp($_);
  my $pt = (index $_, ':') > 0 ? $pt_v6 : $pt_v4;

  my $org = $pt->match_string($_);
  next if (! $org);
  #if ( $org eq "RIPE" ) {
  #  say $_;
  #}i 
  $total++;  
  $blame_orgs->{$org} = 0 unless $blame_orgs->{$org};
  $blame_orgs->{$org}++;
}


my $header = join( ',', sort { $blame_orgs->{$b} <=> $blame_orgs->{$a} } keys %$blame_orgs);
my $output = join( ',', map { $blame_orgs->{$_}/$total * 100 } sort { $blame_orgs->{$b} <=> $blame_orgs->{$a} } keys %$blame_orgs);

say $header;
say $output;  
