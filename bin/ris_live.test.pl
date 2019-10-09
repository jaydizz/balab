#!/usr/bin/perl

use warnings;
use strict;

use Term::ANSIColor;
use Net::Validator qw( :all );

use Mojo::Transaction::WebSocket;
use Mojo::UserAgent;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::IOLoop::Signal;

use InfluxDB::LineProtocol qw(data2line line2data);
use InfluxDB::HTTP;

use Storable;

use Local::Logger qw(:all);

use File::Pid;

use Net::Patricia;

use Time::HiRes qw( usleep ualarm gettimeofday tv_interval nanosleep
                    clock_gettime clock_getres clock_nanosleep clock
                    stat lstat);
use 5.24.1;

our $VERSION = "1.0";

#TODO: why is SSL not working?! FUCK!
#TODO: LWP und InfluxHTTP durch Mojo POST ersetzen.

# Create PID-File
my $pidfile = File::Pid->new({
  file => '/var/run/ris_live.pid',
});

$pidfile->write;
print_intro_header(); #Say hello to the world!

##################################################
#             Setting Up Internal Variables      #
##################################################

#
# RIS-Live parameters
#
my $prefix;
my $path;
my $type = "UPDATE";
my $moreSpecific = \1;

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
my $METRIC_RPKI = "announce_rpki";

our $INFLUX = InfluxDB::HTTP->new(
  host => 'localhost',
  port => 8086,
);
logger("Opening Connection to Influx-DB");
logger("Testing...");
my $ping = $INFLUX->ping();
if ($ping) {
  logger( "Influx Version " . $ping->version . "ready for duty!");
} else {
  die "Influx not working. \n";
}
  
#
# Retrieve the Patricia Trie Datastructure.
#

logger( "Retrieving Patricia Trie...");
my $pt_irr_v4 = retrieve('../stash/irr-patricia-v4.storable');
my $pt_irr_v6 = retrieve('../stash/irr-patricia-v6.storable');

my $pt_rpki_v4 = retrieve('../stash/rpki-patricia-v4.storable');
my $pt_rpki_v6 = retrieve('../stash/rpki-patricia-v6.storable');

logger("Done.");
#
# Storing Received Invalids for later analysis
#

my $irr_invalid_log = "../stash/invalids.log";
my $rpki_invalid_log = "../stash/rpki_invalids.log";
open ($Net::Validaotr::INV_LOG, '>>', $irr_invalid_log);
open ($Net::Validator::RPKI_INV_LOG, '>>', $rpki_invalid_log);

$Net::Validator::LOG_INVALIDS = 0;

my $DEBUG = shift;


#
# Beginning of main
#
my $prefix_processed_in_interval; #We count processed prefixes. sometimes the websocket hangs. If this is zero after 5 minutes, we restart the socket. 

logger("Opening Websocket Connection...");


my $ua; #holds useragent 
my $tx; #holds websocket.


Mojo::IOLoop::Signal->on(USR1 => sub {
  my ($self, $name) = @_;
  logger("Got USR1: Reloading the Patricia Trees.", 'yellow');
  my $pt_irr_v4_tmp  = retrieve('../stash/irr-patricia-v4.storable');
  my $pt_irr_v6_tmp  = retrieve('../stash/irr-patricia-v6.storable');
  my $pt_rpki_v4_tmp = retrieve('../stash/rpki-patricia-v4.storable');
  my $pt_rpki_v6_tmp = retrieve('../stash/rpki-patricia-v6.storable');
  $pt_irr_v4   = $pt_irr_v4_tmp;
  $pt_irr_v6   = $pt_irr_v6_tmp;
  $pt_rpki_v4  = $pt_rpki_v4_tmp;
  $pt_rpki_v6  = $pt_rpki_v6_tmp;
  logger("Done");
});

while(1) {
  
  my $ua  = Mojo::UserAgent->new;
  $ua->inactivity_timeout(20);
  $ua->websocket('ws://ris-live.ripe.net/v1/ws/?client=ba-test' => sub {
    ($ua, $tx) = @_;
    if ( !$tx->is_websocket ) {  
      logger('WebSocket handshake failed!', 'red');
      Mojo::IOLoop->stop();
    }
    $tx->on(json => sub {
      my ($tx, $hash) = @_;
      digest_and_write($hash->{data});
      #$tx->finish;
    });
    $tx->on(finish => sub {
      my ($tx, $code, $reason) = @_;
      logger("WebSocket closed with status $code, $reason", 'red');
      Mojo::IOLoop->stop();
    });
    $tx->send($settings);
  });
  logger("Websocket opened! Ris-Live is now feeding us!");
  # Register a timer to check if the websocket has become stale. 
  Mojo::IOLoop->timer(300 => sub {
    if ( $prefix_processed_in_interval == 0 ) {
      Mojo::IOLoop->stop();
      #$tx->finish;
      logger('Closing stale websocket...', 'red');
    }
    $prefix_processed_in_interval = 0;
  });

  Mojo::IOLoop->start unless Mojo::IOLoop->is_running;
}

