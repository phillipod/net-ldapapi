#!/usr/bin/env bash

set +e
set -uo pipefail

results_file="${CUCUMBER_RESULTS_FILE:?CUCUMBER_RESULTS_FILE must name a writable result file}"
timeout_seconds="${CUCUMBER_TIMEOUT_SECONDS:-180}"
skip_features=" ${CUCUMBER_SKIP_FEATURES:-} "

mkdir -p "$(dirname "$results_file")"
: > "$results_file"

record_result() {
  local status="$1"
  local feature="$2"
  local scenario="$3"
  local step="$4"
  local detail="$5"

  scenario="${scenario//$'\t'/ }"
  scenario="${scenario//$'\r'/ }"
  scenario="${scenario//$'\n'/ }"
  step="${step//$'\t'/ }"
  step="${step//$'\r'/ }"
  step="${step//$'\n'/ }"
  detail="${detail//$'\t'/ }"
  detail="${detail//$'\r'/ }"
  detail="${detail//$'\n'/ }"

  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$status" "$feature" "$scenario" "$step" "$detail" \
    >> "$results_file"
}

locate_failed_step() {
  local feature_file="$1"
  local log_file="$2"

  perl - "$feature_file" "$log_file" <<'PERL'
use strict;
use warnings;

my ($feature_file, $log_file) = @ARGV;
open my $log, '<', $log_file or die "Cannot read $log_file: $!";
my $failed_step_index;
my $last_step_index = 0;
while (my $line = <$log>) {
  $line =~ s/\e\[[0-9;]*[[:alpha:]]//g;
  if ($line =~ /^\s*(ok|not[ ]ok)\s+(\d+)\s+-\s+
      (Given|When|Then|And|But|\*)\s+/x) {
    $last_step_index = $2;
    if ($1 eq 'not ok' && !defined $failed_step_index) {
      $failed_step_index = $2;
    }
  }
}
close $log;

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

my $location = defined $failed_step_index
  ? $execution[$failed_step_index - 1]
  : $execution[$last_step_index];
if ($location) {
  print "$location->{scenario}\t$location->{step}\n";
}
PERL
}

find t/features -maxdepth 1 -type f -name '*.feature' \
  ! -name 'syncrepl.feature' | sort \
  > /tmp/net-ldapapi-features.txt
if [ -f t/features/syncrepl.feature ]; then
  printf '%s\n' t/features/syncrepl.feature \
    >> /tmp/net-ldapapi-features.txt
fi

suite_status=0
while IFS= read -r feature_file; do
  feature_name="$(basename "$feature_file")"
  if [[ "$skip_features" == *" $feature_name "* ]]; then
    case "$feature_name" in
      server_controls.feature)
        skip_reason='OpenLDAP source predates the sssvlv overlay'
        ;;
      syncrepl.feature)
        skip_reason='OpenLDAP source predates the syncprov overlay'
        ;;
      *)
        skip_reason='Feature is not supported by this compatibility lane'
        ;;
    esac
    echo "::notice file=${feature_file}::Skipping ${feature_name}: ${skip_reason}"
    record_result SKIP "$feature_name" '' '' "$skip_reason"
    continue
  fi

  log_file="/tmp/net-ldapapi-${feature_name%.feature}.log"
  echo "::group::${feature_file}"
  timeout --kill-after=5s "${timeout_seconds}s" \
    prove -lv t/01-bdd-cucumber.t :: "$feature_file" 2>&1 \
    | tee "$log_file"
  feature_status="${PIPESTATUS[0]}"

  if [ "$feature_status" -eq 0 ]; then
    record_result PASS "$feature_name" '' '' ''
  else
    suite_status=1
    scenario=''
    failed_step=''
    location="$(locate_failed_step "$feature_file" "$log_file")"
    if [ -n "$location" ]; then
      scenario="${location%%$'\t'*}"
      failed_step="${location#*$'\t'}"
    fi

    signal_detail="$(sed -n \
      's/.*Wstat: [0-9][0-9]* (Signal: \([^,)]*\).*/\1/p' \
      "$log_file" | head -n 1)"
    wait_status="$(sed -n \
      's/.*Wstat: \([0-9][0-9]*\).*/\1/p' \
      "$log_file" | head -n 1)"
    if [ "$feature_status" -eq 124 ]; then
      detail="Feature timed out after ${timeout_seconds} seconds"
    elif [ -n "$signal_detail" ]; then
      detail="Feature process terminated by ${signal_detail}"
    elif [ -n "$wait_status" ] && [ "$((wait_status & 127))" -gt 0 ] \
      && [ "$((wait_status & 127))" -lt 127 ]; then
      detail="Feature process terminated by signal $((wait_status & 127))"
    elif [ "$feature_status" -gt 128 ]; then
      detail="Feature process exited after signal $((feature_status - 128))"
    else
      detail="prove exited with status ${feature_status}"
    fi

    exception_detail="$(awk '
      /Cucumber feature completed without an exception/ { in_exception = 1; next }
      in_exception && /^[[:space:]]*#[[:space:]]+/ {
        line = $0
        sub(/^[[:space:]]*#[[:space:]]+/, "", line)
        if (line !~ /^(Failed test|at |Looks like you failed|Tests were run)/) {
          print line
          exit
        }
      }
    ' "$log_file")"
    if [ -n "$exception_detail" ]; then
      detail="$detail: $exception_detail"
    fi

    if [ -z "$failed_step" ]; then
      failed_step='Cucumber process terminated before reporting the step'
    fi
    echo "::error file=${feature_file}::${failed_step} (${detail})"
    record_result FAIL "$feature_name" "$scenario" "$failed_step" "$detail"
  fi
  echo '::endgroup::'
done < /tmp/net-ldapapi-features.txt

exit "$suite_status"
