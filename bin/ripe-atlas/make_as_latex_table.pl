#!/usr/bin/perl
use strict;
use warnings;

use 5.26.1;


while ( <STDIN> ) {
  my ($as, $score, $mali) =  split ( ',', $_);
  chomp( $as, $score, $mali);
  my $whois = `whois AS$as | egrep -o 'org-name:.*'`;
  chomp $whois;
  $whois =~ s/org-name://;
  my $string;
  if ( $mali ) {
    my $percentage = $score / ($score + $mali ) * 100;
    $string =  "AS$as & $whois & $score & $mali & $percentage\\\\"
  } else {
        $string =  "AS$as & $whois & $score \\\\";
  }
  say $string;
 
}

