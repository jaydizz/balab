#!/usr/bin/perl 

=head1 NAME

Repo Compare

=head1 ABSTRACT

This script loads an irr-trie and an rpki-trie and compares the entries present in both to check cross-coverage. 

=head1 SYNOPSIS
   

=cut

use strict;
use warnings;
use Getopt::Std;
use Storable;
use Net::Patricia;
use Net::Validator qw(:all);
use Local::Logger qw (:all);
use Data::Dumper;
use Local::addrinfo qw( by_cidr mk_iprange_lite mk_iprange is_subset);


use 5.26.1;

my $file = shift;

$Net::Validator::LOG_INVALIDS = 1;


my ($year, $month, $day);

if ( $file =~ /(20\d{2})-(\d{2})-(\d{2})-irrv4\.storable/ ) {
  ($year, $month, $day) = ($1, $2, $3);
} else {
  exit(0);
}
open ($Net::Validator::INV_LOG, '>', "/tmp/$year-$month-$day.invalids");

my $pt_v4 = retrieve $file or die("Could not load v4 trie");
$file =~ s/irrv4/irrv6/;
my $pt_v6 = retrieve $file;


#Now we load the corresponding roas.
my @roas = `find /mount/storage/db/historic/rpki/`;
my $date = "$year/$month/$day";
@roas = grep { /roas\.csv/ } @roas;
@roas = grep { /$date/ } @roas;

return if (!scalar @roas);

my $result_hash = {
      invalid    => 0,
      not_found  => 0, 
      valid      => 0,
      valid_impl => 0,
      valid_ls   => 0,
};
my $total = 0;


foreach my $file (@roas) {
  chomp($file);
  open( my $FH, '<', $file ) or die("Could not open $file");
  my $tmp = <$FH>;
  while (<$FH>) {
    #next if ($_ =~ /#/);
    my ($tmp, $origin_as, $prefix, $max_length) = split /,/, $_;
    $total++;
    chomp($prefix);
    chomp($origin_as);
    #$DB::single = 1; 
    my $return = validate_irr($prefix, $origin_as, $pt_v4, $pt_v6);
    $DB::single = 1;
    add_hashes($return);
  }
  close $FH;
}


#say "Total: $total";
#foreach my $key (sort keys %$result_hash) {
#  print $key . ",";
#}
print "\n";
foreach my $key (sort keys %$result_hash) {
  print $result_hash->{$key}/$total*100 . ",";
}




sub add_hashes {
  my $hash = shift;
  foreach my $bla ( keys %$hash ) {
    $result_hash->{$bla} += $hash->{$bla};
  }
}
