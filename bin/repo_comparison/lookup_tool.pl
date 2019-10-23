#!/usr/bin/perl
use 5.26.1;
use strict;
use warnings;
use Getopt::Std;
use Storable;
use Net::Patricia;
use Net::Validator qw(:all);
use Local::Logger qw (:all);
use Data::Dumper;
use Local::addrinfo qw( by_cidr mk_iprange_lite mk_iprange is_subset);


my $prefix = shift or die("Need prefix");
my $asn = shift or die("Need asn");


my $date = shift or 0;


my $default_dir = "/mount/storage/stash/";

my $pt_irr_v4  = "$default_dir/irr-patricia-v4.storable";
my $pt_irr_v6  = "$default_dir/irr-patricia-v6.storable";
my $pt_rpki_v4 = "$default_dir/rpki-patricia-v4.storable";
my $pt_rpki_v6 = "$default_dir/rpki-patricia-v6.storable";

if ( $date ) {
  my ($year, $month, $day);
  if ( $date =~ /(20\d{2})-(\d{2})-(\d{2})/ ) {
    ($year, $month, $day) = ($1, $2, $3);
  } else {
    die("wrong date");
  }

  if (-e "/mount/storage/stash/historic/$year-$month-$day-rpkiv4.storable") {
    $pt_rpki_v4 = "/mount/storage/stash/historic/$year-$month-$day-rpkiv4.storable";
    say "found specific rpki-trie";
  } 
  if (-e "/mount/storage/stash/historic/$year-$month-$day-rpkiv6.storable") {
    $pt_rpki_v6 = "/mount/storage/stash/historic/$year-$month-$day-rpkiv6.storable";
    say "found specific rpki-trie";
  }
  if (-e "/mount/storage/stash/historic/irr/$year-$month-$day-irrv4.storable") {
    $pt_irr_v4 = "/mount/storage/stash/historic/irr/$year-$month-$day-irrv4.storable";
    say "found specific irr-trie";
  }
  if (-e "/mount/storage/stash/historic/irr/$year-$month-$day-irrv6.storable") {
    $pt_irr_v6 = "/mount/storage/stash/historic/irr/$year-$month-$day-irrv6.storable";
    say "found specific irr-trie";
  }
}


my $trie_irr_v4 = retrieve $pt_irr_v4;
my $trie_irr_v6 = retrieve $pt_irr_v6;
my $trie_rpki_v4 = retrieve $pt_rpki_v4;
my $trie_rpki_v6 = retrieve $pt_rpki_v6;

my $irr_return = validate_irr($prefix, $asn, $trie_irr_v4, $trie_irr_v6);
my $rpki_return = validate_rpki($prefix, $asn, $trie_rpki_v4, $trie_rpki_v6);


say "=====irr====";
foreach my $key (keys %$irr_return) {
  next if ($key eq "pt");
  if ($irr_return->{$key}) {
    say "$prefix is $key";
    if ($key eq "invalid") {
      print "Possible ASNs:\n";
      foreach my $origin_as (keys %{ @{$irr_return->{pt}}[0]->{origin}}) {
    $DB::single = 1;
        print "\t$origin_as source: @{ $irr_return->{pt}}[0]->{origin}->{$origin_as}->{source} \n";
      }
      print "\n";
    }
  }
}

foreach my $key (keys %$rpki_return) {
  next if ($key eq "pt");
  if ($rpki_return->{$key}) {
    say "$prefix is $key";
    if ($key eq "invalid_ml") {
      print "Possible mls:\n";
      foreach my $origin_as (keys %{ @{$rpki_return->{pt}}[0]->{origin}}) {
        print "\t$origin_as source: @{ $rpki_return->{pt}}[0]->{origin}->{$origin_as}->{'max-length'} \n";
      }
      print "\n";
    }
    if ($key eq "valid_ls") {
      print "Covered by : @{$rpki_return->{pt}}[0]->{prefix} \n";
    }
    if ($key eq "invalid") {
      print "Possible ASNs:\n";
      foreach my $origin_as (keys %{ @{$rpki_return->{pt}}[0]->{origin}}) {
        $DB::single = 1;
        print "\t$origin_as source: @{ $rpki_return->{pt}}[0]->{origin}->{$origin_as}->{source} \n";
      }
      print "\n";
    }
  }
}

