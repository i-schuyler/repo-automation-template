# repo-automation/tests/lib/test-common.sh
# shellcheck shell=bash
# Shared Bash test harness for smoke tests.

TEST_TEMP_ROOT="${TMPDIR:-$HOME/.cache}/repo-automation-template-tests"
TEST_CURRENT_CHECK=""
TEST_CURRENT_CHECK_REPORTED=0
TEST_CURRENT_CHECK_FAILED=0
TEST_LAST_TIMEOUT=0
TEST_TIMEOUT_AVAILABLE=""
TEST_TIMEOUT_KILL_AFTER_AVAILABLE=""
TEST_TIMEOUT_WARNED=0
TEST_CLEANUP_RAN=0
TEST_TEMP_DIRS=()
TEST_CHILD_PIDS=()
TEST_OUTPUT_MODE="${TEST_OUTPUT_MODE:-summary}"
TEST_OUTPUT_SCRIPT="${TEST_OUTPUT_SCRIPT:-smoke}"
TEST_OUTPUT_SCRIPT_PATH="${TEST_OUTPUT_SCRIPT_PATH:-repo-automation/tests/smoke.sh}"
TEST_EVENT_KIND=()
TEST_EVENT_CHECK=()
TEST_EVENT_MESSAGE=()
TEST_FIRST_FAILURE_INDEX=-1
TEST_FIRST_WARNING_INDEX=-1

test_print_final_summary() {
  printf '===== FINAL SUMMARY =====\n'
  for summary_line in "$@"; do
    printf '%s\n' "$summary_line"
  done
  printf '===== END =====\n'
}

test_escape_json() {
  local value="${1:-}"

  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

test_record_event() {
  local kind="$1"
  local message="$2"
  local event_index

  event_index="${#TEST_EVENT_KIND[@]}"
  TEST_EVENT_KIND+=("$kind")
  TEST_EVENT_CHECK+=("${TEST_CURRENT_CHECK:-}")
  TEST_EVENT_MESSAGE+=("$message")

  case "$kind" in
    fail)
      TEST_CURRENT_CHECK_FAILED=1
      if [ "$TEST_FIRST_FAILURE_INDEX" -lt 0 ]; then
        TEST_FIRST_FAILURE_INDEX="$event_index"
      fi
      ;;
    warn)
      if [ "$TEST_FIRST_WARNING_INDEX" -lt 0 ]; then
        TEST_FIRST_WARNING_INDEX="$event_index"
      fi
      ;;
  esac
}

test_info() {
  [ "$TEST_OUTPUT_MODE" = "explain" ] && printf 'INFO: %s\n' "$*"
  return 0
}

test_warn() {
  TEST_CURRENT_CHECK_REPORTED=1
  test_record_event "warn" "$*"
  [ "$TEST_OUTPUT_MODE" = "explain" ] && printf 'WARN: %s\n' "$*" >&2
  return 0
}

test_fail() {
  TEST_CURRENT_CHECK_REPORTED=1
  test_record_event "fail" "$*"
  [ "$TEST_OUTPUT_MODE" = "explain" ] && printf 'FAIL: %s\n' "$*" >&2
  return 1
}

test_pass() {
  TEST_CURRENT_CHECK_REPORTED=1
  test_record_event "pass" "$*"
  [ "$TEST_OUTPUT_MODE" = "explain" ] && printf 'PASS: %s\n' "$*"
  return 0
}

test_render_first_failure() {
  local fail_index="$TEST_FIRST_FAILURE_INDEX"
  local message=""
  local check_name=""

  if [ "$fail_index" -lt 0 ]; then
    return 1
  fi

  message="${TEST_EVENT_MESSAGE[$fail_index]}"
  check_name="${TEST_EVENT_CHECK[$fail_index]}"

  if [ -n "$check_name" ] && [ -n "$message" ]; then
    printf 'fail: %s: %s\n' "$check_name" "$message" >&2
    return 0
  fi

  if [ -n "$check_name" ]; then
    printf 'fail: %s\n' "$check_name" >&2
    return 0
  fi

  if [ -n "$message" ]; then
    printf 'fail: %s\n' "$message" >&2
  else
    printf 'fail\n' >&2
  fi
  return 0
}

test_extract_first_actionable_failure() {
  local output_file="$1"
  local failure_line=""

  [ -f "$output_file" ] || return 1

  failure_line="$(
    awk '
      /^fail: / { sub(/^fail: /, "", $0); print; exit }
      /^STOP: / { print; exit }
      /^ERROR: / { print; exit }
    ' "$output_file"
  )"

  [ -n "$failure_line" ] || return 1
  printf '%s\n' "$failure_line"
}

