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
        $asn->{$_}->{score} = 0 unless $asn->{$_}; 
        $asn->{$_}->{score}+= $scores->{$success_text}; 
        $asn->{$_}->{mali} = 0 unless $asn->{$_}; 
        $asn->{$_}->{mali}+= 1; 
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

  $asn->{$last_hop}->{score} = 0 unless $asn->{$last_hop};
  $asn->{$last_hop}->{score} += $scores->{$trace->{success_text}};
  $asn->{$last_hop}->{boni} = 0 unless $asn->{$last_hop};
  $asn->{$last_hop}->{boni}++; #+= $scores->{$trace->{success_text}};
  map {
    $down_covered->{$_} = 0 unless $down_covered->{$_}; 
    $down_covered->{$_}+= $scores->{$trace->{success_text}} 
  } $trace->{as_path}->@*;
  #say Dumper $trace; 
}

foreach my $as ( keys %$asn ) {
  if (!$asn->{$as}->{score}) {
    $asn->{$as}->{score} = 0;
  }
  if (!$asn->{$as}->{mali}) {
    $asn->{$as}->{mali} = 0;
  }
  if (!$asn->{$as}->{boni}) {
    $asn->{$as}->{boni} = 0;
  }
}
   
foreach my $as ( sort { $asn->{$a}->{boni} <=> $asn->{$b}->{boni} } keys %$asn ) {
  my $boni = $asn->{$as}->{boni} ? $asn->{$as}->{boni} : 0;
  my $mali = $asn->{$as}->{mali} ? $asn->{$as}->{mali} : 0;
  next if ($boni == 0 || $mali == 0);
  my $mali = $asn->{$as}->{mali} ? $asn->{$as}->{mali} : 0;
  say "$as, $boni, $mali";
}

my @protected;
map { push @protected, $_  if $asn->{$_}->{score} > 1 } keys %$asn;

my @partial;
map { push @partial, $_ if $asn->{$_}->{boni} > 3 && $asn->{$_}->{mali} > 0} keys %$asn;
say "\n==================\n";

say "Seen: " . scalar keys %$asn;
say "ROV-drop: " . scalar @protected;
say "Percentage: " . scalar @protected / (scalar keys %$asn) * 100;
say "Partial Deployment: " . scalar @partial;
say "Percentage: "  . scalar @partial / (scalar keys %$asn) * 100;
say "Downstream Covered: " . scalar keys %$down_covered;
say "Combined Percentage: " . (scalar @protected + scalar keys %$down_covered)  / (scalar keys %$asn) * 100
