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
  local run_tests_clean_temp_tmpdir="$smoke_test_base/run-tests-clean-temp-tmp-$$"
  local run_tests_clean_temp_out="$smoke_test_base/run-tests-clean-temp-fail-$$.txt"
  local run_tests_clean_temp_err="$smoke_test_base/run-tests-clean-temp-fail-$$.stderr"
  local run_tests_clean_temp_json="$smoke_test_base/run-tests-clean-temp-fail-$$.json"
  local run_tests_clean_temp_json_err="$smoke_test_base/run-tests-clean-temp-fail-$$.json.stderr"
  local run_tests_no_clean_tmpdir="$smoke_test_base/run-tests-no-clean-tmp-$$"
  local run_tests_no_clean_out="$smoke_test_base/run-tests-no-clean-$$.txt"
  local run_tests_no_clean_err="$smoke_test_base/run-tests-no-clean-$$.stderr"
  local run_tests_no_clean_json="$smoke_test_base/run-tests-no-clean-$$.json"
  local run_tests_no_clean_json_err="$smoke_test_base/run-tests-no-clean-$$.json.stderr"
  local run_tests_explicit_log="$smoke_test_base/run-tests-explicit-$$.log"
  local run_tests_explicit_out="$smoke_test_base/run-tests-explicit-$$.txt"
  local run_tests_explicit_err="$smoke_test_base/run-tests-explicit-$$.stderr"
  local run_tests_explicit_json="$smoke_test_base/run-tests-explicit-$$.json"
  local run_tests_explicit_json_err="$smoke_test_base/run-tests-explicit-$$.json.stderr"
  local run_tests_footer_order_out="$smoke_test_base/run-tests-footer-order-$$.txt"
  local run_tests_footer_omit_out="$smoke_test_base/run-tests-footer-omit-$$.txt"
  local run_tests_stale_tmpdir="$smoke_test_base/run-tests-stale-tmp-$$"
  local run_tests_stale_root="$run_tests_stale_tmpdir/repo-automation-template"
  local run_tests_stale_dir="$run_tests_stale_root/run-tests-stale-$$"
  local run_tests_stale_file="$run_tests_stale_root/run-tests-smoke-stale-$$.log"
  local run_tests_stale_fresh_dir="$run_tests_stale_root/run-tests-fresh-$$"
  local run_tests_stale_fresh_file="$run_tests_stale_fresh_dir/fresh.log"
  local run_tests_low_disk_tmpdir="$smoke_test_base/run-tests-low-disk-tmp-$$"
  local run_tests_low_disk_stub_dir="$smoke_test_base/run-tests-low-disk-stub-$$"
  local run_tests_low_disk_out="$smoke_test_base/run-tests-low-disk-$$.txt"
  local run_tests_low_disk_err="$smoke_test_base/run-tests-low-disk-$$.stderr"
  local run_tests_low_disk_marker="$smoke_test_base/run-tests-low-disk-marker-$$"
  local run_tests_low_disk_changed_repo=""
  local run_tests_low_bytes_config_out="$smoke_test_base/run-tests-low-bytes-config-$$.txt"
  local run_tests_low_bytes_config_err="$smoke_test_base/run-tests-low-bytes-config-$$.stderr"
  local run_tests_low_bytes_env_out="$smoke_test_base/run-tests-low-bytes-env-$$.txt"
  local run_tests_low_bytes_env_err="$smoke_test_base/run-tests-low-bytes-env-$$.stderr"
  local run_tests_low_percent_config_out="$smoke_test_base/run-tests-low-percent-config-$$.txt"
  local run_tests_low_percent_config_err="$smoke_test_base/run-tests-low-percent-config-$$.stderr"
  local run_tests_invalid_percent_err="$smoke_test_base/run-tests-invalid-percent-$$.stderr"
  local run_tests_temp_warn_out="$smoke_test_base/run-tests-temp-warn-$$.txt"
  local run_tests_temp_warn_err="$smoke_test_base/run-tests-temp-warn-$$.stderr"
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
  local run_tests_shellcheck_ci_parity_backup="$smoke_test_base/run-tests-shellcheck-ci-parity-backup-$$.sh"
  local run_tests_shellcheck_ci_parity_log="$smoke_test_base/run-tests-shellcheck-ci-parity-$$.args"
  local run_tests_shellcheck_ci_parity_path="$smoke_test_dir/repo-automation/bin/shellcheck-ci-parity"
  local run_tests_shellcheck_stub_dir="$smoke_test_base/run-tests-shellcheck-stub-$$"
  local run_tests_shellcheck_stub_log="$smoke_test_base/run-tests-shellcheck-stub-$$.args"
  local run_tests_shellcheck_focus_out="$smoke_test_base/run-tests-shellcheck-focus-$$.txt"
  local run_tests_shellcheck_focus_log="$smoke_test_base/run-tests-shellcheck-focus-$$.log"
  local run_tests_shellcheck_target="$smoke_test_dir/repo-automation/tests/lib/contracts/repo-health.sh"
  local run_tests_shellcheck_target_backup="$smoke_test_base/run-tests-repo-health-backup-$$.sh"
  local run_tests_shellcheck_readme_backup="$smoke_test_base/run-tests-readme-backup-$$.md"
  local run_tests_shellcheck_docs_backup="$smoke_test_base/run-tests-docs-backup-$$"
  local run_tests_temp_disk_path="$smoke_test_dir/repo-automation/lib/temp-disk.sh"
  local run_tests_temp_disk_backup="$smoke_test_base/run-tests-temp-disk-backup-$$.sh"
  local run_tests_missing_temp_disk_out="$smoke_test_base/run-tests-missing-temp-disk-$$.txt"
  local run_tests_missing_temp_disk_err="$smoke_test_base/run-tests-missing-temp-disk-$$.stderr"
  local run_tests_invalid_clean_stale_out="$smoke_test_base/run-tests-invalid-clean-stale-$$.txt"
  local run_tests_invalid_clean_stale_err="$smoke_test_base/run-tests-invalid-clean-stale-$$.stderr"
  local run_tests_secret_config_marker="$smoke_test_base/run-tests-secret-config-sourced-$$"
  local run_tests_secret_config_json="$smoke_test_base/run-tests-secret-config-$$.json"
  local run_tests_secret_config_json_err="$smoke_test_base/run-tests-secret-config-$$.json.stderr"
  local run_tests_secret_config_explain="$smoke_test_base/run-tests-secret-config-$$.explain.txt"
  local run_tests_secret_config_explain_err="$smoke_test_base/run-tests-secret-config-$$.explain.stderr"
  local run_tests_secret_config_quiet="$smoke_test_base/run-tests-secret-config-$$.quiet.txt"
  local run_tests_secret_config_quiet_err="$smoke_test_base/run-tests-secret-config-$$.quiet.stderr"
  local run_tests_secret_config_source_out="$smoke_test_base/run-tests-secret-source-$$.txt"
  local run_tests_secret_config_source_err="$smoke_test_base/run-tests-secret-source-$$.stderr"
  local run_tests_secret_config_source_marker="$smoke_test_base/run-tests-secret-source-executed-$$"

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

  if [ -f "$run_tests_temp_disk_path" ]; then
    test_pass "smoke fixture copies temp-disk library"
  else
    test_fail "smoke fixture copies temp-disk library"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    mv "$run_tests_temp_disk_path" "$run_tests_temp_disk_backup" || return 1
    repo-automation/bin/run-tests --docs --quiet >"$run_tests_missing_temp_disk_out" 2>"$run_tests_missing_temp_disk_err"
    rc=$?
    mv "$run_tests_temp_disk_backup" "$run_tests_temp_disk_path" || return 1
    exit "$rc"
  ); then
    test_fail "run-tests requires active checkout temp-disk library"
    status=1
  elif [ ! -s "$run_tests_missing_temp_disk_out" ] &&
    grep -Fxq 'STOP: missing required library: repo-automation/lib/temp-disk.sh' "$run_tests_missing_temp_disk_err"; then
    test_pass "run-tests requires active checkout temp-disk library"
  else
    test_fail "run-tests requires active checkout temp-disk library"
    status=1
    mv "$run_tests_temp_disk_backup" "$run_tests_temp_disk_path" >/dev/null 2>&1 || true
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
    repo_auto_print_failure_footer \
      fail "run-tests footer failure" \
      log "$run_tests_log_file" \
      excerpt "$(printf 'first line\nsecond line')" \
      fix "run-tests footer fix" > "$run_tests_footer_order_out"
  ) && [ "$(cat "$run_tests_footer_order_out")" = "$(printf 'fail: run-tests footer failure\nlog: %s\nexcerpt:\nfirst line\nsecond line\nfix: run-tests footer fix\n' "$run_tests_log_file")" ]; then
    test_pass "shared failure footer prints fields in order"
  else
    test_fail "shared failure footer prints fields in order"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    repo_auto_print_failure_footer \
      fail "run-tests footer failure" \
      log none \
      excerpt "$(printf 'first line\nsecond line')" \
      fix "run-tests footer fix" > "$run_tests_footer_omit_out"
  ) && [ "$(cat "$run_tests_footer_omit_out")" = "$(printf 'fail: run-tests footer failure\nexcerpt:\nfirst line\nsecond line\nfix: run-tests footer fix\n')" ] && ! grep -Fq 'log: none' "$run_tests_footer_omit_out"; then
    test_pass "shared failure footer omits empty fields"
  else
    test_fail "shared failure footer omits empty fields"
    status=1
  fi
  if (
    cd "$smoke_repo_root" || return 1
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --explain > "$run_tests_explain_out"
  ) && grep -Eq '^TEST_TEMP_ROOT=' "$run_tests_explain_out" && grep -Eq '^temp_cleanup=enabled$' "$run_tests_explain_out" && grep -Eq '^stale_temp_hours=12$' "$run_tests_explain_out" && grep -Eq '^disk_guard=enabled$' "$run_tests_explain_out" && grep -Eq '^log_policy=run-temp-cleaned-by-default$' "$run_tests_explain_out" && grep -Eq '^PASS: repo-automation/tests/docs-check.sh - passed' "$run_tests_explain_out"; then
    test_pass "run-tests explain output shows details"
  else
    test_fail "run-tests explain output shows details"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --json --json-level=warn > "$run_tests_json" 2> "$run_tests_json_err"
  ) && [ ! -s "$run_tests_json_err" ] && python3 -m json.tool "$run_tests_json" >/dev/null && \
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
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --quiet --log-file="$run_tests_failure_log" > "$run_tests_failure_out"
  ); then
    test_fail "run-tests quiet failure references the log file"
    status=1
  elif grep -Fq "log: $run_tests_failure_log" "$run_tests_failure_out" &&
    grep -Fq 'fail: repo-automation/tests/docs-check.sh' "$run_tests_failure_out" &&
    grep -Fq 'first failure: docs-check: docs index coverage' "$run_tests_failure_out" &&
    grep -Fq 'fix: inspect log and run focused check: repo-automation/tests/docs-check.sh --quiet' "$run_tests_failure_out" &&
    grep -Fq 'COMMAND: repo-automation/tests/docs-check.sh' "$run_tests_failure_log" &&
    grep -Fq 'FAIL: docs-check: docs index coverage:' "$run_tests_failure_log"; then
    test_pass "run-tests quiet failure references the log file"
  else
    test_fail "run-tests quiet failure references the log file"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --log-file="$run_tests_failure_log" > "$run_tests_default_out" 2>&1
  ); then
    test_fail "run-tests default failure with log file reports first failure"
    status=1
  elif grep -Fq 'fail: repo-automation/tests/docs-check.sh' "$run_tests_default_out" &&
    grep -Fq 'first failure: docs-check: docs index coverage' "$run_tests_default_out" &&
    grep -Fq 'log: '"$run_tests_failure_log" "$run_tests_default_out" &&
    grep -Fq 'fix: inspect log and run focused check: repo-automation/tests/docs-check.sh --quiet' "$run_tests_default_out" &&
    ! grep -Fq 'fix: Next: repo-automation/bin/run-tests --explain' "$run_tests_default_out"; then
    test_pass "run-tests default failure with log file reports first failure"
  else
    test_fail "run-tests default failure with log file reports first failure"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --explain > "$run_tests_explain_out" 2>&1
  ); then
    test_fail "run-tests explain failure recommends a better next step"
    status=1
  elif grep -Fxq 'log: cleaned' "$run_tests_explain_out" &&
    grep -Fxq 'fix: use --log-file=<path> or --no-clean-temp for durable logs' "$run_tests_explain_out" &&
    grep -Fq 'excerpt:' "$run_tests_explain_out" &&
    ! grep -Fq 'fix: Next: repo-automation/bin/run-tests --explain' "$run_tests_explain_out"; then
    test_pass "run-tests explain failure recommends a better next step"
  else
    test_fail "run-tests explain failure recommends a better next step"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    REPO_AUTOMATION_STALE_TEMP_HOURS=24 RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --explain > "$run_tests_explain_out" 2>&1 || true
  ) && grep -Fxq 'stale_temp_hours=24' "$run_tests_explain_out"; then
    test_pass "run-tests explain reflects stale temp hour overrides"
  else
    test_fail "run-tests explain reflects stale temp hour overrides"
    status=1
  fi

  rm -f "$smoke_test_dir/docs/run-tests-diagnostic.md" >/dev/null 2>&1 || true

  if (
    cd "$smoke_test_dir" || return 1
    cp "$smoke_test_dir/README.md" "$run_tests_shellcheck_readme_backup" || return 1
    cp -R "$smoke_test_dir/docs" "$run_tests_shellcheck_docs_backup" || return 1
    cp "$smoke_repo_root/README.md" "$smoke_test_dir/README.md" || return 1
    cp "$smoke_repo_root/LICENSE" "$smoke_test_dir/LICENSE" || return 1
    cp -R "$smoke_repo_root/docs" "$smoke_test_dir/" || return 1
    mkdir -p "$run_tests_shellcheck_stub_dir" || return 1
    cp "$run_tests_shellcheck_ci_parity_path" "$run_tests_shellcheck_ci_parity_backup" || return 1
    cp "$run_tests_shellcheck_target" "$run_tests_shellcheck_target_backup" || return 1
    cat > "$run_tests_shellcheck_ci_parity_path" <<EOF
#!/usr/bin/env bash
set -u
set -o pipefail

printf '%s\n' "\$@" > "$run_tests_shellcheck_ci_parity_log"

case "\${1:-}" in
  --print-paths)
    printf '%s\n' \
      repo-automation/bin/check-portability \
      repo-automation/bin/shellcheck-ci-parity
    ;;
  *)
    printf 'unexpected shellcheck-ci-parity args\n' >&2
    exit 1
    ;;
