package Net::Validator;

our $VERSION = '1.15';
use experimental qw( switch );

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
  qw(validate_irr validate_rpki);
our %EXPORT_TAGS = ( all => \@EXPORT_OK, );

our $debug_flag = 0;

=head1 NAME

Net::validator - a framework to parse and process routing-information and validate routing-data. 

=head1 SYNOPSIS

  use Net::Validator qw(:all)


=head1 DESCRIPTION

This framework offeres diverse mechanisms to parse and process routing-databases (IRRs) and ROAs and creates a Patricia-Trie from them. This trie can then be used to perform validation of routes. 

=head1 DATASTRUCTURES

The route dataformat is used to pass a route to the library and has to be of the following format:

The Datastructure returned by the validation-functions is specific 

=head1 EXPORTED 

Nothing is exported by default. The following methods can be exported:



=cut

our $VERBOSE = 0;
our $LOG_INVALIDS = 0;
our $RPKI_INV_LOG;
our $INV_LOG;
our $DEBUG = 0;

=over 4

=item B<$pt = validate_irr($prefix_ref, $asn, $pt_v4, $pt_v6)>

Validates all prefix/asn tupels given in prefix-ref. Prefix-ref is an array_ref containing all prefixes that should be checked with a given origin_as. Can also be a scalar. 
Returns:

  {
    valid     => $count_valid,
    valid_ls  => $count_valid_ls,
    valid_impl=> $count_valid_impl,
    invalid   => $count_invalid,
    not_found => $count_not_found
  };
            
  
=back

=cut


sub validate_irr($$$$) {
  my $prefix_ref = shift;
  my $asn        = shift;
  my $pt_v4      = shift;
  my $pt_v6      = shift;
  
  if (! ref $prefix_ref ) {
    my @tmp;
    push @tmp, $prefix_ref;
    $prefix_ref = \@tmp;
  }
  
  if ( ! ($asn =~/AS\d+/) ) {
    $asn = "AS$asn";
  }
  
  return _validate_irr($prefix_ref, $asn, $pt_v4, $pt_v6);
}

=over 4

=item B<$pt = validate_rpki($prefix_ref, $asn, $pt_v4, $pt_v6)>

Validates all prefix/asn tupels given in prefix-ref. Prefix-ref is an array_ref containing all prefixes that should be checked with a given origin_as. Can also be a scalar. 
Returns:
  
  {
    valid => $count_valid,
    valid_ls => $count_valid_ls,
    invalid  => $count_invalid,
    invalid_ml => $count_invalid_ml,
    not_found  => $count_not_found
  };
=back

=cut

sub validate_rpki {
  my $prefix_ref = shift;
  my $asn        = shift;
  my $pt_v4      = shift;
  my $pt_v6      = shift;
  
  if (! ref $prefix_ref ) {
    my @tmp;
    push @tmp, $prefix_ref;
    $prefix_ref = \@tmp;
  }
  
  if ( ! ($asn =~/AS\d+/) ) {
    $asn = "AS$asn";
  }
  
  return _validate_rpki($prefix_ref, $asn, $pt_v4, $pt_v6);
}

