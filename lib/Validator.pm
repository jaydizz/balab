package Net::Validator;

our $VERSION = '1.15';

use Net::Patricia;
use Local::addrinfo qw( by_cidr mk_iprange_lite mk_iprange is_subset);
use Local::Logger;

use 5.26.1;

use Exporter 'import';
our @EXPORT_OK =
  qw(configure_zones parse_dir parse_files write_zones read_cache write_cache);
our %EXPORT_TAGS = ( all => \@EXPORT_OK, );

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

=item B<$result = validate_and_count_prefixes_irr($routes, $origin_as)>

Expects an arrayref containing all prefixes that are to be checked against the AS specified in $origin_as.
Returns a hash with the results of the following format:

  {
      valid     => $count_valid,
      valid_ls  => $count_valid_ls,
      valid_impl=> $count_valid_impl,
      invalid   => $count_invalid,
      not_found => $count_not_found
  };

=back

=cut

sub validate_and_count_prefixes_irr {
  my $prefixes    = shift or croak("We need prefixes!");
  my $origin_as   = shift or croak("No AS specified!");

  if (!ref $prefixes) {
    croak("Need an array-ref. Use validate_prefix_rpki");
  }
  $origin_as = "AS$origin_as";
 
  my $count = {
      valid      => 0, 
      valid_ls   => 0, 
      valid_impl => 0, 
      invalid    => 0, 
      not_found  => 0, 
   }; 

  foreach my $prefix ( @{$prefix_hash} ) 
    my $validation = _validate_prefix_rpki($prefix, $origin_as);
    $count{$validation->{result}}++;  
  }
  return $count;
}

=over 4

=item B<$result = validate_and_count_prefixes_rpki($routes, $origin_as)>

Expects an arrayref containing all prefixes that are to be checked against the AS specified in $origin_as.
Returns a hash with the results of the following format:

  return {
    valid => $count_valid,
    valid_ls => $count_valid_ls,
    invalid  => $count_invalid,
    invalid_ml => $count_invalid_ml,
    not_found  => $count_not_found
  };



=back

=cut 

sub validate_and_count_prefixes_rpki {
  my $prefixes    = shift or croak("We need prefixes!");
  my $origin_as   = shift or croak("No AS specified!");
  
  if (!ref $prefixes) {
    croak("Need an array-ref. Use validate_prefix_rpki");
  }
  $origin_as = "AS$origin_as";
  
  my $count = {
    valid      => 0,
    valid_ls   => 0,
    invalid    => 0,
    invalid_ml => 0,
    not_found  => 0
  };
  
  foreach my $prefix ( @{$prefixes} ) {
    my $validation = _validate_prefix_rpki($prefix, $origin_as);
    $count{$validation->{result}}++;
  }
  return $count;
}

sub _get_prefix_length {
    my $prefix = shift;
    return ( ( split /\//, $prefix ) )[1];
}

sub _validate_prefix_rpki {
  my $prefix = shift;
  my $origin_as = shift;
  
  my $result = {};

  my $pt_return;
  #Decide if v4/v6
  if ( ( index $prefix, ":" ) > 0 ) {
      $pt_return = $pt_rpki_v6->match_string($prefix);
  }
  else {
      $pt_return = $pt_rpki_v4->match_string($prefix);
  }

  my $prefix_length = _get_prefix_length($prefix);

  if ( $pt_return ) { #Lookup was successful. Prefix Exists in Tree
    $result->{pr_return} = $pt_return; 
    if ($pt_return->{origin}->{$origin_as}) { #Did we find an AS-key?
      my $max_length = $pt_return->{origin}->{$origin_as}->{max_length};
      if ( $prefix_length le $max_length ) {
        if ( $pt_return->{origin}->{$origin_as}->{implicit} ) {
          logger("RPKI: $prefix with $origin_as is rpki-valid with an less-spec match!") if $DEBUG;
          $result->{'result'} = "valid_ls";
        } else {
          logger("RPKI: $prefix with $origin_as is rpki-valid with an exact match!") if $DEBUG;
          $result->{'result'} = "valid";
        }
      } else {
          logger("RPKI: $prefix with $origin_as is rpki-invalid: $prefix_length is longer than max $max_length") if $DEBUG;
          $result->{'result'} = "invalid_ml";
      }
    } else {
      logger("RPKI: $prefix with $origin_as is rpki-invalid: AS is not allowed to announce!") if $DEBUG;
      $result->{'result'} = "invalid";
      file_logger($RPKI_INV_LOG, "$prefix with $origin_as is invalid!");
    }
  } else {
    logger("RPKI: $prefix with $origin_as is not found") if $DEBUG;
    $result->{'result'} = "not_found";
  }

  return $result;
}

sub _validate_prefix_irr {
  my $prefix = shift;
  my $origin_as = shift;

  my $result = {};
  
  my $pt_return;

  # Decide, whether we have v4/v6
  if ( (index $prefix, ":")  > 0) {
    $pt_return = $pt_irr_v6->match_string($prefix);
  } else {
    $pt_return = $pt_irr_v4->match_string($prefix);
  }

  $prefix_length = _get_prefix_length($prefix);

  if ( $pt_return) { #If defined, we found something. 
    $result->{'pt_return'} = $pt_return;
    if ( $pt_return->{origin}->{$origin_as} ) { #If the return Hash contains a key with the origin_as, it is valid
      my $as_hash = $pt_return->{origin}->{$origin_as};
      if ( $as_hash->{implicit} ) {
        logger("IRR: $prefix with $origin_as is valid, implicitely covered!") if $DEBUG;
        $result->{result} = "valid_impl";
      } elsif ( $pt_return->{length} == $prefix_length ) { # ro covers exactly
        logger("IRR: $prefix with $origin_as is valid, exact coverage!") if $DEBUG;
        $result->{result} = "valid";
      } else { #Is explicitely covered by a less-spec. Means: No exact route-object!
        logger("IRR: $prefix with $origin_as is valid, less-specific coverage!") if $DEBUG;
        $result->{result} = "valid_ls";
      }
    } else { #Invalid
      file_logger($INV_LOG ,"$origin_as announced invalid prefix $prefix!");
      $result->{result} = "invalid";
      }
  } else {
    logger("IRR: $prefix with $origin_as is not found") if $DEBUG;
    $result->{result} = "invalid";
  }
  return $result;
}