esac
EOF
    chmod +x "$run_tests_shellcheck_ci_parity_path" || return 1
    cat > "$run_tests_shellcheck_stub_dir/shellcheck" <<EOF
#!/usr/bin/env bash
set -u
set -o pipefail

printf '%s\n' "\$@" > "$run_tests_shellcheck_stub_log"

case "\${REPO_AUTOMATION_SHELLCHECK_MODE:-verify}" in
  verify)
    if [ "\${1:-}" != "-e" ] || [ "\${2:-}" != "SC2317" ]; then
      printf 'unexpected shellcheck flags\n' >&2
      exit 1
    fi
    shift 2
    if [ "\$#" -ne 2 ] ||
      [ "\$1" != "repo-automation/bin/check-portability" ] ||
      [ "\$2" != "repo-automation/bin/shellcheck-ci-parity" ]; then
      printf 'unexpected shellcheck paths\n' >&2
      exit 1
    fi
    ;;
  fail-focus)
    printf 'shellcheck simulated failure\n' >&2
    exit 1
    ;;
  *)
    printf 'unexpected shellcheck mode\n' >&2
    exit 1
    ;;
esac
EOF
    chmod +x "$run_tests_shellcheck_stub_dir/shellcheck" || return 1
    printf '\nif true; then\n' >> "$run_tests_shellcheck_target"
    PATH="$run_tests_shellcheck_stub_dir:$PATH" RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --quiet >"$run_tests_shellcheck_focus_out" 2>"$run_tests_shellcheck_focus_log"
  ); then
    :
  else
    test_fail "run-tests full mode uses shellcheck-ci-parity paths"
    status=1
  fi

  if [ ! -s "$run_tests_shellcheck_focus_out" ] && [ ! -s "$run_tests_shellcheck_focus_log" ]; then
    test_pass "run-tests full mode stays compact with shellcheck-ci-parity paths"
  else
    test_fail "run-tests full mode stays compact with shellcheck-ci-parity paths"
    status=1
  fi

  if grep -Fqx -- '--print-paths' "$run_tests_shellcheck_ci_parity_log"; then
    test_pass "run-tests shellcheck path discovery calls shellcheck-ci-parity --print-paths"
  else
    test_fail "run-tests shellcheck path discovery calls shellcheck-ci-parity --print-paths"
    status=1
  fi

  if grep -Fqx -- 'repo-automation/bin/check-portability' "$run_tests_shellcheck_stub_log" &&
    grep -Fqx -- 'repo-automation/bin/shellcheck-ci-parity' "$run_tests_shellcheck_stub_log" &&
    ! grep -Fq -- 'repo-automation/tests/lib/contracts/repo-health.sh' "$run_tests_shellcheck_stub_log"; then
    test_pass "run-tests shellcheck uses generated paths and skips the old broad find"
  else
    test_fail "run-tests shellcheck uses generated paths and skips the old broad find"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    cp "$run_tests_shellcheck_target_backup" "$run_tests_shellcheck_target" || return 1
    REPO_AUTOMATION_SHELLCHECK_MODE=fail-focus PATH="$run_tests_shellcheck_stub_dir:$PATH" RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --quiet --log-file="$run_tests_shellcheck_focus_log" >"$run_tests_shellcheck_focus_out" 2>&1
  ); then
    test_fail "run-tests shellcheck failure points to shellcheck-ci-parity"
    status=1
  elif grep -Fq 'fail: shellcheck repo-automation scripts and tests' "$run_tests_shellcheck_focus_out" &&
    grep -Fq 'fix: inspect log and run focused check: repo-automation/bin/shellcheck-ci-parity' "$run_tests_shellcheck_focus_out"; then
    test_pass "run-tests shellcheck failure points to shellcheck-ci-parity"
  else
    test_fail "run-tests shellcheck failure points to shellcheck-ci-parity"
    status=1
  fi

  cp "$run_tests_shellcheck_readme_backup" "$smoke_test_dir/README.md" >/dev/null 2>&1 || true
  rm -rf "$smoke_test_dir/docs" >/dev/null 2>&1 || true
  cp -R "$run_tests_shellcheck_docs_backup" "$smoke_test_dir/docs" >/dev/null 2>&1 || true
  rm -f "$smoke_test_dir/LICENSE" >/dev/null 2>&1 || true
  cp "$run_tests_shellcheck_ci_parity_backup" "$run_tests_shellcheck_ci_parity_path" >/dev/null 2>&1 || true
  cp "$run_tests_shellcheck_target_backup" "$run_tests_shellcheck_target" >/dev/null 2>&1 || true
  rm -f "$run_tests_shellcheck_readme_backup" "$run_tests_shellcheck_ci_parity_backup" "$run_tests_shellcheck_target_backup" >/dev/null 2>&1 || true
  rm -rf "$run_tests_shellcheck_docs_backup" >/dev/null 2>&1 || true
  rm -f "$run_tests_shellcheck_ci_parity_log" "$run_tests_shellcheck_stub_log" "$run_tests_shellcheck_focus_out" "$run_tests_shellcheck_focus_log" >/dev/null 2>&1 || true
  rm -rf "$run_tests_shellcheck_stub_dir" >/dev/null 2>&1 || true

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
    cat > repo-automation/tests/docs-check.sh <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail
printf 'docs-check fail\n' >&2
exit 1
EOF
    chmod +x repo-automation/tests/docs-check.sh || return 1
    TMPDIR="$run_tests_clean_temp_tmpdir" RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --quiet --clean-temp > "$run_tests_clean_temp_out" 2> "$run_tests_clean_temp_err"
  ); then
    test_fail "run-tests clean-temp removes run-owned temp output on failure"
    status=1
  elif grep -Eq '^fail: repo-automation/tests/docs-check.sh' "$run_tests_clean_temp_out" &&
    grep -Fxq 'log: cleaned' "$run_tests_clean_temp_out" &&
    grep -Fxq 'fix: use --log-file=<path> or --no-clean-temp for durable logs' "$run_tests_clean_temp_out" &&
    grep -Fq 'excerpt:' "$run_tests_clean_temp_out" &&
    grep -Fq 'COMMAND: repo-automation/tests/docs-check.sh' "$run_tests_clean_temp_out" &&
    grep -Fq 'docs-check fail' "$run_tests_clean_temp_out" &&
    ! grep -Eq '^log: /' "$run_tests_clean_temp_out"; then
    test_pass "run-tests clean-temp removes run-owned temp output on failure"
  else
    test_fail "run-tests clean-temp removes run-owned temp output on failure"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    cat > repo-automation/tests/docs-check.sh <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail
printf 'docs-check fail\n' >&2
exit 1
EOF
    chmod +x repo-automation/tests/docs-check.sh || return 1
    TMPDIR="$run_tests_clean_temp_tmpdir" RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --json --json-level=warn --clean-temp > "$run_tests_clean_temp_json" 2> "$run_tests_clean_temp_json_err"
  ); then
    test_fail "run-tests JSON clean-temp failure reports cleaned log policy"
    status=1
  elif [ ! -s "$run_tests_clean_temp_json_err" ] && python3 -m json.tool "$run_tests_clean_temp_json" >/dev/null &&
    smoke_json_assert "$run_tests_clean_temp_json" 'data.get("log_status") == "cleaned" and data.get("log_policy") == "run-temp-cleaned-by-default" and data.get("log_file") in ("", None) and data.get("log_fix") == "use --log-file=<path> or --no-clean-temp for durable logs"'; then
    test_pass "run-tests JSON clean-temp failure reports cleaned log policy"
  else
    test_fail "run-tests JSON clean-temp failure reports cleaned log policy"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    cat > repo-automation/tests/docs-check.sh <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail
