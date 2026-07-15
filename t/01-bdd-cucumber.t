#!/usr/bin/perl
 
BEGIN {
  require './t/test-config.pl';
  if (!$RunDeveloperTests) {
    print "1..0 # Skipped: Developer tests are not enabled";
  
    exit;
  }   
};


use strict;
use warnings;
use Devel::Cover;
use File::Find;
use Test::More;

# This will find step definitions and feature files in the directory you point
# it at below
use Test::BDD::Cucumber::Loader;
 
# This harness prints out nice TAP
use Test::BDD::Cucumber::Harness::TestBuilder;
 
my @feature_files = @ARGV ? @ARGV : feature_files('t/features/');

for my $feature_file (@feature_files) {
  subtest $feature_file => sub {
    my $ok = eval {
      # Load a feature file with the step definitions in its directory.
      # The features are returned in @features, and the executor is created
      # with the step definitions loaded.
      my ( $executor, @features ) =
        Test::BDD::Cucumber::Loader->load($feature_file);

      # Create a Harness to execute against. TestBuilder harness prints TAP
      my $harness = Test::BDD::Cucumber::Harness::TestBuilder->new({});

      # For each feature found, execute it, using the Harness to print results
      $executor->execute( $_, $harness ) for @features;
      1;
    };

    if (!$ok) {
      fail("Cucumber feature completed without an exception");
      diag($@ || "Unknown exception while running $feature_file");
    }
  };
}

done_testing();

sub feature_files {
  my ($root) = @_;
  my @files;

  find(
    {
      no_chdir => 1,
      wanted   => sub {
        return unless -f $_;
        return unless /\.feature\z/;
        push @files, $_;
      },
    },
    $root,
  );

  return sort @files;
}
