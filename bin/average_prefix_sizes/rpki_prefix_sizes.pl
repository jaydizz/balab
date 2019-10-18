#!/usr/bin/perl 

use strict;
use warnings;


use LWP::Simple;
use PerlIO::gzip;
use Net::Patricia;

use Net::Validator qw( :all );
use Local::Logger qw( logger_no_newline );
use Storable qw (retrieve);
use Data::Dumper;
use 5.26.1;



my $file = shift or die("Need file");
my $VERBOSE = shift or 0;


my $count_prefixes = { 
};
my $count_prefixes_v6 = { 
};

my $count_max_length = {};
my $count_max_length_v6 = {};


sub prefix_counter_v6 {
  my $pt_return = shift;
  my $length = (split  /\//, $pt_return->{prefix})[1] ;
  $count_prefixes_v6->{ $length } = 0 unless $count_prefixes_v6->{ $length };
  $count_prefixes_v6->{ $length } += 1;
  foreach my $origin (keys %{ $pt_return->{origin} }) {
    next if $pt_return->{origin}{$origin}{max_length} le 1;
    $count_max_length_v6->{ $pt_return->{origin}{$origin}{max_length} } = 0 unless $count_prefixes_v6->{$pt_return->{origin}{$origin}{max_length}  };
    $count_max_length_v6->{ $pt_return->{origin}{$origin}{max_length} } += 1;
  }
    
};
sub prefix_counter {
  my $pt_return = shift;
  my $length = (split  /\//, $pt_return->{prefix})[1] ;
  $count_prefixes->{ $length } = 0 unless $count_prefixes->{ $length };
  $count_prefixes->{ $length } += 1;
  foreach my $origin (keys %{ $pt_return->{origin} }) {
    next if $pt_return->{origin}{$origin}{max_length} le 1; 
    $count_max_length->{ $pt_return->{origin}{$origin}{max_length} } = 0 unless $count_prefixes->{$pt_return->{origin}{$origin}{max_length}  };
    $count_max_length->{ $pt_return->{origin}{$origin}{max_length} } += 1;
  }
};

my ($year, $month, $day);

if ( $file =~ /(20\d{2})-(\d{2})-(\d{2})-rpkiv4\.storable/ ) {
  ($year, $month, $day) = ($1, $2, $3);
} else {
  exit(0);
} 

my $pt_v4 = retrieve $file or die("Could not load v4 trie");
$file =~ s/rpkiv4/rpkiv6/;
my $pt_v6 = retrieve $file;

$pt_v4->climb(
  sub { 
    prefix_counter($_[0]);
  }
);
$pt_v6->climb(
  sub { 
    prefix_counter_v6($_[0]);
  }
);

say "$year-$month-$day," . calc_average($count_prefixes) . "," . calc_average($count_prefixes_v6) . "," . calc_average($count_max_length) . "," . calc_average($count_max_length_v6);

sub calc_average {
  my $hashref =shift;
  my $total = 0;
  my $avg = 0;
  foreach my $key ( keys %$hashref ) {
    $total += $hashref->{$key};
    $avg   += $key * $hashref->{$key};
  }
  $avg = int( $avg/$total + 0.5);
}