printf 'docs-check fail\n' >&2
exit 1
EOF
    chmod +x repo-automation/tests/docs-check.sh || return 1
    TMPDIR="$run_tests_no_clean_tmpdir" RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --quiet --no-clean-temp > "$run_tests_no_clean_out" 2> "$run_tests_no_clean_err"
  ); then
    test_fail "run-tests no-clean-temp preserves run-owned temp output on failure"
    status=1
  elif grep -Eq '^fail: repo-automation/tests/docs-check.sh' "$run_tests_no_clean_out" &&
    grep -Fq "log: " "$run_tests_no_clean_out"; then
    no_clean_log_file="$(awk '/^log: / {print $2; exit}' "$run_tests_no_clean_out")"
    if [ -n "$no_clean_log_file" ] && [ -e "$no_clean_log_file" ] && [ -d "$(dirname "$no_clean_log_file")" ] && grep -Fq "log: $no_clean_log_file" "$run_tests_no_clean_out"; then
      test_pass "run-tests no-clean-temp preserves run-owned temp output on failure"
    else
      test_fail "run-tests no-clean-temp preserves run-owned temp output on failure"
      status=1
    fi
  else
    test_fail "run-tests no-clean-temp preserves run-owned temp output on failure"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    cat > repo-automation/tests/docs-check.sh <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail
printf 'docs-check fail\n' >&2
exit 1
EOF
    chmod +x repo-automation/tests/docs-check.sh || return 1
    TMPDIR="$run_tests_no_clean_tmpdir" RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --json --json-level=warn --no-clean-temp > "$run_tests_no_clean_json" 2> "$run_tests_no_clean_json_err"
  ); then
    test_fail "run-tests JSON no-clean-temp preserves run-owned temp output"
    status=1
  elif [ ! -s "$run_tests_no_clean_json_err" ] && python3 -m json.tool "$run_tests_no_clean_json" >/dev/null &&
    smoke_json_assert "$run_tests_no_clean_json" 'data.get("log_status") == "path" and data.get("log_policy") == "run-temp-kept-by-request" and data.get("log_file", "").startswith("'"$run_tests_no_clean_tmpdir"'")'; then
    test_pass "run-tests JSON no-clean-temp preserves run-owned temp output"
  else
    test_fail "run-tests JSON no-clean-temp preserves run-owned temp output"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    mkdir -p "$run_tests_stale_root" || return 1
    mkdir -p "$run_tests_stale_dir" || return 1
    mkdir -p "$run_tests_stale_fresh_dir" || return 1
    printf 'stale\n' > "$run_tests_stale_file" || return 1
    printf 'fresh\n' > "$run_tests_stale_fresh_file" || return 1
    touch -d '13 hours ago' "$run_tests_stale_dir" "$run_tests_stale_file" || return 1
    cat > repo-automation/tests/docs-check.sh <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail
exit 0
EOF
    chmod +x repo-automation/tests/docs-check.sh || return 1
    TMPDIR="$run_tests_stale_tmpdir" RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --quiet > "$run_tests_default_out" 2> "$run_tests_quiet_err"
  ); then
    if [ ! -e "$run_tests_stale_dir" ] && [ ! -e "$run_tests_stale_file" ] && [ -e "$run_tests_stale_fresh_dir" ] && [ -e "$run_tests_stale_fresh_file" ]; then
      test_pass "run-tests prunes stale repo-owned temp output"
    else
      test_fail "run-tests prunes stale repo-owned temp output"
      status=1
    fi
  else
    test_fail "run-tests prunes stale repo-owned temp output"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    cat > repo-automation/tests/docs-check.sh <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail
exit 1
EOF
    chmod +x repo-automation/tests/docs-check.sh || return 1
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --quiet --log-file="$run_tests_explicit_log" > "$run_tests_explicit_out" 2> "$run_tests_explicit_err"
  ); then
    test_fail "run-tests preserves an explicit --log-file path"
    status=1
  elif [ -f "$run_tests_explicit_log" ] && grep -Fq "log: $run_tests_explicit_log" "$run_tests_explicit_out"; then
    test_pass "run-tests preserves an explicit --log-file path"
  else
    test_fail "run-tests preserves an explicit --log-file path"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    cat > repo-automation/tests/docs-check.sh <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail
exit 1
EOF
    chmod +x repo-automation/tests/docs-check.sh || return 1
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --json --json-level=warn --log-file="$run_tests_explicit_log" > "$run_tests_explicit_json" 2> "$run_tests_explicit_json_err"
  ); then
    test_fail "run-tests JSON preserves an explicit --log-file path"
    status=1
  elif [ ! -s "$run_tests_explicit_json_err" ] && python3 -m json.tool "$run_tests_explicit_json" >/dev/null &&
    smoke_json_assert "$run_tests_explicit_json" 'data.get("log_status") == "path" and data.get("log_policy") == "explicit-log-file" and data.get("log_file") == "'"$run_tests_explicit_log"'"'; then
    test_pass "run-tests JSON preserves an explicit --log-file path"
  else
    test_fail "run-tests JSON preserves an explicit --log-file path"
    status=1
  fi

  mkdir -p "$run_tests_low_disk_stub_dir" || return 1
  cat > "$run_tests_low_disk_stub_dir/df" <<'EOF'
#!/usr/bin/env bash
set -u
case "${1:-}" in
  -P*) shift ;;
esac
if [ "${1:-}" = "-k" ]; then
  shift
fi
printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n'
printf 'stubfs %s %s %s %s%% %s\n' \
  "${RUN_TESTS_DF_BLOCKS:-100}" \
  "${RUN_TESTS_DF_USED:-90}" \
  "${RUN_TESTS_DF_AVAILABLE:-10}" \
  "${RUN_TESTS_DF_USE_PERCENT:-90}" \
  "${1:-${RUN_TESTS_DF_MOUNTPOINT:-/}}"
EOF
  chmod +x "$run_tests_low_disk_stub_dir/df" || return 1
  if (
    cd "$smoke_test_dir" || return 1
    cat > repo-automation/tests/smoke.sh <<EOF
#!/usr/bin/env bash
set -u
set -o pipefail
: "\${RUN_TESTS_LOW_DISK_MARKER:?}"
printf 'smoke ran\n' > "\$RUN_TESTS_LOW_DISK_MARKER"
exit 1
EOF
    chmod +x repo-automation/tests/smoke.sh || return 1
    rm -f "$run_tests_low_disk_marker" >/dev/null 2>&1 || true
    TMPDIR="$run_tests_low_disk_tmpdir" RUN_TESTS_DF_BIN="$run_tests_low_disk_stub_dir/df" RUN_TESTS_LOW_DISK_MARKER="$run_tests_low_disk_marker" repo-automation/bin/run-tests --smoke --quiet > "$run_tests_low_disk_out" 2> "$run_tests_low_disk_err"
  ); then
    test_fail "run-tests low-disk guard blocks smoke mode before smoke runs"
    status=1
  elif grep -Fq 'fail: disk space check' "$run_tests_low_disk_out" && [ ! -e "$run_tests_low_disk_marker" ]; then
    test_pass "run-tests low-disk guard blocks smoke mode before smoke runs"
  else
    test_fail "run-tests low-disk guard blocks smoke mode before smoke runs"
    status=1
  fi
  git -C "$smoke_test_dir" checkout -- repo-automation/tests/smoke.sh >/dev/null 2>&1 || true

  if (
    cd "$smoke_test_dir" || return 1
    cat > .repo-automation.local.conf <<EOF
REPO_AUTOMATION_RUN_TESTS_DISK_LOW_BYTES=1000000000
EOF
    rm -f "$run_tests_low_disk_marker" >/dev/null 2>&1 || true
    TMPDIR="$run_tests_low_disk_tmpdir" RUN_TESTS_DF_BIN="$run_tests_low_disk_stub_dir/df" RUN_TESTS_DF_BLOCKS=1171875 RUN_TESTS_DF_USED=50 RUN_TESTS_DF_AVAILABLE=1171875 RUN_TESTS_DF_USE_PERCENT=50 RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --smoke --quiet > "$run_tests_low_bytes_config_out" 2> "$run_tests_low_bytes_config_err"
  ); then
    if [ ! -s "$run_tests_low_bytes_config_out" ] && [ ! -s "$run_tests_low_bytes_config_err" ]; then
      test_pass "run-tests config can lower disk low-bytes threshold"
    else
      test_fail "run-tests config can lower disk low-bytes threshold"
      status=1
    fi
  else
    test_fail "run-tests config can lower disk low-bytes threshold"
    status=1
  fi
  rm -f "$smoke_test_dir/.repo-automation.local.conf" >/dev/null 2>&1 || true

  if (
    cd "$smoke_test_dir" || return 1
    rm -f .repo-automation.local.conf >/dev/null 2>&1 || true
    rm -f "$run_tests_low_disk_marker" >/dev/null 2>&1 || true
    TMPDIR="$run_tests_low_disk_tmpdir" RUN_TESTS_DF_BIN="$run_tests_low_disk_stub_dir/df" RUN_TESTS_DF_BLOCKS=1953125 RUN_TESTS_DF_USED=50 RUN_TESTS_DF_AVAILABLE=1953125 RUN_TESTS_DF_USE_PERCENT=50 RUN_TESTS_SKIP_SMOKE=1 REPO_AUTOMATION_RUN_TESTS_DISK_LOW_BYTES=3000000000 repo-automation/bin/run-tests --smoke --quiet > "$run_tests_low_bytes_env_out" 2> "$run_tests_low_bytes_env_err"
  ); then
    test_fail "run-tests env can raise disk low-bytes threshold"
    status=1
  elif grep -Fq 'fail: disk space check' "$run_tests_low_bytes_env_out"; then
    test_pass "run-tests env can raise disk low-bytes threshold"
  else
    test_fail "run-tests env can raise disk low-bytes threshold"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    cat > .repo-automation.local.conf <<EOF
