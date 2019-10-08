package Local::Logger;
use 5.26.1;

use Term::ANSIColor;

our $VERSION = '1.0';

use Exporter 'import';
our @EXPORT_OK =
  qw(get_formated_time logger file_logger logger_no_newline);
our %EXPORT_TAGS = ( all => \@EXPORT_OK, );


sub get_formated_time {
  my ($sec, $min, $h, $mday, $mon, $year) = localtime(time);
  my $time = sprintf '%04d-%02d-%02d:%02d:%02d:%02d : ', $year, $mon, $mday, $h, $min, $sec;
}

sub logger {
  my $msg = shift;
  my $color = shift || 'reset';
  my $time = get_formated_time();
  print "$time";
  print color('reset');
  print color($color);
  say "$msg";
  print color('reset');
  STDOUT->flush();
}

sub file_logger {
  my $file = shift or die("No file specified in file_logger");
  my $msg = shift;
  my $time = get_formated_time();
  print $file "$time";
  say   $file "$msg";
  STDOUT->flush();
}

sub logger_no_newline {
  my $msg = shift;
  my $color = shift || 'reset';
  my $time = get_formated_time();
  print "$time";
  print color('reset');
  print color($color);
  print "$msg                                  \r";
  STDOUT->flush();
  print color('reset');
}

1;
