package Net::Validator;

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
our $INV_LOG;

=over 4

=item B<$pt = validate_irr($prefix_ref, $asn, $pt_v4, $pt_v6)>

Validates all prefix/asn tupels given in prefix-ref. Prefix-ref is either an array_ref/hash_Ref containing hashrefs as pecified below.

  $prefix_ref : [
              
    
=back

=cut


sub validate_irr($$$) {
  my $prefix_ref = shift;
  my $asn        = shift;
  my $pt_v4      = shift;
  my $pt_v6      = shift;
  
  if (! ref $prefix_ref ) {
    my @tmp;
    push @tmp, $prefix_ref;
    $prefix_ref = \@tmp;
  }
  
  if ( ! $ans =~/AS\d+/ ) {
    $asn = "AS$ans";
  }
  
  return _validate_irr($prefix_ref, $asn, $pt_v4, $pt_v6);
}

sub _validate_irr {
  my $prefix_ref = shift;
  my $asn        = shift;
  my $pt_v4      = shift;
  my $pt_v6      = shift;
  
  my $count_valid = 0;
  my $count_valid_ms = 0;
  my $count_valid_ls = 0;
  my $count_invalid = 0;
  my $count_not_found = 0;
  my $count_valid_impl = 0;
  
  foreach my $prefix ( @{ $prefix_ref } ) {
  
    my $pt_return = _is_ipv6($prefix) ? $pt_v6->match_string($prefix) : $pt_v4->match_string($prefix);  
    my $prefix_length = _get_prefix_length($prefix);
    
    if ( $pt_return) { #If defined, we found something. 
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
    valid_ms  => $count_valid_ms,
    valid_ls  => $count_valid_ls,
    valid_impl=> $count_valid_impl,
    invalid   => $count_invalid,
    not_found => $count_not_found
  };
  
}



sub _get_prefix_length {
  my $prefix = shift;
  
  return ((split /\//, $prefix))[1];  
}


sub _is_ipv6 {
  my $prefix = shift;
  
  if ( (index $prefix, ":")  > 0) {
    return 1:
  }
  return 0;
}