test_render_json() {
  local overall_status="$1"
  local pass_count=0
  local warn_count=0
  local fail_count=0
  local idx=0
  local json_checks=""
  local check_name=""
  local kind=""
  local message=""
  local first=1

  while [ "$idx" -lt "${#TEST_EVENT_KIND[@]}" ]; do
    kind="${TEST_EVENT_KIND[$idx]}"
    check_name="${TEST_EVENT_CHECK[$idx]}"
    message="${TEST_EVENT_MESSAGE[$idx]}"
    case "$kind" in
      pass) pass_count=$((pass_count + 1)) ;;
      warn) warn_count=$((warn_count + 1)) ;;
      fail) fail_count=$((fail_count + 1)) ;;
    esac
    if [ "$first" -eq 0 ]; then
      json_checks+=','
    fi
    json_checks+="{\"check\":\"$(test_escape_json "$check_name")\",\"status\":\"$(test_escape_json "$kind")\",\"message\":\"$(test_escape_json "$message")\"}"
    first=0
    idx=$((idx + 1))
  done

  printf '{'
  printf '"script":"%s",' "$(test_escape_json "$TEST_OUTPUT_SCRIPT")"
  printf '"mode":"json",'
  printf '"status":"%s",' "$(test_escape_json "$overall_status")"
  printf '"pass_count":%s,' "$pass_count"
  printf '"warn_count":%s,' "$warn_count"
  printf '"fail_count":%s,' "$fail_count"
  printf '"checks":[%s]' "$json_checks"
  if [ "$TEST_FIRST_FAILURE_INDEX" -ge 0 ]; then
    printf ',"first_failure":{"check":"%s","message":"%s"}' \
      "$(test_escape_json "${TEST_EVENT_CHECK[$TEST_FIRST_FAILURE_INDEX]}")" \
      "$(test_escape_json "${TEST_EVENT_MESSAGE[$TEST_FIRST_FAILURE_INDEX]}")"
  fi
  printf '}\n'
}

test_finish_output() {
  local status="${1:-0}"
  local fail_count=0
  local warn_count=0
  local idx=0

  while [ "$idx" -lt "${#TEST_EVENT_KIND[@]}" ]; do
    case "${TEST_EVENT_KIND[$idx]}" in
      fail) fail_count=$((fail_count + 1)) ;;
      warn) warn_count=$((warn_count + 1)) ;;
    esac
    idx=$((idx + 1))
  done

  case "$TEST_OUTPUT_MODE" in
    json)
      test_render_json "$([ "$status" -eq 0 ] && printf 'pass' || printf 'fail')"
      ;;
    explain)
      if [ "$status" -eq 0 ]; then
        printf 'pass\n'
      fi
      ;;
    quiet)
      if [ "$status" -ne 0 ]; then
        test_render_first_failure || printf 'fail\n'
      fi
      ;;
    *)
      if [ "$status" -eq 0 ]; then
        printf 'pass\n'
      else
        test_render_first_failure || printf 'fail\n'
      fi
      ;;
  esac
}

test_run_named_check() {
  local check_name="${1:-}"
  local scenario_function="${2:-}"
  local timeout_seconds="${smoke_timeout_seconds:-0}"
  local capture_file=""
  local failure_line=""

  if [ -z "$check_name" ] || [ -z "$scenario_function" ]; then
    test_fail "missing named check or scenario function"
    return 1
  fi

  TEST_CURRENT_CHECK="$check_name"
  TEST_CURRENT_CHECK_REPORTED=0
  TEST_CURRENT_CHECK_FAILED=0
    export TEST_CURRENT_CHECK
  if [ "$TEST_OUTPUT_MODE" = "explain" ]; then
    printf 'RUNNING: %s\n' "$TEST_CURRENT_CHECK"
    if test_run_with_timeout "$timeout_seconds" "$scenario_function"; then
      if [ "$TEST_CURRENT_CHECK_FAILED" -eq 1 ]; then
        return 1
      fi
      if [ "$TEST_CURRENT_CHECK_REPORTED" -eq 0 ]; then
        test_pass "$TEST_CURRENT_CHECK"
      fi
      return 0
    fi

    if [ "$TEST_CURRENT_CHECK_REPORTED" -eq 0 ]; then
      if [ "$TEST_LAST_TIMEOUT" -eq 1 ]; then
        test_fail "$TEST_CURRENT_CHECK timed out"
      else
        test_fail "$TEST_CURRENT_CHECK"
      fi
    fi
    return 1
  fi

  capture_file="$(mktemp "${TEST_TEMP_ROOT}/named-check.XXXXXX")" || return 1

  if test_run_with_timeout "$timeout_seconds" "$scenario_function" >"$capture_file" 2>&1; then
    rm -f -- "$capture_file" >/dev/null 2>&1 || true
    if [ "$TEST_CURRENT_CHECK_FAILED" -eq 1 ]; then
      return 1
    fi
    if [ "$TEST_CURRENT_CHECK_REPORTED" -eq 0 ]; then
      test_pass "$TEST_CURRENT_CHECK"
    fi
    return 0
  fi

  if [ "$TEST_CURRENT_CHECK_REPORTED" -eq 0 ]; then
    if [ "$TEST_LAST_TIMEOUT" -eq 1 ]; then
      test_fail "$TEST_CURRENT_CHECK timed out"
    else
      failure_line="$(test_extract_first_actionable_failure "$capture_file" || true)"
      if [ -n "$failure_line" ]; then
        test_fail "$failure_line"
      else
        test_fail "$TEST_CURRENT_CHECK"
      fi
    fi
  fi
  rm -f -- "$capture_file" >/dev/null 2>&1 || true

  return 1
}

