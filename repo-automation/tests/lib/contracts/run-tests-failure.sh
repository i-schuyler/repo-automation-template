# repo-automation/tests/lib/contracts/run-tests-failure.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.

smoke_check_run_tests_failure_contract() {
  local status=0
  local excerpt_fail_log="$smoke_test_base/run-tests-failure-excerpt-fail-$$.log"
  local excerpt_command_log="$smoke_test_base/run-tests-failure-excerpt-command-$$.log"
  local smoke_failure_file="$smoke_test_base/run-tests-failure-smoke-$$.log"
  local timeout_failure_file="$smoke_test_base/run-tests-failure-timeout-$$.log"
  local first_failure_log="$smoke_test_base/run-tests-failure-first-$$.log"
  local command_log="$smoke_test_base/run-tests-failure-command-$$.log"
  local guidance_log="$smoke_test_base/run-tests-failure-guidance-$$.log"
  local log_fix_out="$smoke_test_base/run-tests-failure-fix-$$.txt"
  local output=""
  local expected=""

  cat > "$excerpt_fail_log" <<'EOF'
INFO: before
context one
FAIL: broken line
context two
context three
EOF
  expected='INFO: before
context one
FAIL: broken line
context two'
  output="$(run_tests_extract_log_excerpt "$excerpt_fail_log")"
  if [ "$output" = "$expected" ]; then
    test_pass "run-tests log excerpt centers fail lines"
  else
    test_fail "run-tests log excerpt centers fail lines"
    status=1
  fi

  cat > "$excerpt_command_log" <<'EOF'
INFO: before
context one
COMMAND: repo-automation/tests/docs-check.sh --quiet
context two
context three
EOF
  expected='INFO: before
context one
COMMAND: repo-automation/tests/docs-check.sh --quiet
context two'
  output="$(run_tests_extract_log_excerpt "$excerpt_command_log")"
  if [ "$output" = "$expected" ]; then
    test_pass "run-tests log excerpt falls back to command lines"
  else
    test_fail "run-tests log excerpt falls back to command lines"
    status=1
  fi

  cat > "$smoke_failure_file" <<'EOF'
INFO: start
fail: lower-case failure
FAIL: upper-case failure
RUNNING: smoke:ignored
EOF
  if [ "$(run_tests_extract_smoke_failure "$smoke_failure_file")" = "lower-case failure" ]; then
    test_pass "run-tests smoke failure extraction returns first failure"
  else
    test_fail "run-tests smoke failure extraction returns first failure"
    status=1
  fi

  cat > "$timeout_failure_file" <<'EOF'
INFO: start
RUNNING: smoke:first
INFO: middle
RUNNING: smoke:last
EOF
  if [ "$(run_tests_extract_smoke_failure "$timeout_failure_file")" = "timed out during smoke:last" ]; then
    test_pass "run-tests smoke failure extraction reports last running line"
  else
    test_fail "run-tests smoke failure extraction reports last running line"
    status=1
  fi

  cat > "$first_failure_log" <<'EOF'
INFO: start
FAIL: first failure
fail: second failure
EOF
  if [ "$(run_tests_extract_log_first_failure "$first_failure_log")" = "first failure" ]; then
    test_pass "run-tests first failure extraction returns first log failure"
  else
    test_fail "run-tests first failure extraction returns first log failure"
    status=1
  fi

  cat > "$command_log" <<'EOF'
INFO: start
COMMAND: repo-automation/bin/run-tests --docs --quiet
EOF
  if [ "$(run_tests_extract_log_command "$command_log")" = "repo-automation/bin/run-tests --docs --quiet" ]; then
    test_pass "run-tests command extraction returns command line"
  else
    test_fail "run-tests command extraction returns command line"
    status=1
  fi

  if [ "$(run_tests_focus_command_from_log 'smoke:run-tests-contract timed out after 120s' 'repo-automation/bin/run-tests --docs --quiet')" = 'repo-automation/tests/contracts/run-tests.sh --quiet' ]; then
    test_pass "run-tests focused command maps run-tests contract"
  else
    test_fail "run-tests focused command maps run-tests contract"
    status=1
  fi

  if [ "$(run_tests_focus_command_from_log 'shellcheck path discovery failed' 'repo-automation/bin/shellcheck-ci-parity --print-paths')" = 'repo-automation/bin/shellcheck-ci-parity --print-paths' ]; then
    test_pass "run-tests focused command maps shellcheck path discovery"
  else
    test_fail "run-tests focused command maps shellcheck path discovery"
    status=1
  fi

  if [ "$(run_tests_focus_command_from_log '' 'repo-automation/tests/docs-check.sh --quiet')" = 'repo-automation/tests/docs-check.sh --quiet' ] && \
    [ "$(run_tests_focus_command_from_log '' 'repo-automation/tests/version-consistency.sh --quiet')" = 'repo-automation/tests/version-consistency.sh --quiet' ] && \
    [ "$(run_tests_focus_command_from_log '' 'repo-automation/tests/smoke.sh --quiet')" = 'repo-automation/tests/smoke.sh --quiet' ]; then
    test_pass "run-tests focused command maps docs version and smoke command lines"
  else
    test_fail "run-tests focused command maps docs version and smoke command lines"
    status=1
  fi

  if [ "$(run_tests_print_log_reference "$command_log")" = "log: $command_log" ]; then
    test_pass "run-tests log reference helper prints log path"
  else
    test_fail "run-tests log reference helper prints log path"
    status=1
  fi

  cat > "$guidance_log" <<'EOF'
INFO: start
COMMAND: repo-automation/bin/run-tests --docs --quiet
FAIL: smoke:run-tests-contract timed out after 120s
EOF
  run_tests_print_failure_fix_from_log "$guidance_log" 0 >"$log_fix_out" 2>&1
  if grep -Fxq "log: $guidance_log" "$log_fix_out" && grep -Fxq 'first failure: smoke:run-tests-contract timed out after 120s' "$log_fix_out" && grep -Fxq 'fix: inspect log and run focused check: repo-automation/tests/contracts/run-tests.sh --quiet' "$log_fix_out"; then
    test_pass "run-tests log fix helper prints focused guidance"
  else
    test_fail "run-tests log fix helper prints focused guidance"
    status=1
  fi

  rm -f "$excerpt_fail_log" "$excerpt_command_log" "$smoke_failure_file" "$timeout_failure_file" "$first_failure_log" "$command_log" "$guidance_log" "$log_fix_out" >/dev/null 2>&1 || true
  return "$status"
}

# repo-automation/tests/lib/contracts/run-tests-failure.sh EOF
