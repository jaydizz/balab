#!/usr/bin/perl 

use strict;
use warnings;

use 5.26.1;

use Net::Patricia;
use NetAddr::IP::Lite qw(
      Zeros
      Ones
      V4mask
      V4net
      :old_nth
      :upper
      :lower
      :nofqdn
);


use Storable qw(store);

my $file = shift;
my $file2 = shift;
chomp($file);
chomp($file2);

my $orgs = qr/(RIPE|ARIN|LACNIC|AFRINIC|APNIC)/;

open( my $FH, '<', $file);
open( my $FH2, '<', $file2);

my $delegations = {};
my $pt_v4 = new Net::Patricia;
my $pt_v6 = new Net::Patricia AF_INET6;


while (<$FH>) {
  my ($addr, $org) = split ',', $_;
  $addr = new NetAddr::IP::Lite $addr;
  if ($org =~ $orgs) {
    $org = $1;
  } else {
    next;
  } 
  $pt_v4->add_string($addr, $org);
}

while (<$FH2>) {
  my ($addr, $org) = split ',', $_;
  if ( !($addr && $org) ) {
    next;
  }
  $addr = new6 NetAddr::IP::Lite $addr;
  if ($org =~ $orgs) {
    $org = $1;
  } else {
    next;
  } 
  $pt_v6->add_string($addr, $org);
}

store $pt_v4, "./pt_v4.storable";
store $pt_v6, "./pt_v6.storable";

