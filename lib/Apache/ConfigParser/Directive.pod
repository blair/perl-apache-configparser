# Apache::ConfigParser::Directive: A single Apache directive or start context.
#
# Copyright (C) 2001 Blair Zajac.  All rights reserved.

package Apache::ConfigParser::Directive;
require 5.004_05;
use strict;
use Exporter;
use Carp;
use File::Spec     0.82;
use Tree::DAG_Node 1.04;

use vars qw(@EXPORT_OK @ISA $VERSION);
@ISA     = qw(Tree::DAG_Node Exporter);
$VERSION = sprintf '%d.%02d', '$Revision: 0.02 $' =~ /(\d+)\.(\d+)/;

# Determine if the filenames are case sensitive.
use constant CASE_SENSITIVE_PATH => (! File::Spec->case_tolerant);

# This is a utility subroutine to determine if the specified path is
# the /dev/null equivalent on this operating system.
use constant DEV_NULL    =>    File::Spec->devnull;
use constant DEV_NULL_LC => lc(File::Spec->devnull);
sub is_dev_null {
  if (CASE_SENSITIVE_PATH) {
    return $_[0] eq DEV_NULL;
  } else {
    return lc($_[0]) eq DEV_NULL_LC;
  }
}

# This constant is used throughout the module.
my $INCORRECT_NUMBER_OF_ARGS = "passed incorrect number of arguments.\n";

# These are declared now but defined and documented below.
use vars         qw(%directive_value_takes_path
                    %directive_value_takes_rel_path);
push(@EXPORT_OK, qw(%directive_value_takes_path
                    %directive_value_takes_rel_path));

=head1 NAME

  Apache::ConfigParser::Directive - An Apache directive or start context

=head1 SYNOPSIS

  use Apache::ConfigParser::Directive;

  # Create a new empty directive.
  my $d = Apache::ConfigParser::Directive->new;

  # Make it a ServerRoot directive.
  # ServerRoot /etc/httpd
  $d->name('ServerRoot');
  $d->value('/etc/httpd');

  # A more complicated directive.  Value automatically splits the
  # argument into separate elements.  It treats elements in "'s as a
  # single element.
  # LogFormat "%h %l %u %t \"%r\" %>s %b" common
  $d->name('LogFormat');
  $d->value('"%h %l %u %t \"%r\" %>s %b" common');

  # Get a string form of the name.
  # Prints `logformat'.
  print $d->name, "\n";

  # Get a string form of the value.
  # Prints `"%h %l %u %t \"%r\" %>s %b" common'.
  print $d->value, "\n";

  # Get the values separated into individual elements.  Whitespace
  # separated elements that are enclosed in "'s are treated as a
  # single element.  Protected quotes, \", are honored to not begin or
  # end a value element.  In this form protected "'s, \", are no
  # longer protected.
  my @value = $d->get_value_array;
  scalar @value == 2;		# There are two elements in this array.
  $value[0] eq '%h %l %u %t \"%r\" %>s %b';
  $value[1] eq 'common';

  # The array form can also be set.  Change style of LogFormat from a
  # common to a referer style log.
  $d->set_value_array('%{Referer}i -> %U', 'referer');

  # This is equivalent.
  $d->value('"%{Referer}i -> %U" referer');

  # There are also an equivalent pair of values that are called
  # `original' that can be accessed via orig_value,
  # get_orig_value_array and set_orig_value_array.
  $d->orig_value('"%{User-agent}i" agent');
  $d->set_orig_value_array('%{User-agent}i', 'agent');
  @value = $d->get_orig_value_array;
  scalar @value == 2;		# There are two elements in this array.
  $value[0] eq '%{User-agent}i';
  $value[1] eq 'agent';

  # You can set undef values for the strings.
  $d->value(undef);

=head1 DESCRIPTION

The C<Apache::ConfigParser::Directive> module is a subclass of
C<Tree::DAG_Node>, which provides methods to represents nodes in a
tree.  Each node is a single Apache configuration directive or root
node for a context, such as <Directory> or <VirtualHost>.  All of the
methods in that module are available here.  This module adds some
additional methods that make it easier to represent Apache directives
and contexts.

