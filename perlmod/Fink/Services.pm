#
# Fink::Services module
#
# Fink - a package manager that downloads source and installs it
# Copyright (c) 2001 Christoph Pfisterer
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#

package Fink::Services;

use strict;
use warnings;

BEGIN {
  use Exporter ();
  our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
  $VERSION = 1.00;
  @ISA         = qw(Exporter);
  @EXPORT      = qw();
  %EXPORT_TAGS = ( );     # eg: TAG => [ qw!name1 name2! ],

  # your exported package globals go here,
  # as well as any optionally exported functions
  @EXPORT_OK   = qw(&read_config &read_properties &read_properties_multival
                    &filename &execute &expand_percent
                    &print_breaking &print_breaking_prefix
                    &print_breaking_twoprefix
                    &prompt &prompt_boolean &prompt_selection
                    &version_cmp &latest_version
                    &collapse_space);
}
our @EXPORT_OK;

# non-exported package globals go here
our $linelength;

# initialize package globals, first exported ones
#$Var1   = '';
#%Hashit = ();

# then the others (which are still accessible as $Some::Module::stuff)
$linelength = 77;

# all file-scoped lexicals must be created before
# the functions below that use them.

# file-private lexicals go here
#my $priv_var    = '';
#my %secret_hash = ();

# here's a file-private function as a closure,
# callable as &$priv_func;  it cannot be prototyped.
#my $priv_func = sub {
#  # stuff goes here.
#};

# make all your functions, whether exported or not;
# remember to put something interesting in the {} stubs
#sub func1      {}    # no prototype
#sub func2()    {}    # proto'd void
#sub func3($$)  {}    # proto'd to 2 scalars

# this one isn't exported, but could be called!
#sub func4(\%)  {}    # proto'd to 1 hash ref

END { }       # module clean-up code here (global destructor)


### create configuration

sub read_config {
  my $filename = shift;
  my ($config_object);

  require Fink::Config;

  $config_object = Fink::Config->new_with_path($filename);

  return $config_object;
}

### read properties file

sub read_properties {
  my ($file) = @_;
  my ($hash, $lastkey, $heredoc);

  $hash = {};
  $lastkey = "";
  $heredoc = 0;

  open(IN,$file) or die "can't open $file: $!";
  while (<IN>) {
    chomp;
    if ($heredoc) {
      if ($_ eq "<<") {
	$heredoc = 0;
      } else {
	$hash->{$lastkey} .= $_."\n";
	if (/<<$/) {
	  print "WARNING: Possible unterminated here-document in \"$file\".\n";
	}
      }
    } else {
      next if /^\s*\#/;   # skip comments
      if (/^([0-9A-Za-z_.\-]+)\:\s*(\S.*?)\s*$/) {
	$lastkey = lc $1;
	if ($2 eq "<<") {
	  $hash->{$lastkey} = "";
	  $heredoc = 1;
	} else {
	  $hash->{$lastkey} = $2;
	}
      } elsif (/^\s+(\S.*?)\s*$/) {
	$hash->{$lastkey} .= "\n".$1;
      }
    }
  }
  close(IN);

  if ($heredoc) {
    print "WARNING: End of file reached during here-document in \"$file\".\n";
  }

  return $hash;
}

### read properties file with multiple values per key

sub read_properties_multival {
  my ($file) = @_;
  my ($hash, $lastkey, $lastindex);

  $hash = {};
  $lastkey = "";
  $lastindex = 0;

  open(IN,$file) or die "can't open $file: $!";
  while (<IN>) {
    next if /^\s*\#/;   # skip comments
    if (/^([0-9A-Za-z_.\-]+)\:\s*(\S.*?)\s*$/) {
      $lastkey = lc $1;
      if (exists $hash->{$lastkey}) {
	$lastindex = @{$hash->{$lastkey}};
	$hash->{$lastkey}->[$lastindex] = $2;
      } else {
	$lastindex = 0;
	$hash->{$lastkey} = [ $2 ];
      }
    } elsif (/^\s+(\S.*?)\s*$/) {
      $hash->{$lastkey}->[$lastindex] .= "\n".$1;
    }
  }
  close(IN);

  return $hash;
}

### execute command

sub execute {
  my $cmd = shift;
  my $quiet = shift || 0;
  my ($retval, $prog);

  print "$cmd\n";
  $retval = system($cmd);
  $retval >>= 8 if defined $retval and $retval >= 256;
  if ($retval and not $quiet) {
    ($prog) = split(/\s+/, $cmd);
    print "### $prog failed, exit code $retval\n";
  }
  return $retval;
}

### do % substitutions on a string

sub expand_percent {
  my $s = shift;
  my $map = shift;
  my ($key, $value, $iterate);

  do {
    $iterate = 0;
    while (($key, $value) = each %$map) {
      if ($s =~ s/\%$key/$value/g) {
	$iterate = 1 if $value =~ /\%/;
      }
    }
  } while ($iterate);

  return $s;
}

### isolate filename from path

sub filename {
  my ($s) = @_;

  if ($s =~ /^mirror\:(\w+)\:(.*)$/) {
    $s = $2;
  }

  if ($s =~ /\/([^\/]+)$/) {
    $s = $1;
  }
  return $s;
}

### user interaction

sub print_breaking {
  my $s = shift;
  my $linebreak = shift;
  $linebreak = 1 unless defined $linebreak;

  print_breaking_twoprefix($s, $linebreak, "", "");
}

