# repo-automation/tests/lib/contracts/failure-log.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.



smoke_check_failure_log_contract() {
  local status=0
  local temp_root="$smoke_test_base/failure-log-root"
  local log_root="$temp_root/repo-automation-template"
  local latest_human="$smoke_test_base/failure-log-latest-$$.txt"
  local kind_json="$smoke_test_base/failure-log-kind-$$.json"
  local help_file="$smoke_test_base/failure-log-help-$$.txt"
  local kind_format_stderr="$smoke_test_base/failure-log-kind-format-$$.txt"
  local kind_missing_stderr="$smoke_test_base/failure-log-kind-missing-$$.txt"
  local kind_empty_stderr="$smoke_test_base/failure-log-kind-empty-$$.txt"
  local lines_format_stderr="$smoke_test_base/failure-log-lines-format-$$.txt"
  local lines_missing_stderr="$smoke_test_base/failure-log-lines-missing-$$.txt"
  local lines_empty_stderr="$smoke_test_base/failure-log-lines-empty-$$.txt"
  local kind_unknown_stderr="$smoke_test_base/failure-log-kind-unknown-$$.txt"

  mkdir -p "$log_root" || return 1
  cat > "$log_root/run-tests-20260512-110000.log" <<'EOF'
INFO: run-tests old
FAIL: old run-tests failure
EOF
  cat > "$log_root/run-tests-20260512-120000.log" <<'EOF'
INFO: run-tests latest
FAIL: latest run-tests failure
detail one
detail two
EOF
  cat > "$log_root/repo-doctor-20260512-130000.log" <<'EOF'
INFO: repo-doctor latest
FAIL: latest repo-doctor failure
detail one
detail two
detail three
EOF
  touch -t 202605121100.00 "$log_root/run-tests-20260512-110000.log" || return 1
  touch -t 202605121200.00 "$log_root/run-tests-20260512-120000.log" || return 1
  touch -t 202605121300.00 "$log_root/repo-doctor-20260512-130000.log" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/failure-log --help > "$help_file"
  ) && \
    grep -Fq -- '--kind=<run-tests|repo-doctor|any>' "$help_file" && \
    grep -Fq -- '--lines=<lines>' "$help_file" && \
    ! grep -Fq -- '--kind=run-tests|repo-doctor|any' "$help_file" && \
    ! grep -Fq -- '--lines=N' "$help_file"; then
    test_pass "failure-log help shows strict value syntax"
  else
    test_fail "failure-log help shows strict value syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$temp_root" repo-automation/bin/failure-log --latest > "$latest_human"
  ) && grep -Eq "^Latest failure log: .*/repo-doctor-20260512-130000\.log$" "$latest_human" && grep -Eq '^FAIL: latest repo-doctor failure$' "$latest_human"; then
    test_pass "failure-log latest human output selects newest matching log"
  else
    test_fail "failure-log latest human output selects newest matching log"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$temp_root" repo-automation/bin/failure-log --kind=run-tests --lines=2 --machine-json > "$kind_json"
  ) && python3 -m json.tool "$kind_json" >/dev/null &&     smoke_json_assert "$kind_json" 'data.get("script") == "failure-log" and data.get("kind") == "run-tests" and data.get("lines") == 2 and data.get("log_file", "").endswith("run-tests-20260512-120000.log") and len(data.get("excerpt", [])) == 2 and "FAIL: latest run-tests failure" in data.get("excerpt", [])'; then
    test_pass "failure-log kind filter, line limits, and machine-json work"
  else
    test_fail "failure-log kind filter, line limits, and machine-json work"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$temp_root" repo-automation/bin/failure-log --kind run-tests >/dev/null 2> "$kind_format_stderr"
  ); then
    test_fail "failure-log rejects --kind <value>"
    status=1
  elif smoke_assert_flag_error_shape "$kind_format_stderr" "flag format not accepted" "--kind" "use --kind=<run-tests|repo-doctor|any>"; then
    test_pass "failure-log rejects --kind <value>"
  else
    test_fail "failure-log rejects --kind <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$temp_root" repo-automation/bin/failure-log --kind >/dev/null 2> "$kind_missing_stderr"
  ); then
    test_fail "failure-log rejects missing --kind value"
    status=1
  elif smoke_assert_flag_error_shape "$kind_missing_stderr" "missing flag value" "--kind" "use --kind=<run-tests|repo-doctor|any>"; then
    test_pass "failure-log rejects missing --kind value"
  else
    test_fail "failure-log rejects missing --kind value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$temp_root" repo-automation/bin/failure-log --kind= >/dev/null 2> "$kind_empty_stderr"
  ); then
    test_fail "failure-log rejects empty --kind value"
    status=1
  elif smoke_assert_flag_error_shape "$kind_empty_stderr" "empty flag value" "--kind" "use --kind=<run-tests|repo-doctor|any>"; then
    test_pass "failure-log rejects empty --kind value"
  else
    test_fail "failure-log rejects empty --kind value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$temp_root" repo-automation/bin/failure-log --lines 2 >/dev/null 2> "$lines_format_stderr"
  ); then
    test_fail "failure-log rejects --lines <value>"
    status=1
  elif smoke_assert_flag_error_shape "$lines_format_stderr" "flag format not accepted" "--lines" "use --lines=<lines>"; then
    test_pass "failure-log rejects --lines <value>"
  else
    test_fail "failure-log rejects --lines <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$temp_root" repo-automation/bin/failure-log --lines >/dev/null 2> "$lines_missing_stderr"
  ); then
    test_fail "failure-log rejects missing --lines value"
    status=1
  elif smoke_assert_flag_error_shape "$lines_missing_stderr" "missing flag value" "--lines" "use --lines=<lines>"; then
    test_pass "failure-log rejects missing --lines value"
  else
    test_fail "failure-log rejects missing --lines value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$temp_root" repo-automation/bin/failure-log --lines= >/dev/null 2> "$lines_empty_stderr"
  ); then
    test_fail "failure-log rejects empty --lines value"
    status=1
  elif smoke_assert_flag_error_shape "$lines_empty_stderr" "empty flag value" "--lines" "use --lines=<lines>"; then
    test_pass "failure-log rejects empty --lines value"
  else
    test_fail "failure-log rejects empty --lines value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$temp_root" repo-automation/bin/failure-log --whatever >/dev/null 2> "$kind_unknown_stderr"
  ); then
    test_fail "failure-log rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$kind_unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/failure-log --help"; then
    test_pass "failure-log rejects unknown flags"
  else
    test_fail "failure-log rejects unknown flags"
    status=1
  fi

  rm -f "$latest_human" "$kind_json" >/dev/null 2>&1 || true
  rm -f "$help_file" "$kind_format_stderr" "$kind_missing_stderr" "$kind_empty_stderr" "$lines_format_stderr" "$lines_missing_stderr" "$lines_empty_stderr" "$kind_unknown_stderr" >/dev/null 2>&1 || true
  rm -f "$log_root"/run-tests-20260512-110000.log "$log_root"/run-tests-20260512-120000.log "$log_root"/repo-doctor-20260512-130000.log >/dev/null 2>&1 || true
  rmdir "$log_root" "$temp_root" >/dev/null 2>&1 || true
  return "$status"
}

# repo-automation/tests/lib/contracts/failure-log.sh EOF