This module holds a directive or context:

  name
  value in string form
  value in array form
  a separate value termed `original' in string form
  a separate value termed `original' in array form
  the filename where the directive was set
  the line number in the filename where the directive was set

The `original' value is separate from the non-`original' value and the
methods to operate on the two sets of values have distinct names.  The
`original' value can be used to store the original value of a
directive while the non-`directive' value can be a modified form, such
as changing the CustomLog filename to make it absolute.  The actual
use of these two distinct values is up to the caller as this module
does not link the two in any way.

=head1 METHODS

The following methods are available:

=over

=cut

=item $d = Apache::ConfigParser::Directive->new;

This creates a brand new C<Apache::ConfigParser::Directive> object.

It is not recommended to pass any arguments to C<new> to set the
internal state and instead use the following methods.

There actually is no C<new> method in the
C<Apache::ConfigParser::Directive> module.  Instead, due to
C<Apache::ConfigParser::Directive> being a subclass of
C<Tree::DAG_Node>, C<Tree::DAG_Node::new> will be used.

=cut

# The Apache::ConfigParser::Directive object still needs to be
# initialized.  This is done here.  Tree::DAG_Node->new calls
# Apache::ConfigParser::Directive->_init, which will call
# Tree::DAG_Node->_init.
sub _init {
  my $self                  = shift;
  $self->SUPER::_init;
  $self->{name}             = '';
  $self->{value}            = '';
  $self->{value_array}      = [];
  $self->{orig_value}       = '';
  $self->{orig_value_array} = [];
  $self->{filename}         = '';
  $self->{line_number}      = -1;
}

=item $d->name

=item $d->name($name)

In the first form get the directive or context's name.  In the second
form set the new name of the directive or context to the lowercase
version of I<$name> and return the original name.

=cut

sub name {
  unless (@_ < 3) {
    confess "$0: Apache::ConfigParser::Directive::name $INCORRECT_NUMBER_OF_ARGS";
  }

  my $self = shift;
  if (@_) {
    my $old       = $self->{name};
    $self->{name} = lc($_[0]);
    return $old;
  } else {
    return $self->{name};
  }
}

=item $d->value

=item $d->value($value)

In the first form get the directive's value in string form.  In the
second form, return the previous directive value in string form and
set the new directive value to I<$value>.  I<$value> can be set to
undef.

If the value is being set, then I<$value> is saved so another call to
C<value> will return I<$value>.  If I<$value> is defined, then
I<$value> is also parsed into an array of elements that can be
retrieved with the C<value_array_ref> or C<get_value_array> methods.
The parser separates elements by whitespace, unless whitespace
separated elements are enclosed by "'s.  Protected quotes, \", are
honored to not begin or end a value element.

=item $d->orig_value

=item $d->orig_value($value)

Identical behavior as C<value>, except that this applies to a the
`original' value.  Use C<orig_value_ref> or C<get_orig_value_array> to
get the value elements.

=cut

# This function manages getting and setting the string value for
# either the `value' or `orig_value' hash keys.
sub _get_set_value_string {
  unless (@_ > 1 and @_ < 4) {
    confess "$0: Apache::ConfigParser::Directive::_get_set_value_string $INCORRECT_NUMBER_OF_ARGS";
  }

  my $self            = shift;
  my $string_var_name = pop;
  my $old_value       = $self->{$string_var_name};
  unless (@_) {
    return $old_value;
  }

  my $value           = shift;
  my $array_var_name  = "${string_var_name}_array";

  if (defined $value) {
    # Keep the value as a string and also create an array of values.
    # Keep content inside " as a single value and also protect \".
    my @values;
    if (length $value) {
      my $v =  $value;
      $v    =~ s/\\"/\200/g;
      while (defined $v and length $v) {
        if ($v =~ s/^"//) {
          my $quote_index = index($v, '"');
          if ($quote_index < 0) {
            $v =~ s/\200/"/g;
            push(@values, $v);
            last;
          } else {
            my $v1 =  substr($v, 0, $quote_index, '');
            $v     =~ s/^"\s*//;
            $v1    =~ s/\200/"/g;
            push(@values, $v1);
          }
        } else {
          my ($v1, $v2) = $v =~ /^(\S+)(?:\s+(.*))?$/;
          $v            = $v2;
          $v1           =~ s/\200/"/g;
          push(@values, $v1);
        }
      }
    }
    $self->{$string_var_name} = $value;
    $self->{$array_var_name}  = \@values;
  } else {
    $self->{$string_var_name} = undef;
    $self->{$array_var_name}  = undef;
  }

  $old_value;
}