END {
  $pidfile->remove;
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

  foreach my $announcement ( @{ $hash->{announcements} }[0] ) { #returns array of hashes
   
    my $tags = {
      #nexthop      => $announcement->{next_hop},
      #origin_as    => $origin_as,
      #peer         => $hash->{peer},
      source       => "ris",
      #peer_as      => $hash->{peer_asn},
      validity     => "valid" 
    };

    #Check received Announcements agains routing DBs
    my $irr_result = validate_irr($announcement->{prefixes}, $origin_as, $pt_irr_v4, $pt_irr_v6);

    #Check received Announcements against RPKI
    my $rpki_result = validate_rpki($announcement->{prefixes}, $origin_as, $pt_rpki_v4, $pt_rpki_v6);
 
    #
    # Build InfluxDB Data Line for IRR-Values
    #
    push @influx_lines, data2line($METRIC, $irr_result->{valid}, $tags );  
    $tags->{validity} = "invalid";
    push @influx_lines, data2line($METRIC, $irr_result->{invalid}, $tags);
    $tags->{validity} = "not_found";
    push @influx_lines, data2line($METRIC, $irr_result->{not_found}, $tags);
    $tags->{validity} = "valid_less_spec";
    push @influx_lines, data2line($METRIC, $irr_result->{valid_ls}, $tags);
    $tags->{validity} = "valid_implicit_coverage";
    push @influx_lines, data2line($METRIC, $irr_result->{valid_impl}, $tags);
    #push @influx_lines, data2line($METRIC, $prefix->{valid_ls}, $tags);
    
    #
    # Build Datalines for RPKI-Checks.
    #
    my $tags_rpki = {
      source => "ris",
      validity => "valid",
    };
    
    
    push @influx_lines, data2line($METRIC_RPKI, $rpki_result->{valid},  $tags_rpki);
    $tags_rpki->{validity} = "valid_ls";
    push @influx_lines, data2line($METRIC_RPKI, $rpki_result->{valid_ls},  $tags_rpki);
    $tags_rpki->{validity} = "invalid_ml";
    push @influx_lines, data2line($METRIC_RPKI, $rpki_result->{invalid_ml},  $tags_rpki);
    $tags_rpki->{validity} = "invalid";
    push @influx_lines, data2line($METRIC_RPKI, $rpki_result->{invalid},  $tags_rpki);
    $tags_rpki->{validity} = "not_found";
    push @influx_lines, data2line($METRIC_RPKI, $rpki_result->{not_found},  $tags_rpki);
    
  }
  
  if ($DEBUG) {
    foreach (@influx_lines) {
      logger($_);
      }
  }
  my $res = $INFLUX->write(
   \@influx_lines,
   database    => "test_measure"
  ) unless ($DEBUG);
  say "Error writing dataset\n $res" unless ($res);
  $prefix_processed_in_interval++;
}  




sub print_intro_header {
  my $db = shift;
  my $time = get_formated_time();
  my $msg =<<"EOF";
           .            .                     .
                  _        .                          .            (
                 (_)        .       .                                     .
  .        ____.--^.
   .      /:  /    |                               +           .         .
         /:  `--=--'   .                                                .
  LS    /: __[\\==`-.___          *           .
       /__|\\ _~~~~~~   ~~--..__            .             .
       \\   \\|::::|-----.....___|~--.                                 .
        \\ _\\_~~~~~-----:|:::______//---...___
    .   [\\  \\  __  --     \\       ~  \\_      ~~~===------==-...____
        [============================================================-
        /         __/__   --  /__    --       /____....----''''~~~~      .
  *    /  /   ==           ____....=---='''~~~~ .
      /____....--=-''':~~~~                      .                .
      .       ~--~         Validator-Class route-destroyer. 
                     .     Version: $VERSION                              ..
                          .Github: https://git.io/fjQD5      .             +
        .     +              .                                       <=>
                                               .                .      .
   .                 *                 .                *                ` -
Graphic stolen from http://www.ascii-art.de/ascii/s/starwars.txt
By Phil Powell

EOF
  print $msg;
}


