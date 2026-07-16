package Net::LDAPapi::Test::CucumberHarness;

use strict;
use warnings;

use Errno qw(EINTR);
use parent 'Test::BDD::Cucumber::Harness::TestBuilder';

sub _escape_marker_field {
  my ($value) = @_;
  $value = '' if !defined $value;
  $value =~ s/%/%25/g;
  $value =~ s/\t/%09/g;
  $value =~ s/\r/%0D/g;
  $value =~ s/\n/%0A/g;
  return $value;
}

sub _write_marker {
  my ($marker) = @_;
  my $offset = 0;

  while ($offset < length($marker)) {
    my $written = syswrite(STDERR, $marker, length($marker) - $offset, $offset);
    next if !defined $written && $! == EINTR;
    die "Could not write Cucumber execution marker: $!\n"
      if !defined $written || $written == 0;
    $offset += $written;
  }
}

sub _step_description {
  my ($context) = @_;
  my $step = $context->step;

  return ucfirst($context->verb) . ' Hook' if !defined $step;
  return ucfirst($step->verb_original) . ' ' . $context->text;
}

sub scenario {
  my ($self, $scenario, @args) = @_;
  $self->{'net_ldapapi_scenario_name'} = $scenario->name || '';
  return $self->SUPER::scenario($scenario, @args);
}

sub scenario_done {
  my ($self, @args) = @_;
  my $result = $self->SUPER::scenario_done(@args);
  delete $self->{'net_ldapapi_scenario_name'};
  return $result;
}

sub step {
  my ($self, $context) = @_;
  my $sequence = ++$self->{'net_ldapapi_step_sequence'};
  my $scenario = $context->scenario;
  my $scenario_name = defined $scenario && $scenario->name
    ? $scenario->name
    : ($self->{'net_ldapapi_scenario_name'} || '');

  $self->{'net_ldapapi_active_step'} = $sequence;
  _write_marker(sprintf(
    "    # NET_LDAPAPI_CUCUMBER_STEP_START\t%d\t%s\t%s\n",
    $sequence,
    _escape_marker_field($scenario_name),
    _escape_marker_field(_step_description($context)),
  ));

  return $self->SUPER::step($context);
}

sub step_done {
  my ($self, @args) = @_;
  my $sequence = $self->{'net_ldapapi_active_step'};

  $self->SUPER::step_done(@args);

  if (defined $sequence) {
    _write_marker(sprintf(
      "    # NET_LDAPAPI_CUCUMBER_STEP_END\t%d\n",
      $sequence,
    ));
    delete $self->{'net_ldapapi_active_step'};
  }
}

1;