REPO_AUTOMATION_RUN_TESTS_DISK_LOW_PERCENT=10
EOF
    rm -f "$run_tests_low_disk_marker" >/dev/null 2>&1 || true
    TMPDIR="$run_tests_low_disk_tmpdir" RUN_TESTS_DF_BIN="$run_tests_low_disk_stub_dir/df" RUN_TESTS_DF_BLOCKS=1953125 RUN_TESTS_DF_USED=86 RUN_TESTS_DF_AVAILABLE=1953125 RUN_TESTS_DF_USE_PERCENT=14 RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --smoke --quiet > "$run_tests_low_percent_config_out" 2> "$run_tests_low_percent_config_err"
  ); then
    if [ ! -s "$run_tests_low_percent_config_out" ] && [ ! -s "$run_tests_low_percent_config_err" ]; then
      test_pass "run-tests config can set disk low-percent threshold"
    else
      test_fail "run-tests config can set disk low-percent threshold"
      status=1
    fi
  else
    test_fail "run-tests config can set disk low-percent threshold"
    status=1
  fi
  rm -f "$smoke_test_dir/.repo-automation.local.conf" >/dev/null 2>&1 || true

  if (
    cd "$smoke_test_dir" || return 1
    cat > .repo-automation.local.conf <<EOF
REPO_AUTOMATION_RUN_TESTS_DISK_LOW_PERCENT=bogus
EOF
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --smoke --quiet > "$run_tests_invalid_percent_err" 2>&1
  ); then
    test_fail "run-tests rejects invalid disk low-percent overrides"
    status=1
  elif grep -Fq 'fail: resolve temp/disk config' "$run_tests_invalid_percent_err" &&
    grep -Fq 'invalid REPO_AUTOMATION_RUN_TESTS_DISK_LOW_PERCENT value' "$run_tests_invalid_percent_err"; then
    test_pass "run-tests rejects invalid disk low-percent overrides"
  else
    test_fail "run-tests rejects invalid disk low-percent overrides"
    status=1
  fi
  rm -f "$smoke_test_dir/.repo-automation.local.conf" >/dev/null 2>&1 || true

  if (
    cd "$smoke_test_dir" || return 1
    cat > .repo-automation.local.conf <<EOF
REPO_AUTOMATION_CLEAN_STALE_TEMP=bogus
EOF
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --smoke --quiet > "$run_tests_invalid_clean_stale_out" 2> "$run_tests_invalid_clean_stale_err"
  ); then
    test_fail "run-tests rejects invalid stale cleanup overrides"
    status=1
  elif grep -Fq 'fail: resolve temp/disk config' "$run_tests_invalid_clean_stale_out" &&
    grep -Fq 'invalid REPO_AUTOMATION_CLEAN_STALE_TEMP value' "$run_tests_invalid_clean_stale_out" &&
    [ ! -s "$run_tests_invalid_clean_stale_err" ]; then
    test_pass "run-tests rejects invalid stale cleanup overrides"
  else
    test_fail "run-tests rejects invalid stale cleanup overrides"
    status=1
  fi
  rm -f "$smoke_test_dir/.repo-automation.local.conf" >/dev/null 2>&1 || true

  if (
    cd "$smoke_test_dir" || return 1
    rm -f "$run_tests_secret_config_marker" >/dev/null 2>&1 || true
    cat > .repo-automation.local.conf <<EOF
password=fixture
touch "$run_tests_secret_config_marker"
EOF
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --json --json-level=warn > "$run_tests_secret_config_json" 2> "$run_tests_secret_config_json_err"
  ); then
    test_fail "run-tests secret-scans local config before sourcing"
    status=1
  elif [ ! -e "$run_tests_secret_config_marker" ] &&
    [ ! -s "$run_tests_secret_config_json_err" ] &&
    python3 -m json.tool "$run_tests_secret_config_json" >/dev/null &&
    smoke_json_assert "$run_tests_secret_config_json" 'data.get("overall_status") == "fail" and any(check.get("name") == "local config secret scan" and check.get("status") == "fail" and "possible secret markers found in .repo-automation.local.conf" in check.get("message", "") for check in data.get("checks", []))'; then
    test_pass "run-tests secret-scans local config before sourcing"
  else
    test_fail "run-tests secret-scans local config before sourcing"
    status=1
  fi
  rm -f "$smoke_test_dir/.repo-automation.local.conf" "$run_tests_secret_config_marker" >/dev/null 2>&1 || true

  if (
    cd "$smoke_test_dir" || return 1
    rm -f "$run_tests_secret_config_marker" >/dev/null 2>&1 || true
    cat > .repo-automation.local.conf <<EOF
password=fixture
touch "$run_tests_secret_config_marker"
EOF
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --explain > "$run_tests_secret_config_explain" 2> "$run_tests_secret_config_explain_err"
  ); then
    test_fail "run-tests explain renders local config secret scan failures"
    status=1
  elif [ ! -e "$run_tests_secret_config_marker" ] &&
    grep -Fq '===== FINAL SUMMARY =====' "$run_tests_secret_config_explain_err" &&
    grep -Fq 'FAIL: local config secret scan - possible secret markers found in .repo-automation.local.conf' "$run_tests_secret_config_explain" &&
    [ -s "$run_tests_secret_config_explain_err" ]; then
    test_pass "run-tests explain renders local config secret scan failures"
  else
    test_fail "run-tests explain renders local config secret scan failures"
    status=1
  fi
  rm -f "$smoke_test_dir/.repo-automation.local.conf" "$run_tests_secret_config_marker" >/dev/null 2>&1 || true

  if (
    cd "$smoke_test_dir" || return 1
    rm -f "$run_tests_secret_config_marker" >/dev/null 2>&1 || true
    cat > .repo-automation.local.conf <<EOF
password=fixture
touch "$run_tests_secret_config_marker"
EOF
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --quiet > "$run_tests_secret_config_quiet" 2> "$run_tests_secret_config_quiet_err"
  ); then
    test_fail "run-tests quiet renders compact local config secret scan failures"
    status=1
  elif [ ! -e "$run_tests_secret_config_marker" ] &&
    [ ! -s "$run_tests_secret_config_quiet_err" ] &&
    grep -Fxq 'fail: local config secret scan - possible secret markers found in .repo-automation.local.conf' "$run_tests_secret_config_quiet"; then
    test_pass "run-tests quiet renders compact local config secret scan failures"
  else
    test_fail "run-tests quiet renders compact local config secret scan failures"
    status=1
  fi
  rm -f "$smoke_test_dir/.repo-automation.local.conf" "$run_tests_secret_config_marker" >/dev/null 2>&1 || true

  if (
    cd "$smoke_test_dir" || return 1
    rm -f "$run_tests_secret_config_source_marker" >/dev/null 2>&1 || true
    cat > .repo-automation.local.conf <<EOF
REPO_AUTOMATION_TEST_TEMP_ROOT="$run_tests_low_disk_tmpdir/repo-automation-template"
return 1
touch "$run_tests_secret_config_source_marker"
EOF
    RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --quiet > "$run_tests_secret_config_source_out" 2> "$run_tests_secret_config_source_err"
  ); then
    test_fail "run-tests quiet handles local config source failures"
    status=1
  elif [ ! -e "$run_tests_secret_config_source_marker" ] &&
    [ ! -s "$run_tests_secret_config_source_err" ] &&
    grep -Fxq 'fail: local config load - failed to source .repo-automation.local.conf' "$run_tests_secret_config_source_out"; then
    test_pass "run-tests quiet handles local config source failures"
  else
    test_fail "run-tests quiet handles local config source failures"
    status=1
  fi
  rm -f "$smoke_test_dir/.repo-automation.local.conf" "$run_tests_secret_config_source_marker" >/dev/null 2>&1 || true

  if (
    cd "$smoke_test_dir" || return 1
    cat > .repo-automation.local.conf <<EOF
REPO_AUTOMATION_TEST_TEMP_ROOT="$run_tests_low_disk_tmpdir/repo-automation-template"
REPO_AUTOMATION_RUN_TESTS_TEMP_WARN_KIB=1
EOF
    cat > repo-automation/tests/docs-check.sh <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail
python3 - <<'PY' >&2
print("x" * 2048)
PY
exit 1
EOF
    chmod +x repo-automation/tests/docs-check.sh || return 1
    RUN_TESTS_DF_BIN="$run_tests_low_disk_stub_dir/df" RUN_TESTS_DF_BLOCKS=1953125 RUN_TESTS_DF_USED=50 RUN_TESTS_DF_AVAILABLE=1953125 RUN_TESTS_DF_USE_PERCENT=50 RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --docs --log-file="$run_tests_low_disk_tmpdir/repo-automation-template/run-tests.log" > "$run_tests_temp_warn_out" 2> "$run_tests_temp_warn_err"
  ); then
    test_fail "run-tests accepts temp warn KiB overrides"
    status=1
  elif grep -Fq 'WARN: TEST_TEMP_ROOT still uses' "$run_tests_temp_warn_err" &&
    grep -Fq 'run-tests.log' "$run_tests_temp_warn_out"; then
    test_pass "run-tests accepts temp warn KiB overrides"
  else
    test_fail "run-tests accepts temp warn KiB overrides"
    status=1
  fi
  rm -f "$smoke_test_dir/.repo-automation.local.conf" >/dev/null 2>&1 || true
  git -C "$smoke_test_dir" checkout -- repo-automation/tests/docs-check.sh >/dev/null 2>&1 || true

  run_tests_low_disk_changed_repo="$(smoke_setup_subset_repo)" || {
    test_fail "run-tests low-disk guard blocks changed smoke selection before smoke runs"
    status=1
  }

  if [ -n "$run_tests_low_disk_changed_repo" ] && (
    cd "$run_tests_low_disk_changed_repo" || return 1
    cat > repo-automation/tests/smoke.sh <<EOF
#!/usr/bin/env bash
set -u
set -o pipefail
: "\${RUN_TESTS_LOW_DISK_MARKER:?}"
printf 'smoke ran\n' > "\$RUN_TESTS_LOW_DISK_MARKER"
exit 1
EOF
    chmod +x repo-automation/tests/smoke.sh || return 1
    rm -f "$run_tests_low_disk_marker" >/dev/null 2>&1 || true
    TMPDIR="$run_tests_low_disk_tmpdir" RUN_TESTS_DF_BIN="$run_tests_low_disk_stub_dir/df" RUN_TESTS_LOW_DISK_MARKER="$run_tests_low_disk_marker" repo-automation/bin/run-tests --changed --quiet > "$run_tests_low_disk_out" 2> "$run_tests_low_disk_err"
  ); then
    test_fail "run-tests low-disk guard blocks changed smoke selection before smoke runs"
    status=1
  elif grep -Fq 'fail: disk space check' "$run_tests_low_disk_out" && [ ! -e "$run_tests_low_disk_marker" ]; then
    test_pass "run-tests low-disk guard blocks changed smoke selection before smoke runs"
  else
    test_fail "run-tests low-disk guard blocks changed smoke selection before smoke runs"
    status=1
  fi
  git -C "$smoke_test_dir" checkout -- repo-automation/tests/smoke.sh >/dev/null 2>&1 || true

  if (
    cd "$smoke_test_dir" || return 1
    rm -f "$run_tests_low_disk_marker" >/dev/null 2>&1 || true
    TMPDIR="$run_tests_low_disk_tmpdir" RUN_TESTS_DF_BIN="$run_tests_low_disk_stub_dir/df" RUN_TESTS_DF_BLOCKS=1000000 RUN_TESTS_DF_USED=840000 RUN_TESTS_DF_AVAILABLE=1024 RUN_TESTS_DF_USE_PERCENT=84 RUN_TESTS_LOW_DISK_MARKER="$run_tests_low_disk_marker" RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --smoke --quiet > "$run_tests_low_disk_out" 2> "$run_tests_low_disk_err"
  ); then
    test_fail "run-tests low-disk guard prevents heavy checks"
    status=1
  elif grep -Fq 'available disk space below 1.5G (1048576 bytes free)' "$run_tests_low_disk_out" && [ ! -e "$run_tests_low_disk_marker" ]; then
    test_pass "run-tests low-disk guard prevents heavy checks"
  else
    test_fail "run-tests low-disk guard prevents heavy checks"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    rm -f "$run_tests_low_disk_marker" >/dev/null 2>&1 || true
    TMPDIR="$run_tests_low_disk_tmpdir" RUN_TESTS_DF_BIN="$run_tests_low_disk_stub_dir/df" RUN_TESTS_DF_BLOCKS=1000000 RUN_TESTS_DF_USED=860000 RUN_TESTS_DF_AVAILABLE=2000000 RUN_TESTS_DF_USE_PERCENT=86 RUN_TESTS_LOW_DISK_MARKER="$run_tests_low_disk_marker" RUN_TESTS_SKIP_SMOKE=1 repo-automation/bin/run-tests --smoke --quiet > "$run_tests_low_disk_out" 2> "$run_tests_low_disk_err"
  ); then
    test_fail "run-tests low-disk guard prevents heavy checks"
    status=1
  elif grep -Fq 'available disk space below 15% (14% free)' "$run_tests_low_disk_out" && [ ! -e "$run_tests_low_disk_marker" ]; then
    test_pass "run-tests low-disk guard prevents heavy checks"
  else
    test_fail "run-tests low-disk guard prevents heavy checks"
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

  rm -f "$run_tests_help" "$run_tests_default_out" "$run_tests_quiet_out" "$run_tests_quiet_err" "$run_tests_explain_out" "$run_tests_json" "$run_tests_json_err" "$run_tests_log_file" "$run_tests_no_log_file" "$run_tests_no_log_out" "$run_tests_failure_log" "$run_tests_failure_out" "$run_tests_timeout_format_stderr" "$run_tests_timeout_missing_stderr" "$run_tests_timeout_empty_stderr" "$run_tests_log_file_format_stderr" "$run_tests_log_file_missing_stderr" "$run_tests_log_file_empty_stderr" "$run_tests_json_level_format_stderr" "$run_tests_json_level_missing_stderr" "$run_tests_json_level_empty_stderr" "$run_tests_unknown_stderr" "$run_tests_temp_disk_backup" "$run_tests_missing_temp_disk_out" "$run_tests_missing_temp_disk_err" "$run_tests_invalid_clean_stale_out" "$run_tests_invalid_clean_stale_err" "$run_tests_secret_config_marker" "$run_tests_secret_config_json" "$run_tests_secret_config_json_err" "$run_tests_secret_config_explain" "$run_tests_secret_config_explain_err" "$run_tests_secret_config_quiet" "$run_tests_secret_config_quiet_err" "$run_tests_secret_config_source_out" "$run_tests_secret_config_source_err" "$run_tests_secret_config_source_marker" >/dev/null 2>&1 || true
  return "$status"
}

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
  ) && python3 -m json.tool "$github_settings_repo_json" >/dev/null && \
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
  ) && python3 -m json.tool "$github_settings_json" >/dev/null && \
    smoke_json_assert "$github_settings_json" 'data.get("overall_status") == "pass" and data.get("repo") == "i-schuyler/repo-automation-template" and data.get("default_branch") == "main" and data.get("actions_enabled") is True and data.get("pr_template_exists") is True and data.get("issue_templates_exist") is True and data.get("ci_workflow_exists") is True'; then
    test_pass "github-settings-check machine-json is parseable"
  else
    test_fail "github-settings-check machine-json is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/repo-doctor --check=github-settings-readiness --json --json-level=all > "$github_settings_doctor_json"
  ) && python3 -m json.tool "$github_settings_doctor_json" >/dev/null && \
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
  local managed_file_manifest_backup="$smoke_test_base/managed-file-manifest-backup-$$.json"
  local managed_file_installer_backup="$smoke_test_base/managed-file-installer-backup-$$.sh"

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
    cp "$managed_file_manifest_path" "$managed_file_manifest_backup" || return 1
    cp "$managed_file_installer_path" "$managed_file_installer_backup" || return 1
    repo-automation/bin/managed-file-add --path="$managed_file_new_path" --kind=doc >/dev/null
  ) && python3 -m json.tool "$managed_file_manifest_path" >/dev/null && \
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

  cp "$managed_file_manifest_backup" "$managed_file_manifest_path" >/dev/null 2>&1 || true
  cp "$managed_file_installer_backup" "$managed_file_installer_path" >/dev/null 2>&1 || true

  rm -f "$managed_file_help" "$managed_file_add_help" "$managed_file_clean_out" "$managed_file_clean_err" "$managed_file_fail_stderr" "$managed_file_add_stderr" >/dev/null 2>&1 || true
  rm -f "$managed_file_manifest_backup" "$managed_file_installer_backup" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_shellcheck_ci_parity_contract() {
  local status=0
  local shellcheck_help="$smoke_test_base/shellcheck-ci-parity-help-$$.txt"
  local shellcheck_unknown_stderr="$smoke_test_base/shellcheck-ci-parity-unknown.stderr"
  local shellcheck_paths="$smoke_test_base/shellcheck-ci-parity-paths-$$.txt"
  local shellcheck_paths_check="$smoke_test_base/shellcheck-ci-parity-paths-check-$$.stderr"
  local shellcheck_paths_status=0
  local shellcheck_workflow="$smoke_test_base/shellcheck-ci-parity-workflow-$$.txt"
  local shellcheck_temp_disk_path="$smoke_test_dir/repo-automation/lib/temp-disk.sh"
  local shellcheck_temp_disk_backup="$smoke_test_base/shellcheck-ci-parity-temp-disk-backup-$$.sh"
  local shellcheck_missing_temp_disk_out="$smoke_test_base/shellcheck-ci-parity-missing-temp-disk-$$.txt"
  local shellcheck_missing_temp_disk_err="$smoke_test_base/shellcheck-ci-parity-missing-temp-disk-$$.stderr"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/shellcheck-ci-parity --help > "$shellcheck_help"
  ) && grep -Fq -- 'Usage: repo-automation/bin/shellcheck-ci-parity [--help]' "$shellcheck_help" && grep -Fq -- 'Run ShellCheck against the metadata-driven CI file set with the CI parity exclusion.' "$shellcheck_help" && grep -Fq -- 'Use --print-paths to show the exact file set.' "$shellcheck_help"; then
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

  if (
    cd "$smoke_test_dir" || return 1
    mv "$shellcheck_temp_disk_path" "$shellcheck_temp_disk_backup" || return 1
    repo-automation/bin/shellcheck-ci-parity --print-paths > "$shellcheck_missing_temp_disk_out" 2> "$shellcheck_missing_temp_disk_err"
    rc=$?
    mv "$shellcheck_temp_disk_backup" "$shellcheck_temp_disk_path" || return 1
    exit "$rc"
  ); then
    test_fail "shellcheck-ci-parity requires active checkout temp-disk library"
    status=1
  elif [ ! -s "$shellcheck_missing_temp_disk_out" ] &&
    grep -Fxq 'fail: missing shellcheck path: repo-automation/lib/temp-disk.sh' "$shellcheck_missing_temp_disk_err"; then
    test_pass "shellcheck-ci-parity requires active checkout temp-disk library"
  else
    test_fail "shellcheck-ci-parity requires active checkout temp-disk library"
    status=1
    mv "$shellcheck_temp_disk_backup" "$shellcheck_temp_disk_path" >/dev/null 2>&1 || true
  fi

  if (
    cd "$smoke_test_dir/repo-automation/tests" || return 1
    ../bin/shellcheck-ci-parity --print-paths > "$shellcheck_paths"
  ); then
    python3 - "$smoke_test_dir/repo-automation/helper-metadata.json" "$shellcheck_paths" <<'PY' >/dev/null 2> "$shellcheck_paths_check" || shellcheck_paths_status=1