sub value {
  unless (@_ and @_ < 3) {
    confess "$0: Apache::ConfigParser::Directive::value $INCORRECT_NUMBER_OF_ARGS";
  }

  return _get_set_value_string(@_, 'value');
}

sub orig_value {
  unless (@_ and @_ < 3) {
    confess "$0: Apache::ConfigParser::Directive::orig_value $INCORRECT_NUMBER_OF_ARGS";
  }

  return _get_set_value_string(@_, 'orig_value');
}

=item $d->value_array_ref

=item $d->value_array_ref(\@array)

In the first form get a reference to the value array.  This can return
an undefined value if an undefined value was passed to C<value> or an
undefined reference was passed to C<value_array_ref>.  In the second
form C<value_array_ref> sets the value array and value string.  Both
forms of C<value_array_ref> return the original array reference.

If you modify the value array reference after getting it and do not
use C<value_array_ref> C<set_value_array> to set the value, then the
string returned from C<value> will not be consistent with the array.

=item $d->orig_value_array_ref

=item $d->orig_value_array_ref(\@array)

Identical behavior as C<value_array_ref>, except that this applies to
the `original' value.

=cut

# This is a utility function that takes the hash key name to place the
# value elements into, saves the array and creates a value string
# suitable for placing into an Apache configuration file.
sub _set_value_array {
  unless (@_ > 1) {
    confess "$0: Apache::ConfigParser::Directive::_set_value_string $INCORRECT_NUMBER_OF_ARGS";
  }

  my $self            = shift;
  my $string_var_name = pop;
  my $array_var_name  = "${string_var_name}_array";
  my @values          = @_;

  my $value = '';
  foreach my $s (@values) {
    next unless length $s;

    $value .= ' ' if length $value;

    # Make a copy of the string so that the regex doesn't modify the
    # contents of @values.
    my $substring  =  $s;
    $substring     =~ s/(["\\])/\\$1/g;
    if ($substring =~ /\s/) {
      $value .= "\"$substring\"";
    } else {
      $value .= $substring;
    }
  }

  $self->{$string_var_name} = $value;
  $self->{$array_var_name}  = \@values;
}

sub value_array_ref {
  unless (@_ and @_ < 3) {
    confess "$0: Apache::ConfigParser::Directive::value_array_ref $INCORRECT_NUMBER_OF_ARGS";
  }

  my $self = shift;

  my $old = $self->{value_array};

  if (@_) {
    my $ref = shift;
    if (defined $ref) {
      $self->_set_value_array(@$ref, 'value');
    } else {
      $self->{value}       = undef;
      $self->{value_array} = undef;
    }
  }

  $old;
}

sub orig_value_array_ref {
  unless (@_ and @_ < 3) {
    confess "$0: Apache::ConfigParser::Directive::orig_value_array_ref $INCORRECT_NUMBER_OF_ARGS";
  }

  my $self = shift;

  my $old = $self->{orig_value_array};

  if (@_) {
    my $ref = shift;
    if (defined $ref) {
      $self->_set_value_array(@$ref, 'orig_value');
    } else {
      $self->{value}       = undef;
      $self->{value_array} = undef;
    }
  }

  $old;
}

=item $d->get_value_array

Get the value array elements.  If the value was set to an undefined
value using C<value>, then C<get_value_array> will return an empty
list in a list context, an undefined value in a scalar context, or
nothing in a void context.

=item $d->get_orig_value_array

This has the same behavior of C<get_value_array> except that it
operates on the `original' value.

