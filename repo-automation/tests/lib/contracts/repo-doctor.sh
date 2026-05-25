# repo-automation/tests/lib/contracts/repo-doctor.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.

smoke_check_repo_doctor_contract() {
  local status=0
  local doctor_help="$smoke_test_base/repo-doctor-help-$$.txt"
  local doctor_default_out="$smoke_test_base/repo-doctor-quick-default-$$.txt"
  local doctor_quiet_out="$smoke_test_base/repo-doctor-quick-quiet-$$.txt"
  local doctor_quiet_err="$smoke_test_base/repo-doctor-quick-quiet-$$.stderr"
  local doctor_explain_out="$smoke_test_base/repo-doctor-quick-explain-$$.txt"
  local doctor_explain_no_log_out="$smoke_test_base/repo-doctor-quick-explain-nolog-$$.txt"
  local doctor_json_warn="$smoke_test_base/repo-doctor-quick-warn-$$.json"
  local doctor_json_warn_err="$smoke_test_base/repo-doctor-quick-warn-$$.stderr"
  local doctor_default_fail_out="$smoke_test_base/repo-doctor-default-fail-$$.txt"
  local doctor_default_fail_err="$smoke_test_base/repo-doctor-default-fail-$$.stderr"
  local doctor_quiet_fail_out="$smoke_test_base/repo-doctor-quiet-fail-$$.txt"
  local doctor_quiet_fail_err="$smoke_test_base/repo-doctor-quiet-fail-$$.stderr"
  local doctor_json_fail="$smoke_test_base/repo-doctor-fail-$$.json"
  local doctor_json_fail_err="$smoke_test_base/repo-doctor-fail-$$.stderr"
  local doctor_explain_fail_out="$smoke_test_base/repo-doctor-explain-fail-$$.txt"
  local doctor_explain_fail_err="$smoke_test_base/repo-doctor-explain-fail-$$.stderr"
  local doctor_remote_repo=""
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
    repo-automation/bin/repo-doctor --check=config --explain --no-log > "$doctor_explain_no_log_out"
  ) && grep -Fxq '===== FINAL SUMMARY =====' "$doctor_explain_no_log_out" && \
    grep -Fxq 'rc=0' "$doctor_explain_no_log_out" && \
    grep -Fxq 'overall_status=pass' "$doctor_explain_no_log_out" && \
    grep -Fxq 'log=none' "$doctor_explain_no_log_out"; then
    test_pass "repo-doctor explain success ends with final summary"
  else
    test_fail "repo-doctor explain success ends with final summary"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --json --check=config --json-level=all > "$doctor_json_warn" 2> "$doctor_json_warn_err"
  ) && [ ! -s "$doctor_json_warn_err" ] && python3 -m json.tool "$doctor_json_warn" >/dev/null && \
    smoke_json_assert "$doctor_json_warn" 'data.get("overall_status") == "pass" and data.get("json_level") == "all" and any(check.get("name") == "config-exists" and check.get("status") == "pass" for check in data.get("checks", []))'; then
    test_pass "repo-doctor json output is parseable"
  else
    test_fail "repo-doctor json output is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    mv .repo-automation.conf .repo-automation.conf.bak || return 1
    repo-automation/bin/repo-doctor --check=config > "$doctor_default_fail_out" 2> "$doctor_default_fail_err"
    result=$?
    mv .repo-automation.conf.bak .repo-automation.conf || return 1
    [ "$result" -ne 0 ]
  ) && [ ! -s "$doctor_default_fail_err" ] && \
    grep -Fxq 'fail: config-exists - missing .repo-automation.conf' "$doctor_default_fail_out" && \
    grep -Fxq 'fix: restore .repo-automation.conf or run from a configured repo' "$doctor_default_fail_out" && \
    ! grep -Fq 'FINAL SUMMARY' "$doctor_default_fail_out"; then
    test_pass "repo-doctor default failure stays compact"
  else
    test_fail "repo-doctor default failure stays compact"
    status=1
    (
      cd "$smoke_test_dir" || true
      [ -f .repo-automation.conf ] || mv .repo-automation.conf.bak .repo-automation.conf >/dev/null 2>&1 || true
    )
  fi

  if (
    cd "$smoke_test_dir" || return 1
    mv .repo-automation.conf .repo-automation.conf.bak || return 1
    repo-automation/bin/repo-doctor --check=config --quiet > "$doctor_quiet_fail_out" 2> "$doctor_quiet_fail_err"
    result=$?
    mv .repo-automation.conf.bak .repo-automation.conf || return 1
    [ "$result" -ne 0 ]
  ) && [ ! -s "$doctor_quiet_fail_err" ] && \
    grep -Fxq 'fail: config-exists - missing .repo-automation.conf' "$doctor_quiet_fail_out" && \
    grep -Fxq 'fix: restore .repo-automation.conf or run from a configured repo' "$doctor_quiet_fail_out"; then
    test_pass "repo-doctor quiet failure prints fix"
  else
    test_fail "repo-doctor quiet failure prints fix"
    status=1
    (
      cd "$smoke_test_dir" || true
      [ -f .repo-automation.conf ] || mv .repo-automation.conf.bak .repo-automation.conf >/dev/null 2>&1 || true
    )
  fi

  doctor_remote_repo="$(smoke_setup_subset_repo)" || {
    test_fail "repo-doctor git failure fixture creates a repo"
    status=1
    doctor_remote_repo=""
  }

  if [ -n "$doctor_remote_repo" ] && (
    cd "$doctor_remote_repo" || return 1
    EXPECTED_REMOTE_URL="https://example.invalid/repo.git" repo-automation/bin/repo-doctor --check=git --json --json-level=all > "$doctor_json_fail" 2> "$doctor_json_fail_err"
    result=$?
    [ "$result" -ne 0 ]
  ) && [ ! -s "$doctor_json_fail_err" ] && python3 -m json.tool "$doctor_json_fail" >/dev/null && \
    smoke_json_assert "$doctor_json_fail" 'data.get("overall_status") == "fail" and data.get("first_failure") == "git-remote-match" and data.get("suggested_fix") == "update EXPECTED_REMOTE_URL in .repo-automation.conf or set the configured git remote URL to match"'; then
    test_pass "repo-doctor json failure is parseable and stdout-only"
  else
    test_fail "repo-doctor json failure is parseable and stdout-only"
    status=1
  fi

  if [ -n "$doctor_remote_repo" ] && (
    cd "$doctor_remote_repo" || return 1
    EXPECTED_REMOTE_URL="https://example.invalid/repo.git" repo-automation/bin/repo-doctor --check=git --explain > "$doctor_explain_fail_out" 2> "$doctor_explain_fail_err"
    result=$?
    [ "$result" -ne 0 ]
  ) && [ ! -s "$doctor_explain_fail_err" ] && \
    grep -Fxq '===== FINAL SUMMARY =====' "$doctor_explain_fail_out" && \
    grep -Fxq 'rc=1' "$doctor_explain_fail_out" && \
    grep -Fxq 'overall_status=fail' "$doctor_explain_fail_out" && \
    grep -Fxq 'first_failure=git-remote-match' "$doctor_explain_fail_out" && \
    grep -Eq '^log=.+$' "$doctor_explain_fail_out" && \
    ! grep -Fxq 'log=none' "$doctor_explain_fail_out" && \
    grep -Fxq 'fix: update EXPECTED_REMOTE_URL in .repo-automation.conf or set the configured git remote URL to match' "$doctor_explain_fail_out" && \
    ! grep -Fq 'fix: repo-automation/bin/repo-doctor --explain' "$doctor_explain_fail_out"; then
    test_pass "repo-doctor explain failure ends with final summary"
  else
    test_fail "repo-doctor explain failure ends with final summary"
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
  ) && python3 -m json.tool "$doctor_json" >/dev/null; then
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
  ) && python3 -m json.tool "$artifact_pass_json" >/dev/null && \
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
  ) && python3 -m json.tool "$artifact_fail_json" >/dev/null && \
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
  ) && python3 -m json.tool "$doctor_missing_json" >/dev/null && \
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