import json
import sys
from pathlib import Path

metadata_path = Path(sys.argv[1])
paths_path = Path(sys.argv[2])
repo_root = metadata_path.parent.parent

try:
    helper_metadata = json.loads(metadata_path.read_text())
except Exception as exc:
    print(f"fail: unable to parse helper metadata: {metadata_path}", file=sys.stderr)
    print(f"detail: {exc}", file=sys.stderr)
    raise SystemExit(1)

helpers = helper_metadata.get("helpers")
if not isinstance(helpers, list):
    print(f"fail: helper metadata missing helpers array: {metadata_path}", file=sys.stderr)
    raise SystemExit(1)

expected = []
seen = set()


def add(path: Path) -> None:
    rel_path = path.relative_to(repo_root).as_posix()
    if rel_path in seen:
        print(f"fail: duplicate shellcheck path: {rel_path}", file=sys.stderr)
        raise SystemExit(1)
    if not path.exists():
        print(f"fail: missing shellcheck path: {rel_path}", file=sys.stderr)
        raise SystemExit(1)
    if not path.is_file():
        print(f"fail: expected file path: {rel_path}", file=sys.stderr)
        raise SystemExit(1)
    seen.add(rel_path)
    expected.append(rel_path)


for helper in helpers:
    if not isinstance(helper, dict):
        continue
    helper_path = helper.get("path")
    if isinstance(helper_path, str) and helper_path.startswith("repo-automation/bin/"):
        add(repo_root / helper_path)

for path in sorted((repo_root / "repo-automation" / "lib").glob("*.sh")):
    add(path)

for pattern in (
    "repo-automation/tests/lib/*.sh",
    "repo-automation/tests/contracts/*.sh",
):
    matches = sorted(repo_root.glob(pattern))
    if not matches:
        print(f"fail: no shellcheck paths matched {pattern}", file=sys.stderr)
        raise SystemExit(1)
    for path in matches:
        add(path)

for relative_path in (
    "repo-automation/tests/docs-check.sh",
    "repo-automation/tests/smoke.sh",
    "repo-automation/tests/version-consistency.sh",
):
    add(repo_root / relative_path)

actual = paths_path.read_text().splitlines()
if actual != sorted(expected):
    print("fail: shellcheck-ci-parity --print-paths output mismatch", file=sys.stderr)
    print("expected:", file=sys.stderr)
    for path in sorted(expected):
        print(path, file=sys.stderr)
    print("actual:", file=sys.stderr)
    for path in actual:
        print(path, file=sys.stderr)
    raise SystemExit(1)

if len(actual) != len(set(actual)):
    print("fail: shellcheck-ci-parity --print-paths contains duplicate lines", file=sys.stderr)
    raise SystemExit(1)

if "repo-automation/bin/check-tooling" not in actual:
    print("fail: shellcheck-ci-parity --print-paths is missing repo-automation/bin/check-tooling", file=sys.stderr)
    raise SystemExit(1)

if "repo-automation/bin/shellcheck-ci-parity" not in actual:
    print("fail: shellcheck-ci-parity --print-paths is missing repo-automation/bin/shellcheck-ci-parity", file=sys.stderr)
    raise SystemExit(1)

if "repo-automation/lib/common.sh" not in actual:
    print("fail: shellcheck-ci-parity --print-paths is missing repo-automation/lib/common.sh", file=sys.stderr)
    raise SystemExit(1)

if "repo-automation/lib/temp-disk.sh" not in actual:
    print("fail: shellcheck-ci-parity --print-paths is missing repo-automation/lib/temp-disk.sh", file=sys.stderr)
    raise SystemExit(1)
PY
    if [ "$shellcheck_paths_status" -eq 0 ]; then
      test_pass "shellcheck-ci-parity prints the metadata-driven file set"
    else
      test_fail "shellcheck-ci-parity prints the metadata-driven file set"
      status=1
    fi
  else
    test_fail "shellcheck-ci-parity prints the metadata-driven file set"
    status=1
  fi

  if grep -Fq -- 'mapfile -t shellcheck_paths < <(repo-automation/bin/shellcheck-ci-parity --print-paths)' "$smoke_repo_root/.github/workflows/ci.yml" && \
    ! grep -Fq -- 'bash -n repo-automation/bin/' "$smoke_repo_root/.github/workflows/ci.yml" && \
    ! grep -Fq -- 'shellcheck -e SC2317 repo-automation/bin/' "$smoke_repo_root/.github/workflows/ci.yml"; then
    test_pass "ci workflow uses shellcheck-ci-parity --print-paths"
  else
    test_fail "ci workflow uses shellcheck-ci-parity --print-paths"
    status=1
  fi

  rm -f "$shellcheck_help" >/dev/null 2>&1 || true
  rm -f "$shellcheck_paths" "$shellcheck_paths_check" "$shellcheck_workflow" "$shellcheck_missing_temp_disk_out" "$shellcheck_missing_temp_disk_err" "$shellcheck_temp_disk_backup" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_portability_make_path_fixture() {
  local fixture_dir="$1"

  mkdir -p "$fixture_dir" || return 1
  ln -sf "$(command -v bash)" "$fixture_dir/bash" || return 1
  ln -sf "$(command -v dirname)" "$fixture_dir/dirname" || return 1
}

