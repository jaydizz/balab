#!/usr/bin/perl

use warnings;
use strict;

use Mojo::Transaction::WebSocket;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);

use InfluxDB::LineProtocol qw(data2line line2data);
use InfluxDB::HTTP;
use 5.24.1;


#TODO: why is SSL not working?! FUCK!
#TODO: LWP und InfluxHTTP durch Mojo POST ersetzen.

#
# RIS-Live parameters
#
my $prefix;
my $path;
my $type = "UPDATE";
my $moreSpecific = \1;


#
# Internal vars. Do not edit beyond this point!
#

# Generate Settings hash for websocket connection.

my $settings = encode_json {
  type => 'ris_subscribe',
  data => {
       moreSpecific => $moreSpecific,
       type => $type,
       require => 'announcements'
  }
};

# Influx Stuff

our $INFLUX = InfluxDB::HTTP->new(
  host => 'localhost',
  port => 8086,
);

say "Testing InfluxDB...";
my $ping = $INFLUX->ping();
if ($ping) {
  say "Influx Version " . $ping->version . "ready for duty! \n";
} else {
  die "Influx not working. \n";
}
  

#
# Subs for doing all the work
#

sub digest_hash {
  my $hash = shift;
  my $measurements;
  # Measurement has the following format:
  #{
  #  id => number;
  #  tags => {
  #    nexthop   => 
  #    origin_as =>
  #    valid     => 'valid|invalid_reason'
  #  }
  #}
  foreach my $announcement ($hash->{annoucements}) {
  }
}  



#
# Beginning of main
#

my $ua  = Mojo::UserAgent->new;

my $res = $ua->websocket('ws://ris-live.ripe.net/v1/ws/?client=' => sub {
  my ($ua, $tx) = @_;
    $DB::single = 1;
  say 'WebSocket handshake failed!' and return unless $tx->is_websocket;
  $tx->on(json => sub {
    my ($tx, $hash) = @_;
    $DB::single = 1;
    foreach my $prefix_arr ($hash->{data}->{announcements}[0]->{prefixes}) {
      if ( $prefix_arr > 1) {
        foreach my $prefix (@{$prefix_arr}) {
          print "$prefix \n";
          $DB::single = 1;
        }
      }
    }
    #say "WebSocket message via JSON:" . $hash->{data}->{announcements}[0]->{prefixes}[0];
    #$tx->finish;
  });
  $tx->send($settings);
});
say $res;
Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