test_register_temp_dir() {
  local temp_dir="${1:-}"

  if [ -z "$temp_dir" ]; then
    test_warn "missing temp dir to register"
    return 1
  fi

  case "$temp_dir" in
    "$TEST_TEMP_ROOT"/*|"$TEST_TEMP_ROOT")
      ;;
    *)
      test_warn "refusing to register temp dir outside test root"
      return 1
      ;;
  esac

  TEST_TEMP_DIRS+=("$temp_dir")
}

test_register_child_pid() {
  local child_pid="${1:-}"

  case "$child_pid" in
    ''|*[!0-9]*)
      test_warn "missing child pid to register"
      return 1
      ;;
  esac

  TEST_CHILD_PIDS+=("$child_pid")
}

test_unregister_child_pid() {
  local child_pid="${1:-}"
  local updated_pids=()
  local pid

  case "$child_pid" in
    ''|*[!0-9]*)
      test_warn "missing child pid to unregister"
      return 1
      ;;
  esac

  for pid in "${TEST_CHILD_PIDS[@]}"; do
    if [ "$pid" != "$child_pid" ]; then
      updated_pids+=("$pid")
    fi
  done

  TEST_CHILD_PIDS=("${updated_pids[@]}")
}

test_kill_registered_child_pid() {
  local child_pid="${1:-}"

  case "$child_pid" in
    ''|*[!0-9]*)
      return 0
      ;;
  esac

  test_kill_child_tree "$child_pid"
  wait "$child_pid" >/dev/null 2>&1 || true
}

test_kill_child_tree() {
  local child_pid="${1:-}"
  local descendant_pid=""

  case "$child_pid" in
    ''|*[!0-9]*)
      return 0
      ;;
  esac

  if kill -0 "$child_pid" >/dev/null 2>&1; then
    while IFS= read -r descendant_pid; do
      [ -n "$descendant_pid" ] || continue
      test_kill_child_tree "$descendant_pid"
    done <<EOF
$(ps -o pid= --ppid "$child_pid" 2>/dev/null | awk '{print $1}')
EOF
    kill "$child_pid" >/dev/null 2>&1 || true
    kill -KILL "$child_pid" >/dev/null 2>&1 || true
  fi
}

test_have_timeout() {
  if [ -n "$TEST_TIMEOUT_AVAILABLE" ]; then
    [ "$TEST_TIMEOUT_AVAILABLE" = "1" ]
    return $?
  fi

  if type -P timeout >/dev/null 2>&1; then
    TEST_TIMEOUT_AVAILABLE=1
  else
    TEST_TIMEOUT_AVAILABLE=0
  fi

  [ "$TEST_TIMEOUT_AVAILABLE" = "1" ]
}

test_timeout_has_kill_after() {
  if [ -n "$TEST_TIMEOUT_KILL_AFTER_AVAILABLE" ]; then
    [ "$TEST_TIMEOUT_KILL_AFTER_AVAILABLE" = "1" ]
    return $?
  fi

  if test_have_timeout && command timeout --help 2>&1 | grep -q -- '--kill-after'; then
    TEST_TIMEOUT_KILL_AFTER_AVAILABLE=1
  else
    TEST_TIMEOUT_KILL_AFTER_AVAILABLE=0
  fi

  [ "$TEST_TIMEOUT_KILL_AFTER_AVAILABLE" = "1" ]
}

test_timeout_kill_after() {
  local timeout_seconds="${1:-0}"
  local kill_after=5

  case "$timeout_seconds" in
    ''|*[!0-9]*|0)
      kill_after=1
      ;;
    *)
      if [ "$timeout_seconds" -le 10 ]; then
        kill_after=1
      elif [ "$timeout_seconds" -le 30 ]; then
        kill_after=2
      else
        kill_after=5
      fi
      ;;
  esac

  printf '%ss' "$kill_after"
}

test_warn_timeout_once() {
  if [ "$TEST_TIMEOUT_WARNED" -eq 1 ]; then
    return 0
  fi

  TEST_TIMEOUT_WARNED=1
  test_warn "timeout command not found; running smoke subchecks without per-check timeout guards"
}

test_cleanup() {
  local temp_dir
  local child_pid

  if [ "$TEST_CLEANUP_RAN" -eq 1 ]; then
    return 0
  fi
  TEST_CLEANUP_RAN=1

  for child_pid in "${TEST_CHILD_PIDS[@]}"; do
    test_kill_registered_child_pid "$child_pid"
  done

  for temp_dir in "${TEST_TEMP_DIRS[@]}"; do
    case "$temp_dir" in
      "$TEST_TEMP_ROOT"/*|"$TEST_TEMP_ROOT")
        rm -rf -- "$temp_dir" >/dev/null 2>&1 || true
        ;;
    esac
  done

  return 0
}

test_run_with_timeout() {
  local timeout_seconds="${1:-0}"
  local command_string="${2:-}"
  local shell_command
  local child_pid
  local watchdog_pid
  local timeout_marker=""
  local exit_code=0
  local is_function=0
  local watchdog_timeout=0

  TEST_LAST_TIMEOUT=0

  if [ -z "$command_string" ]; then
    test_fail "missing command string for timeout runner"
    return 1
  fi

  if printf '%s' "$command_string" | grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$' && declare -F "$command_string" >/dev/null 2>&1; then
    is_function=1
  fi

  if [ "$is_function" -eq 1 ]; then
    if [ "$timeout_seconds" -gt 0 ]; then
      timeout_marker="${TEST_TEMP_ROOT}/timeout.$$.$RANDOM"
    fi

    (
      # Keep cleanup ownership in the parent shell so a timed-out child cannot
      # delete shared smoke fixtures that later checks still need.
      trap - EXIT INT TERM
      TEST_CLEANUP_RAN=1
      "$command_string"
    ) &
    child_pid=$!
    test_register_child_pid "$child_pid"

    if [ "$timeout_seconds" -gt 0 ]; then
      (
        sleep "$timeout_seconds"
        if kill -0 "$child_pid" >/dev/null 2>&1; then
          : > "$timeout_marker"
          test_kill_child_tree "$child_pid"
        fi
      ) &
      watchdog_pid=$!
    fi

    wait "$child_pid"
    exit_code=$?
    test_unregister_child_pid "$child_pid"

    if [ "$timeout_seconds" -gt 0 ]; then
      kill "$watchdog_pid" >/dev/null 2>&1 || true
      wait "$watchdog_pid" >/dev/null 2>&1 || true
      if [ -f "$timeout_marker" ]; then
        watchdog_timeout=1
        rm -f -- "$timeout_marker" >/dev/null 2>&1 || true
      fi
    fi
  else
    shell_command="cd $(printf '%q' "$PWD") && eval $(printf '%q' "$command_string")"

    if [ "$timeout_seconds" -gt 0 ] && test_have_timeout; then
      if test_timeout_has_kill_after; then
        command timeout --kill-after="$(test_timeout_kill_after "$timeout_seconds")" "${timeout_seconds}s" bash -lc "$shell_command" &
      else
        command timeout "${timeout_seconds}s" bash -lc "$shell_command" &
      fi
    else
      if [ "$timeout_seconds" -gt 0 ]; then
        test_warn_timeout_once
      fi
      bash -lc "$shell_command" &
    fi

    child_pid=$!
    test_register_child_pid "$child_pid"
    wait "$child_pid"
    exit_code=$?
    test_unregister_child_pid "$child_pid"
  fi

  if [ "$watchdog_timeout" -eq 1 ]; then
    TEST_LAST_TIMEOUT=1
    case "$exit_code" in
      0|124|137|143)
        exit_code=124
        ;;
    esac
  else
    case "$exit_code" in
      124|137|143)
        TEST_LAST_TIMEOUT=1
        ;;
    esac
  fi

  if [ -n "$timeout_marker" ]; then
    rm -f -- "$timeout_marker" >/dev/null 2>&1 || true
  fi

  return "$exit_code"
}

# repo-automation/tests/lib/test-common.sh EOF
