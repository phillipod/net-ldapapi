#!/usr/bin/perl

use strict;
use warnings;
  
use Test::More;
use Test::BDD::Cucumber::StepFile;

our %TestConfig = %main::TestConfig;

When qr/I've (asynchronously )?bound with (.+?) authentication to the directory/, sub {
  my $async = $1 ? 1 : 0;
  my $type = lc($2);
  
  S->{'bind_async'} = $async;
  S->{'bind_result'} = "skipped";

  if ($type eq "default") {
    $type = lc($TestConfig{'ldap'}{'default_bind_type'});
  }

  S->{'bind_type'} = $type;
  
  if ($type eq "anonymous") {
  
    SKIP: {
      skip("anonymous authentication disabled in t/test-config.pl", 1) if $TestConfig{'ldap'}{'bind_types'}{'anonymous'}{'enabled'} != 1;

      if ($async) {
        S->{'bind_result'} = S->{'object'}->bind();
      } else {
        S->{'bind_result'} = S->{'object'}->bind_s();
      }
    }

  } elsif ($type eq "simple") {

    SKIP: {
      skip("simple authentication disabled in t/test-config.pl", 1) if $TestConfig{'ldap'}{'bind_types'}{'simple'}{'enabled'} != 1;

      if ($async) {
        S->{'bind_result'} = S->{'object'}->bind(
          -dn => $TestConfig{'ldap'}{'bind_types'}{'simple'}{'bind_dn'},
          -password => $TestConfig{'ldap'}{'bind_types'}{'simple'}{'bind_pw'});
      } else {      
        S->{'bind_result'} = S->{'object'}->bind_s(
          -dn => $TestConfig{'ldap'}{'bind_types'}{'simple'}{'bind_dn'},
          -password => $TestConfig{'ldap'}{'bind_types'}{'simple'}{'bind_pw'});
      }
    }
    
  }
};

1;
