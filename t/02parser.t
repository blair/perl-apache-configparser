#!/usr/bin/perl -w

$| = 1;

use strict;
use Test::More tests => 97;

BEGIN { use_ok('Apache::ConfigParser'); }

# Cd into t if it exists.
chdir 't' if -d 't';

package EmptySubclass;
use Apache::ConfigParser;
use vars qw(@ISA);
@ISA = qw(Apache::ConfigParser);
package main;

# Find all of the httpd\d+.conf files.
my @conf_files = glob('httpd[0-9][0-9].conf');
is(@conf_files, 7, 'seven httpd\d+.conf files found');

# A parser should be created when no arguments are passed in.
{
  my $c = EmptySubclass->new;
  ok($c, 'Apache::ConfigParser created for no configuration file');
  isa_ok($c, 'EmptySubclass');
}

# A parser passed an non-existant file should not be created.
{
  my $c = EmptySubclass->new('non-existant file');
  ok(!defined $c, 'Apache::ConfigParser for non-existant file is not created');
}

# This subroutine just modifies the passed string to make sure that
# this string does not show up in particular output.
sub post_transform_munge {
  is(@_, 3, 'post_transform_munge passed 3 arguments');
  my ($parser, $directive, $filename) = @_;
  "MUNGE $filename";
}

# This is the subroutine that will modify any Include filenames.  Trim
# off any directory names in the filename.
sub post_transform_path {
  is(@_, 3, 'post_transform_path passed 3 arguments');
  my ($parser, $directive, $filename) = @_;
  my @elements = split(m#/#, $filename);
  $elements[-1];
}

# This is the option to pass to the constructor to transform the
# Go through each httpd\d+.conf file and parse it.  Compare the result
# with the precomputed answer.
for (my $i=0; $i<@conf_files; ++$i) {
  my $conf_file = $conf_files[$i];

  # Only test the include transformation on httpd05.conf.
  my $c;
  my $opts_ref;
  if ($conf_file eq 'httpd05.conf') {
    $opts_ref = {post_transform_path_sub => \&post_transform_path};
  } elsif ($conf_file eq 'httpd07.conf') {
    $opts_ref = {post_transform_path_sub => \&post_transform_munge};
  }
  if ($opts_ref) {
    $c = EmptySubclass->new($opts_ref, $conf_file);
  } else {
    $c = EmptySubclass->new($conf_file);
  }
  ok($c, "loaded `$conf_file'");
  isa_ok($c, 'EmptySubclass');

  # Check the number of LoadModule's in each configuration file.  This
  # array is indexed by the number of configuration file.
  my @load_modules = (0, 37, 0, 37, 18, 0, 1);
  is($c->find_at_and_down_option_names('LoadModule'),
     $load_modules[$i],
     "found $load_modules[$i] LoadModule's in the whole file");

  # Check that the search for siblings of a particular node works.
  # Since some LoadModule's are inside <IfDefine> contexts, then this
  # will not find all of the LoadModules.
  @load_modules = (0, 26, 0, 26, 18, 0, 1);
  is($c->find_in_siblings_option_names('LoadModule'),
     $load_modules[$i],
     "found $load_modules[$i] LoadModule's at the top level");

  # This does a similar search but providing the start node.
  is($c->find_in_siblings_option_names(($c->root->daughters)[-1],
                                       'LoadModule'),
     $load_modules[$i],
     "found $load_modules[$i] LoadModule's one level down");

  # Data::Dumper does not sort the hash keys so different versions of
  # Perl generate the same object but different Data::Dumper::Dumper
  # outputs.  To work around this, recursively descend into the object
  # and print the output ourselves.
  my @result = $c->dump($c);

  # Read the answer file.
  my $answer_file =  $conf_file;
  $answer_file    =~ s/\.conf$/\.answer/;

# if (open(ZANSWER, ">$answer_file.tmp")) {
#   print ZANSWER join("\n", @result), "\n";
#   close(ZANSWER);
# }

  my $open_file = open(ANSWER, $answer_file);
  ok($open_file, "opened `$answer_file' for reading");
 SKIP: {
    skip "Cannot open $answer_file: $!", 1 unless $open_file;
    my @answer = <ANSWER>;
    @answer    = map { $_ =~ s/\r?\n$//; $_ } @answer;
    close(ANSWER);

    ok(eq_array(\@answer, \@result), "internal structure is ok");
  }
}
