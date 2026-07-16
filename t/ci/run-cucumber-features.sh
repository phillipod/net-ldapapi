#!/usr/bin/env bash

set +e
set -uo pipefail

results_file="${CUCUMBER_RESULTS_FILE:?CUCUMBER_RESULTS_FILE must name a writable result file}"
timeout_seconds="${CUCUMBER_TIMEOUT_SECONDS:-180}"
skip_features=" ${CUCUMBER_SKIP_FEATURES:-} "
log_dir="${CUCUMBER_LOG_DIR:-}"

mkdir -p "$(dirname "$results_file")"
if [ -n "$log_dir" ]; then
  mkdir -p "$log_dir"
fi
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

  perl t/ci/locate-cucumber-failure.pl "$feature_file" "$log_file"
}

find t/features -type f -name '*.feature' \
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
  timeout -k 5s "${timeout_seconds}s" \
    prove -blv t/01-bdd-cucumber.t :: "$feature_file" 2>&1 \
    | tee "$log_file"
  feature_status="${PIPESTATUS[0]}"
  if [ -n "$log_dir" ]; then
    cp "$log_file" "$log_dir/$feature_name.log" 2>/dev/null || true
  fi

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
      failed_step='Cucumber harness failed while no Gherkin step was active'
    fi
    echo "::error file=${feature_file}::${failed_step} (${detail})"
    record_result FAIL "$feature_name" "$scenario" "$failed_step" "$detail"
  fi
  echo '::endgroup::'
done < /tmp/net-ldapapi-features.txt

exit "$suite_status"