=cut

sub get_value_array {
  unless (@_ == 1) {
    confess "$0: Apache::ConfigParser::Directive::get_value_array $INCORRECT_NUMBER_OF_ARGS";
  }

  my $ref = shift->{value_array};

  if ($ref) {
    return @$ref;
  } else {
    return;
  }
}

sub get_orig_value_array {
  unless (@_ == 1) {
    confess "$0: Apache::ConfigParser::Directive::get_orig_value_array $INCORRECT_NUMBER_OF_ARGS";
  }

  my $ref = shift->{orig_value_array};

  if ($ref) {
    return @$ref;
  } else {
    return;
  }
}

=item $d->set_value_array(@values)

Set the value array elements.  If no elements are passed in, then the
value will be defined but empty and a following call to
C<get_value_array> will return an empty array.

After setting the value elements with this method, the string returned
from calling C<value> is a concatenation of each of the elements so
that the output could be used for an Apache configuration file.  If
any elements contain whitespace, then the "'s are placed around the
element as the element is being concatenated into the value string and
if any elements contain a " or a \, then a copy of the element is made
and the character is protected, i.e. \" or \\, and then copied into
the value string.

=item $d->set_orig_value_array(@values)

This has the same behavior as C<set_value_array> except that it
operates on the `original' value, so to get a string version,
C<orig_value>.

=cut

sub set_value_array {
  return _set_value_array(@_, 'value');
}

sub set_orig_value_array {
  return _set_value_array(@_, 'orig_value');
}

=item $d->value_is_path

Returns true if C<$d>'s directive can take a file or directory path as
its value array element 0 and that element is a file or directory
path.  Both the directive name and the argument is checked, because
some directives such as ErrorLog, can take values that are not paths
(i.e. piped command or syslog:facility).  The /dev/null equivalent for
the operating system is not treated as a path, since on some operating
systems the /dev/null equivalent is not a file, such as nul on
Windows.

The method actually does not check if its argument is a path, rather
it checks if the argument does not match all of the other possible
non-path values for the specific directive because different operating
systems have different path formats, such as Unix, Windows and
Macintosh.

=cut

# This is a function that does the work for value_is_path,
# orig_value_is_path, value_is_abs_path, orig_value_is_abs_path,
# value_is_rel_path and orig_value_is_rel_path.
sub _value_is_path_or_abs_path_or_rel_path {
  unless (@_ == 4) {
    confess "$0: Apache::ConfigParser::Directive::_value_is_path_or_abs_path_or_rel_path $INCORRECT_NUMBER_OF_ARGS";
  }

  my ($self, $check_for_abs_path, $check_for_rel_path, $array_var_name) = @_;

  my $array_ref = $self->{$array_var_name};

  unless ($array_ref) {
    return 0;
  }

  my $value_element_0 = $self->{$array_var_name}->[0];

  unless (defined $value_element_0 and length $value_element_0) {
    return 0;
  }

  if (is_dev_null($value_element_0)) {
    return 0;
  }

  my $directive_name = $self->name;

  unless (defined $directive_name and length $directive_name) {
    return 0;
  }

  my $sub_ref;
  if ($check_for_rel_path) {
    $sub_ref = $directive_value_takes_rel_path{$directive_name};
  } else {
    $sub_ref = $directive_value_takes_path{$directive_name};
  }

  unless ($sub_ref) {
    return 0;
  }

  my $result = &$sub_ref($value_element_0);
  if ($result) {
    if ($check_for_abs_path) {
      return File::Spec->file_name_is_absolute($value_element_0) ? 1 : 0;
    } elsif ($check_for_rel_path) {
      return File::Spec->file_name_is_absolute($value_element_0) ? 0 : 1;
    } else {
      return $result ? 1 : 0;
    }
  } else {
    return 0;
  }
}

sub value_is_path {
  _value_is_path_or_abs_path_or_rel_path($_[0], 0, 0, 'value_array');
}

=item $d->orig_value_is_path

Returns true if C<$d>'s directive can take a file or directory path as
its `original' value array element 0 and that element is a file or
directory path.  This has the same semantics as C<value_is_path>.

