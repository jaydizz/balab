#!/usr/bin/perl

use strict;
use warnings;
use 5.26.1;

use Storable qw( retrieve );
use Data::Dumper;

my $dir = "/mount/storage/stash/ripe-atlas/raw/";

my @files = `find $dir`;
chomp(@files);
@files = grep { /msm/ } @files;

my $total_asns;

my $asn = { } ;

my $scores = {
  'success'         => -9999,
  'stars'           => 1,
  'network_unreach' => 3,
  'host_unreach'    => 2,
};

my $down_covered = { };

foreach my $file ( @files ) {
  my $msm = retrieve( $file );
  my @traces = @{ $msm };
  foreach my $trace ( @traces ) {
    my $success      = $trace->{success};
    my $success_text = $trace->{success_text};

    if ( $success ) { #Goofed up. None of the ASs is filtering.
      map {
        $asn->{$_} = 0 unless $asn->{$_}; 
        $asn->{$_}+= $scores->{$success_text} 
      } $trace->{as_path}->@*;
    } else {
      process_as_path($trace);
    }
  }
}

sub process_as_path { 
  my $trace = shift;
  
  my $last_hop = pop $trace->{as_path}->@*;
  return  if (! (defined $last_hop) );

  $asn->{$last_hop} = 0 unless $asn->{$last_hop};
  $asn->{$last_hop} += $scores->{$trace->{success_text}};
  map {
    $down_covered->{$_} = 0 unless $down_covered->{$_}; 
    $down_covered->{$_}+= $scores->{$trace->{success_text}} 
  } $trace->{as_path}->@*;
  #say Dumper $trace; 
}
  
   
foreach my $as ( sort { $asn->{$a} <=> $asn->{$b} } keys %$asn ) {
  say "$as, $asn->{$as}";
}

my @protected;
map { push @protected, $_  if $asn->{$_} > 1 } keys %$asn;

say "\n==================\n";

say "Seen: " . scalar keys %$asn;
say "ROV-drop: " . scalar @protected;
say "Percentage: " . scalar @protected / (scalar keys %$asn) * 100;

say "Downstream Covered: " . scalar keys %$down_covered;
say "Combined Percentage: " . (scalar @protected + scalar keys %$down_covered)  / (scalar keys %$asn) * 100
