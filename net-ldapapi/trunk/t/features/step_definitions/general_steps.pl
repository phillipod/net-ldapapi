#!/usr/bin/perl

use strict;
use warnings;
  
use Test::More;
use Test::BDD::Cucumber::StepFile;

our %TestConfig = %main::TestConfig;

Given qr/a usable (\S+) class/, sub {  use_ok($1); };
Given qr/a Net::LDAPapi object that has been connected to the LDAP server/, sub {
  my $object = Net::LDAPapi->new($TestConfig{'ldap'}{'server'}, $TestConfig{'ldap'}{'port'});
  ok( $object, "Net::LDAPapi object created");
  
  S->{'object'} = $object;
};

Then qr/the (.+) result is (.+)/, sub {
  my $result_type = $1;
  my $desired_result = $2;
    
  if (S->{$result_type . '_result'} eq "skipped") {
    ok(1, C->{'scenario'}->{'name'} . " skipped");
  } else {
    if (defined(S->{$result_type . '_result'})) {
      cmp_ok(ldap_err2string(S->{$result_type . '_result'}), 'eq', ldap_err2string(S->{'object'}->$desired_result), C->{'scenario'}->{'name'}); # || diag "error: " .  ldap_err2string(S->{'bind_result'});
    } else {
      ok(0, C->{'scenario'}->{'name'});
    }
  }
};

1;
