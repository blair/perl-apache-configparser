# This -*- perl -*- script writes the Makefile for this package.

use strict;
require 5.004_05;
use ExtUtils::MakeMaker;

$| = 1;
my $missing_modules = 0;

print "Checking for Tree::DAG_Node...";
eval {
  require Tree::DAG_Node;
  Tree::DAG_Node->VERSION(1.04);
};
if ($@) {
  print " failed\n";
  ++$missing_modules;
  print <<EOT;
$@
The Tree::DAG_Node must be installed to set up a tree structure for
the Apache configuration files.

EOT
} else {
  print " ok\n";
}

print "Checking for Test::More...";
eval {
  require Test::More;
  Tree::DAG_Node->VERSION(0.19);
};
if ($@) {
  print " failed\n";
  ++$missing_modules;
  print <<EOT;
$@
Test::More is used to test the package.

EOT
} else {
  print " ok\n";
}

print <<EOT if $missing_modules;
The missing module can be obtained from CPAN.  Visit
  <URL:http://www.perl.com/CPAN/> to find a CPAN site near you.

EOT

WriteMakefile(
  'NAME'	 => 'Apache::ConfigParser',
  'VERSION_FROM' => 'lib/Apache/ConfigParser.pm', # finds $VERSION
  'dist'         => {
    'COMPRESS'   => 'gzip -9',
    'SUFFIX'     => 'gz'
  },
);	
