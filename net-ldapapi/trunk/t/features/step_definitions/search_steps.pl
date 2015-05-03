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

Then qr/for each entry returned the dn and the first attribute are valid/, sub {
  for (my $ent = S->{'object'}->first_entry; $ent; $ent = S->{'object'}->next_entry) {
    isnt(S->{'object'}->get_dn(), "", "Is the dn for the entry not empty?");
    
    if (isnt(my $attr = S->{'object'}->first_attribute(), "", "Is the first attribute retrievable?")) {
      my @vals = S->{'object'}->get_values($attr);

      ok(($#vals >= 0), "Are values returned?");
    }
  }
};

1;
