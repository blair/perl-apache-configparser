# Apache::ConfigParser::Directive: A single Apache directive or start context.
#
# Copyright (C) 2001 Blair Zajac.  All rights reserved.

package Apache::ConfigParser::Directive;
require 5.004_05;
use strict;

=head1 NAME

  Apache::ConfigParser::Directive - An Apache directive or start context

=head1 SYNOPSIS

  use Apache::ConfigParser::Directive;

  # Create a new emtpy directive.
  my $d = Apache::ConfigParser::Directive->new;

  # Make it a ServerRoot directive.
  # ServerRoot /etc/httpd
  $d->name('ServerRoot');
  $d->value('/etc/httpd');

  # A more complicated directive.  Value automatically splits the
  # argument into separate elements.  It treats elements in "'s as a
  # single ement.
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

use Exporter;
use Carp;
use Tree::DAG_Node 1.04;

use vars qw(@ISA $VERSION);
@ISA     = qw(Tree::DAG_Node Exporter);
$VERSION = sprintf '%d.%02d', '$Revision: 0.01 $' =~ /(\d+)\.(\d+)/;

# This constant is used throughout the module.
my $INCORRECT_NUMBER_OF_ARGS = "passed incorrect number of arguments.\n";

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
a the `original' value.

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

=item $d->filename

=item $d->filename($filename)

In the first form get the filename where this pariticular directive or
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

1;

=back

=head1 SEE ALSO

L<Apache::ConfigParser::Directive> and L<Tree::DAG_Node>.

=head1 AUTHOR

Blair Zajac <blair@orcaware.com>.

=head1 COPYRIGHT

Copyright (C) 2001 Blair Zajac.  All rights reserved.  This program is
free software; you can redistribute it and/or modify it under the same
terms as Perl itself.
