#!/usr/bin/env perl

use strict;
use warnings;

use File::Temp qw(tempfile);
use Test::More;

BEGIN {
  package Test::BDD::Cucumber::Harness::TestBuilder;

  sub scenario { return 'parent scenario' }
  sub scenario_done { return 'parent scenario done' }
  sub step { return 'parent step' }
  sub step_done { return }

  $INC{'Test/BDD/Cucumber/Harness/TestBuilder.pm'} = __FILE__;
}

require './t/lib/Net/LDAPapi/Test/CucumberHarness.pm';

my ($feature_handle, $feature_file) = tempfile();
print {$feature_handle} <<'GHERKIN';
Feature: Failure attribution

  Background:
    Given shared setup

  Scenario: First scenario
    When the first action runs
    Then the first result is returned

  Scenario: Second scenario
    When the second action runs
    Then the second result is returned
GHERKIN
close $feature_handle;

is(
  locate_failure(<<'LOG'),
    # NET_LDAPAPI_CUCUMBER_STEP_START	1	First scenario	Given shared setup
LOG
  "First scenario\tGiven shared setup\n",
  'attributes a crash in the first step from its active marker',
);

is(
  locate_failure(<<'LOG'),
    # NET_LDAPAPI_CUCUMBER_STEP_START	1	First scenario	Given shared setup
    # NET_LDAPAPI_CUCUMBER_STEP_END	1
    ok 1 - Given shared setup
LOG
  '',
  'does not guess a step after the last completed marker',
);

is(
  locate_failure(<<'LOG'),
    # NET_LDAPAPI_CUCUMBER_STEP_START	1	First scenario	Given shared setup
    not ok 1 - Given shared setup
    # NET_LDAPAPI_CUCUMBER_STEP_END	1
LOG
  "First scenario\tGiven shared setup\n",
  'attributes a reported TAP failure after the marker is closed',
);

is(
  locate_failure(<<'LOG'),
    # NET_LDAPAPI_CUCUMBER_STEP_START	1	First scenario	Given shared setup
    # NET_LDAPAPI_CUCUMBER_STEP_END	1
    ok 1 - Given shared setup
    # NET_LDAPAPI_CUCUMBER_STEP_START	2	First scenario	When the first action runs
LOG
  "First scenario\tWhen the first action runs\n",
  'attributes a crash to the most recently started unfinished step',
);

is(
  locate_failure(<<'LOG'),
    # NET_LDAPAPI_CUCUMBER_STEP_START	1	First%25scenario	When a%09tab runs
LOG
  "First%scenario\tWhen a\ttab runs\n",
  'decodes escaped marker fields',
);

is(
  locate_failure("Cannot load Net/LDAPapi.pm at t/01-bdd-cucumber.t line 22.\n"),
  '',
  'leaves feature setup failures unattributed to a Gherkin step',
);

my ($marker_handle, $marker_file) = tempfile();
{
  local *STDERR;
  open STDERR, '>&', $marker_handle or die "Cannot redirect STDERR: $!";

  my $harness = bless {}, 'Net::LDAPapi::Test::CucumberHarness';
  my $scenario = bless {
    name => 'Scenario 100%',
  }, 'Net::LDAPapi::Test::FakeScenario';
  my $context = bless {
    scenario => undef,
    step => bless({ verb_original => 'Given' },
      'Net::LDAPapi::Test::FakeStep'),
    text => "a\tvalue",
  }, 'Net::LDAPapi::Test::FakeContext';

  is($harness->scenario($scenario), 'parent scenario',
    'delegates scenario setup to the Test::BDD::Cucumber harness');
  is($harness->step($context), 'parent step',
    'delegates step execution after emitting its start marker');
  $harness->step_done($context);
  is($harness->scenario_done($scenario), 'parent scenario done',
    'delegates scenario completion to the Test::BDD::Cucumber harness');
}
seek $marker_handle, 0, 0 or die "Cannot rewind marker log: $!";
my $marker_log = do { local $/; <$marker_handle> };
is(
  $marker_log,
  "    # NET_LDAPAPI_CUCUMBER_STEP_START\t1\tScenario 100%25\tGiven a%09value\n" .
    "    # NET_LDAPAPI_CUCUMBER_STEP_END\t1\n",
  'writes an escaped start marker and a matching completion marker',
);

done_testing();

sub locate_failure {
  my ($log) = @_;
  my ($log_handle, $log_file) = tempfile();
  print {$log_handle} $log;
  close $log_handle;

  open my $locator, '-|', $^X,
    't/ci/locate-cucumber-failure.pl', $feature_file, $log_file
    or die "Cannot run Cucumber failure locator: $!";
  local $/;
  my $output = <$locator>;
  close $locator
    or die "Cucumber failure locator failed with status $?";

  return defined $output ? $output : '';
}

package Net::LDAPapi::Test::FakeScenario;

sub name { return $_[0]->{'name'} }

package Net::LDAPapi::Test::FakeStep;

sub verb_original { return $_[0]->{'verb_original'} }

package Net::LDAPapi::Test::FakeContext;

sub scenario { return $_[0]->{'scenario'} }
sub step { return $_[0]->{'step'} }
sub text { return $_[0]->{'text'} }
