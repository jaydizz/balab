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
my $as   = shift or 0;
chomp($as);
$Net::Validator::LOG_INVALIDS = 1;


my ($year, $month, $day);

if ( $file =~ /(20\d{2})-(\d{2})-(\d{2})-irrv4\.storable/ ) {
  ($year, $month, $day) = ($1, $2, $3);
} else {
  exit(0);
}
open ($Net::Validator::INV_LOG, '>', "/mount/storage/stash/repo_compare/$year-$month-$day.invalids");
open (my $not_founds_log , '>', "/mount/storage/stash/repo_compare/$year-$month-$day.not_found");

my $pt_v4 = retrieve $file or die("Could not load v4 trie");
$file =~ s/irrv4/irrv6/;
my $pt_v6 = retrieve $file;


#Now we load the corresponding roas.
my @roas = `find /mount/storage/db/historic/rpki/`;
my $date = "$year/$month/$day";
@roas = grep { /roas\.csv/ } @roas;
@roas = grep { /$date/ } @roas;

exit(0) if (!scalar @roas);

my $result_hash = {
      invalid    => 0,
      not_found  => 0, 
      valid      => 0,
      valid_impl => 0,
      valid_ls   => 0,
};

my $as_stats;

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
    my $return = validate_irr($prefix, $origin_as, $pt_v4, $pt_v6);
    
    if ( $return->{not_found} && $max_length ge 1) { #Let's not give up yet!
      my $cidr = (split /\//, $prefix)[0];
      my $return2 = validate_irr("$cidr/$max_length", $origin_as, $pt_v4, $pt_v6);
      if ( !$return2->{invalid} && !$return2->{not_found} ) {
        $return = $return2;
      } else {
        say "$prefix  : $origin_as not found." if $origin_as eq $as;
        $as_stats->{$origin_as} = 0 unless $as_stats->{$origin_as};
        $as_stats->{$origin_as} += 1;
      }
    }
    add_hashes($return);
  }
  close $FH;
}


foreach my $as (keys %$as_stats ) {
    say $not_founds_log  "$as,$as_stats->{$as}";
}
close ($not_founds_log);
#say "Total: $total";
#foreach my $key (sort keys %$result_hash) {
#  print $key . ",";
#}
my $result = "$year-$month-$day,";
foreach my $key (sort keys %$result_hash) {
  next if $key eq "pt";
  $result = $result .  $result_hash->{$key}/$total*100 . ",";
}
say $result;



sub add_hashes {
  my $hash = shift;
  foreach my $bla ( keys %$hash ) {
    $result_hash->{$bla} += $hash->{$bla};
  }
}