smoke_check_portability_clear_advisories() {
  python3 - "$smoke_test_dir" <<'PY' || return 1
from pathlib import Path
import sys

root = Path(sys.argv[1])
replacements = {
    root / "repo-automation" / "bin" / "repo-doctor": [
        ("-printf '%P\\n'", "-print"),
    ],
    root / "repo-automation" / "bin" / "post-codex-packet": [
        ("stat -c", "stat -f"),
    ],
    root / "repo-automation" / "bin" / "repo-zip": [
        ("stat -c", "stat -f"),
    ],
    root / "repo-automation" / "bin" / "evidence-bundle": [
        ("stat -c", "stat -f"),
    ],
    root / "repo-automation" / "bin" / "status-packet": [
        ("stat -c", "stat -f"),
    ],
    root / "repo-automation" / "bin" / "post-codex-review": [
        ("stat -c", "stat -f"),
    ],
    root / "repo-automation" / "bin" / "failure-log": [
        ("stat -c", "stat -f"),
    ],
    root / "repo-automation" / "tests" / "docs-check.sh": [
        ("/tmp", "${TMPDIR:-$HOME/.cache}"),
        ("/var/tmp", "${TMPDIR:-$HOME/.cache}"),
    ],
    root / "repo-automation" / "tests" / "contracts" / "repo-flow.sh": [
        ("/tmp/example", "${TMPDIR:-$HOME/.cache}/example"),
    ],
}

for path, edits in replacements.items():
    text = path.read_text(encoding="utf-8")
    for old, new in edits:
        text = text.replace(old, new)
    path.write_text(text, encoding="utf-8")
PY
}

smoke_check_portability_contract() {
  local status=0
  local help_out="$smoke_test_base/check-portability-help-$$.txt"
  local help_err="$smoke_test_base/check-portability-help-$$.stderr"
  local unknown_err="$smoke_test_base/check-portability-unknown-$$.stderr"
  local targets_out="$smoke_test_base/check-portability-targets-$$.txt"
  local targets_err="$smoke_test_base/check-portability-targets-$$.stderr"
  local advisory_out="$smoke_test_base/check-portability-advisory-$$.txt"
  local advisory_err="$smoke_test_base/check-portability-advisory-$$.stderr"
  local quiet_out="$smoke_test_base/check-portability-quiet-$$.txt"
  local quiet_err="$smoke_test_base/check-portability-quiet-$$.stderr"
  local json_out="$smoke_test_base/check-portability-json-$$.json"
  local json_err="$smoke_test_base/check-portability-json-$$.stderr"
  local clean_json_out="$smoke_test_base/check-portability-clean-json-$$.json"
  local clean_json_err="$smoke_test_base/check-portability-clean-json-$$.stderr"
  local allowed_out="$smoke_test_base/check-portability-allowed-$$.txt"
  local allowed_err="$smoke_test_base/check-portability-allowed-$$.stderr"
  local temp_out="$smoke_test_base/check-portability-temp-$$.txt"
  local temp_err="$smoke_test_base/check-portability-temp-$$.stderr"
  local portable_out="$smoke_test_base/check-portability-portable-$$.txt"
  local portable_err="$smoke_test_base/check-portability-portable-$$.stderr"
  local python_out="$smoke_test_base/check-portability-python-$$.txt"
  local python_err="$smoke_test_base/check-portability-python-$$.stderr"
  local workflow_path="$smoke_test_dir/.github/workflows/ci.yml"
  local path_fixture="$smoke_test_base/check-portability-path-fixture-$$"
  smoke_check_portability_make_path_fixture "$path_fixture" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$path_fixture" repo-automation/bin/check-portability --help >"$help_out" 2>"$help_err"
  ) && grep -Fqx 'Usage: repo-automation/bin/check-portability [--help] [--quiet] [--explain] [--json] [--print-targets]' "$help_out" &&
    grep -Fq -- '--print-targets' "$help_out" &&
    ! grep -Fq -- '--print-targets=' "$help_out" &&
    [ ! -s "$help_err" ]; then
    test_pass "check-portability help works before shellcheck availability"
  else
    test_fail "check-portability help works before shellcheck availability"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/check-portability --bogus >"$help_out" 2>"$unknown_err"
  ); then
    test_fail "check-portability rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$unknown_err" "unknown flag" "--bogus" "run repo-automation/bin/check-portability --help"; then
    test_pass "check-portability rejects unknown flags"
  else
    test_fail "check-portability rejects unknown flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir/repo-automation/tests" || return 1
    ../bin/check-portability --print-targets >"$targets_out"
  ); then
    if python3 - "$targets_out" <<'PY' >/dev/null 2>"$targets_err"
import sys
from pathlib import Path

targets = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
if targets != sorted(targets):
    raise SystemExit(1)
if len(targets) != len(set(targets)):
    raise SystemExit(1)
required = {
    "repo-automation/bin/check-portability",
    ".github/workflows/ci.yml",
}
if not required.issubset(set(targets)):
    raise SystemExit(1)
PY
    then
    test_pass "check-portability prints the metadata-driven file set"
    else
      test_fail "check-portability prints the metadata-driven file set"
      status=1
    fi
  else
    test_fail "check-portability prints the metadata-driven file set"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/check-portability >"$advisory_out" 2>"$advisory_err"
  ) && grep -Fq 'warn: portability advisory findings' "$advisory_out" &&
    [ -s "$advisory_out" ] &&
    [ ! -s "$advisory_err" ]; then
    test_pass "check-portability advisory findings exit 0"
  else
    test_fail "check-portability advisory findings exit 0"
    status=1
  fi

  smoke_check_portability_clear_advisories || return 1

  cat > "$workflow_path" <<'EOF'
name: CI
permissions:
  contents: read
jobs:
  portability:
    runs-on: ubuntu-latest
    steps:
      - run: echo ready
EOF

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/check-portability --quiet >"$quiet_out" 2>"$quiet_err"
  ) && [ ! -s "$quiet_out" ] && [ ! -s "$quiet_err" ]; then
    test_pass "check-portability quiet success is silent"
  else
    test_fail "check-portability quiet success is silent"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/check-portability --json >"$json_out" 2>"$json_err"
  ) && [ ! -s "$json_err" ] && python3 -m json.tool "$json_out" >/dev/null &&
    smoke_json_assert "$json_out" 'data.get("script") == "check-portability" and data.get("status") == "pass" and data.get("target_count") > 0 and data.get("fail_count") == 0 and data.get("warn_count") == 0 and isinstance(data.get("targets"), list) and isinstance(data.get("findings"), list) and isinstance(data.get("target_sources"), dict)'; then
    test_pass "check-portability json is valid"
  else
    test_fail "check-portability json is valid"
    status=1
  fi

  cat > "$workflow_path" <<'EOF'
name: CI
permissions:
  contents: read
jobs:
  portability:
    runs-on: ubuntu-latest
    steps:
      - run: python3 script.py
EOF

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/check-portability >"$allowed_out" 2>"$allowed_err"
  ) && grep -Fqx 'pass' "$allowed_out" && [ ! -s "$allowed_err" ]; then
    test_pass "check-portability allows python3 command tokens"
  else
    test_fail "check-portability allows python3 command tokens"
    status=1
  fi

  cat > "$workflow_path" <<'EOF'
name: CI
permissions:
  contents: read
jobs:
  portability:
    runs-on: ubuntu-latest
    steps:
      - run: echo /tmp/cache
EOF

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/check-portability >"$temp_out" 2>"$temp_err"
  ) && grep -Fq 'warn:' "$temp_out" && grep -Fq 'portability-temp-path' "$temp_out" && grep -Fq '${TMPDIR:-$HOME/.cache}' "$temp_out" && [ ! -s "$temp_err" ]; then
    test_pass "check-portability warns on tmp-path portability drift"
  else
    test_fail "check-portability warns on tmp-path portability drift"
    status=1
  fi

  cat > "$workflow_path" <<'EOF'
name: CI
permissions:
  contents: read
jobs:
  portability:
    runs-on: ubuntu-latest
    steps:
      - run: grep -P '^x$' /dev/null
EOF

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/check-portability >"$portable_out" 2>"$portable_err"
  ) && grep -Fq 'warn:' "$portable_out" && grep -Fq 'portability-grep-p' "$portable_out" && [ ! -s "$portable_err" ]; then
    test_pass "check-portability warns on GNU/BSD-sensitive drift"
  else
    test_fail "check-portability warns on GNU/BSD-sensitive drift"
    status=1
  fi

  cat > "$workflow_path" <<'EOF'
name: CI
permissions:
  contents: read
jobs:
  portability:
    runs-on: ubuntu-latest
    steps:
      - run: python - <<'PY'
          print('bad')
        PY
EOF

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/check-portability >"$python_out" 2>"$python_err"
  ); then
    test_fail "check-portability rejects executable python command tokens"
    status=1
  elif grep -Fq 'fail: portability drift' "$python_out" || grep -Fq 'fail: portability drift' "$python_err"; then
    test_pass "check-portability rejects executable python command tokens"
  else
    test_fail "check-portability rejects executable python command tokens"
    status=1
  fi

  if grep -Fq 'repo-automation/bin/check-portability 2>&1 | tee "$check_portability_log"' "$smoke_repo_root/.github/workflows/ci.yml" &&
    grep -Fq 'repo-automation/bin/repo-doctor --quick --no-run-tests --json --json-level=warn --log-file="$RUNNER_TEMP/repo-doctor.log"' "$smoke_repo_root/.github/workflows/ci.yml" &&
    grep -Fq 'repo-automation/bin/ci-failure-artifacts --out-dir="$RUNNER_TEMP/ci-failure-artifacts"' "$smoke_repo_root/.github/workflows/ci.yml" &&
    grep -Fq '${{ runner.temp }}/ci-failure-artifacts/**' "$smoke_repo_root/.github/workflows/ci.yml"; then
    test_pass "ci workflow captures portability and failure artifacts"
  else
    test_fail "ci workflow captures portability and failure artifacts"
    status=1
  fi

  rm -f "$help_out" "$help_err" "$unknown_err" "$targets_out" "$targets_err" "$advisory_out" "$advisory_err" "$quiet_out" "$quiet_err" "$json_out" "$json_err" "$clean_json_out" "$clean_json_err" "$allowed_out" "$allowed_err" "$temp_out" "$temp_err" "$portable_out" "$portable_err" "$python_out" "$python_err" >/dev/null 2>&1 || true
  rm -rf "$path_fixture" >/dev/null 2>&1 || true
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

