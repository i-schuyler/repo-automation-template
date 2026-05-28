# repo-automation/tests/lib/contracts/test-timeout.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.

smoke_timeout_success() {
  :
}

smoke_timeout_slow() {
  sleep 2
}

smoke_timeout_spawn_descendant() {
  local pid_file="${smoke_timeout_pid_file:-}"
  local smoke_timeout_spawned_pid=""

  trap 'smoke_timeout_cleanup_pid "$smoke_timeout_spawned_pid"; trap - RETURN' RETURN

  sleep 20 &
  smoke_timeout_spawned_pid="$!"
  printf '%s\n' "$smoke_timeout_spawned_pid" > "$pid_file"
}

smoke_timeout_cleanup_pid() {
  local pid="${1:-}"

  case "$pid" in
    ''|*[!0-9]*)
      return 0
      ;;
  esac

  if kill -0 "$pid" >/dev/null 2>&1; then
    kill "$pid" >/dev/null 2>&1 || true
    kill -KILL "$pid" >/dev/null 2>&1 || true
  fi
}

smoke_timeout_cleanup_success_temp_dir() {
  local temp_dir="${smoke_timeout_success_temp_dir:-}"

  mkdir -p "$temp_dir" || return 1
  test_register_temp_dir "$temp_dir" || return 1
}

smoke_timeout_preserve_failure_temp_dir() {
  local temp_dir="${smoke_timeout_failure_temp_dir:-}"

  mkdir -p "$temp_dir" || return 1
  test_register_temp_dir "$temp_dir" || return 1
  test_fail "timeout runner preserves failed temp artifacts"
  return 1
}

smoke_check_test_timeout_contract() {
  local status=0
  local timeout_root=""
  local success_result=0
  local timeout_result=0
  local success_temp_dir=""
  local failure_temp_dir=""
  local function_pid_file=""
  local function_sleep_pid=""
  local function_descendant_result=0
  local external_pid_file=""
  local external_sleep_pid=""
  local external_descendant_result=0
  local smoke_timeout_pid_file=""

  timeout_root="$(mktemp -d "${TEST_TEMP_ROOT}/test-timeout.XXXXXX")" || return 1
  test_register_temp_dir "$timeout_root" || return 1
  TEST_TEMP_ROOT="$timeout_root"

  success_temp_dir="$TEST_TEMP_ROOT/success-cleanup.$$"
  smoke_timeout_success_temp_dir="$success_temp_dir"
  if test_run_with_timeout 2 smoke_timeout_cleanup_success_temp_dir; then
    success_result=0
  else
    success_result=$?
  fi
  if [ "$success_result" -eq 0 ] && [ "$TEST_LAST_TIMEOUT" -eq 0 ] && [ "${#TEST_CHILD_PIDS[@]}" -eq 0 ] && [ ! -e "$success_temp_dir" ]; then
    test_pass "timeout runner cleans registered temp dirs on success"
  else
    test_fail "timeout runner cleans registered temp dirs on success"
    status=1
  fi

  failure_temp_dir="$TEST_TEMP_ROOT/failure-preserve.$$"
  smoke_timeout_failure_temp_dir="$failure_temp_dir"
  if test_run_with_timeout 2 smoke_timeout_preserve_failure_temp_dir; then
    timeout_result=0
  else
    timeout_result=$?
  fi
  if [ "$timeout_result" -ne 0 ] && [ "$TEST_LAST_TIMEOUT" -eq 0 ] && [ "${#TEST_CHILD_PIDS[@]}" -eq 0 ] && [ -d "$failure_temp_dir" ]; then
    test_pass "timeout runner preserves failed temp artifacts"
  else
    test_fail "timeout runner preserves failed temp artifacts"
    status=1
  fi

  if test_run_with_timeout 2 smoke_timeout_success; then
    success_result=0
  else
    success_result=$?
  fi

  if [ "$success_result" -eq 0 ] && [ "$TEST_LAST_TIMEOUT" -eq 0 ] && [ "${#TEST_CHILD_PIDS[@]}" -eq 0 ] && [ -z "$(find "$TEST_TEMP_ROOT" -maxdepth 1 -name 'timeout.*' -print -quit)" ]; then
    test_pass "timeout runner returns cleanly on success"
  else
    test_fail "timeout runner returns cleanly on success"
    status=1
  fi

  if test_run_with_timeout 1 smoke_timeout_slow; then
    timeout_result=0
  else
    timeout_result=$?
  fi

  if [ "$timeout_result" -ne 0 ] && [ "$TEST_LAST_TIMEOUT" -eq 1 ] && [ "${#TEST_CHILD_PIDS[@]}" -eq 0 ] && [ -z "$(find "$TEST_TEMP_ROOT" -maxdepth 1 -name 'timeout.*' -print -quit)" ]; then
    test_pass "timeout runner times out cleanly"
  else
    test_fail "timeout runner times out cleanly"
    status=1
  fi

  function_pid_file="$TEST_TEMP_ROOT/function-descendant.$$"
  smoke_timeout_pid_file="$function_pid_file"
  function_sleep_pid=""
  if test_run_with_timeout 2 smoke_timeout_spawn_descendant; then
    function_descendant_result=0
  else
    function_descendant_result=$?
  fi
  if [ -f "$function_pid_file" ]; then
    function_sleep_pid="$(cat "$function_pid_file" 2>/dev/null || true)"
  fi
  if [ "$function_descendant_result" -eq 0 ] && [ "$TEST_LAST_TIMEOUT" -eq 0 ] && [ "${#TEST_CHILD_PIDS[@]}" -eq 0 ] && [ -n "$function_sleep_pid" ] && ! kill -0 "$function_sleep_pid" >/dev/null 2>&1; then
    test_pass "timeout runner cleans function descendants on exit"
  else
    test_fail "timeout runner cleans function descendants on exit"
    status=1
  fi
  smoke_timeout_cleanup_pid "$function_sleep_pid"
  smoke_timeout_pid_file=""

  external_pid_file="$TEST_TEMP_ROOT/external-descendant.$$"
  external_sleep_pid=""
  if test_run_with_timeout 2 "sleep 20 & bg_pid=\$!; printf '%s\n' \"\$bg_pid\" > \"$external_pid_file\"; :"; then
    external_descendant_result=0
  else
    external_descendant_result=$?
  fi
  if [ -f "$external_pid_file" ]; then
    external_sleep_pid="$(cat "$external_pid_file" 2>/dev/null || true)"
  fi
  if [ "$external_descendant_result" -eq 0 ] && [ "$TEST_LAST_TIMEOUT" -eq 0 ] && [ "${#TEST_CHILD_PIDS[@]}" -eq 0 ] && [ -n "$external_sleep_pid" ] && ! kill -0 "$external_sleep_pid" >/dev/null 2>&1; then
    test_pass "timeout runner cleans external descendants on exit"
  else
    test_fail "timeout runner cleans external descendants on exit"
    status=1
  fi
  smoke_timeout_cleanup_pid "$external_sleep_pid"

  outside_root="$(mktemp -d "${TEST_TEMP_ROOT%/*}/test-timeout-outside.XXXXXX")" || return 1
  if test_register_temp_dir "$outside_root"; then
    test_fail "timeout runner refuses temp dirs outside test root"
    status=1
  else
    test_pass "timeout runner refuses temp dirs outside test root"
  fi
  rm -rf -- "$outside_root" >/dev/null 2>&1 || true

  return "$status"
}

# repo-automation/tests/lib/contracts/test-timeout.sh EOF
