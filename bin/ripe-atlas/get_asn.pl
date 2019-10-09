#!/usr/bin/perl 

use strict;
use warnings;
use 5.10.0;

use Mojo::JSON qw(decode_json encode_json);

use Data::Dumper;
use Mojo::UserAgent;
use Mojo::DOM;
use Mojo::IOLoop;
use Mojo::URL;


#use Modern::Perl;
use Storable;


my $url = "https://atlas.ripe.net/api/v2/measurements/22840285/results/?format=json&filename=RIPE-Atlas-measurement-22840285.json"; 

my $ua = Mojo::UserAgent->new;
my $doc = $ua->get($url);
my $decoded = decode_json($doc->res->dom->all_text);



my $seen_asns = {};
my @seen_prefixes; 

my $asn_cache = retrieve "/tmp/asn_cache.storable";

foreach my $node (@{ $decoded} ) {
  foreach my $hop ( @{ $node->{'result'} } ) {
    foreach my $result ( @{ $hop->{'result'} } ) {
      if ($result->{'from'}) {
        push @seen_prefixes, $result->{'from'};  
      }
    }
  }
} 

my $active = 0;

Mojo::IOLoop->recurring(  0 => sub {
    for ($active .. 100 - 1) {
      # Either we are active and have things left to process or we stop the IOLoop.
      return ($active or Mojo::IOLoop->stop) unless (my $prefix = shift @seen_prefixes);
      ++$active;
      add_seen_asn( get_as_number( $prefix ) );
      --$active;
    }
  } 
);
Mojo::IOLoop->recurring(  10 => sub {
  say $#seen_prefixes . " left to lookup";
  } 
);
 
Mojo::IOLoop->start unless Mojo::IOLoop->is_running;



$DB::single = 1;





store $seen_asns, "/tmp/seen_asn.storable";
store $asn_cache, "/tmp/asn_cache.storable";

exit(0);

sub add_seen_asn{
  my $asn = shift;
  foreach (@{ $asn }) {
    $seen_asns->{$_} = 0 if ( $seen_asns->{$asn} ) ;
    $seen_asns->{$_}++;
  }
}
sub get_as_number{
  my $prefix = shift;
  if ( $asn_cache->{$prefix} ) {
    return $asn_cache->{$prefix};
  } else {  
    my $ua = Mojo::UserAgent->new;
    my $url = "https://stat.ripe.net/data/network-info/data.json?resource=$prefix";
    my $doc = $ua->get($url);
    my $decoded = decode_json($doc->res->dom->all_text);
    $asn_cache->{$prefix} = $decoded->{'data'}->{'asns'};
    return $decoded->{'data'}->{'asns'};
  }
}

