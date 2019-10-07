package Net::DBWalker;

our $VERSION = '1.15';

use lib "./";
use Net::Patricia;
use Local::addrinfo qw( by_cidr mk_iprange_lite mk_iprange is_subset);
use Local::Logger;

use 5.26.1;

use Exporter 'import';
our @EXPORT_OK =
  qw(configure_zones parse_dir parse_files write_zones read_cache write_cache);
our %EXPORT_TAGS = ( all => \@EXPORT_OK, );

our $debug_flag = 0;

=head1 NAME

Net::validator - a framework to parse and process routing-information and validate routing-data. 

=head1 SYNOPSIS

  use Net::Validator qw(all)


=head1 DESCRIPTION

This framework offeres diverse mechanisms to parse and process routing-databases (IRRs) and ROAs and creates a Patricia-Trie from them. This trie can then be used to perform validation of routes. 

=head1 DATASTRUCTURES

The route dataformat is used to pass a route to the library and has to be of the following format:

The Datastructure returned by the validation-functions is specific 

=head1 EXPORTED 

Nothing is exported by default. The following methods can be exported:


=over 4

=item B<$result = process_irr(@files, $verbose)>

Parses all IRR-Files given in @files and returns a hashref containing references to a v4 and v6 patricia trie. 
{
  v4 => ref
  v6 => ref
}

Verbose causes output of status-information. 

=back

=cut

our $pt_irr_v4;
our $pt_irr_v6;
our $pt_rpki_v4;
our $pt_rpki_v6;

#These hold the parsed objects.
our $stash_irr_v4;
our $stash_irr_v6;
our $stash_rpki_v4;
our $stash_rpki_v6;

sub process_irr {
  my $files = shift;
  
  $pt_irr_v4 = new Net::Patricia;
  $pt_irr_v6 = new Net::Patricia AF_INET6;
  
  # These hold the collected routes. 
  $stash_irr_v4  = { };
  $stash_irr_v6  = { };

  foreach my $file (@files) {
    _parse_route_objects($file);
  }    
  
  my $return = {
    v4 => _digest_routes($stash_irr_v4),
    v6 => _digest_routes($stash_irr_v6)
  };
  
  return $return;
}

sub process_roas {
  my $files = shift;
  my $format = shift;

  my $delimiter = $format->{'delimiter'};
  my $1 = $format->{'1'}; #What is the first, second and bla block in the file
  my $2 = $format->{'2'};
  my $3 = $format->{'3'};
  my $3 = $format->{'4'};
  
sub _parse_route_objects {
  my $file = shift;
  
  logger("Processing file: $file", 'yellow') if $verbose;
  my $start = time;
  my $counter = 0;

  open( my $FH, '<', $file ) or die "could not open file $file";
  
  #Temporary Variables to hold matches.
  my $net_addr; #everything before the /
  my $mask;     #everything after the /
  my $origin_as;
  my $routeobject_found;
  my $prefix;
  
  while (<$FH>) {
    #Handling ipv4 objects. 
    if ($_ =~ /route:\s+([\d\.]+)\/(\d+)/) {
      $net_addr = $1;
      $mask = $2;
      $prefix = "$1/$2";
      $routeobject_found = 4;
    }
    if ($_ =~ /route6:+\s+([\d:\.a-f]+)\/(\d+)/) {
      $net_addr = $1;
      $mask = $2;
      $prefix = "$1/$2";
      $routeobject_found = 6;
    }

    if ( $routeobject_found && $_ =~ /origin:\s+(AS\d+)/ ) {

      my $stash = $routeobject_found == 6 ? $stash_irr_v6 : $stash_irr_v4;

      $stash->{$prefix}->{length} = $mask;
      $stash->{$prefix}->{origin}->{$1}->{source} = $file;
      $stash->{$prefix}->{prefix} = $prefix;

      #Additionally calculate base and end ip for easier sorting and containment checks. 
      my $ip_range = mk_iprange($prefix);
      $stash->{$prefix}->{ base_n } = $ip_range->{base_n};
      $stash->{$prefix}->{ last_n } = $ip_range->{last_n};
      $stash->{$prefix}->{ base_p } = $ip_range->{base_p};
      $stash->{$prefix}->{ last_p } = $ip_range->{last_p};
      $stash->{$prefix}->{ version } = $ip_range->{version};

      if ($debug_flag) {
        say "found $prefix : $origin_as";
      }
      $counter++;
      ($mask, $origin_as, $prefix) = undef;

      #Add some verbosity
      if (($counter % 1000 ) == 0) {
        last if $debug_flag;
        my $duration = time - $start;
        logger_no_newline("processed $counter route-objects in $duration seconds") if $verbose;
      }
      $routeobject_found = 0;

    }
  }
  print "\n" if $verbose;
  close ($FH);
  my $duration = time - $start;
  logger("Done. It took $duration seconds to find $counter prefixes", 'green') if $verbose;
}


sub digest_hash_and_write {
  my $stash_ref = shift;
  
  logger("Digesting $case Hash.") if $verbose;


  my $af_inet;
  my @sorted;

  logger("Sorting....") if $verbose;
  #First we need the hasref as an array for sorting. 
  foreach my $prefix (keys %$stash_ref) {
    push @sorted, $stash_ref->{$prefix};
  }

  @sorted = sort by_cidr @sorted; #Make it fit the name!

  $af_inet = $sorted[0]->{version};
  logger("Done. Got AF_INET $af_inet.") if $verbose;
  logger("Resolving implicit Coverage.") if $verbose;
  my $i = 0;
  #
  # Sorted is in format a,a1,a2,b,b1,b2...
  # All IP-spaces that can contain themselfes consecutetively stored.
  # As soon as the next prefix is not contained by the previous one, 
  # we can skip to the next one.
  #

  while ( $i <= $#sorted ) {
    my $j = $i + 1; #We look at the next entry in the sorted list.

    while ( $j <= $#sorted && is_subset($sorted[$j], $sorted[$i] ) ) {
      my $tmp_hash = dclone( $sorted[$i]->{origin} ); #Create a true copy of our hash.
      foreach my $as ( keys %$tmp_hash ) {
        #If an AS is already present in the origins, we don't want to mark it as implicit. Also if it already inherits an implicit, don't overwrite it.
        $tmp_hash->{$as}->{implicit} = 1 unless (defined $sorted[$j]->{origin}->{$as}) || (defined $tmp_hash->{$as}->{implicit});
      }
      %{ $sorted[$j]->{origin} } = ( %{ $sorted[$j]->{origin} }, %$tmp_hash ); #Append additional Origins.
      $j++;
    }
    $i++;
  }
  my $pt;
  logger("Creating and Writing the Trie.") if $verbose;
  if ($af_inet == AF_INET) {
   $pt = new Net::Patricia;
  } else {
   $pt = new Net::Patricia AF_INET6;
  }

  foreach my $prefix (@sorted) {
    $pt->add_string($prefix->{prefix}, $prefix);
  }

  logger("Done.", 'green') if $verbose;
  return $pt;
}