=cut

sub orig_value_is_path {
  _value_is_path_or_abs_path_or_rel_path($_[0], 0, 0, 'orig_value_array');
}

=item $d->value_is_abs_path

Returns true if C<$d>'s directive can take either an absolute or
relative file or directory path as its value array element 0 and that
element is an absolute file or directory path.  Both the directive
name and the argument is checked, because some directives such as
ErrorLog, can take values that are not paths (i.e. piped command or
syslog:facility).  The /dev/null equivalent for the operating system
is not treated as a path, since on some operating systems the
/dev/null equivalent is not a file, such as nul on Windows.

Unlike C<value_is_path> and C<orig_value_is_path>, this method does
check if the argument is in the format of a relative path that is used
on the operating system running using this module.

=cut

sub value_is_abs_path {
  _value_is_path_or_abs_path_or_rel_path($_[0], 1, 0, 'value_array');
}

=item $d->orig_value_is_abs_path

Returns true if C<$d>'s directive can take either an absolute or
relative file or directory path as its `original' value array element
0 and that element is an absolute file or directory path.  Has the
same semantics as C<value_is_abs_path>.

=cut

sub orig_value_is_abs_path {
  _value_is_path_or_abs_path_or_rel_path($_[0], 1, 0, 'orig_value_array');
}

=item $d->value_is_rel_path

Returns true if C<$d>'s directive can take either an absolute or
relative file or directory path as its value array element 0 and that
element is a relative file or directory path.  If a relative path name
is given as a value to a directive that does not take relative file or
directory names, such as AgentLog, then this subroutine will return 0
even though the path is relative.  Both the directive name and the
argument is checked, because some directives such as ErrorLog, can
take values that are not paths (i.e. piped command or
syslog:facility).  The /dev/null equivalent for the operating system
is not treated as a path, since on some operating systems the
/dev/null equivalent is not a file, such as nul on Windows.

Unlike C<value_is_path> and C<orig_value_is_path>, this method does
check if the argument is in the format of a relative path that is used
on the operating system running using this module.

=cut

sub value_is_rel_path {
  _value_is_path_or_abs_path_or_rel_path($_[0], 0, 1, 'value_array');
}

=item $d->orig_value_is_rel_path

Returns true if C<$d>'s directive can take either an absolute or
relative file or directory path as its `original' value array element
0 and that element is a relative file or directory path.  Has the same
semantics as C<value_is_rel_path>.

=cut

sub orig_value_is_rel_path {
  _value_is_path_or_abs_path_or_rel_path($_[0], 0, 1, 'orig_value_array');
}

=item $d->filename

=item $d->filename($filename)

In the first form get the filename where this particular directive or
context appears.  In the second form set the new filename of the
directive or context and return the original filename.

=cut

sub filename {
  unless (@_ < 3) {
    confess "$0: Apache::ConfigParser::Directive::filename $INCORRECT_NUMBER_OF_ARGS";
  }

  my $self = shift;
  if (@_) {
    my $old           = $self->{filename};
    $self->{filename} = $_[0];
    return $old;
  } else {
    return $self->{filename};
  }
}

=item $d->line_number

=item $d->line_number($line_number)

In the first form get the line number where the directive or context
appears in a filename.  In the second form set the new line number of
the directive or context and return the original line number.

=cut

sub line_number {
  unless (@_ < 3) {
    confess "$0: Apache::ConfigParser::Directive::line_number $INCORRECT_NUMBER_OF_ARGS";
  }

  my $self = shift;
  if (@_) {
    my $old              = $self->{line_number};
    $self->{line_number} = $_[0];
    return $old;
  } else {
    return $self->{line_number};
  }
}

=back

=head1 EXPORTED VARIABLES

The following variables are exported via C<@EXPORT_OK>.

=over 4

=item %directive_value_takes_path

