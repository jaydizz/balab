#!/usr/bin/perl 

use strict;
use warnings;
use 5.26.1;

use Mojo::JSON qw(decode_json encode_json);

use Data::Dumper;
use Mojo::UserAgent;
use Mojo::DOM;
use Mojo::URL;
use Storable qw(store);



use List::MoreUtils qw(uniq);

my $id = shift;
my $force = shift or 0;

if (-e "/mount/storage/stash/ripe-atlas/raw/msm-$id" && !$force) {
  say " $id stash exists. Skipping. Use force to overwrite! ";
  exit(0);
} 

my $VERBOSE = shift or 0;
my $url = "https://atlas.ripe.net/api/v2/measurements/$id/results/?start=0&format=json";

my $ua = Mojo::UserAgent->new;
my $doc = $ua->get($url);
my $decoded = decode_json($doc->res->dom->all_text);

my @measurements;
my $asn_cache;
my @probe_ids;

foreach my $measurement ( @{ $decoded } ) {
  my $result = { }; # Hash holds result of measurement and meta-information.
  
  my $traceroute = $measurement->{result};
  push @probe_ids, $measurement->{prb_id};
  #First we determine the success of a trace by looking at the last hop. If the last hop ist our IP/AS, all ASNs in the path are not filtering.

  my $last_hop = @{ $traceroute }[-1]; 
  $DB::single = 1; 
  $result->{success}      = is_trace_success($last_hop);
  ($result->{success_text}, $result->{last_hop}) = get_success_text($last_hop); 
  $result->{probe_id}     = $measurement->{prb_id}; 
  
  foreach my $hop ( @{ $traceroute } ) {  #Each Traceroute holds multiple Hops
    foreach my $ping ( @{ $hop->{result} } ) { #Each Hop is pinged three times. 
      if ($ping->{from}) {
        push @{ $result->{hops} }, $ping->{from};
        push @{ $result->{as_path} }, get_as_number($ping->{from});
      }
    }
  }
  @{ $result->{hops} } = uniq  @{ $result->{hops} }; 
  @{ $result->{as_path} } = uniq  @{ $result->{as_path} }; 
  
  push @measurements, $result;
}



sub get_success_text {
  my $last_hop = shift;
 
  my $ping_count = 0;
  my $star_count = 0;
  foreach my $ping ( @{ $last_hop->{result} } ) {
    if ($ping->{from} && ($ping->{from} eq '151.216.20.1' || $ping->{from} eq '2001:7fc::1') ) {
      return  ("success", $ping->{from});
    }
    if ($ping->{x}) {
      $star_count++;
    }
    if ($star_count  == 3 ) {
      return ("stars", 'X');
    }
    if ($ping->{err}) {
      if ($ping->{err} eq "N") {
        return ("network_unreach", $ping->{from});
      }
      if ($ping->{err} eq "H") {
        return ("host_unreach", $ping->{from});
      }
   }
  }
}
        

sub is_trace_success {
  my $last_hop = shift;

  my $ping_count = 0;
  foreach my $ping ( @{ $last_hop->{result} } ) {
    if ($ping->{from} && ($ping->{from} eq '151.216.20.1' || $ping->{from} eq '2001:7fc::1') ) {
      return  1;
    }
  }
  return 0;
}

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

say "Completed msm $id";
#say join ( "\n", @probe_ids );
store \@measurements, "/mount/storage/stash/ripe-atlas/raw/msm-$id";


