#!/usr/bin/perl
use strict;
use warnings;

use Net::IRR qw( :route );
my $host = 'whois.radb.net';

my $i = Net::IRR->connect( host => $host ) or die "can't connect to $host\n";
print $i->route_search("2001:4490:48dc::/46", EXACT_MATCH)