This hash is keyed by the lowercase version of a directive name.  This
hash is keyed by all directives that accept a file or directory path
value as its first value array element. The hash value is a subroutine
reference to pass the value array element containing the file,
directory, pipe or syslog entry to.  If a hash entry exists for a
particular entry, then the directive name can take either a relative
or absolute path to either a file or directory.  The hash does not
distinguish between directives that take only filenames, only
directories or both, and it does not distinguish if the directive
takes only absolute, only relative or both types of paths.

The hash value for the lowercase directive name is a subroutine
reference.  The subroutine returns 1 if its only argument is a path
and 0 otherwise.  The /dev/null equivalent (C<File::Spec->devnull>)
for the operating system being used is not counted as a path, since on
some operating systems the /dev/null equivalent is not a filename,
such as nul on Windows.

The subroutine actually does not check if its argument is a path,
rather it checks if the argument does not match one of the other
possible non-path values for the specific directive because different
operating systems have different path formats, such as Unix, Windows
and Macintosh.  For example, ErrorLog can take a filename, such as

  ErrorLog /var/log/httpd/error_log

or a piped command, such as

  ErrorLog "| cronolog /var/log/httpd/%Y/%m/%d/error.log"

or a syslog entry of the two forms:

  ErrorLog syslog
  ErrorLog syslog:local7

The particular subroutine for ErrorLog checks if the value is not
equal to C<File::Spec->devnull>, does not begin with a | or does not
match syslog(:[a-zA-Z0-9]+)?.

These subroutines do not remove any "'s before checking on the type of
value.

This hash is used by C<value_is_path> and C<orig_value_is_path>.

This is a list of directives and any special values to check for as of
Apache 1.3.20.

  AccessConfig
  AgentLog          check for "| prog"
  AuthDBGroupFile
  AuthDBMGroupFile
  AuthDBMUserFile
  AuthDBUserFile
  AuthDigestFile
  AuthGroupFile
  AuthUserFile
  CacheRoot
  CookieLog
  CoreDumpDirectory
  CustomLog         check for "| prog"
  Directory
  DocumentRoot
  ErrorLog          check for "| prog", or syslog or syslog:facility
  Include
  LoadFile
  LoadModule
  LockFile
  MimeMagicFile
  MMapFile
  PidFile
  RefererLog        check for "| prog"
  ResourceConfig
  RewriteLock
  ScoreBoardFile
  ScriptLog
  ServerRoot
  TransferLog       check for "| prog"
  TypesConfig

=item %directive_value_takes_rel_path

This hash is keyed by the lowercase version of a directive name.  This
hash contains only those directive names that can accept both relative
and absolute file or directory names.  The hash value is a subroutine
reference to pass the value array element containing the file,
directory, pipe or syslog entry to.  The hash does not distinguish
between directives that take only filenames, only directories or both.

The hash value for the lowercase directive name is a subroutine
reference.  The subroutine returns 1 if its only argument is a path
and 0 otherwise.  The /dev/null equivalent (C<File::Spec->devnull>)
for the operating system being used is not counted as a path, since on
some operating systems the /dev/null equivalent is not a filename,
such as nul on Windows.

The subroutine actually does not check if its argument is a path,
rather it checks if the argument does not match one of the other
possible non-path values for the specific directive because different
operating systems have different path formats, such as Unix, Windows
and Macintosh.  For example, ErrorLog can take a filename, such as

  ErrorLog /var/log/httpd/error_log

or a piped command, such as

  ErrorLog "| cronolog /var/log/httpd/%Y/%m/%d/error.log"

or a syslog entry of the two forms:

  ErrorLog syslog
  ErrorLog syslog:local7

The particular subroutine for ErrorLog checks if the value is not
equal to C<File::Spec->devnull>, does not begin with a | or does not
match syslog(:[a-zA-Z0-9]+)?.

These subroutines do not remove any "'s before checking on the type of
value.

This hash is used by C<value_is_rel_path> and
C<orig_value_is_rel_path>.

This is a list of directives and any special values to check for as of
Apache 1.3.20.

  AccessConfig
  AuthGroupFile
  AuthUserFile
  CookieLog
  CustomLog         check for "| prog"
  ErrorLog          check for "| prog", or syslog or syslog:facility
  Include
  LoadFile
  LoadModule
  LockFile
  MimeMagicFile
  PidFile
  RefererLog        check for "| prog"
  ResourceConfig
  ScoreBoardFile
  ScriptLog
  TransferLog       check for "| prog"
  TypesConfig

