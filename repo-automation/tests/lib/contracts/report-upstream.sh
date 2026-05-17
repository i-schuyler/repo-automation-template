# repo-automation/tests/lib/contracts/report-upstream.sh

# shellcheck shell=bash



smoke_check_report_upstream_preview() {
  local status=0
  local report_bug_json="$smoke_test_base/report-upstream-bug-$$.json"
  local report_feature_json="$smoke_test_base/report-upstream-feature-$$.json"
  local report_preview_bug="$smoke_test_base/report-upstream-bug-preview-$$.md"
  local report_preview_feature="$smoke_test_base/report-upstream-feature-preview-$$.md"
  local report_type_format_stderr="$smoke_test_base/report-upstream-type-format-$$.stderr"
  local report_type_missing_stderr="$smoke_test_base/report-upstream-type-missing-$$.stderr"
  local report_type_empty_stderr="$smoke_test_base/report-upstream-type-empty-$$.stderr"
  local report_unknown_stderr="$smoke_test_base/report-upstream-unknown-$$.stderr"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-report-upstream \
      --type=bug \
      --title="Bug smoke" \
      --command="repo-automation/bin/example --flag" \
      --expected=works \
      --actual=fails \
      --dry-run \
      --json \
      --preview-file="$report_preview_bug" > "$report_bug_json"
  ) && python -m json.tool "$report_bug_json" >/dev/null && [ -f "$report_preview_bug" ]; then
    test_pass "report-upstream bug dry-run/json preview succeeds"
  else
    test_fail "report-upstream bug dry-run/json preview succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-report-upstream \
      --type=feature \
      --title="Feature smoke" \
      --use-case="repeat docs churn" \
      --proposed="better helper" \
      --why-upstream="shared contract" \
      --dry-run \
      --json \
      --preview-file="$report_preview_feature" > "$report_feature_json"
  ) && python -m json.tool "$report_feature_json" >/dev/null && [ -f "$report_preview_feature" ]; then
    test_pass "report-upstream feature dry-run/json preview succeeds"
  else
    test_fail "report-upstream feature dry-run/json preview succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-report-upstream --type bug >/dev/null 2> "$report_type_format_stderr"
  ); then
    test_fail "report-upstream rejects --type <value>"
    status=1
  elif smoke_assert_flag_error_shape "$report_type_format_stderr" "flag format not accepted" "--type" "use --type=<bug|feature>"; then
    test_pass "report-upstream rejects --type <value>"
  else
    test_fail "report-upstream rejects --type <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-report-upstream --type >/dev/null 2> "$report_type_missing_stderr"
  ); then
    test_fail "report-upstream rejects missing --type value"
    status=1
  elif smoke_assert_flag_error_shape "$report_type_missing_stderr" "missing flag value" "--type" "use --type=<bug|feature>"; then
    test_pass "report-upstream rejects missing --type value"
  else
    test_fail "report-upstream rejects missing --type value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-report-upstream --type= >/dev/null 2> "$report_type_empty_stderr"
  ); then
    test_fail "report-upstream rejects empty --type value"
    status=1
  elif smoke_assert_flag_error_shape "$report_type_empty_stderr" "empty flag value" "--type" "use --type=<bug|feature>"; then
    test_pass "report-upstream rejects empty --type value"
  else
    test_fail "report-upstream rejects empty --type value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-report-upstream --whatever >/dev/null 2> "$report_unknown_stderr"
  ); then
    test_fail "report-upstream rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$report_unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/repo-automation-report-upstream --help"; then
    test_pass "report-upstream rejects unknown flags"
  else
    test_fail "report-upstream rejects unknown flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-report-upstream --type=bug --dry-run >/dev/null 2>&1
  ); then
    test_fail "report-upstream missing title fails safely"
    status=1
  else
    test_pass "report-upstream missing title fails safely"
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-report-upstream --type=wrong --title="Invalid type" --dry-run >/dev/null 2>&1
  ); then
    test_fail "report-upstream invalid type fails safely"
    status=1
  else
    test_pass "report-upstream invalid type fails safely"
  fi

  rm -f "$report_bug_json" "$report_feature_json" "$report_preview_bug" "$report_preview_feature" "$report_type_format_stderr" "$report_type_missing_stderr" "$report_type_empty_stderr" "$report_unknown_stderr" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_report_upstream_secret_scan() {
  local status=0
  local report_secret_json="$smoke_test_base/report-upstream-secret-$$.json"

  if (
    cd "$smoke_test_dir" || return 1
    printf 'token=supersecret\n' > logs-secret.txt || return 1
    repo-automation/bin/repo-automation-report-upstream \
      --type=bug \
      --title="Secret scan smoke" \
      --logs-file=logs-secret.txt \
      --dry-run \
      --json > "$report_secret_json"
    return 1
  ); then
    test_fail "report-upstream secret scan blocks likely secret logs"
    status=1
  else
    if python -m json.tool "$report_secret_json" >/dev/null && \
      smoke_json_assert "$report_secret_json" 'data.get("redaction_scan") == "blocked"'; then
      test_pass "report-upstream secret scan blocks likely secret logs"
    else
      test_fail "report-upstream secret scan blocks likely secret logs"
      status=1
    fi
  fi

  if (
    cd "$smoke_test_dir" || return 1
    rm -f logs-secret.txt || return 1
  ); then
    :
  fi

  rm -f "$report_secret_json" >/dev/null 2>&1 || true
  return "$status"
}

# repo-automation/tests/lib/contracts/report-upstream.sh EOF
