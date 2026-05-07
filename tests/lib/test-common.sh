# tests/lib/test-common.sh
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
  TEST_CURRENT_CHECK="$1"
  printf 'RUNNING: %s\n' "$TEST_CURRENT_CHECK"
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

  if [ "$TEST_CLEANUP_RAN" -eq 1 ]; then
    return 0
  fi
  TEST_CLEANUP_RAN=1

  if [ "${#TEST_CHILD_PIDS[@]}" -gt 0 ]; then
    kill "${TEST_CHILD_PIDS[@]}" >/dev/null 2>&1 || true
    wait "${TEST_CHILD_PIDS[@]}" >/dev/null 2>&1 || true
  fi

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
  local exit_code=0

  TEST_LAST_TIMEOUT=0

  if [ -z "$command_string" ]; then
    test_fail "missing command string for timeout runner"
    return 1
  fi

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

  case "$exit_code" in
    124|137|143)
      TEST_LAST_TIMEOUT=1
      ;;
  esac

  return "$exit_code"
}

# tests/lib/test-common.sh EOF
