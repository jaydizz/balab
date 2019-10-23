package Net::DBWalker;

our $VERSION = '1.15';

use lib "./";
use Net::Patricia;
use Local::addrinfo qw( :all );
use Local::Logger qw( :all );

use Mojo::JSON qw(decode_json encode_json);
use Carp qw( croak );
use Storable qw( dclone );
use 5.26.1;

use Exporter 'import';
our @EXPORT_OK =
  qw(process_irr VERBOSE process_roas export_roas_as_json export_irr_as_json);
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



=cut

our $VERBOSE = 0;
our $pt_irr_v4;
our $pt_irr_v6;
our $pt_rpki_v4;
our $pt_rpki_v6;

#These hold the parsed objects.
our $stash_irr_v4;
our $stash_irr_v6;
our $stash_rpki_v4;
our $stash_rpki_v6;

=over 4

=item B<$pt = process_irr($files)>

Parses files specified in $files (either scalar or array-ref) and constructs an lookup-trie for validation. Returns hashref containing v4/v6 trie.
  
  $pt = {
    v4 => pt_v4 
    v6 => pt_v6
  }

=back

=cut

sub process_irr {
  my $files = shift;
  croak("Files for IRRs need to be specified either as arrayref or scalar!") if !$files;
  if (!ref $files) {
    my @tmp;
    push @tmp, $files;
    $files = \@tmp;
  }
  # These hold the collected routes. 
  $stash_irr_v4  = { };
  $stash_irr_v6  = { };

  foreach my $file (@{ $files }) {
    _parse_route_objects($file, $stash_irr_v4, $stash_irr_v6)
  }    
  
  my $pt_irr = {
    v4 => _create_pt(_sort_and_resolv($stash_irr_v4)),
    v6 => _create_pt(_sort_and_resolv($stash_irr_v6)),
    size => {
      v4 => scalar keys %$stash_irr_v4,
      v6 => scalar keys %$stash_irr_v6
    }
  };
  
  return $pt_irr;
}

=over 4

=item B<$json = export_irr_as_json($files)>

Return a hash containg the parsed route-objects as json-strings. Takes either a scalar or an array as a file.
  
  e.g. $json = {
          v4 => json-v4..
          v6 => json-v6..
       }

=back

=cut


sub export_irr_as_json {
  my $files = shift;
  croak("Files for IRRs need to be specified either as arrayref or scalar!") if !$files;
  if (!ref $files) {
    my @tmp;
    push @tmp, $files;
    $files = \@tmp;
  }
  # These hold the collected routes. 
  $stash_irr_v4  = { };
  $stash_irr_v6  = { };

  foreach my $file (@{ $files }) {
    _parse_route_objects($file, $stash_irr_v4, $stash_irr_v6)
  }    
  
  my $json_irr = {
    v4 => encode_json(_sort_and_resolv($stash_irr_v4)),
    v6 => encode_json(_sort_and_resolv($stash_irr_v6)),
  };
  
  return $json_irr;
}

=over 4

=item B<$pt = process_roas($files, [$format])>

Parses files specified in $files (either scalar or array-ref) and constructs an lookup-trie for validation. Returns hashref containing v4/v6 trie.
Format specifies the format of the file containing roas. The Numbers correspond to the fields in a csv.
  
  $format = {
    delimiter   => ',',
    $origin_as  => '1',
    $prefix     => '2',
    $max_length => '3'
  }
  $pt = {
     v4 => pt_v4 
     v6 => pt_v6
  }

=back

=cut


sub process_roas {
  my $files = shift;
  my $format = shift;

  #Allow Processing of a single file.
  if (!ref $files) {
    my @tmp;
    push @tmp, $files;
    $files = \@tmp;
  }
  if ( $format == undef ) {
    logger("Using default layout for roa-files.") if $VERBOSE;
    $format = {
      delimiter => ',',
      origin_as => '0',
      prefix => '1',
      max_length => '2',
    };
  }
  croak("$format needs to be either a hash-ref or undef.") if !ref $format;
  
  # Initialize Stash Objects
  $stash_rpki_v4 = { };
  $stash_rpki_v6 = { };

  #And here we go!
  foreach my $file (@{ $files }) {
    _parse_roas($file, $stash_rpki_v4, $stash_rpki_v6, $format);
  }
  
  my $pt_rpki = {
    v4 => _create_pt(_sort_and_resolv($stash_rpki_v4)),
    v6 => _create_pt(_sort_and_resolv($stash_rpki_v6)),
    size => {
      v4 => scalar keys %$stash_rpki_v4,
      v6 => scalar keys %$stash_rpki_v6
    }

  };

  return $pt_rpki;
}


=over 4

=item B<$json = export_rpki_as_json($files)>

Return a hash containg the parsed roas as json-strings. Takes either a scalar or an array as a file.
  
  e.g. $json = {
          v4 => json-v4..
          v6 => json-v6..
        }

=back

=cut


