#!/usr/bin/perl -w

$| = 1;

use strict;
use Test::More tests => 41;

BEGIN { use_ok('Apache::ConfigParser::Directive'); }

# Cd into t if it exists.
chdir 't' if -d 't';

package EmptySubclass;
use Apache::ConfigParser::Directive;
use vars qw(@ISA);
@ISA = qw(Apache::ConfigParser);
package main;

my $d = Apache::ConfigParser::Directive->new;
ok($d, 'Apache::ConfigParser::Directive created');

# Check the initial values of the object.
is($d->name,        '', 'initial name is empty');
is($d->value,       '', 'initial value is empty');
is($d->orig_value,  '', 'initial `original\' value is empty');

my @value = $d->get_value_array;
ok(eq_array(\@value, []), 'initial value array is empty');

@value = $d->get_orig_value_array;
ok(eq_array(\@value, []), 'initial `original\' value array is empty');

is($d->filename,    '', 'initial filename is empty');
is($d->line_number, -1, 'initial line number is -1');

is($d->filename('file.txt'), '',         'filename is empty and set it');
is($d->filename,             'file.txt', 'filename is now file.txt');

is($d->line_number(123),  -1, 'line number is -1 and set it to 123');
is($d->line_number,      123, 'line number is now 123');

# Test setting and getting parameters.
is($d->name('SomeDirective'), '',              'name is empty and set it');
is($d->name,                  'somedirective', 'name is no somedirective');

is($d->value('SomeValue1 Value2'), '', 'initial value is empty and set it');
is($d->value, 'SomeValue1 Value2', 'value is now SomeValue1 Value2');

@value = $d->get_value_array;
ok(eq_array(\@value, [qw(SomeValue1 Value2)]), 'value array has two elements');
ok(eq_array(\@value, $d->value_array_ref),     'value array ref matches');

# Check that the `original' value has not changed.
is($d->orig_value, '', '`original\' value has not changed');
@value = $d->get_orig_value_array;
ok(eq_array(\@value, []), '`original\' value array has not changed');
ok(eq_array([], $d->orig_value_array_ref),
   '`original\' value array ref has not changed');

# Try a more complicates value string.
my $str1 = '"%h \"%r\" %>s \"%{Referer}i\" \"%{User-Agent}i\"" \foo  bar';
is($d->value($str1), 'SomeValue1 Value2', 'setting a new complicated value');
is($d->value,
   '"%h \"%r\" %>s \"%{Referer}i\" \"%{User-Agent}i\"" \foo  bar',
   'complicated string value matched');
@value = $d->get_value_array;
ok(eq_array(\@value,
            ['%h "%r" %>s "%{Referer}i" "%{User-Agent}i"', '\foo', 'bar']),
   'complicated value array matches');
ok(eq_array($d->value_array_ref,
            ['%h "%r" %>s "%{Referer}i" "%{User-Agent}i"', '\foo', 'bar']),
   'complicated value array ref matches');

# Set the value using the array interface.
$d->set_orig_value_array;
is($d->orig_value, '', 'set empty array results in empty string value');
@value = $d->get_orig_value_array;
ok(eq_array(\@value, []), 'set empty array results in empty array value');
ok(eq_array([], $d->orig_value_array_ref),
   'set empty array results in empty array value ref');

@value = ('this', 'value', 'has whitespace and quotes in it ""\ \ ');
$d->set_orig_value_array(@value);
my @v = $d->get_orig_value_array;
ok(eq_array(\@v, \@value), 'complicated set value array matches array');
ok(eq_array(\@v, $d->orig_value_array_ref),
   'complicates set value array matches array ref');
is($d->orig_value,
   'this value "has whitespace and quotes in it \"\"\\\\ \\\\ "',
   'complicated set value array string matches');

# Test setting and getting undefined values.
is($d->value(undef),    $str1, 'value matches and set to undef');
is($d->value_array_ref, undef, 'value array ref is undef');
is($d->value(''),       undef, 'value is now undef');
ok(eq_array([], $d->value_array_ref), 'value array ref to empty array');
ok(eq_array([], $d->value_array_ref(undef)), 'value array ref to empty array');
is($d->value,           undef, 'value is not undef again');
is($d->value_array_ref, undef, 'value array ref is again undef');
is(scalar $d->get_value_array, undef, 'getting value array returns undef');
@value = $d->get_value_array;
ok(eq_array(\@value, []), 'value array is empty');
