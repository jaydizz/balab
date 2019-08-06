#!/usr/bin/perl

use warnings;
use strict;

use Mojo::Transaction::WebSocket;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);

use InfluxDB::LineProtocol qw(data2line line2data);
use InfluxDB::HTTP;

use Storable;

use Net::Patricia;

use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
                    clock_gettime clock_getres clock_nanosleep clock
                    stat lstat);
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

#
# Influx Stuff
# Connecting to InfluxDB and testing.
#
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
  
#
# Retrieve the Patricia Trie Datastructure.
#

say "Retrieving Patricia Trie...";
my $ptv4 = retrieve('../stash/irr-patricia-v4.storable');
my $ptv6 = retrieve('../stash/irr-patricia-v6.storable');

#
# Storing Received Invalids for later analysis
#

my $invalid_log = "../stash/invalids.log";
open (my $INV_LOG, '>>', $invalid_log);

say "And here we go!";
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
      #nexthop      => $announcement->{next_hop},
      #origin_as    => $origin_as,
      #peer         => $hash->{peer},
      source       => "ris",
      #peer_as      => $hash->{peer_asn},
      validity     => "valid" 
    };

    my $result = check_prefixes_irr($announcement->{prefixes}, $origin_as);
    #Now we can put together a InfluxData-Line.
    push @influx_lines, data2line($METRIC, $result->{valid}, $tags );  #Build a hashref from two hashrefs.
    $tags->{validity} = "invalid";
    push @influx_lines, data2line($METRIC, $result->{invalid}, $tags);
    $tags->{validity} = "not_found";
    push @influx_lines, data2line($METRIC, $result->{not_found}, $tags);
    $tags->{validity} = "valid_less_spec";
    push @influx_lines, data2line($METRIC, $result->{valid_ls}, $tags);
    #push @influx_lines, data2line($METRIC, $prefix->{valid_ls}, $tags);
  }
  
  $DB::single = 1;
  my $res = $INFLUX->write(
   \@influx_lines,
   database    => "test_measure"
  );
  say "Error writing dataset\n $res" unless ($res);
}  


sub check_prefixes_irr {
  my $prefix_hash = shift;
  my $origin_as = shift;
  $origin_as = "AS$origin_as";
  
  # Counter Variables.
  my $count_valid = 0;
  my $count_valid_ms = 0;
  my $count_valid_ls = 0;
  my $count_invalid = 0;
  my $count_not_found = 0;

  # Contains the Patricia Lookup Return hash.
  my $pt_return;

  # Contains the length of the prefix;
  my $prefix_length;
  

  foreach my $prefix ( @{ $prefix_hash } ) {
    # Decide, whether we have v4/v6
    if ( (index $prefix, ":")  > 0) {
      $pt_return = $ptv6->match_string($prefix);
    } else {
      $pt_return = $ptv4->match_string($prefix);
    }
    
    $prefix_length = ((split /\//, $prefix))[1]; # Holds the prefix length of current prefix.

    if ( $pt_return) { #If defined, we found something. 
      if ( $pt_return->{$origin_as} ) { #If the return Hash contains a key with the origin_as, it is valid
        if ( $pt_return->{length} == $prefix_length ) { # ro covers exactly
          say "$prefix with $origin_as is valid, exact coverage!" if $DEBUG;
          $count_valid++;
        } else {
          say "$prefix with $origin_as is valid, less-specific coverage!" if $DEBUG;
          $count_valid_ls++;
        }
      } else { #got some bad news...
        say $INV_LOG "$origin_as announced invalid prefix $prefix!";
        $count_invalid++;
      }
   } else {
      say "$prefix with $origin_as is not found" if $DEBUG;
      $count_not_found++;     
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
