# repo-automation/tests/lib/contracts/run-tests-results.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.

smoke_check_run_tests_results_contract() {
  local status=0
  local -a run_tests_checks=()
  local -a run_tests_log_lines=()

  # shellcheck source=/dev/null
  source "$smoke_repo_root/repo-automation/lib/run-tests-results.sh" || return 1

  run_tests_log() {
    run_tests_log_lines+=("$*")
  }

  run_tests_add_check "alpha" "pass" "ok"
  if [ "${#run_tests_checks[@]}" -eq 1 ] &&
    [ "${run_tests_checks[0]}" = "alpha|pass|0|ok" ] &&
    [ "${#run_tests_log_lines[@]}" -eq 1 ] &&
    [ "${run_tests_log_lines[0]}" = "PASS: alpha - ok" ]; then
    test_pass "run-tests results add_check records and logs"
  else
    test_fail "run-tests results add_check records and logs"
    status=1
  fi

  run_tests_checks=()
  run_tests_log_lines=()

  run_tests_record_pass "pass one" "done"
  run_tests_record_warn "warn one" "careful"
  run_tests_record_fail "fail one" "broken" 1
  run_tests_record_skip "skip one" "ignored"

  if [ "${#run_tests_checks[@]}" -eq 4 ] &&
    [ "${run_tests_checks[0]}" = "pass one|pass|0|done" ] &&
    [ "${run_tests_checks[1]}" = "warn one|warn|0|careful" ] &&
    [ "${run_tests_checks[2]}" = "fail one|fail|1|broken" ] &&
    [ "${run_tests_checks[3]}" = "skip one|skipped|0|ignored" ]; then
    test_pass "run-tests results wrappers append exact entries"
  else
    test_fail "run-tests results wrappers append exact entries"
    status=1
  fi

  if [ "$(run_tests_counts)" = "1 1 1 1" ]; then
    test_pass "run-tests results counts totals"
  else
    test_fail "run-tests results counts totals"
    status=1
  fi

  run_tests_checks=(
    "first pass|pass|0|one"
    "second pass|pass|0|two"
    "warn one|warn|0|watch"
  )

  if [ "$(run_tests_first_entry_by_status pass)" = "first pass|pass|0|one" ]; then
    test_pass "run-tests results first entry returns first matching status"
  else
    test_fail "run-tests results first entry returns first matching status"
    status=1
  fi

  if ! run_tests_first_entry_by_status skipped >/dev/null 2>&1; then
    test_pass "run-tests results first entry fails when status missing"
  else
    test_fail "run-tests results first entry fails when status missing"
    status=1
  fi

  return "$status"
}

# repo-automation/tests/lib/contracts/run-tests-results.sh EOF
