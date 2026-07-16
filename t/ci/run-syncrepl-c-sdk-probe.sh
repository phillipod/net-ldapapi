#!/usr/bin/env bash

# Build and run the direct libldap SyncRepl probe without making the enclosing
# Cucumber invocation stop.  The probe result is deliberately a separate TSV:
# it distinguishes an SDK/server failure from a Net::LDAPapi Perl/XS failure.

set -uo pipefail

openldap_prefix="${OPENLDAP_PREFIX:?OPENLDAP_PREFIX must name the source build}"
results_file="${SYNCPROBE_RESULTS_FILE:?SYNCPROBE_RESULTS_FILE must name a writable result file}"
log_file="${SYNCPROBE_LOG_FILE:?SYNCPROBE_LOG_FILE must name a writable log file}"
ldap_uri="${SYNCPROBE_LDAP_URI:-ldap://127.0.0.1:39010}"
bind_dn="${SYNCPROBE_BIND_DN:-cn=admin,dc=example,dc=com}"
password="${SYNCPROBE_PASSWORD:-password}"
base_dn="${SYNCPROBE_BASE_DN:-dc=example,dc=com}"
timeout_seconds="${SYNCPROBE_TIMEOUT_SECONDS:-30}"
wall_timeout_seconds="${SYNCPROBE_WALL_TIMEOUT_SECONDS:-90}"
compiler="${CC:-cc}"
probe_binary="${SYNCPROBE_BINARY:-$(dirname "$log_file")/syncrepl-c-sdk-probe}"
cancel_skip_reason="${SYNCPROBE_CANCEL_SKIP_REASON:-}"
read -r -a probe_modes <<< "${SYNCPROBE_MODES:-notification cancel}"

mkdir -p "$(dirname "$results_file")" "$(dirname "$log_file")"
: > "$results_file"
: > "$log_file"

record_result() {
  local mode="$1"
  local status="$2"
  local stage="$3"
  local detail="$4"

  detail="${detail//$'\t'/ }"
  detail="${detail//$'\r'/ }"
  detail="${detail//$'\n'/ }"
  printf '%s\t%s\t%s\t%s\n' "$mode" "$status" "$stage" "$detail" \
    >> "$results_file"
}

compile_args=(
  -std=c99
  -O2
  -Wall
  -Wextra
  "-I${openldap_prefix}/include"
  "-L${openldap_prefix}/lib"
  "-Wl,-rpath,${openldap_prefix}/lib"
)
if [ -n "${SYNCPROBE_SASL_LIB_DIR:-}" ]; then
  compile_args+=("-L${SYNCPROBE_SASL_LIB_DIR}")
fi

{
  printf 'C-SYNCPROBE compiler: %s\n' "$compiler"
  printf 'C-SYNCPROBE OpenLDAP prefix: %s\n' "$openldap_prefix"
  printf 'C-SYNCPROBE command:'
  printf ' %q' "$compiler" "${compile_args[@]}" \
    -o "$probe_binary" t/ci/syncrepl-c-sdk-probe.c -lldap -llber -lresolv -lsasl2
  printf '\n'
} >> "$log_file"

if ! "$compiler" "${compile_args[@]}" \
  -o "$probe_binary" t/ci/syncrepl-c-sdk-probe.c \
  -lldap -llber -lresolv -lsasl2 >> "$log_file" 2>&1; then
  for mode in "${probe_modes[@]}"; do
    record_result "$mode" FAIL compile \
      'the direct C SDK probe did not compile or link'
  done
  exit 0
fi

ldd "$probe_binary" >> "$log_file" 2>&1 || true

run_probe() {
  local mode="$1"
  local mode_log_file
  local probe_status
  local last_stage
  local detail

  case "$mode" in
    notification|cancel)
      ;;
    *)
      record_result "$mode" FAIL configuration \
        'SYNCPROBE_MODES contains an unsupported probe mode'
      return
      ;;
  esac

  if [ "$mode" = cancel ] && [ -n "$cancel_skip_reason" ]; then
    record_result cancel SKIP compatibility "$cancel_skip_reason"
    return
  fi

  mode_log_file="${log_file}.${mode}"
  : > "$mode_log_file"
  printf 'C-SYNCPROBE mode: %s\n' "$mode" >> "$log_file"
  timeout -k 5s "${wall_timeout_seconds}s" \
    "$probe_binary" "$ldap_uri" "$bind_dn" "$password" "$base_dn" \
    "$timeout_seconds" "$mode" > "$mode_log_file" 2>&1
  probe_status=$?
  cat "$mode_log_file" >> "$log_file"

  if [ "$probe_status" -eq 0 ]; then
    if [ "$mode" = notification ]; then
      detail='observed an expected post-subscription change notification'
    else
      detail='observed a change notification and cancelled the persistent search'
    fi
    record_result "$mode" PASS run "$detail"
    return
  fi

  last_stage="$(awk -F '\t' '
    /^NET_LDAPAPI_C_SYNC_STAGE/ && $2 !~ /^cleanup_/ { last = $2 }
    END { print last }
  ' "$mode_log_file")"
  if [ -z "$last_stage" ]; then
    last_stage='before the first staged SDK call'
  fi
  if [ "$probe_status" -eq 124 ]; then
    detail="probe timed out after ${wall_timeout_seconds} seconds at ${last_stage}"
  elif [ "$probe_status" -gt 128 ]; then
    detail="process exited after signal $((probe_status - 128)) at ${last_stage}"
  else
    detail="process exited with status ${probe_status} at ${last_stage}"
  fi
  record_result "$mode" FAIL run "$detail"
}

for mode in "${probe_modes[@]}"; do
  run_probe "$mode"
done

exit 0
