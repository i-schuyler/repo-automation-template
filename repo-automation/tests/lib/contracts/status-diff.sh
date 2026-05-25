# repo-automation/tests/lib/contracts/status-diff.sh

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

smoke_check_touched_files_contract() {
  local status=0
  local touched_worktree_json="$smoke_test_base/touched-files-worktree-$$.json"
  local touched_range_json="$smoke_test_base/touched-files-range-$$.json"
  local touched_help="$smoke_test_base/touched-files-help-$$.txt"
  local gh_stub_dir="$smoke_test_base/gh-stub"
  local touched_range_repo=""
  local touched_base_format_stderr="$smoke_test_base/touched-files-base-format-$$.txt"
  local touched_base_missing_stderr="$smoke_test_base/touched-files-base-missing-$$.txt"
  local touched_base_empty_stderr="$smoke_test_base/touched-files-base-empty-$$.txt"
  local touched_head_format_stderr="$smoke_test_base/touched-files-head-format-$$.txt"
  local touched_head_missing_stderr="$smoke_test_base/touched-files-head-missing-$$.txt"
  local touched_head_empty_stderr="$smoke_test_base/touched-files-head-empty-$$.txt"
  local touched_base_unknown_stderr="$smoke_test_base/touched-files-base-unknown-$$.txt"
  local touched_positional_stderr="$smoke_test_base/touched-files-positional-$$.txt"

  smoke_write_gh_stub "$gh_stub_dir" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/touched-files --help > "$touched_help"
  ) && \
    grep -Fq -- '--base=<ref>' "$touched_help" && \
    grep -Fq -- '--head=<ref>' "$touched_help" && \
    ! grep -Fq -- '--base REF' "$touched_help" && \
    ! grep -Fq -- '--head REF' "$touched_help"; then
    test_pass "touched-files help shows strict value syntax"
  else
    test_fail "touched-files help shows strict value syntax"
    status=1
  fi


  if (
    cd "$smoke_test_dir" || return 1
    printf '\nsmoke touched-files\n' >> README.md || return 1
    : > scratch.txt || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/touched-files --machine-json > "$touched_worktree_json"
  ) && python3 -m json.tool "$touched_worktree_json" >/dev/null && \
    smoke_json_assert "$touched_worktree_json" 'data.get("mode") == "working-tree" and "README.md" in data.get("working_tree_tracked_files", []) and "scratch.txt" in data.get("untracked_files", [])'; then
    test_pass "touched-files working-tree fallback is parseable"
  else
    test_fail "touched-files working-tree fallback is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    rm -f scratch.txt >/dev/null 2>&1 || true
    git checkout -- README.md >/dev/null 2>&1 || true
  ); then
    :
  fi

  touched_range_repo="$(smoke_setup_subset_repo)" || {
    test_fail "touched-files commit-range fixture creates a repo"
    status=1
  }

  if [ -n "$touched_range_repo" ] && (
    cd "$touched_range_repo" || return 1
    git checkout -b feature/touched-files-range >/dev/null 2>&1 || return 1
    printf '
range touch
' >> repo-automation/docs/testing.md || return 1
    git add repo-automation/docs/testing.md || return 1
    git commit -m "range touch" >/dev/null || return 1
    repo-automation/bin/touched-files --machine-json > "$touched_range_json"
  ) && python3 -m json.tool "$touched_range_json" >/dev/null &&     smoke_json_assert "$touched_range_json" 'data.get("mode") == "commit-range" and "repo-automation/docs/testing.md" in data.get("commit_range_files", [])'; then
    test_pass "touched-files commit-range output is parseable"
  else
    test_fail "touched-files commit-range output is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/touched-files --base main >/dev/null 2> "$touched_base_format_stderr"
  ); then
    test_fail "touched-files rejects --base <ref>"
    status=1
  elif smoke_assert_flag_error_shape "$touched_base_format_stderr" "flag format not accepted" "--base" "use --base=<ref>"; then
    test_pass "touched-files rejects --base <ref>"
  else
    test_fail "touched-files rejects --base <ref>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/touched-files --head main >/dev/null 2> "$touched_head_format_stderr"
  ); then
    test_fail "touched-files rejects --head <ref>"
    status=1
  elif smoke_assert_flag_error_shape "$touched_head_format_stderr" "flag format not accepted" "--head" "use --head=<ref>"; then
    test_pass "touched-files rejects --head <ref>"
  else
    test_fail "touched-files rejects --head <ref>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/touched-files --base >/dev/null 2> "$touched_base_missing_stderr"
  ); then
    test_fail "touched-files rejects missing --base value"
    status=1
  elif smoke_assert_flag_error_shape "$touched_base_missing_stderr" "missing flag value" "--base" "use --base=<ref>"; then
    test_pass "touched-files rejects missing --base value"
  else
    test_fail "touched-files rejects missing --base value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/touched-files --head >/dev/null 2> "$touched_head_missing_stderr"
  ); then
    test_fail "touched-files rejects missing --head value"
    status=1
  elif smoke_assert_flag_error_shape "$touched_head_missing_stderr" "missing flag value" "--head" "use --head=<ref>"; then
    test_pass "touched-files rejects missing --head value"
  else
    test_fail "touched-files rejects missing --head value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/touched-files --base= >/dev/null 2> "$touched_base_empty_stderr"
  ); then
    test_fail "touched-files rejects empty --base value"
    status=1
  elif smoke_assert_flag_error_shape "$touched_base_empty_stderr" "empty flag value" "--base" "use --base=<ref>"; then
    test_pass "touched-files rejects empty --base value"
  else
    test_fail "touched-files rejects empty --base value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/touched-files --head= >/dev/null 2> "$touched_head_empty_stderr"
  ); then
    test_fail "touched-files rejects empty --head value"
    status=1
  elif smoke_assert_flag_error_shape "$touched_head_empty_stderr" "empty flag value" "--head" "use --head=<ref>"; then
    test_pass "touched-files rejects empty --head value"
  else
    test_fail "touched-files rejects empty --head value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/touched-files --whatever >/dev/null 2> "$touched_base_unknown_stderr"
  ); then
    test_fail "touched-files rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$touched_base_unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/touched-files --help"; then
    test_pass "touched-files rejects unknown flags"
  else
    test_fail "touched-files rejects unknown flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/touched-files positional >/dev/null 2> "$touched_positional_stderr"
  ); then
    test_fail "touched-files rejects positional arguments"
    status=1
  elif grep -Fxq 'STOP: unknown argument: positional' "$touched_positional_stderr"; then
    test_pass "touched-files rejects positional arguments"
  else
    test_fail "touched-files rejects positional arguments"
    status=1
  fi

  rm -f "$touched_worktree_json" "$touched_range_json" "$touched_help" "$touched_base_format_stderr" "$touched_base_missing_stderr" "$touched_base_empty_stderr" "$touched_head_format_stderr" "$touched_head_missing_stderr" "$touched_head_empty_stderr" "$touched_base_unknown_stderr" "$touched_positional_stderr" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_status_packet_contract() {
  local status=0
  local temp_root="$smoke_test_base/status-packet-root"
  local log_root="$temp_root/repo-automation-template"
  local status_human="$smoke_test_base/status-packet-human-$$.txt"
  local status_json="$smoke_test_base/status-packet-json-$$.json"
  local status_final_summary="$smoke_test_base/status-packet-final-summary-$$.txt"
  local status_final_summary_hooks="$smoke_test_base/status-packet-final-summary-hooks-$$.txt"
  local status_explain="$smoke_test_base/status-packet-explain-$$.txt"
  local gh_stub_dir="$smoke_test_base/gh-stub-status-packet"
  local status_unknown_stderr="$smoke_test_base/status-packet-unknown-$$.txt"
  local status_packet_local_config="$smoke_test_dir/.repo-automation.local.conf"

  smoke_write_gh_stub "$gh_stub_dir" || return 1
  mkdir -p "$log_root" || return 1
  cat > "$log_root/run-tests-20260512-140000.log" <<'EOF'
INFO: run-tests recent
EOF
  cat > "$log_root/repo-doctor-20260512-150000.log" <<'EOF'
INFO: repo-doctor recent
EOF
  touch -t 202605121400.00 "$log_root/run-tests-20260512-140000.log" || return 1
  touch -t 202605121500.00 "$log_root/repo-doctor-20260512-150000.log" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    printf '
status packet smoke
' >> README.md || return 1
    printf 'scratch
' > status-packet-scratch.txt || return 1
    TMPDIR="$temp_root" PATH="$gh_stub_dir:$PATH" GH_STUB_PR_LIST_JSON='[]' repo-automation/bin/status-packet > "$status_human"
  ) && grep -Eq '^Branch: main$' "$status_human" && grep -Eq '^Git status --short:$' "$status_human" && grep -Eq '^ M README.md$' "$status_human" && grep -Eq '^\?\? status-packet-scratch\.txt$' "$status_human" && grep -Eq '^Tracked changed files:$' "$status_human" && grep -Eq '^- README.md$' "$status_human" && grep -Eq '^Untracked files:$' "$status_human" && grep -Eq '^- status-packet-scratch\.txt$' "$status_human" && grep -Eq '^Recent logs:$' "$status_human" && grep -Eq "^- run-tests: $log_root/run-tests-20260512-140000.log$" "$status_human" && grep -Eq "^- repo-doctor: $log_root/repo-doctor-20260512-150000.log$" "$status_human"; then
    test_pass "status-packet human output reports compact repo state"
  else
    test_fail "status-packet human output reports compact repo state"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$temp_root" PATH="$gh_stub_dir:$PATH" GH_STUB_PR_LIST_JSON='[]' repo-automation/bin/status-packet --machine-json > "$status_json"
  ) && python3 -m json.tool "$status_json" >/dev/null &&     smoke_json_assert "$status_json" 'data.get("script") == "status-packet" and data.get("machine_json") is True and data.get("branch") == "main" and "README.md" in data.get("changed_tracked_files", []) and "status-packet-scratch.txt" in data.get("untracked_files", []) and data.get("recent_logs", {}).get("run_tests", "").endswith("run-tests-20260512-140000.log") and data.get("recent_logs", {}).get("repo_doctor", "").endswith("repo-doctor-20260512-150000.log") and data.get("overall_status") == "pass"'; then
    test_pass "status-packet machine-json reports compact repo state"
  else
    test_fail "status-packet machine-json reports compact repo state"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$temp_root" PATH="$gh_stub_dir:$PATH" GH_STUB_PR_LIST_JSON='[]' repo-automation/bin/status-packet --explain > "$status_explain"
  ) && [ "$(wc -l < "$status_explain" | tr -d '[:space:]')" -eq 7 ] && grep -Fxq '===== FINAL SUMMARY =====' "$status_explain" && grep -Eq '^branch=main$' "$status_explain" && grep -Eq '^rc=0$' "$status_explain" && grep -Eq '^output_lines=[0-9]+$' "$status_explain" && awk -F= '$1=="output_lines" { exit !($2 <= 25) }' "$status_explain" && grep -Eq '^url_or_stop=pass$' "$status_explain" && grep -Eq '^status_count=[0-9]+$' "$status_explain" && grep -Fxq '===== END =====' "$status_explain"; then
    test_pass "status-packet explain output uses the compact marker contract"
  else
    test_fail "status-packet explain output uses the compact marker contract"
    status=1
  fi

  cat > "$status_packet_local_config" <<'EOF'