smoke_check_contract_debt_report_contract() {
  local status=0
  smoke_setup_temp_repo || return 1
  local report_tmpdir="$smoke_test_base/contract-debt-report-$$"
  local report_dir="$report_tmpdir/repo-automation-template/contract-debt-report"
  local report_markdown="$report_dir/contract-debt-report.md"
  local report_json="$report_dir/contract-debt-report.json"
  local help_out="$smoke_test_base/contract-debt-help-$$.txt"
  local help_err="$smoke_test_base/contract-debt-help-$$.stderr"
  local unknown_err="$smoke_test_base/contract-debt-unknown-$$.stderr"
  local outdir_space_err="$smoke_test_base/contract-debt-outdir-space-$$.stderr"
  local outdir_empty_err="$smoke_test_base/contract-debt-outdir-empty-$$.stderr"
  local default_out="$smoke_test_base/contract-debt-default-$$.txt"
  local default_err="$smoke_test_base/contract-debt-default-$$.stderr"
  local quiet_out="$smoke_test_base/contract-debt-quiet-$$.txt"
  local quiet_err="$smoke_test_base/contract-debt-quiet-$$.stderr"
  local explain_out="$smoke_test_base/contract-debt-explain-$$.txt"
  local explain_err="$smoke_test_base/contract-debt-explain-$$.stderr"
  local json_out="$smoke_test_base/contract-debt-json-$$.json"
  local json_err="$smoke_test_base/contract-debt-json-$$.stderr"
  local seeded_large_file="$smoke_test_dir/repo-automation/bin/contract-debt-large-candidate"
  local large_json="$smoke_test_base/contract-debt-large-$$.json"
  local large_err="$smoke_test_base/contract-debt-large-$$.stderr"
  local shared_coverage_json="$smoke_test_base/contract-debt-shared-coverage-$$.json"
  local shared_coverage_err="$smoke_test_base/contract-debt-shared-coverage-$$.stderr"
  local missing_shared_json="$smoke_test_base/contract-debt-missing-shared-$$.json"
  local missing_shared_err="$smoke_test_base/contract-debt-missing-shared-$$.stderr"
  local missing_doc_json="$smoke_test_base/contract-debt-missing-doc-$$.json"
  local missing_doc_err="$smoke_test_base/contract-debt-missing-doc-$$.stderr"
  local missing_contract_json="$smoke_test_base/contract-debt-missing-contract-$$.json"
  local missing_contract_err="$smoke_test_base/contract-debt-missing-contract-$$.stderr"
  local gap_json="$smoke_test_base/contract-debt-gap-$$.json"
  local gap_err="$smoke_test_base/contract-debt-gap-$$.stderr"
  local json_gap_file="$smoke_test_dir/repo-automation/tests/contracts/ci-failure-artifacts.sh"
  local quiet_gap_file="$smoke_test_dir/repo-automation/tests/contracts/repo-doctor.sh"
  local invalid_meta_err="$smoke_test_base/contract-debt-invalid-meta-$$.stderr"
  local invalid_meta_json="$smoke_test_base/contract-debt-invalid-meta-$$.json"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/contract-debt-report --help >"$help_out" 2>"$help_err"
  ) && grep -Fq 'Usage: repo-automation/bin/contract-debt-report [--help] [--out-dir=<path>] [--quiet] [--explain] [--json]' "$help_out" &&
    grep -Fq 'Generate an advisory maintainability and contract debt report.' "$help_out" &&
    grep -Fq 'Debt findings warn but do not fail the command.' "$help_out" &&
    ! grep -Fq 'fail:' "$help_err"; then
    test_pass "contract-debt-report help shows usage and summary"
  else
    test_fail "contract-debt-report help shows usage and summary"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/contract-debt-report --bogus > /dev/null 2>"$unknown_err"
  ); then
    test_fail "contract-debt-report unknown flag is rejected"
    status=1
  elif grep -Fxq 'fail: unknown flag' "$unknown_err" &&
    grep -Fxq 'flag: --bogus' "$unknown_err" &&
    grep -Fxq 'fix: run repo-automation/bin/contract-debt-report --help' "$unknown_err"; then
    test_pass "contract-debt-report unknown flag is rejected"
  else
    test_fail "contract-debt-report unknown flag is rejected"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/contract-debt-report --out-dir "$report_tmpdir/space" > /dev/null 2>"$outdir_space_err"
  ); then
    test_fail "contract-debt-report rejects spaced out-dir syntax"
    status=1
  elif grep -Fxq 'fail: flag format not accepted' "$outdir_space_err" &&
    grep -Fxq 'flag: --out-dir' "$outdir_space_err" &&
    grep -Fxq 'fix: use --out-dir=<path>' "$outdir_space_err"; then
    test_pass "contract-debt-report rejects spaced out-dir syntax"
  else
    test_fail "contract-debt-report rejects spaced out-dir syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/contract-debt-report --out-dir= > /dev/null 2>"$outdir_empty_err"
  ); then
    test_fail "contract-debt-report rejects empty out-dir syntax"
    status=1
  elif grep -Fxq 'fail: empty flag value' "$outdir_empty_err" &&
    grep -Fxq 'flag: --out-dir' "$outdir_empty_err" &&
    grep -Fxq 'fix: use --out-dir=<path>' "$outdir_empty_err"; then
    test_pass "contract-debt-report rejects empty out-dir syntax"
  else
    test_fail "contract-debt-report rejects empty out-dir syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report >"$default_out" 2>"$default_err"
  ) && [ "$(cat "$default_out")" = "$report_markdown" ] && [ ! -s "$default_err" ] && [ -f "$report_markdown" ] && [ -f "$report_json" ]; then
    test_pass "contract-debt-report default output prints the markdown path"
  else
    test_fail "contract-debt-report default output prints the markdown path"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --quiet >"$quiet_out" 2>"$quiet_err"
  ) && [ ! -s "$quiet_out" ] && [ ! -s "$quiet_err" ]; then
    test_pass "contract-debt-report quiet output is silent"
  else
    test_fail "contract-debt-report quiet output is silent"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --explain >"$explain_out" 2>"$explain_err"
  ) && [ ! -s "$explain_err" ] &&
    grep -Eq '^status: (pass|warn)$' "$explain_out" &&
    grep -Eq '^counts: warn=[0-9]+ fail=[0-9]+ total=[0-9]+ included=[0-9]+ omitted=[0-9]+$' "$explain_out" &&
    grep -Eq "^report_markdown: $report_markdown$" "$explain_out" &&
    grep -Eq "^report_json: $report_json$" "$explain_out" &&
    grep -Eq '^top_categories: ' "$explain_out"; then
    test_pass "contract-debt-report explain output includes counts and paths"
  else
    test_fail "contract-debt-report explain output includes counts and paths"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --json >"$json_out" 2>"$json_err"
  ) && [ ! -s "$json_err" ] && python3 -m json.tool "$json_out" >/dev/null &&
    smoke_json_assert "$json_out" 'data.get("script") == "contract-debt-report" and data.get("overall_status") in ("pass", "warn") and data.get("report_markdown", "").endswith("contract-debt-report.md") and data.get("report_json", "").endswith("contract-debt-report.json") and "script_large_lines" in data.get("thresholds", {}) and "max_findings_per_category" in data.get("thresholds", {})'; then
    cmp -s "$json_out" "$report_json" &&
      [ -f "$report_markdown" ] &&
      test_pass "contract-debt-report json output is valid and matches the report file"
  else
    test_fail "contract-debt-report json output is valid and matches the report file"
    status=1
  fi

  python3 - "$seeded_large_file" <<'PY' || return 1
from pathlib import Path
import sys
path = Path(sys.argv[1])
path.write_text("\n".join(f"line {i}" for i in range(1, 505)) + "\n", encoding="utf-8")
PY
  git -C "$smoke_test_dir" add repo-automation/bin/contract-debt-large-candidate || return 1

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --json >"$large_json" 2>"$large_err"
  ) && [ ! -s "$large_err" ] && python3 -m json.tool "$large_json" >/dev/null &&
    smoke_json_assert "$large_json" 'data.get("overall_status") == "warn" and any(f.get("severity") == "warn" and f.get("category") == "file-size" and f.get("path") == "repo-automation/bin/contract-debt-large-candidate" for f in data.get("findings", []))'; then
    test_pass "contract-debt-report warns on large files"
  else
    test_fail "contract-debt-report warns on large files"
    status=1
  fi

  cat > "$smoke_test_dir/repo-automation/tests/lib/contracts/contract-debt-shared-coverage.sh" <<'EOF'
# shellcheck shell=bash

smoke_check_contract_debt_shared_coverage_contract() {
  # shared contract coverage markers
  # --json python3 -m json.tool
  # --quiet quiet success
  # unknown flag fail: fix:
  return 0
}
EOF

  cat > "$smoke_test_dir/repo-automation/tests/contracts/contract-debt-shared-coverage.sh" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/contracts/contract-debt-shared-coverage.sh"

smoke_main_impl() {
  local status=0

  smoke_run_named_check "smoke:contract-debt-shared-coverage-contract" smoke_check_contract_debt_shared_coverage_contract || status=1

  return "$status"
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_main_impl "$@"
}

smoke_main "$@"
EOF

  cat > "$smoke_test_dir/repo-automation/bin/contract-debt-shared-coverage" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

echo contract-debt-shared-coverage
EOF

  cat > "$smoke_test_dir/repo-automation/docs/contract-debt-shared-coverage.md" <<'EOF'
# Contract Debt Shared Coverage

`repo-automation/bin/contract-debt-shared-coverage` is a focused helper used by the contract-debt-report smoke checks.

```sh
repo-automation/bin/contract-debt-shared-coverage
```
EOF

  cat > "$smoke_test_dir/repo-automation/tests/lib/contracts/contract-debt-missing-shared.sh" <<'EOF'
# shellcheck shell=bash

smoke_check_contract_debt_missing_shared_support() {
  return 0
}
EOF

  cat > "$smoke_test_dir/repo-automation/tests/contracts/aa-contract-debt-missing-shared.sh" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/contracts/contract-debt-missing-shared.sh"

smoke_main_impl() {
  local status=0

  # shared wrapper coverage markers
  # --json python3 -m json.tool
  # --quiet quiet success
  # unknown flag fail: fix:
  smoke_run_named_check "smoke:contract-debt-missing-shared-contract" smoke_check_contract_debt_missing_shared_contract || status=1

  return "$status"
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_main_impl "$@"
}

smoke_main "$@"
EOF

  cat > "$smoke_test_dir/repo-automation/bin/aa-contract-debt-missing-shared" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

echo contract-debt-missing-shared
EOF

  cat > "$smoke_test_dir/repo-automation/docs/aa-contract-debt-missing-shared.md" <<'EOF'
# Contract Debt Missing Shared

`repo-automation/bin/aa-contract-debt-missing-shared` is a focused helper used by the contract-debt-report smoke checks.

```sh
repo-automation/bin/aa-contract-debt-missing-shared
```
EOF

  cat > "$smoke_test_dir/repo-automation/bin/contract-debt-gap-doc" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

echo contract-debt-gap-doc
EOF

  cat > "$smoke_test_dir/repo-automation/bin/contract-debt-gap-contract" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

echo contract-debt-gap-contract
EOF

  cat > "$smoke_test_dir/repo-automation/docs/contract-debt-gap-contract.md" <<'EOF'
# Contract Debt Gap Contract

`repo-automation/bin/contract-debt-gap-contract` is a focused helper used by the contract-debt-report smoke checks.

