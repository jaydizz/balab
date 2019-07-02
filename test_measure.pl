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


my $METRIC = "announce";

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

sub digest_and_write {
  #TODO: v6 vs v4!
  my $hash = shift;
  #Holds Influx-DB Lines.
  my @influx_lines;   

 
  my $origin_as = pop @{$hash->{path}};

  $DB::single = 1;
  foreach my $announcement ( @{ $hash->{announcements} }[0] ) { #returns array of hashes
    my $prefix_count = scalar @{$announcement->{prefixes}},
    my $valid = rand(10) <= 3 ? "valid" : "invalid";
    
    my $tags = {
      nexthop      => $announcement->{next_hop},
      origin_as    => $origin_as,
      peer         => $hash->{peer},
      valid        => $valid,
      source       => "ris",
      peer_as      => $hash->{peer_asn}, 
    };
    #$DB::single = 1;

    #Now we can put together a InfluxData-Line.
    push @influx_lines, data2line($METRIC, $prefix_count, $tags);
    #say data2line($METRIC, $prefix_count, $tags);
 
  }
  my $res = $INFLUX->write(
   \@influx_lines,
   database    => "test_measure"
  );
  say "Successfully wrote dataset!" unless ($res);
  
  
}  


sub check_prefix {
  my $prefix = shift;
}

#
# Beginning of main
#

my $ua  = Mojo::UserAgent->new;

my $res = $ua->websocket('ws://ris-live.ripe.net/v1/ws/?client=' => sub {
  my ($ua, $tx) = @_;
  say 'WebSocket handshake failed!' and return unless $tx->is_websocket;
  $tx->on(json => sub {
    my ($tx, $hash) = @_;
    digest_and_write($hash->{data});
    #$tx->finish;
  });
  $tx->send($settings);
});
say $res;
Mojo::IOLoop->start unless Mojo::IOLoop->is_running;

