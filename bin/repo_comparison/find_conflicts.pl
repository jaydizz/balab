#!/usr/bin/perl 

# This Script compares rpki tries with irr tries and tells us the percentage of unique prefixes that have more information presen in irr or rpki.

use strict;
use warnings;
use Net::Patricia;
use Net::Validator qw(:all);
use Local::Logger qw (:all);
use Storable qw( retrieve );
use 5.26.1;



my $rpki_historic_dir = "/mount/storage/stash/historic/";
my $file = shift or die( "We needs input-file!" );
chomp($file);

$Net::Validator::LOG_INVALIDS = 0;

my ($year, $month, $day);
if ( $file =~ /(20\d{2})-(\d{2})-(\d{2})-irrv4\.storable/ ) {
  ($year, $month, $day) = ($1, $2, $3);
} else {
  exit(0);
}


my $stats_dir = "/mount/storage/stash/historic/stats/repo_compare/";
my $stats_per_irr = "$stats_dir/$year-$month-$day-per_irr";
open( my $STATS_PER_IRR, '>', $stats_per_irr);

my $blame_log = "/tmp/$year-$month-$day-blamelog";
open (my $BLAME_LOG, '>', $blame_log);

my $not_found_log = "/mount/storage/stash/historic/stats/repo_compare/not_found/";
open (my $NF_LOG, '>', "$not_found_log/$year-$month-$day");
my $blame_sources = { };

my $pt_irr_v4 = retrieve $file or die( "could not open file $file" );

# Generate v6 filename
$file =~ s/irrv4/irrv6/;
my $pt_irr_v6 = retrieve $file or die( "could not open file $file" );

$file = "$rpki_historic_dir/$year-$month-$day-rpkiv4.storable";
my $pt_rpki_v4 = retrieve $file or die( "could not open file $file" );
$file =~ s/v4/v6/g;
my $pt_rpki_v6 = retrieve $file or die( "could not open file $file" );


####################################################################


my $unique_prefix_coverage = {
  count                 => 0,  #Total count of unique prefixes present in the IRRs
  count_conflicts       => 0, #Count of conflicting ASes.
                                #If a prefix has multiple conflicts, they are counted as they occur. 
  covered_exact         => 0,  #both contain the exakt same information
  not_found             => 0,  #RPKI Prefix is not found in IRR
  old_info_irr          => 0,   #To be implemented: If IRRs hold more information, 
  unique_conflicts      => 0,  #Contains the unique conflict count. 
                                 #If a prefix has conflicts, this is incremented by 1
}; 



##########################################################################
# Beginning of Main!
##########################################################################


$pt_rpki_v4->climb(
  sub {
    compare_tries($_[0], 0);
  }
);
$pt_rpki_v6->climb(
  sub {
    compare_tries($_[0], 1);
  }
);


my $string = join(',', sort keys %$unique_prefix_coverage);
#say "$string";
$string = join(',', map { $unique_prefix_coverage->{$_}/$unique_prefix_coverage->{count}*100 } sort keys %$unique_prefix_coverage);
say "$year-$month-$day,$string";

$string = join(',', sort keys %$blame_sources);

my $per_irr = join(',', 
  map { $blame_sources->{$_}/$unique_prefix_coverage->{count_conflicts}*100}
  sort keys %$blame_sources);
say $STATS_PER_IRR "$year-$month-$day,$per_irr";


exit(0);

##########################################################################
# End of Main!
##########################################################################




sub compare_tries {
  my $prefix_node = shift;
  my $AF     = shift or 0;
  my $prefix = $prefix_node->{prefix};
  
  my $pt_irr =  $AF ? $pt_irr_v6 : $pt_irr_v4;
  $unique_prefix_coverage->{count}++; 
  
  my $lookup_result = $pt_irr->match_exact_string($prefix);
  if ( ! defined $lookup_result ) {
    say $NF_LOG "$prefix";
    $unique_prefix_coverage->{not_found}++;
    return;
  }
  
  # Let's find out if all elements are equal. 
  my @irr_conflicts = grep { !exists $prefix_node->{origin}->{$_}} keys %{$lookup_result->{origin}};

  # if the conflicts contains more than 0 values, we have conflicting info in the IRRS.
  if ( scalar @irr_conflicts > 0 ) {
    my $blames = join(',', @irr_conflicts);
    my $officials = join(',', keys %{ $prefix_node->{origin}});
    #say "$prefix: $blames : $officials";
    
    $unique_prefix_coverage->{unique_conflicts}++;
    foreach my $as ( @irr_conflicts ) {
      $unique_prefix_coverage->{count_conflicts}++;
      $blame_sources->{ $lookup_result->{origin}->{$as}->{source} } = 0 unless $blame_sources->{ $lookup_result->{origin}->{$as}->{source} };
      $blame_sources->{ $lookup_result->{origin}->{$as}->{source} }++;
    }
    return;
  }

  # No differences -> exakt coverage! 
  if ( scalar @irr_conflicts == 0) {
    $unique_prefix_coverage->{covered_exact}++;
    return;
  }
}

  
  
