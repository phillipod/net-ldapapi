#!/usr/bin/perl

use strict;
use warnings;

use Net::LDAPapi;
use Test::More;
use Test::BDD::Cucumber::StepFile;

our %TestConfig = %main::TestConfig;

sub _test_container_dn {
  return sprintf('%s,%s',
    $TestConfig{'data'}{'test_container_dn'},
    $TestConfig{'ldap'}{'base_dn'});
}

sub _remove_test_container {
  my ($object) = @_;
  my @delete_dns;

  my $search_status = $object->search_s(
    -basedn => _test_container_dn(),
    -scope => LDAP_SCOPE_SUBTREE,
    -filter => '(objectClass=*)',
    -attrs => ['objectClass'],
  );

  return 1 if $search_status == LDAP_NO_SUCH_OBJECT;
  return 0 if $search_status != LDAP_SUCCESS;

  while (my $entry = $object->result_entry) {
    push @delete_dns, $object->get_dn($entry);
  }

  for my $dn (sort { length($b) <=> length($a) } @delete_dns) {
    my $delete_status = $object->delete_s(-dn => $dn);
    return 0 if $delete_status != LDAP_SUCCESS
      && $delete_status != LDAP_NO_SUCH_OBJECT;
  }

  return 1;
}

sub _wait_for_async_result {
  my ($object, $message_id, $wait_for_all) = @_;
  my $timeout = $TestConfig{'async_result_timeout'} || 30;
  my $deadline = time() + $timeout;

  while (time() <= $deadline) {
    my $result = $object->result($message_id, $wait_for_all, 1);
    return $result if defined $result;
    return undef if defined $object->{'status'} && $object->{'status'} == -1;
  }

  return undef;
}

Given qr/a usable (\S+) class/, sub {  use_ok($1); };
Given qr/a Net::LDAPapi object that has been connected to the (.+?)?\s?LDAP server/, sub {
  my $type = $1;
 
  if (!defined($type)) {
    $type = $TestConfig{'ldap'}{'default_server'};
  }
  
  my $object = Net::LDAPapi->new(%{$TestConfig{'ldap'}{'server'}{$type}});

  ok( $object, 'Net::LDAPapi object created');
  
  S->{'object'} = $object;
};

When qr/a test container has been created/, sub { 
  my %args = ();

  my $reset_ok = _remove_test_container(S->{'object'});
  ok($reset_ok, 'Was resetting any stale test container successful?');
  return if !$reset_ok;
  
  $args{'-dn'} = _test_container_dn();
  $args{'-mod'} = $TestConfig{'data'}{'test_container_attributes'};
 
  my $status = S->{'object'}->add_s(%args);
  
  is(ldap_err2string($status), ldap_err2string(LDAP_SUCCESS), 'Was adding the test container successful?');
};

Then qr/the test container has been deleted/, sub {
  ok(_remove_test_container(S->{'object'}),
    'Was deleting the test container and its contents successful?');
};

Then qr/(after waiting for all results, )?the (.+) result message type is (.+)/, sub {
  my $wait_for_all = $1 ? 1 : 0;
  my $test_function = $2;
  my $desired_result = $3;

  SKIP: {
            
    skip(C->{'scenario'}->{'name'} . " skipped", 1) if S->{$test_function . '_result'} eq "skipped";

    isnt( S->{$test_function . '_result'}, undef, "Do we have result from $test_function?");
  
    if (is( S->{$test_function . '_async'}, 1, "Was $test_function asynchronous?")) {
      S->{$test_function . '_result_id'} = _wait_for_async_result(
        S->{'object'},
        S->{$test_function . '_result'},
        $wait_for_all,
      );

      return if !isnt(
        S->{$test_function . '_result_id'},
        undef,
        "Did $test_function complete before the async result timeout?",
      );

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