FINAL_SUMMARY_AFTER_START_HOOK="mark"
FINAL_SUMMARY_BEFORE_END_HOOK="recap"
EOF

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$temp_root" PATH="$gh_stub_dir:$PATH" GH_STUB_PR_LIST_JSON='[]' repo-automation/bin/status-packet --explain > "$status_final_summary_hooks"
  ) && [ "$(wc -l < "$status_final_summary_hooks" | tr -d '[:space:]')" -eq 9 ] && [ "$(sed -n '2p' "$status_final_summary_hooks")" = 'mark' ] && [ "$(sed -n '8p' "$status_final_summary_hooks")" = 'recap' ] && grep -Fxq '===== FINAL SUMMARY =====' "$status_final_summary_hooks" && grep -Eq '^branch=main$' "$status_final_summary_hooks" && grep -Eq '^rc=0$' "$status_final_summary_hooks" && grep -Eq '^output_lines=[0-9]+$' "$status_final_summary_hooks" && awk -F= '$1=="output_lines" { exit !($2 <= 25) }' "$status_final_summary_hooks" && grep -Eq '^url_or_stop=pass$' "$status_final_summary_hooks" && grep -Eq '^status_count=[0-9]+$' "$status_final_summary_hooks" && grep -Fxq '===== END =====' "$status_final_summary_hooks"; then
    test_pass "status-packet explain hook lines render in the contract"
  else
    test_fail "status-packet explain hook lines render in the contract"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$temp_root" PATH="$gh_stub_dir:$PATH" GH_STUB_PR_LIST_JSON='[]' repo-automation/bin/status-packet --whatever >/dev/null 2> "$status_unknown_stderr"
  ); then
    test_fail "status-packet rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$status_unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/status-packet --help"; then
    test_pass "status-packet rejects unknown flags"
  else
    test_fail "status-packet rejects unknown flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    git checkout -- README.md >/dev/null 2>&1 || return 1
    rm -f status-packet-scratch.txt >/dev/null 2>&1 || return 1
  ); then
    :
  fi

  rm -f "$status_human" "$status_json" "$status_final_summary" "$status_final_summary_hooks" "$status_explain" "$status_unknown_stderr" "$status_packet_local_config" >/dev/null 2>&1 || true
  rm -f "$log_root"/run-tests-20260512-140000.log "$log_root"/repo-doctor-20260512-150000.log >/dev/null 2>&1 || true
  rmdir "$log_root" "$temp_root" >/dev/null 2>&1 || true
  return "$status"
}

# repo-automation/tests/lib/contracts/status-diff.sh EOF