sub print_breaking_prefix {
  my $s = shift;
  my $linebreak = shift;
  $linebreak = 1 unless defined $linebreak;
  my $prefix = shift;
  $prefix = "" unless defined $prefix;

  print_breaking_twoprefix($s, $linebreak, $prefix, $prefix);
}

sub print_breaking_twoprefix {
  my $s = shift;
  my $linebreak = shift;
  $linebreak = 1 unless defined $linebreak;
  my $prefix1 = shift;
  $prefix1 = "" unless defined $prefix1;
  my $prefix2 = shift;
  $prefix2 = "" unless defined $prefix2;
  my ($pos, $t, $reallength, $prefix, $first);

  chomp($s);

  $first = 1;
  $prefix = $prefix1;
  $reallength = $linelength - length($prefix);
  while (length($s) > $reallength) {
    $pos = rindex($s," ",$reallength);
    if ($pos < 0) {
      $t = substr($s,0,$reallength);
      $s = substr($s,$reallength);
    } else {
      $t = substr($s,0,$pos);
      $s = substr($s,$pos+1);
    }
    print "$prefix$t\n";
    if ($first) {
      $first = 0;
      $prefix = $prefix2;
      $reallength = $linelength - length($prefix);
    }
  }
  print "$prefix$s";
  print "\n" if $linebreak;
}

sub prompt {
  my $prompt = shift;
  my $default_value = shift;
  $default_value = "" unless defined $default_value;
  my ($answer);

  &print_breaking("$prompt [$default_value] ", 0);
  $answer = <STDIN>;
  chomp($answer);
  $answer = $default_value if $answer eq "";
  return $answer;
}

sub prompt_boolean {
  my $prompt = shift;
  my $default_value = shift;
  $default_value = 1 unless defined $default_value;
  my ($answer, $meaning);

  while (1) {
    &print_breaking("$prompt [".($default_value ? "Y/n" : "y/N")."] ", 0);
    $answer = <STDIN>;
    chomp($answer);
    if ($answer eq "") {
      $meaning = $default_value;
      last;
    } elsif ($answer =~ /^y(es?)?/i) {
      $meaning = 1;
      last;
    } elsif ($answer =~ /^no?/i) {
      $meaning = 0;
      last;
    }
  }

  return $meaning;
}

# select from a list of choices
# parameters:
#  prompt         - a string
#  default_value  - a number between 1 and the number of choices
#  names          - a hashref containing display names for the choices,
#                   indexed by the choices themselves (not their index)
#  the choices    - a list of choices; one of these will be returned

sub prompt_selection {
  my $prompt = shift;
  my $default_value = shift;
  $default_value = 1 unless defined $default_value;
  my $names = shift;
  my @choices = @_;
  my ($key, $count, $answer);

  $count = 1;
  foreach $key (@choices) {
    print "\n($count)  ";
    if (exists $names->{$key}) {
      print $names->{$key};
    } else {
      print $key;
    }
    $count++;
  }
  print "\n\n";

  &print_breaking("$prompt [$default_value] ", 0);
  $answer = <STDIN>;
  chomp($answer);
  if (!$answer) {
    $answer = 0;
  }
  $answer = int($answer);
  if ($answer > 0 && $answer <= $#choices + 1) {
    return $choices[$answer-1];
  }
  return $choices[$default_value-1];
}

### comparing versions

sub version_cmp {
  my ($a1, $b1, $a2, $b2, @ca, @cb, $res);
  $a1 = shift;
  $b1 = shift;

  while ($a1 ne "" and $b1 ne "") {
    # pull a string of non-digit chars from the left
    # compare it left-to-right, sorting non-letters higher than letters
    $a1 =~ /^(\D*)/;
    @ca = unpack("C*", $1);
    $a1 = substr($a1,length($1));
    $b1 =~ /^(\D*)/;
    @cb = unpack("C*", $1);
    $b1 = substr($b1,length($1));

    while ($#ca >= 0 and $#cb >= 0) {
      $res = chr($a2 = shift @ca);
      $a2 += 256 if $res !~ /[A-Za-z]/;
      $res = chr($b2 = shift @cb);
      $b2 += 256 if $res !~ /[A-Za-z]/;
      $res = $a2 <=> $b2;
      return $res if $res;
    }
    $res = $#ca <=> $#cb;   # terminate when exactly one is exhausted
    return $res if $res;

    last unless ($a1 ne "" and $b1 ne "");

    # pull a string of digits from the left
    # compare it numerically
    $a1 =~ /^(\d*)/;
    $a2 = $1;
    $a1 = substr($a1,length($a2));
    $b1 =~ /^(\d*)/;
    $b2 = $1;
    $b1 = substr($b1,length($b2));
    $res = $a2 <=> $b2;
    return $res if $res;
  }

  # at this point, at least one of the strings is exhausted
  return $a1 cmp $b1;
}

sub latest_version {
  my ($latest, $v);

  $latest = shift;
  while (defined($v = shift)) {
    if (version_cmp($v,$latest) > 0) {
      $latest = $v;
    }
  }
  return $latest;
}

### collapse white space inside a string (removes newlines)

sub collapse_space {
  my $s = shift;
  $s =~ s/\s+/ /gs;
  return $s;
}

### EOF
1;
