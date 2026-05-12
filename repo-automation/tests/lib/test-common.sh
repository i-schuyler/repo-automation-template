# repo-automation/tests/lib/test-common.sh
# shellcheck shell=bash
# Shared Bash test harness for smoke tests.

TEST_TEMP_ROOT="${TMPDIR:-$HOME/.cache}/repo-automation-template-tests"
TEST_CURRENT_CHECK=""
TEST_LAST_TIMEOUT=0
TEST_TIMEOUT_AVAILABLE=""
TEST_TIMEOUT_KILL_AFTER_AVAILABLE=""
TEST_TIMEOUT_WARNED=0
TEST_CLEANUP_RAN=0
TEST_TEMP_DIRS=()
TEST_CHILD_PIDS=()

test_info() {
  printf 'INFO: %s\n' "$*"
}

test_warn() {
  printf 'WARN: %s\n' "$*" >&2
}

test_fail() {
  printf 'FAIL: %s\n' "$*" >&2
  return 1
}

test_pass() {
  printf 'PASS: %s\n' "$*"
}

test_run_named_check() {
  local check_name="${1:-}"
  local scenario_function="${2:-}"
  local timeout_seconds="${smoke_timeout_seconds:-0}"

  if [ -z "$check_name" ] || [ -z "$scenario_function" ]; then
    test_fail "missing named check or scenario function"
    return 1
  fi

  TEST_CURRENT_CHECK="$check_name"
  export TEST_CURRENT_CHECK
  printf 'RUNNING: %s\n' "$TEST_CURRENT_CHECK"

  if test_run_with_timeout "$timeout_seconds" "$scenario_function"; then
    test_pass "$TEST_CURRENT_CHECK"
    return 0
  fi

  if [ "$TEST_LAST_TIMEOUT" -eq 1 ]; then
    test_fail "$TEST_CURRENT_CHECK timed out"
  else
    test_fail "$TEST_CURRENT_CHECK"
  fi

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
  local child_pgid=""
  local shell_pgid=""

  case "$child_pid" in
    ''|*[!0-9]*)
      return 0
      ;;
  esac

  if kill -0 "$child_pid" >/dev/null 2>&1; then
    shell_pgid="$(ps -o pgid= -p "$$" 2>/dev/null | tr -d '[:space:]')"
    child_pgid="$(ps -o pgid= -p "$child_pid" 2>/dev/null | tr -d '[:space:]')"

    if [ -n "$child_pgid" ] && [ -n "$shell_pgid" ] && [ "$child_pgid" = "$child_pid" ] && [ "$child_pgid" != "$shell_pgid" ]; then
      kill -- "-$child_pid" >/dev/null 2>&1 || true
    fi

    kill "$child_pid" >/dev/null 2>&1 || true
  fi

  wait "$child_pid" >/dev/null 2>&1 || true
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
  local child_pgid=""

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
          child_pgid="$(ps -o pgid= -p "$child_pid" 2>/dev/null | tr -d '[:space:]')"
          if [ -n "$child_pgid" ]; then
            kill -- "-$child_pgid" >/dev/null 2>&1 || true
          fi
          kill "$child_pid" >/dev/null 2>&1 || true
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