```sh
repo-automation/bin/contract-debt-gap-contract
```
EOF

  python3 - "$smoke_test_dir/repo-automation/helper-metadata.json" "$smoke_test_dir/repo-automation/manifest.json" <<'PY' || return 1
from pathlib import Path
import json
import sys

metadata_path = Path(sys.argv[1])
manifest_path = Path(sys.argv[2])

metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
helpers = metadata.setdefault("helpers", [])

helper_entries = [
    {
        "name": "contract-debt-shared-coverage",
        "path": "repo-automation/bin/contract-debt-shared-coverage",
        "doc_path": "repo-automation/docs/contract-debt-shared-coverage.md",
        "contract_test_path": "repo-automation/tests/contracts/contract-debt-shared-coverage.sh",
        "kind": "script",
        "public": True,
        "phone_safe": True,
        "check_cost_tier": "broad-local",
        "writes_files": False,
        "writes_git": False,
        "uses_github": False,
        "runs_run_tests": False,
        "can_run_broad_checks": True,
        "supports_quiet": True,
        "supports_json": True,
        "artifact_helper": False,
        "umbrella_helper": False,
        "workflow_role": "audit",
        "config_keys": [],
    },
    {
        "name": "contract-debt-aa-missing-shared",
        "path": "repo-automation/bin/aa-contract-debt-missing-shared",
        "doc_path": "repo-automation/docs/aa-contract-debt-missing-shared.md",
        "contract_test_path": "repo-automation/tests/contracts/aa-contract-debt-missing-shared.sh",
        "kind": "script",
        "public": True,
        "phone_safe": True,
        "check_cost_tier": "broad-local",
        "writes_files": False,
        "writes_git": False,
        "uses_github": False,
        "runs_run_tests": False,
        "can_run_broad_checks": True,
        "supports_quiet": True,
        "supports_json": True,
        "artifact_helper": False,
        "umbrella_helper": False,
        "workflow_role": "audit",
        "config_keys": [],
    },
    {
        "name": "contract-debt-gap-doc",
        "path": "repo-automation/bin/contract-debt-gap-doc",
        "contract_test_path": "repo-automation/tests/contracts/contract-debt-shared-coverage.sh",
        "kind": "script",
        "public": True,
        "phone_safe": True,
        "check_cost_tier": "broad-local",
        "writes_files": False,
        "writes_git": False,
        "uses_github": False,
        "runs_run_tests": False,
        "can_run_broad_checks": True,
        "supports_quiet": True,
        "supports_json": True,
        "artifact_helper": False,
        "umbrella_helper": False,
        "workflow_role": "audit",
        "config_keys": [],
    },
    {
        "name": "contract-debt-gap-contract",
        "path": "repo-automation/bin/contract-debt-gap-contract",
        "doc_path": "repo-automation/docs/contract-debt-gap-contract.md",
        "kind": "script",
        "public": True,
        "phone_safe": True,
        "check_cost_tier": "broad-local",
        "writes_files": False,
        "writes_git": False,
        "uses_github": False,
        "runs_run_tests": False,
        "can_run_broad_checks": True,
        "supports_quiet": True,
        "supports_json": True,
        "artifact_helper": False,
        "umbrella_helper": False,
        "workflow_role": "audit",
        "config_keys": [],
    },
]

known_helpers = {entry.get("name") for entry in helpers if isinstance(entry, dict)}
for entry in helper_entries:
    if entry["name"] not in known_helpers:
        helpers.append(entry)

manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
managed_files = manifest.setdefault("managed_files", [])
known_paths = {entry.get("path") for entry in managed_files if isinstance(entry, dict)}

for path in [
    "repo-automation/bin/contract-debt-shared-coverage",
    "repo-automation/docs/contract-debt-shared-coverage.md",
    "repo-automation/tests/contracts/contract-debt-shared-coverage.sh",
    "repo-automation/bin/contract-debt-missing-shared",
    "repo-automation/bin/aa-contract-debt-missing-shared",
    "repo-automation/docs/aa-contract-debt-missing-shared.md",
    "repo-automation/tests/contracts/aa-contract-debt-missing-shared.sh",
    "repo-automation/bin/contract-debt-gap-doc",
    "repo-automation/bin/contract-debt-gap-contract",
    "repo-automation/docs/contract-debt-gap-contract.md",
]:
    if path not in known_paths:
        managed_files.append({"path": path})

metadata_path.write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
PY

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --json >"$shared_coverage_json" 2>"$shared_coverage_err"
  ) && [ ! -s "$shared_coverage_err" ] && python3 -m json.tool "$shared_coverage_json" >/dev/null &&
    smoke_json_assert "$shared_coverage_json" 'not any(f.get("severity") == "warn" and f.get("category") == "contract-coverage" and f.get("helper") == "contract-debt-shared-coverage" for f in data.get("findings", []))'; then
    test_pass "contract-debt-report uses shared contract bodies for coverage"
  else
    test_fail "contract-debt-report uses shared contract bodies for coverage"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --json >"$missing_shared_json" 2>"$missing_shared_err"
  ) && [ ! -s "$missing_shared_err" ] && python3 -m json.tool "$missing_shared_json" >/dev/null &&
    smoke_json_assert "$missing_shared_json" 'any(f.get("severity") == "warn" and f.get("category") == "contract-coverage" and f.get("helper") == "check-tooling" and "missing shared contract function" in f.get("message", "") for f in data.get("findings", []))'; then
    test_pass "contract-debt-report warns when a shared contract function is missing"
  else
    test_fail "contract-debt-report warns when a shared contract function is missing"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --json >"$missing_doc_json" 2>"$missing_doc_err"
  ) && [ ! -s "$missing_doc_err" ] && python3 -m json.tool "$missing_doc_json" >/dev/null &&
    smoke_json_assert "$missing_doc_json" 'any(f.get("severity") == "warn" and f.get("category") == "metadata-gap" and f.get("helper") == "contract-debt-gap-doc" and "doc_path metadata is missing or empty" in f.get("message", "") for f in data.get("findings", []))'; then
    test_pass "contract-debt-report warns when doc_path metadata is missing"
  else
    test_fail "contract-debt-report warns when doc_path metadata is missing"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --json >"$missing_contract_json" 2>"$missing_contract_err"
  ) && [ ! -s "$missing_contract_err" ] && python3 -m json.tool "$missing_contract_json" >/dev/null &&
    smoke_json_assert "$missing_contract_json" 'any(f.get("severity") == "warn" and f.get("category") == "metadata-gap" and f.get("helper") == "contract-debt-gap-contract" and "contract_test_path metadata is missing or empty" in f.get("message", "") for f in data.get("findings", []))'; then
    test_pass "contract-debt-report warns when contract_test_path metadata is missing"
  else
    test_fail "contract-debt-report warns when contract_test_path metadata is missing"
    status=1
  fi

  python3 - "$smoke_test_dir/repo-automation/helper-metadata.json" <<'PY' || return 1
from pathlib import Path
import json
import sys
path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
helpers = data.setdefault("helpers", [])
helpers.append(
    {
        "name": "contract-debt-gap",
        "path": "repo-automation/bin/contract-debt-gap",
        "doc_path": "repo-automation/docs/contract-debt-gap.md",
        "contract_test_path": "repo-automation/tests/contracts/contract-debt-gap.sh",
        "kind": "script",
        "public": True,
        "phone_safe": True,
        "check_cost_tier": "broad-local",
        "writes_files": False,
        "writes_git": False,
        "uses_github": False,
        "runs_run_tests": False,
        "can_run_broad_checks": True,
        "supports_quiet": True,
        "supports_json": True,
        "artifact_helper": False,
        "umbrella_helper": False,
        "workflow_role": "audit",
        "config_keys": [],
    }
)
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --json >"$gap_json" 2>"$gap_err"
  ) && [ ! -s "$gap_err" ] && python3 -m json.tool "$gap_json" >/dev/null &&
    smoke_json_assert "$gap_json" 'data.get("overall_status") == "warn" and any(f.get("severity") == "warn" and f.get("category") == "metadata-gap" and f.get("path") in ("repo-automation/docs/contract-debt-gap.md", "repo-automation/tests/contracts/contract-debt-gap.sh", "repo-automation/bin/contract-debt-gap") for f in data.get("findings", []))'; then
    test_pass "contract-debt-report warns on helper metadata and file gaps"
  else
    test_fail "contract-debt-report warns on helper metadata and file gaps"
    status=1
  fi

  cat > "$json_gap_file" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

# smoke:ci-failure-artifacts contract coverage stub
echo contract-debt-report
EOF
  chmod +x "$json_gap_file" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --json >"$gap_json" 2>"$gap_err"
  ) && [ ! -s "$gap_err" ] && python3 -m json.tool "$gap_json" >/dev/null &&
    smoke_json_assert "$gap_json" 'any(f.get("severity") == "warn" and f.get("category") == "contract-coverage" and f.get("helper") == "ci-failure-artifacts" and "supports_json" in f.get("message", "") for f in data.get("findings", []))'; then
    test_pass "contract-debt-report warns when supports_json coverage is missing"
  else
    test_fail "contract-debt-report warns when supports_json coverage is missing"
    status=1
  fi

  cat > "$quiet_gap_file" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

# smoke:repo-doctor contract coverage stub
echo contract-debt-report
EOF
  chmod +x "$quiet_gap_file" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --json >"$large_json" 2>"$large_err"
  ) && [ ! -s "$large_err" ] && python3 -m json.tool "$large_json" >/dev/null &&
    smoke_json_assert "$large_json" 'any(f.get("severity") == "warn" and f.get("category") == "contract-coverage" and f.get("helper") == "ci-failure-artifacts" and "quiet" in f.get("message", "") for f in data.get("findings", []))'; then
    test_pass "contract-debt-report warns when supports_quiet coverage is missing"
  else
    test_fail "contract-debt-report warns when supports_quiet coverage is missing"
    status=1
  fi

  cat > "$smoke_test_dir/repo-automation/helper-metadata.json" <<'EOF'
not-json
EOF

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$report_tmpdir" repo-automation/bin/contract-debt-report --json >"$invalid_meta_json" 2>"$invalid_meta_err"
  ); then
    test_fail "contract-debt-report fails on invalid helper metadata"
    status=1
  elif python3 -m json.tool "$invalid_meta_json" >/dev/null &&
    smoke_json_assert "$invalid_meta_json" 'data.get("overall_status") == "fail" and any(f.get("severity") == "fail" for f in data.get("findings", []))'; then
    test_pass "contract-debt-report fails on invalid helper metadata"
  else
    test_fail "contract-debt-report fails on invalid helper metadata"
    status=1
  fi

  rm -f "$help_out" "$help_err" "$unknown_err" "$outdir_space_err" "$outdir_empty_err" "$default_out" "$default_err" "$quiet_out" "$quiet_err" "$explain_out" "$explain_err" "$json_out" "$json_err" "$large_json" "$large_err" "$shared_coverage_json" "$shared_coverage_err" "$missing_shared_json" "$missing_shared_err" "$missing_doc_json" "$missing_doc_err" "$missing_contract_json" "$missing_contract_err" "$gap_json" "$gap_err" "$invalid_meta_json" "$invalid_meta_err" >/dev/null 2>&1 || true
  rm -f "$seeded_large_file" >/dev/null 2>&1 || true
  return "$status"
}

# repo-automation/tests/lib/contracts/repo-health.sh EOF
