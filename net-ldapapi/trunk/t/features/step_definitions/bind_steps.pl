#!/usr/bin/perl

use strict;
use warnings;
  
use Test::More;
use Test::BDD::Cucumber::StepFile;

our %TestConfig = %main::TestConfig;

When qr/I've (asynchronously )?bound with (.+?) authentication to the directory/, sub {
  my $async = $1 ? 1 : 0;
  my $type = lc($2);

  my $func = "bind_s";
  my %args = ();
  
  if ($async) {
    $func = "bind";
  }
  S->{'bind_async'} = $async;
      
  if ($type eq "default") {
    $type = lc($TestConfig{'ldap'}{'default_bind_type'});
  }
  S->{'bind_type'} = $type;

  S->{'bind_result'} = "skipped";
  
  SKIP: {

    if ($type eq "anonymous") {
      skip("anonymous authentication disabled in t/test-config.pl", 1) if $TestConfig{'ldap'}{'bind_types'}{'anonymous'}{'enabled'} != 1;
    } elsif ($type eq "simple") {
      skip("simple authentication disabled in t/test-config.pl", 1) if $TestConfig{'ldap'}{'bind_types'}{'simple'}{'enabled'} != 1;

      %args = (
          -dn => $TestConfig{'ldap'}{'bind_types'}{'simple'}{'bind_dn'},
          -password => $TestConfig{'ldap'}{'bind_types'}{'simple'}{'bind_pw'}
      );
    }
    
    S->{'bind_result'} = S->{'object'}->$func(%args);
     
  }
};

1;
