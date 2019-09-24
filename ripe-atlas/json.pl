#!/usr/bin/perl 

use strict;
use warnings;
use Mojo::JSON qw( decode_json );
use Data::Dumper;

use 5.10.0;

my $file = shift;
my $output_file = "/tmp/out.txt";

open (my $FH, "<", $file);
open (my $OUT, ">", $output_file);

my $doc = <$FH>;

my $json = decode_json( $doc );

my $unsuccessful = {};
my $unsuccessful_cnt = 0;


my $errors = {
  N => "Network Unreachbale",
  H => "Host Unreachable",
};

foreach my $measurement ( @{ $json } ) {
  foreach my $hop ( @{ $measurement->{result} } ) {
    if ( $hop->{result}->{err} ) {
      $unsuccessful->{ $measurement->{prb_id } }->{reason} = $hop->{result}->{err}->{err};;
      $unsuccessful_cnt++;    
      last;
     }
  }
}

say "We have $unsuccessful_cnt unsuccessful measurements";
foreach my $probe ( keys %$unsuccessful ) {
  say "$probe has reason: $errors->{ $unsuccessful->{probe}->{reason} }";
}

#print $OUT Dumper $json;
