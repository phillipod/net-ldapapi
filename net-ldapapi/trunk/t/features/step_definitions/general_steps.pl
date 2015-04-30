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

Then qr/(after waiting for all results, )?the (.+) result message type is (.+)/, sub {
  my $wait_for_all = $1 ? 1 : 0;
  my $test_function = $2;
  my $desired_result = $3;

  SKIP: {
            
    skip(C->{'scenario'}->{'name'} . " skipped", 1) if S->{$test_function . '_result'} eq "skipped";

    isnt( S->{$test_function . '_result'}, undef, "Do we have result from $test_function?");
  
    if (is( S->{$test_function . '_async'}, 1, "Was $test_function asynchronous?")) {
      S->{$test_function . '_result_id'} = S->{'object'}->result(S->{$test_function . '_result'}, $wait_for_all, 1);

      is(S->{'object'}->msgtype2str(S->{'object'}->{"status"}), $desired_result, "Does expected result message type match?");  
    }
  }
};

Then qr/the (.+) result is (.+)/, sub {
  my $test_function = $1;
  my $desired_result = $2;
  
  SKIP: {
            
    skip(C->{'scenario'}->{'name'} . " skipped", 1) if S->{$test_function . '_result'} eq "skipped";

    if (isnt( S->{$test_function . '_result'}, undef, "Do we have result from $test_function?")) {

      if (S->{$test_function . '_async'}) {
        my $ref = {S->{'object'}->parse_result(S->{$test_function . '_result_id'})};

        is(ldap_err2string($ref->{'errcode'}), ldap_err2string(S->{'object'}->$desired_result), "Does expected async result code match?");        
      } else {
        is(ldap_err2string(S->{$test_function . '_result'}), ldap_err2string(S->{'object'}->$desired_result), "Does expected result code match?");        
      }
    }            
  }
};

1;
