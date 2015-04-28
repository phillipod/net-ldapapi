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

Then qr/the (.+) result message type is (.+)/, sub {
  my $test_function = $1;
  my $desired_result = $2;

  if (S->{$test_function . '_result'} eq "skipped") {
    ok(1, C->{'scenario'}->{'name'} . " skipped");
  } else {
    if (defined(S->{$test_function . '_result'})) {

      if (S->{$test_function . '_async'}) {
        S->{$test_function . '_result_id'} = S->{'object'}->result(S->{$test_function . '_result'}, 0, 1);

        cmp_ok(S->{'object'}->msgtype2str(S->{'object'}->{"status"}), "eq", $desired_result, C->{'scenario'}->{'name'});
      } else {
        ok(0, C->{'scenario'}->{'name'});
      }

    } else {
      ok(0, C->{'scenario'}->{'name'});
    }
  }  
};

Then qr/the (.+) result is (.+)/, sub {
  my $test_function = $1;
  my $desired_result = $2;
    
  if (S->{$test_function . '_result'} eq "skipped") {
    ok(1, C->{'scenario'}->{'name'} . " skipped");
  } else {
    if (defined(S->{$test_function . '_result'})) {

      if (S->{$test_function . '_async'}) {
        my $ref = {S->{'object'}->parse_result(S->{$test_function . '_result_id'})};
        
        cmp_ok(ldap_err2string($ref->{'errcode'}), 'eq', ldap_err2string(S->{'object'}->$desired_result), C->{'scenario'}->{'name'});        
      } else {
        cmp_ok(ldap_err2string(S->{$test_function . '_result'}), 'eq', ldap_err2string(S->{'object'}->$desired_result), C->{'scenario'}->{'name'});
      }

    } else {
      ok(0, C->{'scenario'}->{'name'});
    }
  }
};

1;
