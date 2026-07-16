#!/usr/bin/env perl

use strict;
use warnings;

my ($feature_file, $log_file) = @ARGV;
die "Usage: $0 FEATURE_FILE LOG_FILE\n"
  if !defined $feature_file || !defined $log_file;

open my $log, '<', $log_file or die "Cannot read $log_file: $!";
my $failed_step_index;
my ($active_step_id, $active_scenario, $active_step);

while (my $line = <$log>) {
  $line =~ s/\e\[[0-9;]*[[:alpha:]]//g;
  $line =~ s/\r?\n\z//;

  if ($line =~ /NET_LDAPAPI_CUCUMBER_STEP_START\t(\d+)\t([^\t]*)\t(.*)\z/) {
    ($active_step_id, $active_scenario, $active_step) = (
      $1,
      _decode_marker_field($2),
      _decode_marker_field($3),
    );
    next;
  }
  if ($line =~ /NET_LDAPAPI_CUCUMBER_STEP_END\t(\d+)\z/) {
    if (defined $active_step_id && $active_step_id == $1) {
      undef $active_step_id;
      undef $active_scenario;
      undef $active_step;
    }
    next;
  }

  if ($line =~ /^\s*(ok|not[ ]ok)\s+(\d+)\s+-\s+
      (Given|When|Then|And|But|\*)\s+/x) {
    if ($1 eq 'not ok' && !defined $failed_step_index) {
      $failed_step_index = $2;
    }
  }
}
close $log;

if (!defined $failed_step_index) {
  if (defined $active_step_id) {
    print "$active_scenario\t$active_step\n";
  }
  exit;
}

open my $feature, '<', $feature_file
  or die "Cannot read $feature_file: $!";
my @background;
my @scenarios;
my $section = '';
while (my $line = <$feature>) {
  if ($line =~ /^\s*Background:/) {
    $section = 'background';
    next;
  }
  if ($line =~ /^\s*Scenario(?: Outline)?:\s*(.*?)\s*$/) {
    push @scenarios, { name => $1, steps => [] };
    $section = 'scenario';
    next;
  }
  next unless $line =~ /^\s*(Given|When|Then|And|But|\*)\s+(.*?)\s*$/;
  my $step = "$1 $2";
  if ($section eq 'background') {
    push @background, $step;
  } elsif ($section eq 'scenario' && @scenarios) {
    push @{$scenarios[-1]{steps}}, $step;
  }
}
close $feature;

my @execution;
for my $scenario (@scenarios) {
  push @execution, map {
    { scenario => $scenario->{name}, step => $_ }
  } (@background, @{$scenario->{steps}});
}

my $location = $execution[$failed_step_index - 1];
if ($location) {
  print "$location->{scenario}\t$location->{step}\n";
}

sub _decode_marker_field {
  my ($value) = @_;
  $value =~ s/%0A/\n/g;
  $value =~ s/%0D/\r/g;
  $value =~ s/%09/\t/g;
  $value =~ s/%25/%/g;
  return $value;
}
