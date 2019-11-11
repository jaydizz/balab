#!/usr/bin/perl 

use strict;
use warnings;
use 5.26.1;

use Mojo::JSON qw(decode_json encode_json);

use Data::Dumper;
use Mojo::UserAgent;
use Mojo::DOM;
use Mojo::IOLoop;
use Mojo::URL;


use List::MoreUtils qw(uniq);

my $id = shift;
my $url = "https://atlas.ripe.net/api/v2/measurements/$id/results/?start=0&format=json";

my $ua = Mojo::UserAgent->new;
my $doc = $ua->get($url);
my $decoded = decode_json($doc->res->dom->all_text);


my $results = { };
#say Dumper $decoded;
#exit(0);
my $asn_cache;

foreach my $probe_msm ( @{ $decoded } ) {
  
  my $probe_id = $probe_msm->{prb_id};
  
  $results->{$probe_id}{success} = 1; #Sucess until proven unsuccessful.
  my @msm_results = @{ $probe_msm->{result} };
    
  my $last_real_hop = ""; #The last hop that had an IP in case of ***.

  
  #foreach my $hop (@msm_results) {   #Holds the measurement_result
  for (my $hop_count = 0; $hop_count < scalar @msm_results; $hop_count++) {
    my $hop = $msm_results[$hop_count];
    
    my $ping_count = 0;
    
     
    foreach my $result ($hop->{result}) {  #For each hop in the measurement-results
     $ping_count++; 
     my $star_pings = 0;              #How often did we get * ?
     foreach my $ping ( @$result ) {  #each trace executes 3 pings.
        if ( $ping->{x} ) { #ping was not successful!
          $star_pings++;
        }
        if ( ($ping_count == 1) && $ping->{from} ) { #We only take one hop IP since we assume that all hops are within the same AS. 
          push @{ $results->{$probe_id}{hops} }, $ping->{from};
        }
        if ( $star_pings == 3 && $hop_count == scalar @msm_results - 1) { #Last hop are stars. Fuck!
          $results->{$probe_id}{success} = 0;
          $results->{$probe_id}{success_text} = "stars";
          last;
        }
        if ( $ping->{err} && ($ping->{err} eq "H") ) {
          $results->{$probe_id}{success} = 0;
          $results->{$probe_id}{success_text} = "host_unreach";
          $results->{$probe_id}{filtered_hop} = $ping->{from};
          last;
        }
        if ( $ping->{err} && ($ping->{err} eq "N") ) {
          $results->{$probe_id}{success} = 0;
          $results->{$probe_id}{success_text} = "network_unreach";
          $results->{$probe_id}{filtered_hop} = $ping->{from};
          last;
        }
        #$results->{$probe_id}{filtered_hop} = $msm_results[$hop_count-1]->{result}}[0];
        
        $ping_count++;
      }
    }
  }
}




my $filtering_asses = {};
my $downcovered_asses = {};
my $not_filtering_asses = {};

foreach my $probe_id (sort keys %$results) {
  if ( $results->{$probe_id}{success} == 0 ) {
    say "$probe_id did not reach us for reason: $results->{$probe_id}{success_text}";
    if ( $results->{$probe_id}{hops} ) { 
      my @as_path_arr = map{ get_as_number($_) } @{$results->{$probe_id}{hops}};
      map { $downcovered_asses->{$_}++ } uniq @as_path_arr;
      
      my $as_path = join(',', @as_path_arr);
      say "\tAS_PATH:$as_path";
      $DB::single = 1;
      my $filtering_as = get_as_number(@{$results->{$probe_id}{hops}}[scalar @{$results->{$probe_id}{hops}} - 1]);
      $filtering_asses->{$filtering_as} = 0 unless $filtering_asses->{$filtering_as};
      $filtering_asses->{$filtering_as}++;
      say "\tFILTERING_AS: $filtering_as";
    }
    
   } else {
    my @as_path = map{ get_as_number($_) } @{$results->{$probe_id}{hops}};
    foreach my $as (@as_path) {
      $not_filtering_asses->{$as} = 0 unless $not_filtering_asses->{$as};
      $not_filtering_asses->{$as}++;
    }
    }
}


foreach my $filtering_as ( 
 sort { $filtering_asses->{$a} <=> $filtering_asses->{$b} } 
 keys %$filtering_asses)
{
  say "AS " . $filtering_as . "  $filtering_asses->{$filtering_as} hits!";
}

say scalar keys %$filtering_asses ;
say scalar keys %$downcovered_asses ;
say scalar keys %$not_filtering_asses ;


#temporary: Get ASNs
sub get_as_number{
  my $prefix = shift;
  if ( $asn_cache->{$prefix} ) {
    return  $asn_cache->{$prefix} ;
  } else {
    my $ua = Mojo::UserAgent->new;
    my $url = "https://stat.ripe.net/data/network-info/data.json?resource=$prefix";
    my $doc = $ua->get($url);
    my $decoded = decode_json($doc->res->dom->all_text);
    if ($decoded->{'data'}->{'asns'}[0] ) {
      $asn_cache->{$prefix} = @{ $decoded->{'data'}->{'asns'} }[0];
      return $decoded->{'data'}->{'asns'}[0];
    } else {
      $asn_cache->{$prefix} = "X";
      return 'X';
    }
  }
}



