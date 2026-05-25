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

smoke_check_test_timeout_contract() {
  local status=0
  local timeout_root=""
  local success_result=0
  local timeout_result=0

  timeout_root="$(mktemp -d "${TEST_TEMP_ROOT}/test-timeout.XXXXXX")" || return 1
  test_register_temp_dir "$timeout_root" || return 1
  TEST_TEMP_ROOT="$timeout_root"

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

  return "$status"
}

# repo-automation/tests/lib/contracts/test-timeout.sh EOF
