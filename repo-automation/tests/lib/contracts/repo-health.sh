# repo-automation/tests/lib/contracts/repo-health.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.



smoke_check_run_tests_contract() {
  local status=0
  local run_tests_help="$smoke_test_base/run-tests-help-$$.txt"
  local run_tests_default_out="$smoke_test_base/run-tests-default-$$.txt"
  local run_tests_quiet_out="$smoke_test_base/run-tests-quiet-$$.txt"
  local run_tests_quiet_err="$smoke_test_base/run-tests-quiet-$$.stderr"
  local run_tests_explain_out="$smoke_test_base/run-tests-explain-$$.txt"
  local run_tests_json="$smoke_test_base/run-tests-warn-$$.json"
  local run_tests_json_err="$smoke_test_base/run-tests-warn-$$.stderr"
  local run_tests_log_file="$smoke_test_base/run-tests-log-$$.log"
  local run_tests_no_log_file="$smoke_test_base/run-tests-no-log-$$.log"
  local run_tests_no_log_out="$smoke_test_base/run-tests-no-log-$$.txt"
  local run_tests_failure_log="$smoke_test_base/run-tests-failure-$$.log"
  local run_tests_failure_out="$smoke_test_base/run-tests-failure-$$.txt"
  local run_tests_timeout_format_stderr="$smoke_test_base/run-tests-timeout-format-$$.stderr"
  local run_tests_timeout_missing_stderr="$smoke_test_base/run-tests-timeout-missing-$$.stderr"
  local run_tests_timeout_empty_stderr="$smoke_test_base/run-tests-timeout-empty-$$.stderr"
  local run_tests_log_file_format_stderr="$smoke_test_base/run-tests-log-file-format-$$.stderr"
  local run_tests_log_file_missing_stderr="$smoke_test_base/run-tests-log-file-missing-$$.stderr"
  local run_tests_log_file_empty_stderr="$smoke_test_base/run-tests-log-file-empty-$$.stderr"
  local run_tests_json_level_format_stderr="$smoke_test_base/run-tests-json-level-format-$$.stderr"
  local run_tests_json_level_missing_stderr="$smoke_test_base/run-tests-json-level-missing-$$.stderr"
  local run_tests_json_level_empty_stderr="$smoke_test_base/run-tests-json-level-empty-$$.stderr"
  local run_tests_unknown_stderr="$smoke_test_base/run-tests-unknown-$$.stderr"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/run-tests --help > "$run_tests_help"
  ) && \
    grep -Fq -- '--timeout=<seconds>' "$run_tests_help" && \
    grep -Fq -- '--log-file=<path>' "$run_tests_help" && \
    grep -Fq -- '--json-level=fail|warn|all' "$run_tests_help" && \
    ! grep -Fq -- '--timeout SECONDS' "$run_tests_help" && \
    ! grep -Fq -- '--log-file FILE' "$run_tests_help" && \
    ! grep -Fq -- '--json-level fail|warn|all' "$run_tests_help"; then
    test_pass "run-tests help shows strict value syntax"
  else
    test_fail "run-tests help shows strict value syntax"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --timeout=200 > "$run_tests_default_out"
  ) && [ "$(cat "$run_tests_default_out")" = "pass" ]; then
    test_pass "run-tests default output is compact"
  else
    test_fail "run-tests default output is compact"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --quiet > "$run_tests_quiet_out" 2> "$run_tests_quiet_err"
  ) && [ ! -s "$run_tests_quiet_out" ] && [ ! -s "$run_tests_quiet_err" ]; then
    test_pass "run-tests quiet output is silent on success"
  else
    test_fail "run-tests quiet output is silent on success"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --explain > "$run_tests_explain_out"
  ) && grep -Eq '^PASS: repo-automation/tests/docs-check.sh - passed' "$run_tests_explain_out"; then
    test_pass "run-tests explain output shows details"
  else
    test_fail "run-tests explain output shows details"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --json --json-level=warn > "$run_tests_json" 2> "$run_tests_json_err"
  ) && [ ! -s "$run_tests_json_err" ] && python -m json.tool "$run_tests_json" >/dev/null && \
    smoke_json_assert "$run_tests_json" 'data.get("script") == "run-tests" and data.get("json_level") == "warn" and data.get("overall_status") in ("pass", "warn", "fail")'; then
    test_pass "run-tests json warn is parseable"
  else
    test_fail "run-tests json warn is parseable"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --timeout=200 --log-file="$run_tests_log_file" >/dev/null
  ) && [ -f "$run_tests_log_file" ]; then
    test_pass "run-tests log-file creates a log"
  else
    test_fail "run-tests log-file creates a log"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    cat > docs/run-tests-diagnostic.md <<'EOF'
# Diagnostic

