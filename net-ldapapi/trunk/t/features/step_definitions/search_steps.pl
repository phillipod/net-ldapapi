#!/usr/bin/perl

use strict;
use warnings;
  
use Test::More;
use Test::BDD::Cucumber::StepFile;

our %TestConfig = %main::TestConfig;

When qr/I've searched for records with scope (.+)/, sub {
  my $scope = $1;
  
  S->{'search_result'} = S->{'object'}->search_s(
    -basedn => $TestConfig{'LDAP'}{'BaseDN'},
    -scope => S->{'object'}->$scope,
    -filter => $TestConfig{'Search'}{'Filter'},
    -attrs => \[],
    -attrsonly => 0);
};

Then qr/the search count matches/, sub {
  cmp_ok(S->{'object'}->count_entries, "==", $TestConfig{'Search'}{'Count'}, C->{'scenario'}->{'name'});
};

1;
