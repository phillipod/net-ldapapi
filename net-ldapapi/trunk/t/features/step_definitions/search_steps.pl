#!/usr/bin/perl

use strict;
use warnings;
  
use Test::More;
use Test::BDD::Cucumber::StepFile;

our %TestConfig = %main::TestConfig;

When qr/I've (asynchronously )?searched for records with scope (.+)/, sub {
  my $async = $1 ? 1 : 0;
  my $scope = $2;

  my $func = "search_s";
  if ($async) {
    $func = "search";
  }
  
  S->{'search_async'} = $async;
  
  S->{'search_result'} = S->{'object'}->$func(
    -basedn => $TestConfig{'ldap'}{'base_dn'},
    -scope => S->{'object'}->$scope,
    -filter => $TestConfig{'search'}{'filter'},
    -attrs => \@{['cn']},
    -attrsonly => 0);
};

Then qr/the search count matches/, sub {
  is(S->{'object'}->count_entries, $TestConfig{'search'}{'count'}, "Does the search count match?");
};

1;
