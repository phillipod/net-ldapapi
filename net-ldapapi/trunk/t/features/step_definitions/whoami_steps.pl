#!/usr/bin/perl

use strict;
use warnings;
  
use Test::More;
use Test::BDD::Cucumber::StepFile;

our %TestConfig = %main::TestConfig;

When qr/I\'ve queried the directory for my identity/, sub {
  S->{'identity_result'} = "skipped";
  S->{'identity_authzid'} = "-1";
  
  SKIP: {
    skip(S->{'bind_type'} . " authentication disabled in t/test-config.pl", 1) if S->{"bind_result"} eq "skipped";
    
    S->{'identity_result'} = S->{'object'}->whoami_s(\S->{'identity_authzid'});
  }

};

Then qr/the identity matches/, sub {
  if (S->{'bind_result'} eq "skipped") {
    ok(1, C->{'scenario'}->{'name'} . " skipped");
  } else {

    if (S->{'bind_type'} eq "anonymous") {
      cmp_ok("", "eq", "", C->{'scenario'}->{'name'});
    } elsif (S->{'bind_type'} eq "simple") {
      my ($attr, $value) = split(/:/, S->{'identity_authzid'});
    
      cmp_ok(lc($value), "eq", lc($TestConfig{'ldap'}{'bind_types'}{'simple'}{'bind_dn'}), C->{'scenario'}->{'name'});
    }

  }
};

1;