smoke_check_repo_config_local_override_contract() {
  local status=0
  local local_config_path="$smoke_test_dir/.repo-automation.local.conf"

  if {
    cd "$smoke_test_dir" || return 1
    cat > "$local_config_path" <<'EOF'
DEFAULT_BRANCH="trunk"
FINAL_SUMMARY_AFTER_START_HOOK="mark"
FINAL_SUMMARY_BEFORE_END_HOOK="recap"
EOF
    # shellcheck disable=SC1091
    source repo-automation/lib/common.sh && repo_auto_load_config >/dev/null && \
      [ "$CI_PROVIDER" = "github" ] && \
      [ "$CHECK_PROFILE_DEFAULT" = "docs" ] && \
      [ "$DEFAULT_BRANCH" = "trunk" ] && \
      [ "$FINAL_SUMMARY_AFTER_START_HOOK" = "mark" ] && \
      [ "$FINAL_SUMMARY_BEFORE_END_HOOK" = "recap" ]
  }; then
    test_pass "repo-automation config loads local overrides after tracked defaults"
  else
    test_fail "repo-automation config loads local overrides after tracked defaults"
    status=1
  fi

  rm -f "$local_config_path" >/dev/null 2>&1 || true
  return "$status"
}

# repo-automation/tests/lib/contracts/repo-doctor.sh EOF
