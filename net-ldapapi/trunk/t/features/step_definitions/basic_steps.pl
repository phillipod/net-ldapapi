#!/usr/bin/perl

use strict;
use warnings;
  
use Test::More;
use Test::BDD::Cucumber::StepFile;

our %TestConfig = %main::TestConfig;

Given qr/a usable (\S+) class/, sub {  use_ok($1); };
Given qr/a Net::LDAPapi object that has been connected to the LDAP server/, sub {
  my $object = Net::LDAPapi->new($TestConfig{'LDAP'}{'Server'}, $TestConfig{'LDAP'}{'Port'});
  ok( $object, "Net::LDAPapi object created");
  
  S->{'object'} = $object;
};

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

When qr/I've searched for records with scope (.+)/, sub {
  my $scope = $1;
  
  S->{'search_result'} = S->{'object'}->search_s(
    -basedn => $TestConfig{'LDAP'}{'BaseDN'},
    -scope => S->{'object'}->$scope,
    -filter => $TestConfig{'Search'}{'Filter'},
    -attrs => \[],
    -attrsonly => 0);
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

Then qr/the search count matches/, sub {
  cmp_ok(S->{'object'}->count_entries, "==", $TestConfig{'Search'}{'Count'}, C->{'scenario'}->{'name'});
};