=back

=cut

sub directive_value_is_not_dev_null {
  !is_dev_null($_[0]);
}

sub directive_value_is_not_dev_null_and_pipe {
  if (is_dev_null($_[0])) {
    return 0;
  }

  return $_[0] !~ /^\s*\|/;
}

sub directive_value_is_not_dev_null_and_pipe_and_syslog {
  if (is_dev_null($_[0])) {
    return 0;
  }

  return $_[0] !~ /^\s*(?:(?:\|)|(?:syslog(?::[a-zA-Z0-9]+)?))/;
}

%directive_value_takes_rel_path = (
  AccessConfig   => \&directive_value_is_not_dev_null,
  AuthGroupFile  => \&directive_value_is_not_dev_null,
  AuthUserFile   => \&directive_value_is_not_dev_null,
  CookieLog      => \&directive_value_is_not_dev_null,
  CustomLog      => \&directive_value_is_not_dev_null_and_pipe,
  ErrorLog       => \&directive_value_is_not_dev_null_and_pipe_and_syslog,
  Include        => \&directive_value_is_not_dev_null,
  LoadFile       => \&directive_value_is_not_dev_null,
  LoadModule     => \&directive_value_is_not_dev_null,
  LockFile       => \&directive_value_is_not_dev_null,
  MimeMagicFile  => \&directive_value_is_not_dev_null,
  PidFile        => \&directive_value_is_not_dev_null,
  RefererLog     => \&directive_value_is_not_dev_null_and_pipe,
  ResourceConfig => \&directive_value_is_not_dev_null,
  ScoreBoardFile => \&directive_value_is_not_dev_null,
  ScriptLog      => \&directive_value_is_not_dev_null,
  TransferLog    => \&directive_value_is_not_dev_null_and_pipe,
  TypesConfig    => \&directive_value_is_not_dev_null);

# Make all of the %directive_value_takes_rel_path key names lowercase
# and copy the same key/value pairs to %directive_value_takes_path.
foreach my $key (keys %directive_value_takes_rel_path) {
  my $value                             =
    delete $directive_value_takes_rel_path{$key};
  $key                                  = lc($key);
  $directive_value_takes_rel_path{$key} = $value;
  $directive_value_takes_path{$key}     = $value;
}

# Add these key/value pairs to %directive_value_takes_path;
my %add_directive_value_takes_path = (
  AgentLog          => \&directive_value_is_not_dev_null_and_pipe,
  AuthDBGroupFile   => \&directive_value_is_not_dev_null,
  AuthDBMGroupFile  => \&directive_value_is_not_dev_null,
  AuthDBMUserFile   => \&directive_value_is_not_dev_null,
  AuthDBUserFile    => \&directive_value_is_not_dev_null,
  AuthDigestFile    => \&directive_value_is_not_dev_null,
  CacheRoot         => \&directive_value_is_not_dev_null,
  CoreDumpDirectory => \&directive_value_is_not_dev_null,
  Directory         => \&directive_value_is_not_dev_null,
  DocumentRoot      => \&directive_value_is_not_dev_null,
  MMapFile          => \&directive_value_is_not_dev_null,
  RewriteLock       => \&directive_value_is_not_dev_null,
  ServerRoot        => \&directive_value_is_not_dev_null);

# Make all of the %directive_value_takes_path key names lowercase.
foreach my $key (keys %add_directive_value_takes_path) {
  my $value                         = $add_directive_value_takes_path{$key};
  $key                              = lc($key);
  $directive_value_takes_path{$key} = $value;
}

=head1 SEE ALSO

L<Apache::ConfigParser::Directive> and L<Tree::DAG_Node>.

=head1 AUTHOR

Blair Zajac <blair@orcaware.com>.

=head1 COPYRIGHT

Copyright (C) 2001 Blair Zajac.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut

1;