sub export_roas_as_json {
  my $files = shift;
  my $format = shift;

  #Allow Processing of a single file.
  if (!ref $files) {
    my @tmp;
    push @tmp, $files;
    $files = \@tmp;
  }
  if ( $format == undef ) {
    logger("Using default layout for roa-files.") if $VERBOSE;
    $format = {
      delimiter => ',',
      origin_as => '0',
      prefix => '1',
      max_length => '2',
      
    };
  }
  croak("$format needs to be either a hash-ref or undef.") if !ref $format;
  
  # Initialize Stash Objects
  $stash_rpki_v4 = { };
  $stash_rpki_v6 = { };

  #And here we go!
  foreach my $file (@{ $files }) {
    _parse_roas($file, $stash_rpki_v4, $stash_rpki_v6);
  }
  
  my $json_rpki = {
    v4 => encode_json(_sort_and_resolv($stash_rpki_v4)),
    v6 => encode_json(_sort_and_resolv($stash_rpki_v6)),
  };

  return $json_rpki;
}

  

sub _parse_route_objects {
  my $file = shift;
  my $stash_v4 = shift;
  my $stash_v6 = shift;

  logger("Processing file: $file", 'yellow') if $VERBOSE;
  my $start = time;
  my $counter = 0;
  my $FH;
  open( $FH, '<', $file ) or die "could not open file $file";
  
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

      my $stash = $routeobject_found == 6 ? $stash_v6 : $stash_v4;

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
        logger_no_newline("processed $counter route-objects in $duration seconds") if $VERBOSE;
      }
      $routeobject_found = 0;

    }
  }
  print "\n" if $VERBOSE;
  close ($FH);
  my $duration = time - $start;
  logger("Done. It took $duration seconds to find $counter prefixes", 'green') if $VERBOSE;
}

sub _parse_roas {
  my $file = shift;
  my $stash_v4 = shift;
  my $stash_v6 = shift;
  my $format = shift;

  
  logger("RPKI: Processing file: $file") if $VERBOSE;

  my $start = time;
  my $counter = 0;
  open (my $FH, '<', $file) or die "could not open file $file";
  
  my $header = <$FH>; # stripping the header. 
  

  while (<$FH>) {
      my @split = split /,/, $_;
      
      my $origin_as   = $split[$format->{'origin_as'} ];
      my $prefix      = $split[$format->{'prefix'}    ];
      my $max_length  = $split[$format->{'max_length'}];
      my $stash = (index $prefix, ":") > 0 ? $stash_v6 : $stash_v4;

      $stash->{$prefix}->{origin}->{$origin_as}->{max_length} = $max_length;
      $stash->{$prefix}->{origin}->{$origin_as}->{source} = $file;
      $stash->{$prefix}->{prefix} = $prefix;

      my $ip_range = mk_iprange($prefix);
      $stash->{$prefix}->{ base_n } = $ip_range->{base_n};
      $stash->{$prefix}->{ last_n } = $ip_range->{last_n};
      $stash->{$prefix}->{ base_p } = $ip_range->{base_p};
      $stash->{$prefix}->{ last_p } = $ip_range->{last_p};
      $stash->{$prefix}->{ version } = $ip_range->{version};

      if (($counter % 1000 ) == 0) {
        last if $debug_flag;
        my $duration = time - $start;
        logger_no_newline("processed $counter ROAs in $duration seconds") if $VERBOSE;
      }
      $counter++;
    }
  print "\n" if $VERBOSE;  #Flush stdout.
  my $duration = time - $start;
  logger("Done. It took $duration seconds to find $counter prefixes", 'green') if $VERBOSE;
}
 

sub _sort_and_resolv {
  my $stash_ref = shift;
  
  logger("Digesting Hash.") if $VERBOSE;


  my $af_inet;
  my @sorted;

  logger("Sorting....") if $VERBOSE;
  #First we need the hasref as an array for sorting. 
  foreach my $prefix (keys %$stash_ref) {
    push @sorted, $stash_ref->{$prefix};
  }

  @sorted = sort by_cidr @sorted; #Make it fit the name!

  $af_inet = $sorted[0]->{version};
  logger("Done. Got AF_INET $af_inet.") if $VERBOSE;
  logger("Resolving implicit Coverage.") if $VERBOSE;
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
  return \@sorted;
}

sub _create_pt {
  my $nodes = shift;
  
  my $pt;
  logger("Creating Trie.") if $VERBOSE;
  my $af = @{ $nodes }[0]->{version};
  if (!$af) {
    logger("Found no valid records. Skipping.");
    return new Net::Patricia AF_INET6;
  }
  if ($af == AF_INET) {
   $pt = new Net::Patricia;
  } else {
   $pt = new Net::Patricia AF_INET6;
  }

  foreach my $prefix (@{ $nodes }) {
    $pt->add_string($prefix->{prefix}, $prefix);
  }

  logger("Done.", 'green') if $VERBOSE;
  return $pt;
} 
   

1;
