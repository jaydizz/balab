#!/usr/bin/perl

use warnings;
use strict;

use Mojo::Transaction::WebSocket;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);

use InfluxDB::LineProtocol qw(data2line line2data);
use InfluxDB::HTTP;

use Storable;

use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
                    clock_gettime clock_getres clock_nanosleep clock
                    stat lstat);
use 5.24.1;


#TODO: why is SSL not working?! FUCK!
#TODO: LWP und InfluxHTTP durch Mojo POST ersetzen.

#
# Stash-Files usw.
#

my $prefix_stash = retrieve("../stash/route-objects.storable");
my %prefix_stash = %$prefix_stash;
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
my $METRIC = "announce";

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
  
#Setup Whois Service (RADB for Testing Reasons
#my $ra_db = 'whois.radb.net';
#my $WHOIS = Net::IRR->connect( host => $ra_db ) or die "can't connect to $ra_db\n";


my $DEBUG = shift;

#
# Subs for doing all the work
#

sub digest_and_write {
  #TODO: v6 vs v4!
  my $hash = shift;
  #Holds Influx-DB Lines.
  my @influx_lines;   
 
  my $origin_as = pop @{$hash->{path}};

  foreach my $announcement ( @{ $hash->{announcements} }[0] ) { #returns array of hashes
   
    my $tags = {
      nexthop      => $announcement->{next_hop},
      origin_as    => $origin_as,
      peer         => $hash->{peer},
      source       => "ris",
      peer_as      => $hash->{peer_asn},
      validity     => "valid" 
    };

    my $result = check_prefixes_irr($announcement->{prefixes}, $origin_as);
    #Now we can put together a InfluxData-Line.
    push @influx_lines, data2line($METRIC, $result->{valid}, $tags );  #Build a hashref from two hashrefs.
    $tags->{validity} = "invalid";
    push @influx_lines, data2line($METRIC, $result->{invalid}, $tags);
    $tags->{validity} = "not_found";
    push @influx_lines, data2line($METRIC, $result->{not_found}, $tags);
    #push @influx_lines, data2line($METRIC, $prefix->{valid_ls}, $tags);
 
  }
  
  $DB::single = 1;
  my $res = $INFLUX->write(
   \@influx_lines,
   database    => "test_measure"
  );
  say "Successfully wrote dataset!" unless ($res);
}  


sub check_prefixes_irr {
  my $prefix_hash = shift;
  my $origin_as = shift;
  $origin_as = "AS$origin_as";

  my $count_valid = 0;
  my $count_valid_ms = 0;
  my $count_valid_ls = 0;
  my $count_invalid = 0;
  my $count_not_found = 0;

  foreach my $prefix ( @{ $prefix_hash } ) {
    if (!$prefix_stash{$prefix}) {
      #say "$prefix with $origin_as is not found";
      $count_not_found++;
    } elsif ($prefix_stash{$prefix}->{$origin_as}) {
      #say "$prefix with $origin_as is valid";
      $count_valid++;
    } else {
      $count_invalid++;
      #say "$prefix with $origin_as is invalid";
    }
  }
  return {
    valid     => $count_valid,
    valid_ms  => $count_valid_ms,
    valid_ls  => $count_valid_ls,
    invalid   => $count_invalid,
    not_found => $count_not_found
  };
}


#
# Beginning of main
#
while(1) {
my $ua  = Mojo::UserAgent->new;
$ua->inactivity_timeout(0);
$ua->websocket('ws://ris-live.ripe.net/v1/ws/?client=ba-test' => sub {
  my ($ua, $tx) = @_;
  say 'WebSocket handshake failed!' and return unless $tx->is_websocket;
  $tx->on(json => sub {
    my ($tx, $hash) = @_;
    digest_and_write($hash->{data});
    #$tx->finish;
  });
  $tx->on(finish => sub {
    my ($tx, $code, $reason) = @_;
    say "WebSocket closed with status $code.";
  });
  $tx->send($settings);
});
Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}