Body.
EOF
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --quiet --log-file="$run_tests_failure_log" > "$run_tests_failure_out"
  ); then
    test_fail "run-tests quiet failure references the log file"
    status=1
  elif grep -Fq "log: $run_tests_failure_log" "$run_tests_failure_out" &&
    grep -Fq 'fail: repo-automation/tests/docs-check.sh' "$run_tests_failure_out" &&
    grep -Fq 'COMMAND: repo-automation/tests/docs-check.sh' "$run_tests_failure_log" &&
    grep -Fq 'FAIL: docs index coverage:' "$run_tests_failure_log"; then
    test_pass "run-tests quiet failure references the log file"
  else
    test_fail "run-tests quiet failure references the log file"
    status=1
  fi
  rm -f "$smoke_test_dir/docs/run-tests-diagnostic.md" >/dev/null 2>&1 || true

  if (
    cd "$smoke_repo_root" || return 1
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --timeout=200 --log-file="$run_tests_no_log_file" --no-log > "$run_tests_no_log_out"
  ) && [ ! -e "$run_tests_no_log_file" ] && ! grep -Eq '^Log:' "$run_tests_no_log_out"; then
    test_pass "run-tests no-log does not create a log"
  else
    test_fail "run-tests no-log does not create a log"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/run-tests --timeout 200 >/dev/null 2> "$run_tests_timeout_format_stderr"
  ); then
    test_fail "run-tests rejects --timeout <seconds>"
    status=1
  elif smoke_assert_flag_error_shape "$run_tests_timeout_format_stderr" "flag format not accepted" "--timeout" "use --timeout=<seconds>"; then
    test_pass "run-tests rejects --timeout <seconds>"
  else
    test_fail "run-tests rejects --timeout <seconds>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/run-tests --timeout >/dev/null 2> "$run_tests_timeout_missing_stderr"
  ); then
    test_fail "run-tests rejects missing --timeout value"
    status=1
  elif smoke_assert_flag_error_shape "$run_tests_timeout_missing_stderr" "missing flag value" "--timeout" "use --timeout=<seconds>"; then
    test_pass "run-tests rejects missing --timeout value"
  else
    test_fail "run-tests rejects missing --timeout value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/run-tests --timeout= >/dev/null 2> "$run_tests_timeout_empty_stderr"
  ); then
    test_fail "run-tests rejects empty --timeout value"
    status=1
  elif smoke_assert_flag_error_shape "$run_tests_timeout_empty_stderr" "empty flag value" "--timeout" "use --timeout=<seconds>"; then
    test_pass "run-tests rejects empty --timeout value"
  else
    test_fail "run-tests rejects empty --timeout value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/run-tests --log-file "$run_tests_log_file" >/dev/null 2> "$run_tests_log_file_format_stderr"
  ); then
    test_fail "run-tests rejects --log-file <path>"
    status=1
  elif smoke_assert_flag_error_shape "$run_tests_log_file_format_stderr" "flag format not accepted" "--log-file" "use --log-file=<path>"; then
    test_pass "run-tests rejects --log-file <path>"
  else
    test_fail "run-tests rejects --log-file <path>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/run-tests --log-file >/dev/null 2> "$run_tests_log_file_missing_stderr"
  ); then
    test_fail "run-tests rejects missing --log-file value"
    status=1
  elif smoke_assert_flag_error_shape "$run_tests_log_file_missing_stderr" "missing flag value" "--log-file" "use --log-file=<path>"; then
    test_pass "run-tests rejects missing --log-file value"
  else
    test_fail "run-tests rejects missing --log-file value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/run-tests --log-file= >/dev/null 2> "$run_tests_log_file_empty_stderr"
  ); then
    test_fail "run-tests rejects empty --log-file value"
    status=1
  elif smoke_assert_flag_error_shape "$run_tests_log_file_empty_stderr" "empty flag value" "--log-file" "use --log-file=<path>"; then
    test_pass "run-tests rejects empty --log-file value"
  else
    test_fail "run-tests rejects empty --log-file value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/run-tests --json-level warn >/dev/null 2> "$run_tests_json_level_format_stderr"
  ); then
    test_fail "run-tests rejects --json-level <value>"
    status=1
  elif smoke_assert_flag_error_shape "$run_tests_json_level_format_stderr" "flag format not accepted" "--json-level" "use --json-level=<fail|warn|all>"; then
    test_pass "run-tests rejects --json-level <value>"
  else
    test_fail "run-tests rejects --json-level <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/run-tests --json-level >/dev/null 2> "$run_tests_json_level_missing_stderr"
  ); then
    test_fail "run-tests rejects missing --json-level value"
    status=1
  elif smoke_assert_flag_error_shape "$run_tests_json_level_missing_stderr" "missing flag value" "--json-level" "use --json-level=<fail|warn|all>"; then
    test_pass "run-tests rejects missing --json-level value"
  else
    test_fail "run-tests rejects missing --json-level value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/run-tests --json-level= >/dev/null 2> "$run_tests_json_level_empty_stderr"
  ); then
    test_fail "run-tests rejects empty --json-level value"
    status=1
  elif smoke_assert_flag_error_shape "$run_tests_json_level_empty_stderr" "empty flag value" "--json-level" "use --json-level=<fail|warn|all>"; then
    test_pass "run-tests rejects empty --json-level value"
  else
    test_fail "run-tests rejects empty --json-level value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/run-tests --whatever >/dev/null 2> "$run_tests_unknown_stderr"
  ); then
    test_fail "run-tests rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$run_tests_unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/run-tests --help"; then
    test_pass "run-tests rejects unknown flags"
  else
    test_fail "run-tests rejects unknown flags"
    status=1
  fi

  local run_tests_subset_repo=""
  local run_tests_subset_smoke_json="$smoke_test_base/run-tests-subset-smoke-$$.json"
  local run_tests_subset_docs_json="$smoke_test_base/run-tests-subset-docs-$$.json"
  local run_tests_subset_version_json="$smoke_test_base/run-tests-subset-version-$$.json"
  local run_tests_subset_changed_json="$smoke_test_base/run-tests-subset-changed-$$.json"
  local run_tests_subset_changed_default_out="$smoke_test_base/run-tests-subset-changed-default-$$.txt"
  local run_tests_subset_changed_default_err="$smoke_test_base/run-tests-subset-changed-default-$$.stderr"
  local run_tests_subset_changed_quiet_out="$smoke_test_base/run-tests-subset-changed-quiet-$$.txt"
  local run_tests_subset_changed_quiet_err="$smoke_test_base/run-tests-subset-changed-quiet-$$.stderr"
  local run_tests_subset_changed_smoke_json="$smoke_test_base/run-tests-subset-changed-smoke-$$.json"
  local run_tests_subset_changed_bin_json="$smoke_test_base/run-tests-subset-changed-bin-$$.json"

  run_tests_subset_repo="$(smoke_setup_subset_repo)" || {
    test_fail "run-tests subset fixture creates a repo"
    status=1
  }

  if [ -n "$run_tests_subset_repo" ] && (
    cd "$run_tests_subset_repo" || return 1
    repo-automation/bin/run-tests --smoke --json --json-level=all > "$run_tests_subset_smoke_json" || true
  ) && python -m json.tool "$run_tests_subset_smoke_json" >/dev/null &&     smoke_json_assert "$run_tests_subset_smoke_json" 'data.get("script") == "run-tests" and len(data.get("checks", [])) == 1 and data.get("checks", [])[0].get("name") == "repo-automation/tests/smoke.sh"'; then
    test_pass "run-tests smoke subset runs only smoke"
  else
    test_fail "run-tests smoke subset runs only smoke"
    status=1
  fi

  if [ -n "$run_tests_subset_repo" ] && (
    cd "$run_tests_subset_repo" || return 1
    repo-automation/bin/run-tests --docs --json --json-level=all > "$run_tests_subset_docs_json" || true
  ) && python -m json.tool "$run_tests_subset_docs_json" >/dev/null &&     smoke_json_assert "$run_tests_subset_docs_json" 'data.get("script") == "run-tests" and len(data.get("checks", [])) == 1 and data.get("checks", [])[0].get("name") == "repo-automation/tests/docs-check.sh"'; then
    test_pass "run-tests docs subset runs only docs-check"
  else
    test_fail "run-tests docs subset runs only docs-check"
    status=1
  fi

  if [ -n "$run_tests_subset_repo" ] && (
    cd "$run_tests_subset_repo" || return 1
    repo-automation/bin/run-tests --version --json --json-level=all > "$run_tests_subset_version_json" || true
  ) && python -m json.tool "$run_tests_subset_version_json" >/dev/null &&     smoke_json_assert "$run_tests_subset_version_json" 'data.get("script") == "run-tests" and len(data.get("checks", [])) == 1 and data.get("checks", [])[0].get("name") == "repo-automation/tests/version-consistency.sh"'; then
    test_pass "run-tests version subset runs only version-consistency"
  else
    test_fail "run-tests version subset runs only version-consistency"
    status=1
  fi

  if [ -n "$run_tests_subset_repo" ] && (
    cd "$run_tests_subset_repo" || return 1
    cat > repo-automation/tests/docs-check.sh <<EOF
#!/usr/bin/env bash
set -u
set -o pipefail
exit 0
EOF
    chmod +x repo-automation/tests/docs-check.sh || return 1
    git add repo-automation/tests/docs-check.sh || return 1
    git commit -m "test: stub passing docs-check" >/dev/null 2>&1 || return 1
    printf '\nAdditional docs note.\n' >> repo-automation/docs/testing.md || return 1
    repo-automation/bin/run-tests --changed > "$run_tests_subset_changed_default_out" 2> "$run_tests_subset_changed_default_err"
  ) && [ "$(cat "$run_tests_subset_changed_default_out")" = "pass" ] && [ ! -s "$run_tests_subset_changed_default_err" ]; then
    test_pass "run-tests changed subset defaults to compact pass output"
  else
    test_fail "run-tests changed subset defaults to compact pass output"
    status=1
  fi

  if [ -n "$run_tests_subset_repo" ] && (
    cd "$run_tests_subset_repo" || return 1
    repo-automation/bin/run-tests --changed --quiet > "$run_tests_subset_changed_quiet_out" 2> "$run_tests_subset_changed_quiet_err"
  ) && [ ! -s "$run_tests_subset_changed_quiet_out" ] && [ ! -s "$run_tests_subset_changed_quiet_err" ]; then
    test_pass "run-tests changed subset quiet output is silent"
  else
    test_fail "run-tests changed subset quiet output is silent"
    status=1
  fi

  if [ -n "$run_tests_subset_repo" ] && (
    cd "$run_tests_subset_repo" || return 1
    repo-automation/bin/run-tests --changed --json --json-level=all > "$run_tests_subset_changed_json" || true
  ) && python -m json.tool "$run_tests_subset_changed_json" >/dev/null &&     smoke_json_assert "$run_tests_subset_changed_json" 'data.get("selected_subsets") == ["docs"] and any(check.get("name") == "repo-automation/tests/docs-check.sh" for check in data.get("checks", [])) and not any(check.get("name") == "repo-automation/tests/smoke.sh" for check in data.get("checks", []))'; then
    test_pass "run-tests changed subset follows docs-only changes"
  else
    test_fail "run-tests changed subset follows docs-only changes"
    status=1
  fi

  local run_tests_subset_changed_smoke_repo=""
  run_tests_subset_changed_smoke_repo="$(smoke_setup_subset_repo)" || {
    test_fail "run-tests changed subset follows docs plus smoke changes"
    status=1
  }

  if [ -n "$run_tests_subset_changed_smoke_repo" ] && (
    cd "$run_tests_subset_changed_smoke_repo" || return 1
    printf '\nsubset docs plus smoke change\n' >> repo-automation/docs/testing.md || return 1
    printf '\n# subset smoke change\n' >> repo-automation/tests/smoke.sh || return 1
    repo-automation/bin/run-tests --changed --json --json-level=all > "$run_tests_subset_changed_smoke_json" || true
  ) && python -m json.tool "$run_tests_subset_changed_smoke_json" >/dev/null &&     smoke_json_assert "$run_tests_subset_changed_smoke_json" 'len(data.get("selected_subsets", [])) == 2 and "docs" in data.get("selected_subsets", []) and "smoke" in data.get("selected_subsets", []) and any(check.get("name") == "repo-automation/tests/docs-check.sh" for check in data.get("checks", [])) and any(check.get("name") == "repo-automation/tests/smoke.sh" for check in data.get("checks", []))'; then
    test_pass "run-tests changed subset follows docs plus smoke changes"
  else
    test_fail "run-tests changed subset follows docs plus smoke changes"
    status=1
  fi

  local run_tests_subset_changed_bin_repo=""
  run_tests_subset_changed_bin_repo="$(smoke_setup_subset_repo)" || {
    test_fail "run-tests changed subset follows docs plus bin changes"
    status=1
  }

  if [ -n "$run_tests_subset_changed_bin_repo" ] && (
    cd "$run_tests_subset_changed_bin_repo" || return 1
    printf '\nsubset docs plus bin change\n' >> repo-automation/docs/testing.md || return 1
    printf '\n# subset bin change\n' >> repo-automation/bin/failure-log || return 1
    repo-automation/bin/run-tests --changed --json --json-level=all > "$run_tests_subset_changed_bin_json" || true
  ) && python -m json.tool "$run_tests_subset_changed_bin_json" >/dev/null &&     smoke_json_assert "$run_tests_subset_changed_bin_json" 'len(data.get("selected_subsets", [])) == 2 and "docs" in data.get("selected_subsets", []) and "smoke" in data.get("selected_subsets", []) and any(check.get("name") == "repo-automation/tests/docs-check.sh" for check in data.get("checks", [])) and any(check.get("name") == "repo-automation/tests/smoke.sh" for check in data.get("checks", []))'; then
    test_pass "run-tests changed subset follows docs plus bin changes"
  else
    test_fail "run-tests changed subset follows docs plus bin changes"
    status=1
  fi

  rm -f "$run_tests_help" "$run_tests_default_out" "$run_tests_quiet_out" "$run_tests_quiet_err" "$run_tests_explain_out" "$run_tests_json" "$run_tests_json_err" "$run_tests_log_file" "$run_tests_no_log_file" "$run_tests_no_log_out" "$run_tests_failure_log" "$run_tests_failure_out" "$run_tests_timeout_format_stderr" "$run_tests_timeout_missing_stderr" "$run_tests_timeout_empty_stderr" "$run_tests_log_file_format_stderr" "$run_tests_log_file_missing_stderr" "$run_tests_log_file_empty_stderr" "$run_tests_json_level_format_stderr" "$run_tests_json_level_missing_stderr" "$run_tests_json_level_empty_stderr" "$run_tests_unknown_stderr" "$run_tests_subset_smoke_json" "$run_tests_subset_docs_json" "$run_tests_subset_version_json" "$run_tests_subset_changed_default_out" "$run_tests_subset_changed_default_err" "$run_tests_subset_changed_quiet_out" "$run_tests_subset_changed_quiet_err" "$run_tests_subset_changed_json" "$run_tests_subset_changed_smoke_json" "$run_tests_subset_changed_bin_json" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_repo_doctor_contract() {
  local status=0
  local doctor_help="$smoke_test_base/repo-doctor-help-$$.txt"
  local doctor_default_out="$smoke_test_base/repo-doctor-quick-default-$$.txt"
  local doctor_quiet_out="$smoke_test_base/repo-doctor-quick-quiet-$$.txt"
  local doctor_quiet_err="$smoke_test_base/repo-doctor-quick-quiet-$$.stderr"
  local doctor_explain_out="$smoke_test_base/repo-doctor-quick-explain-$$.txt"
  local doctor_json_warn="$smoke_test_base/repo-doctor-quick-warn-$$.json"
  local doctor_json_warn_err="$smoke_test_base/repo-doctor-quick-warn-$$.stderr"
  local doctor_log_file="$smoke_test_base/repo-doctor-log-$$.log"
  local doctor_no_log_file="$smoke_test_base/repo-doctor-no-log-$$.log"
  local doctor_no_log_out="$smoke_test_base/repo-doctor-no-log-$$.txt"
  local doctor_json="$smoke_test_base/repo-doctor-quick-$$.json"
  local doctor_config_out="$smoke_test_base/repo-doctor-config-$$.txt"
  local doctor_timeout_format_stderr="$smoke_test_base/repo-doctor-timeout-format-$$.stderr"
  local doctor_timeout_missing_stderr="$smoke_test_base/repo-doctor-timeout-missing-$$.stderr"
  local doctor_timeout_empty_stderr="$smoke_test_base/repo-doctor-timeout-empty-$$.stderr"
  local doctor_log_file_format_stderr="$smoke_test_base/repo-doctor-log-file-format-$$.stderr"
  local doctor_log_file_missing_stderr="$smoke_test_base/repo-doctor-log-file-missing-$$.stderr"
  local doctor_log_file_empty_stderr="$smoke_test_base/repo-doctor-log-file-empty-$$.stderr"
  local doctor_json_level_format_stderr="$smoke_test_base/repo-doctor-json-level-format-$$.stderr"
  local doctor_json_level_missing_stderr="$smoke_test_base/repo-doctor-json-level-missing-$$.stderr"
  local doctor_json_level_empty_stderr="$smoke_test_base/repo-doctor-json-level-empty-$$.stderr"
  local doctor_check_format_stderr="$smoke_test_base/repo-doctor-check-format-$$.stderr"
  local doctor_check_missing_stderr="$smoke_test_base/repo-doctor-check-missing-$$.stderr"
  local doctor_check_empty_stderr="$smoke_test_base/repo-doctor-check-empty-$$.stderr"
  local doctor_unknown_stderr="$smoke_test_base/repo-doctor-unknown-$$.stderr"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --help > "$doctor_help"
  ) && \
    grep -Fq -- '--timeout=<seconds>' "$doctor_help" && \
    grep -Fq -- '--log-file=<path>' "$doctor_help" && \
    grep -Fq -- '--json-level=fail|warn|all' "$doctor_help" && \
    grep -Fq -- '--check=<name>' "$doctor_help" && \
    ! grep -Fq -- '--timeout SECONDS' "$doctor_help" && \
    ! grep -Fq -- '--log-file FILE' "$doctor_help" && \
    ! grep -Fq -- '--json-level fail|warn|all' "$doctor_help" && \
    ! grep -Fq -- '--check NAME' "$doctor_help"; then
    test_pass "repo-doctor help shows strict value syntax"
  else
    test_fail "repo-doctor help shows strict value syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --check=config --timeout=200 > "$doctor_default_out"
  ) && [ "$(cat "$doctor_default_out")" = "pass" ]; then
    test_pass "repo-doctor default output is compact"
  else
    test_fail "repo-doctor default output is compact"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --check=config --quiet --timeout=200 > "$doctor_quiet_out" 2> "$doctor_quiet_err"
  ) && [ ! -s "$doctor_quiet_out" ] && [ ! -s "$doctor_quiet_err" ]; then
    test_pass "repo-doctor quiet output is silent on success"
  else
    test_fail "repo-doctor quiet output is silent on success"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --quick --explain > "$doctor_explain_out"
  ) && grep -Eq '^PASS: git-branch - current branch:' "$doctor_explain_out"; then
    test_pass "repo-doctor quick explain output shows details"
  else
    test_fail "repo-doctor quick explain output shows details"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --json --check=config --json-level=all > "$doctor_json_warn" 2> "$doctor_json_warn_err"
  ) && [ ! -s "$doctor_json_warn_err" ] && python -m json.tool "$doctor_json_warn" >/dev/null && \
    smoke_json_assert "$doctor_json_warn" 'data.get("overall_status") == "pass" and data.get("json_level") == "all" and any(check.get("name") == "config-exists" and check.get("status") == "pass" for check in data.get("checks", []))'; then
    test_pass "repo-doctor json output is parseable"
  else
    test_fail "repo-doctor json output is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --quick --timeout=200 --log-file="$doctor_log_file" >/dev/null
  ) && [ -f "$doctor_log_file" ]; then
    test_pass "repo-doctor log-file creates a log"
  else
    test_fail "repo-doctor log-file creates a log"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --quick --timeout=200 --log-file="$doctor_no_log_file" --no-log > "$doctor_no_log_out"
  ) && [ ! -e "$doctor_no_log_file" ] && ! grep -Eq '^Log:' "$doctor_no_log_out"; then
    test_pass "repo-doctor no-log does not create a log"
  else
    test_fail "repo-doctor no-log does not create a log"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --check=config --timeout=200 --no-run-tests > "$doctor_config_out"
  ); then
    test_pass "repo-doctor config check succeeds"
  else
    test_fail "repo-doctor config check succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --json --quick > "$doctor_json"
  ) && python -m json.tool "$doctor_json" >/dev/null; then
    test_pass "repo-doctor json quick is parseable"
  else
    test_fail "repo-doctor json quick is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --timeout 200 >/dev/null 2> "$doctor_timeout_format_stderr"
  ); then
    test_fail "repo-doctor rejects --timeout <seconds>"
    status=1
  elif smoke_assert_flag_error_shape "$doctor_timeout_format_stderr" "flag format not accepted" "--timeout" "use --timeout=<seconds>"; then
    test_pass "repo-doctor rejects --timeout <seconds>"
  else
    test_fail "repo-doctor rejects --timeout <seconds>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --timeout >/dev/null 2> "$doctor_timeout_missing_stderr"
  ); then
    test_fail "repo-doctor rejects missing --timeout value"
    status=1
  elif smoke_assert_flag_error_shape "$doctor_timeout_missing_stderr" "missing flag value" "--timeout" "use --timeout=<seconds>"; then
    test_pass "repo-doctor rejects missing --timeout value"
  else
    test_fail "repo-doctor rejects missing --timeout value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --timeout= >/dev/null 2> "$doctor_timeout_empty_stderr"
  ); then
    test_fail "repo-doctor rejects empty --timeout value"
    status=1
  elif smoke_assert_flag_error_shape "$doctor_timeout_empty_stderr" "empty flag value" "--timeout" "use --timeout=<seconds>"; then
    test_pass "repo-doctor rejects empty --timeout value"
  else
    test_fail "repo-doctor rejects empty --timeout value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --log-file "$doctor_log_file" >/dev/null 2> "$doctor_log_file_format_stderr"
  ); then
    test_fail "repo-doctor rejects --log-file <path>"
    status=1
  elif smoke_assert_flag_error_shape "$doctor_log_file_format_stderr" "flag format not accepted" "--log-file" "use --log-file=<path>"; then
    test_pass "repo-doctor rejects --log-file <path>"
  else
    test_fail "repo-doctor rejects --log-file <path>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --log-file >/dev/null 2> "$doctor_log_file_missing_stderr"
  ); then
    test_fail "repo-doctor rejects missing --log-file value"
    status=1
  elif smoke_assert_flag_error_shape "$doctor_log_file_missing_stderr" "missing flag value" "--log-file" "use --log-file=<path>"; then
    test_pass "repo-doctor rejects missing --log-file value"
  else
    test_fail "repo-doctor rejects missing --log-file value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --log-file= >/dev/null 2> "$doctor_log_file_empty_stderr"
  ); then
    test_fail "repo-doctor rejects empty --log-file value"
    status=1
  elif smoke_assert_flag_error_shape "$doctor_log_file_empty_stderr" "empty flag value" "--log-file" "use --log-file=<path>"; then
    test_pass "repo-doctor rejects empty --log-file value"
  else
    test_fail "repo-doctor rejects empty --log-file value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --json-level warn >/dev/null 2> "$doctor_json_level_format_stderr"
  ); then
    test_fail "repo-doctor rejects --json-level <value>"
    status=1
  elif smoke_assert_flag_error_shape "$doctor_json_level_format_stderr" "flag format not accepted" "--json-level" "use --json-level=<fail|warn|all>"; then
    test_pass "repo-doctor rejects --json-level <value>"
  else
    test_fail "repo-doctor rejects --json-level <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --json-level >/dev/null 2> "$doctor_json_level_missing_stderr"
  ); then
    test_fail "repo-doctor rejects missing --json-level value"
    status=1
  elif smoke_assert_flag_error_shape "$doctor_json_level_missing_stderr" "missing flag value" "--json-level" "use --json-level=<fail|warn|all>"; then
    test_pass "repo-doctor rejects missing --json-level value"
  else
    test_fail "repo-doctor rejects missing --json-level value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --json-level= >/dev/null 2> "$doctor_json_level_empty_stderr"
  ); then
    test_fail "repo-doctor rejects empty --json-level value"
    status=1
  elif smoke_assert_flag_error_shape "$doctor_json_level_empty_stderr" "empty flag value" "--json-level" "use --json-level=<fail|warn|all>"; then
    test_pass "repo-doctor rejects empty --json-level value"
  else
    test_fail "repo-doctor rejects empty --json-level value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --check config >/dev/null 2> "$doctor_check_format_stderr"
  ); then
    test_fail "repo-doctor rejects --check <name>"
    status=1
  elif smoke_assert_flag_error_shape "$doctor_check_format_stderr" "flag format not accepted" "--check" "use --check=<name>"; then
    test_pass "repo-doctor rejects --check <name>"
  else
    test_fail "repo-doctor rejects --check <name>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --check >/dev/null 2> "$doctor_check_missing_stderr"
  ); then
    test_fail "repo-doctor rejects missing --check value"
    status=1
  elif smoke_assert_flag_error_shape "$doctor_check_missing_stderr" "missing flag value" "--check" "use --check=<name>"; then
    test_pass "repo-doctor rejects missing --check value"
  else
    test_fail "repo-doctor rejects missing --check value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --check= >/dev/null 2> "$doctor_check_empty_stderr"
  ); then
    test_fail "repo-doctor rejects empty --check value"
    status=1
  elif smoke_assert_flag_error_shape "$doctor_check_empty_stderr" "empty flag value" "--check" "use --check=<name>"; then
    test_pass "repo-doctor rejects empty --check value"
  else
    test_fail "repo-doctor rejects empty --check value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --whatever >/dev/null 2> "$doctor_unknown_stderr"
  ); then
    test_fail "repo-doctor rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$doctor_unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/repo-doctor --help"; then
    test_pass "repo-doctor rejects unknown flags"
  else
    test_fail "repo-doctor rejects unknown flags"
    status=1
  fi

  rm -f "$doctor_help" "$doctor_default_out" "$doctor_quiet_out" "$doctor_quiet_err" "$doctor_explain_out" "$doctor_json_warn" "$doctor_json_warn_err" "$doctor_log_file" "$doctor_no_log_file" "$doctor_no_log_out" "$doctor_json" "$doctor_config_out" "$doctor_timeout_format_stderr" "$doctor_timeout_missing_stderr" "$doctor_timeout_empty_stderr" "$doctor_log_file_format_stderr" "$doctor_log_file_missing_stderr" "$doctor_log_file_empty_stderr" "$doctor_json_level_format_stderr" "$doctor_json_level_missing_stderr" "$doctor_json_level_empty_stderr" "$doctor_check_format_stderr" "$doctor_check_missing_stderr" "$doctor_check_empty_stderr" "$doctor_unknown_stderr" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_repo_doctor_artifact_guard() {
  local status=0
  local artifact_repo=""
  local artifact_pass_json="$smoke_test_base/repo-doctor-artifact-pass-$$.json"
  local artifact_fail_json="$smoke_test_base/repo-doctor-artifact-fail-$$.json"

  artifact_repo="$(smoke_setup_subset_repo)" || {
    test_fail "repo-doctor artifact guard fixture creates a repo"
    return 1
  }

  if (
    cd "$artifact_repo" || return 1
    printf 'tracked scratch file\n' > scratch.txt || return 1
    git add scratch.txt >/dev/null 2>&1 || return 1
    git commit -m "track scratch file" >/dev/null 2>&1 || return 1
    repo-automation/bin/repo-doctor --check=artifact-guard --json --json-level=all > "$artifact_pass_json"
  ) && python -m json.tool "$artifact_pass_json" >/dev/null && \
    smoke_json_assert "$artifact_pass_json" 'data.get("overall_status") == "pass" and any(check.get("name") == "artifact-guard" and check.get("status") == "pass" for check in data.get("checks", []))'; then
    test_pass "repo-doctor artifact guard ignores tracked root files"
  else
    test_fail "repo-doctor artifact guard ignores tracked root files"
    status=1
  fi

  if (
    cd "$artifact_repo" || return 1
    mkdir -p .cache tmp temp || return 1
    printf 'generated root artifact\n' > touched.json || return 1
    printf 'generated root artifact\n' > range.json || return 1
    printf 'generated root artifact\n' > .tmp-guard || return 1
    printf 'generated root artifact\n' > tmp-guard.tmp || return 1
    printf 'generated root artifact\n' > root.log || return 1
    printf 'generated root artifact\n' > tmp-guard.log || return 1
    repo-automation/bin/repo-doctor --check=artifact-guard --json > "$artifact_fail_json"
    result=$?
    [ "$result" -ne 0 ]
  ) && python -m json.tool "$artifact_fail_json" >/dev/null && \
    smoke_json_assert "$artifact_fail_json" 'data.get("overall_status") == "fail" and any(check.get("name") == "artifact-guard" and check.get("status") == "fail" and ".cache/" in check.get("message", "") and "tmp/" in check.get("message", "") and "temp/" in check.get("message", "") and "touched.json" in check.get("message", "") and "range.json" in check.get("message", "") and ".tmp-guard" in check.get("message", "") and "tmp-guard.tmp" in check.get("message", "") and "root.log" in check.get("message", "") and "tmp-guard.log" in check.get("message", "") and "scratch.txt" not in check.get("message", "") for check in data.get("checks", []))'; then
    test_pass "repo-doctor artifact guard detects repo-root artifacts"
  else
    test_fail "repo-doctor artifact guard detects repo-root artifacts"
    status=1
  fi

  rm -f "$artifact_pass_json" "$artifact_fail_json" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_repo_doctor_missing_config() {
  local status=0
  local doctor_missing_json="$smoke_test_base/repo-doctor-missing-config-$$.json"

  if (
    cd "$smoke_test_dir" || return 1
    mv .repo-automation.conf .repo-automation.conf.bak || return 1
    repo-automation/bin/repo-doctor --json --quick > "$doctor_missing_json"
    result=$?
    mv .repo-automation.conf.bak .repo-automation.conf || return 1
    [ "$result" -ne 0 ]
  ) && python -m json.tool "$doctor_missing_json" >/dev/null && \
    smoke_json_assert "$doctor_missing_json" 'data.get("overall_status") == "fail"'; then
    test_pass "repo-doctor missing config fails safely"
  else
    test_fail "repo-doctor missing config fails safely"
    status=1
    (
      cd "$smoke_test_dir" || true
      [ -f .repo-automation.conf ] || mv .repo-automation.conf.bak .repo-automation.conf >/dev/null 2>&1 || true
    )
  fi

  rm -f "$doctor_missing_json" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_github_settings_contract() {
  local status=0
  local github_settings_json="$smoke_test_base/github-settings-check-$$.json"
  local github_settings_repo_json="$smoke_test_base/github-settings-check-repo-$$.json"
  local github_settings_help="$smoke_test_base/github-settings-check-help-$$.txt"
  local github_settings_pass_human="$smoke_test_base/github-settings-check-pass-$$.txt"
  local github_settings_quiet_human="$smoke_test_base/github-settings-check-quiet-$$.txt"
  local github_settings_explain_human="$smoke_test_base/github-settings-check-explain-$$.txt"
  local github_settings_repo_format_stderr="$smoke_test_base/github-settings-check-repo-format.stderr"
  local github_settings_repo_missing_stderr="$smoke_test_base/github-settings-check-repo-missing.stderr"
  local github_settings_repo_empty_stderr="$smoke_test_base/github-settings-check-repo-empty.stderr"
  local github_settings_unknown_stderr="$smoke_test_base/github-settings-check-unknown.stderr"
  local github_settings_doctor_json="$smoke_test_base/repo-doctor-github-settings-$$.json"
  local gh_stub_dir="$smoke_test_base/gh-stub-settings"

  smoke_write_gh_stub "$gh_stub_dir" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/github-settings-check --help > "$github_settings_help"
  ) && grep -Fq -- '--repo=<owner/repo>' "$github_settings_help" && grep -Fq -- '--quiet' "$github_settings_help" && grep -Fq -- '--explain' "$github_settings_help" && ! grep -Fq -- '--repo OWNER/REPO' "$github_settings_help"; then
    test_pass "github-settings-check help shows strict repo syntax"
  else
    test_fail "github-settings-check help shows strict repo syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/github-settings-check > "$github_settings_pass_human" 2>&1
  ) && [ "$(cat "$github_settings_pass_human")" = "pass" ]; then
    test_pass "github-settings-check default human output is compact"
  else
    test_fail "github-settings-check default human output is compact"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/github-settings-check --quiet > "$github_settings_quiet_human" 2>&1
  ) && [ ! -s "$github_settings_quiet_human" ]; then
    test_pass "github-settings-check quiet success is silent"
  else
    test_fail "github-settings-check quiet success is silent"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/github-settings-check --explain > "$github_settings_explain_human" 2>&1
  ) && grep -Eq '^pass=[0-9]+ warn=[0-9]+ fail=[0-9]+ skipped=[0-9]+$' "$github_settings_explain_human" && grep -Eq '^PASS: github-context - ' "$github_settings_explain_human"; then
    test_pass "github-settings-check explain output is detailed"
  else
    test_fail "github-settings-check explain output is detailed"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/github-settings-check --repo=i-schuyler/repo-automation-template --machine-json > "$github_settings_repo_json"
  ) && python -m json.tool "$github_settings_repo_json" >/dev/null && \
    smoke_json_assert "$github_settings_repo_json" 'data.get("overall_status") == "pass" and data.get("repo") == "i-schuyler/repo-automation-template" and data.get("repo_source") == "flag"'; then
    test_pass "github-settings-check accepts explicit repo syntax"
  else
    test_fail "github-settings-check accepts explicit repo syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/github-settings-check --repo i-schuyler/repo-automation-template >/dev/null 2> "$github_settings_repo_format_stderr"
  ); then
    test_fail "github-settings-check rejects --repo <owner/repo>"
    status=1
  elif smoke_assert_flag_error_shape "$github_settings_repo_format_stderr" "flag format not accepted" "--repo" "use --repo=<owner/repo>"; then
    test_pass "github-settings-check rejects --repo <owner/repo>"
  else
    test_fail "github-settings-check rejects --repo <owner/repo>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/github-settings-check --repo >/dev/null 2> "$github_settings_repo_missing_stderr"
  ); then
    test_fail "github-settings-check rejects missing --repo value"
    status=1
  elif smoke_assert_flag_error_shape "$github_settings_repo_missing_stderr" "missing flag value" "--repo" "use --repo=<owner/repo>"; then
    test_pass "github-settings-check rejects missing --repo value"
  else
    test_fail "github-settings-check rejects missing --repo value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/github-settings-check --repo= >/dev/null 2> "$github_settings_repo_empty_stderr"
  ); then
    test_fail "github-settings-check rejects empty --repo value"
    status=1
  elif smoke_assert_flag_error_shape "$github_settings_repo_empty_stderr" "empty flag value" "--repo" "use --repo=<owner/repo>"; then
    test_pass "github-settings-check rejects empty --repo value"
  else
    test_fail "github-settings-check rejects empty --repo value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/github-settings-check --whatever >/dev/null 2> "$github_settings_unknown_stderr"
  ); then
    test_fail "github-settings-check rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$github_settings_unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/github-settings-check --help"; then
    test_pass "github-settings-check rejects unknown flags"
  else
    test_fail "github-settings-check rejects unknown flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/github-settings-check --machine-json > "$github_settings_json"
  ) && python -m json.tool "$github_settings_json" >/dev/null && \
    smoke_json_assert "$github_settings_json" 'data.get("overall_status") == "pass" and data.get("repo") == "i-schuyler/repo-automation-template" and data.get("default_branch") == "main" and data.get("actions_enabled") is True and data.get("pr_template_exists") is True and data.get("issue_templates_exist") is True and data.get("ci_workflow_exists") is True'; then
    test_pass "github-settings-check machine-json is parseable"
  else
    test_fail "github-settings-check machine-json is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/repo-doctor --check=github-settings-readiness --json --json-level=all > "$github_settings_doctor_json"
  ) && python -m json.tool "$github_settings_doctor_json" >/dev/null && \
    smoke_json_assert "$github_settings_doctor_json" 'data.get("overall_status") == "pass" and any(check.get("name") == "github-settings-readiness" and check.get("status") == "pass" for check in data.get("checks", []))'; then
    test_pass "repo-doctor github-settings-readiness check passes"
  else
    test_fail "repo-doctor github-settings-readiness check passes"
    status=1
  fi

  rm -f "$github_settings_json" "$github_settings_repo_json" "$github_settings_help" "$github_settings_repo_format_stderr" "$github_settings_repo_missing_stderr" "$github_settings_repo_empty_stderr" "$github_settings_unknown_stderr" "$github_settings_pass_human" "$github_settings_quiet_human" "$github_settings_explain_human" "$github_settings_doctor_json" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_managed_file_tools_contract() {
  local status=0
  local managed_file_help="$smoke_test_base/managed-file-check-help-$$.txt"
  local managed_file_add_help="$smoke_test_base/managed-file-add-help-$$.txt"
  local managed_file_clean_out="$smoke_test_base/managed-file-check-clean.out"
  local managed_file_clean_err="$smoke_test_base/managed-file-check-clean.err"
  local managed_file_fail_stderr="$smoke_test_base/managed-file-check-fail.stderr"
  local managed_file_add_stderr="$smoke_test_base/managed-file-add.stderr"
  local managed_file_new_path="repo-automation/docs/managed-file-tools-smoke.md"
  local managed_file_manifest_path="$smoke_test_dir/repo-automation/manifest.json"
  local managed_file_installer_path="$smoke_test_dir/repo-automation/bin/repo-automation-install"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/managed-file-check --help > "$managed_file_help"
  ) && grep -Fq -- '--changed' "$managed_file_help" && grep -Fq -- '--quiet' "$managed_file_help" && ! grep -Fq -- '--changed CHANGED' "$managed_file_help"; then
    test_pass "managed-file-check help shows strict flag syntax"
  else
    test_fail "managed-file-check help shows strict flag syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/managed-file-add --help > "$managed_file_add_help"
  ) && grep -Fq -- '--path=<path>' "$managed_file_add_help" && grep -Fq -- '--kind=<kind>' "$managed_file_add_help" && ! grep -Fq -- '--path PATH' "$managed_file_add_help" && ! grep -Fq -- '--kind KIND' "$managed_file_add_help"; then
    test_pass "managed-file-add help shows strict value syntax"
  else
    test_fail "managed-file-add help shows strict value syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/managed-file-add --whatever >/dev/null 2> "$managed_file_add_stderr"
  ); then
    test_fail "managed-file-add rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$managed_file_add_stderr" "unknown flag" "--whatever" "run repo-automation/bin/managed-file-add --help"; then
    test_pass "managed-file-add rejects unknown flags"
  else
    test_fail "managed-file-add rejects unknown flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/managed-file-check --changed > "$managed_file_clean_out" 2> "$managed_file_clean_err"
  ) && [ "$(cat "$managed_file_clean_out")" = "pass" ] && [ ! -s "$managed_file_clean_err" ]; then
    test_pass "managed-file-check prints pass on clean success"
  else
    test_fail "managed-file-check prints pass on clean success"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/managed-file-check --changed --quiet > "$managed_file_clean_out" 2> "$managed_file_clean_err"
  ) && [ ! -s "$managed_file_clean_out" ] && [ ! -s "$managed_file_clean_err" ]; then
    test_pass "managed-file-check quiet output is silent on clean success"
  else
    test_fail "managed-file-check quiet output is silent on clean success"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    printf '# helper smoke\n' > "$managed_file_new_path" || return 1
    repo-automation/bin/managed-file-check --changed >/dev/null 2> "$managed_file_fail_stderr"
  ); then
    test_fail "managed-file-check flags new repo-automation paths for review"
    status=1
  elif grep -Fq 'coverage review required' "$managed_file_fail_stderr"; then
    test_pass "managed-file-check flags new repo-automation paths for review"
  else
    test_fail "managed-file-check flags new repo-automation paths for review"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/managed-file-add --path="$managed_file_new_path" --kind=doc >/dev/null
  ) && python -m json.tool "$managed_file_manifest_path" >/dev/null && \
    grep -Fq -- "\"path\": \"$managed_file_new_path\"" "$managed_file_manifest_path" && \
    grep -Fq -- "\"$managed_file_new_path\"" "$managed_file_installer_path"; then
    test_pass "managed-file-add updates manifest and installer coverage"
  else
    test_fail "managed-file-add updates manifest and installer coverage"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/managed-file-check --changed >/dev/null
  ); then
    test_pass "managed-file-check passes after managed-file-add"
  else
    test_fail "managed-file-check passes after managed-file-add"
    status=1
  fi

  rm -f "$managed_file_help" "$managed_file_add_help" "$managed_file_clean_out" "$managed_file_clean_err" "$managed_file_fail_stderr" "$managed_file_add_stderr" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_shellcheck_ci_parity_contract() {
  local status=0
  local shellcheck_help="$smoke_test_base/shellcheck-ci-parity-help-$$.txt"
  local shellcheck_unknown_stderr="$smoke_test_base/shellcheck-ci-parity-unknown.stderr"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/shellcheck-ci-parity --help > "$shellcheck_help"
  ) && grep -Fq -- 'Usage: repo-automation/bin/shellcheck-ci-parity [--help]' "$shellcheck_help" && grep -Fq -- 'Run ShellCheck against the CI file set with the CI parity exclusion.' "$shellcheck_help"; then
    test_pass "shellcheck-ci-parity help works before shellcheck availability"
  else
    test_fail "shellcheck-ci-parity help works before shellcheck availability"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/shellcheck-ci-parity --whatever >/dev/null 2> "$shellcheck_unknown_stderr"
  ); then
    test_fail "shellcheck-ci-parity rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$shellcheck_unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/shellcheck-ci-parity --help"; then
    test_pass "shellcheck-ci-parity rejects unknown flags"
  else
    test_fail "shellcheck-ci-parity rejects unknown flags"
    status=1
  fi

  rm -f "$shellcheck_help" >/dev/null 2>&1 || true
  return "$status"
}

# repo-automation/tests/lib/contracts/repo-health.sh EOF
