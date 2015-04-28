#!/usr/bin/perl

use strict;
use warnings;
  
use Test::More;
use Test::BDD::Cucumber::StepFile;

our %TestConfig = %main::TestConfig;

When qr/I've bound with (.+?) authentication to the directory/, sub {
  my $type = $1;
  
  S->{'bind_result'} = "skipped";

  if ($type eq "default") {
    $type = lc($TestConfig{'LDAP'}{'DefaultBindType'});
  }
  
  if ($type =~ /anonymous/i) {
  
    SKIP: {
      skip("anonymous authentication disabled in t/test-config.pl", 1) if $TestConfig{'LDAP'}{'BindTypes'}{'Anonymous'}{'Enabled'} != 1;

      S->{'bind_result'} = S->{'object'}->bind_s();
    }

  } elsif ($type =~ /simple/i) {

    SKIP: {
      skip("simple authentication disabled in t/test-config.pl", 1) if $TestConfig{'LDAP'}{'BindTypes'}{'Simple'}{'Enabled'} != 1;
      
      S->{'bind_result'} = S->{'object'}->bind_s(
        -dn => $TestConfig{'LDAP'}{'BindTypes'}{'Simple'}{'BindDN'},
        -password => $TestConfig{'LDAP'}{'BindTypes'}{'Simple'}{'BindPW'});
    }
    
  }
};

1;
