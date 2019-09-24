#!/usr/bin/perl 

=head1 NAME

graph_gen

=head1 ABSTRACT

This tool queries INFLUX-DB for aggregate Data for plotting nice graphs regarding RPKI and IRR foo

=cut

use strict;
use warnings;
use 5.26.1;

use Mojo::JSON qw(decode_json);
use Data::Dumper;
use List::Util qw(sum);
use Storable;

my $tmp_file = "./json.tmp";

my $json;


#if ( -e $tmp_file ) {
#  $json = retrieve($tmp_file);  
#} else { 
  my $curl = `curl  -G 'http://localhost:8086/query' --data-urlencode "db=test_measure" --data-urlencode "q=SELECT sum(\"value\") FROM announce_rpki WHERE time >= now()-28d AND time < now() GROUP BY time(1d), \"validity\" fill(none)"`;
  chomp $curl;
  $json = decode_json($curl);
 # store($json, $tmp_file);
#}

# Let's fucking roll with perl datastructures. YAY! 
my $result = { }; # We extract all the valuable data to this hash.

foreach my $tag_group (@{ $json->{"results"}[0]->{"series"} }) {
    
  my $tag = $tag_group->{"tags"}->{"validity"};
  
  foreach my $value_group ( @{ $tag_group->{"values"} } ) {
    #          _time of msrmt______             _____Value____
    my $time = @{ $value_group }[0];
    my $value = @{ $value_group }[1];
    $result->{$time}{$tag} = $value;
     
  }
}

#Now, we need to summarize all values to get a total for percents...

foreach my $timestamp (keys %$result) {
  my @values;
  foreach my $value ( keys %{ $result->{$timestamp} } ) {
    push @values, $result->{$timestamp}->{$value};
    $result->{$timestamp}->{total} = sum(@values);
  }
} 

my @lines = ();
my $header = "";

foreach my $timestamp (sort keys %$result) {
  $header = join(" ", sort keys %{ $result->{$timestamp} }) . "\n";
  my $line = "\n$timestamp ";
  foreach my $tag (sort keys  %{ $result->{$timestamp} }) {
    next if $tag eq "total";
    $line .= $result->{$timestamp}->{$tag} / $result->{$timestamp}->{"total"} * 100;
    $line .= " ";
  }
  push @lines, $line;
}

$header =~ s/total//;
print "time " . $header;
foreach (@lines) {
  print $_;
}
  
#say Dumper $result;