sub _validate_irr {
  my $prefix_ref = shift;
  my $origin_as  = shift;
  my $pt_v4      = shift;
  my $pt_v6      = shift;
  
  my $count_valid = 0;
  my $count_valid_ms = 0;
  my $count_valid_ls = 0;
  my $count_invalid = 0;
  my $count_not_found = 0;
  my $count_valid_impl = 0;
  my @pts;
  
  foreach my $prefix ( @{ $prefix_ref } ) {
    my $pt_return;
    eval { 
      $pt_return = _is_ipv6($prefix) ? $pt_v6->match_string($prefix) : $pt_v4->match_string($prefix);  
    };
    if ($@) {
      die ("Invalid Key: $prefix");
    }
    my $prefix_length = _get_prefix_length($prefix);
    
    if ( $pt_return) { #If defined, we found something. 
      push @pts, $pt_return;
      if ( $pt_return->{origin}->{$origin_as} ) { #If the return Hash contains a key with the origin_as, it is valid
        my $as_hash = $pt_return->{origin}->{$origin_as};
        if ( $as_hash->{implicit} ) {
          logger("IRR: $prefix with $origin_as is valid, implicitely covered!") if $DEBUG;
          $count_valid_impl++;
        } elsif ( $pt_return->{length} == $prefix_length ) { # ro covers exactly
          logger("IRR: $prefix with $origin_as is valid, exact coverage!") if $DEBUG;
          $count_valid++;
        } else { #Is explicitely covered by a less-spec. Means: No exact route-object!
          logger("IRR: $prefix with $origin_as is valid, less-specific coverage!") if $DEBUG;
          $count_valid_ls++;
        }
      } else { #Invalid
        file_logger($INV_LOG ,"$origin_as announced invalid prefix $prefix!") if $LOG_INVALIDS;
        $count_invalid++;
        }
    } else {
      logger("IRR: $prefix with $origin_as is not found") if $DEBUG;
      $count_not_found++;
   }
  } 
  return {
    valid     => $count_valid,
    valid_ls  => $count_valid_ls,
    valid_impl=> $count_valid_impl,
    invalid   => $count_invalid,
    not_found => $count_not_found,
    pt        => \@pts
  };
  
}



sub _validate_rpki {
  
  my $prefix_ref = shift;
  my $origin_as = shift;
  my $pt_v4 = shift;
  my $pt_v6 = shift;

  my $count_valid      = 0;    #Valid
  my $count_valid_ls   = 0; #Valid, covered becaus of max-length
  my $count_valid_impl = 0;
  my $count_invalid = 0;
  my $count_invalid_ml = 0; #Invalid, Max-length!

  my $count_not_found = 0;
  my @pts;;
  foreach my $prefix ( @{ $prefix_ref } ) {
    # Decide, whether we have v4/v6
    my $pt_return = _is_ipv6($prefix) ? $pt_v6->match_string($prefix) : $pt_v4->match_string($prefix);  
    my $prefix_length = _get_prefix_length($prefix);

    if ( $pt_return ) { #Lookup was successful. Prefix Exists in Tree
      push @pts, $pt_return;
      if ($pt_return->{origin}->{$origin_as}) { #Did we find an AS-key?
        my $max_length = $pt_return->{origin}->{$origin_as}->{max_length};
        given ( $prefix_length cmp $max_length ) {
          when ( $_ == 0 || $prefix_length == _get_prefix_length($pt_return->{prefix})) {
            logger("RPKI: $prefix with $origin_as is rpki-valid with an exact match!") if $DEBUG;
            $count_valid++;
          }
          when ( $_ < 0 ) {
            if ( $pt_return->{origin}->{$origin_as}->{implicit} ) {
              logger("RPKI: $prefix with $origin_as is rpki-valid with an less-spec match!") if $DEBUG;
              $count_valid_impl++;
            } else {
              logger("RPKI: $prefix with $origin_as is rpki-valid with an less-spec match!") if $DEBUG;
              $count_valid_ls++;
            }
          }
          when ( $_ > 0 ) {
            logger("RPKI: $prefix with $origin_as is rpki-invalid: $prefix_length is longer than max $max_length") if $DEBUG;
            $count_invalid_ml++;
          }
        }
      } else {
        logger("RPKI: $prefix with $origin_as is rpki-invalid: AS is not allowed to announce!") if $DEBUG;
        $count_invalid++;
        file_logger($RPKI_INV_LOG, "$prefix with $origin_as is invalid!") if $LOG_INVALIDS;
      }
    } else {
      logger("RPKI: $prefix with $origin_as is not found") if $DEBUG;
      $count_not_found++;
    }
  }
  return {
    valid => $count_valid,
    valid_ls => $count_valid_ls,
    valid_impl => $count_valid_impl,
    invalid  => $count_invalid,
    invalid_ml => $count_invalid_ml,
    not_found  => $count_not_found,
    pt         => \@pts
  };
}


sub _get_prefix_length {
  my $prefix = shift;
  
  return ((split /\//, $prefix))[1];  
}


sub _is_ipv6 {
  my $prefix = shift;
  
  if ( (index $prefix, ":")  > 0) {
    return 1;
  }
  return 0;
}
1;
