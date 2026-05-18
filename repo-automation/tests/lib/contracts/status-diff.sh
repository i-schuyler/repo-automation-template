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
  rm -f "$help_file" "$kind_format_stderr" "$kind_missing_stderr" "$kind_empty_stderr" "$kind_unknown_stderr" >/dev/null 2>&1 || true
  rm -f "$log_root"/run-tests-20260512-110000.log "$log_root"/run-tests-20260512-120000.log "$log_root"/repo-doctor-20260512-130000.log >/dev/null 2>&1 || true
  rmdir "$log_root" "$temp_root" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_touched_files_and_ci_contract() {
  local status=0
  local touched_worktree_json="$smoke_test_base/touched-files-worktree-$$.json"
  local touched_range_json="$smoke_test_base/touched-files-range-$$.json"
  local touched_help="$smoke_test_base/touched-files-help-$$.txt"
  local ci_status_help="$smoke_test_base/ci-status-help-$$.txt"
  local ci_watch_help="$smoke_test_base/ci-watch-help-$$.txt"
  local ci_status_pr_json="$smoke_test_base/ci-status-pr-$$.json"
  local ci_status_branch_json="$smoke_test_base/ci-status-branch-$$.json"
  local ci_status_pr_human="$smoke_test_base/ci-status-pr-human-$$.txt"
  local ci_status_pr_quiet="$smoke_test_base/ci-status-pr-quiet-$$.txt"
  local ci_status_pr_explain="$smoke_test_base/ci-status-pr-explain-$$.txt"
  local ci_status_failure_stderr="$smoke_test_base/ci-status-failure-$$.txt"
  local ci_watch_timeout_stderr="$smoke_test_base/ci-watch-timeout-$$.txt"
  local ci_status_pr_format_stderr="$smoke_test_base/ci-status-pr-format-$$.txt"
  local ci_status_pr_missing_stderr="$smoke_test_base/ci-status-pr-missing-$$.txt"
  local ci_status_pr_empty_stderr="$smoke_test_base/ci-status-pr-empty-$$.txt"
  local ci_status_unknown_stderr="$smoke_test_base/ci-status-unknown-$$.txt"
  local ci_watch_timeout_format_stderr="$smoke_test_base/ci-watch-timeout-format-$$.txt"
  local ci_watch_timeout_missing_stderr="$smoke_test_base/ci-watch-timeout-missing-$$.txt"
  local ci_watch_timeout_empty_stderr="$smoke_test_base/ci-watch-timeout-empty-$$.txt"
  local ci_watch_unknown_stderr="$smoke_test_base/ci-watch-unknown-$$.txt"
  local ci_watch_pass_json="$smoke_test_base/ci-watch-pass-$$.json"
  local ci_watch_pass_stderr="$smoke_test_base/ci-watch-pass-$$.txt"
  local ci_watch_pass_human="$smoke_test_base/ci-watch-pass-human-$$.txt"
  local ci_watch_pass_quiet="$smoke_test_base/ci-watch-pass-quiet-$$.txt"
  local ci_watch_pass_explain="$smoke_test_base/ci-watch-pass-explain-$$.txt"
  local ci_watch_fail_json="$smoke_test_base/ci-watch-fail-$$.json"
  local ci_watch_fail_stderr="$smoke_test_base/ci-watch-fail-$$.txt"
  local gh_stub_dir="$smoke_test_base/gh-stub"
  local touched_range_repo=""
  local touched_base_format_stderr="$smoke_test_base/touched-files-base-format-$$.txt"
  local touched_base_missing_stderr="$smoke_test_base/touched-files-base-missing-$$.txt"
  local touched_base_empty_stderr="$smoke_test_base/touched-files-base-empty-$$.txt"
  local touched_base_unknown_stderr="$smoke_test_base/touched-files-base-unknown-$$.txt"

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
    repo-automation/bin/ci-status --help > "$ci_status_help"
  ) && \
    grep -Fq -- '--pr=<number>' "$ci_status_help" && \
    grep -Fq -- '--branch=<name>' "$ci_status_help" && \
    grep -Fq -- '--quiet' "$ci_status_help" && \
    grep -Fq -- '--explain' "$ci_status_help" && \
    ! grep -Fq -- '--pr=NUMBER' "$ci_status_help" && \
    ! grep -Fq -- '--branch=NAME' "$ci_status_help"; then
    test_pass "ci-status help shows strict value syntax"
  else
    test_fail "ci-status help shows strict value syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/ci-watch --help > "$ci_watch_help"
  ) && \
    grep -Fq -- '--pr=<number>' "$ci_watch_help" && \
    grep -Fq -- '--branch=<name>' "$ci_watch_help" && \
    grep -Fq -- '--poll-seconds=<seconds>' "$ci_watch_help" && \
    grep -Fq -- '--timeout=<seconds>' "$ci_watch_help" && \
    grep -Fq -- '--quiet' "$ci_watch_help" && \
    grep -Fq -- '--explain' "$ci_watch_help" && \
    ! grep -Fq -- '--pr=NUMBER' "$ci_watch_help" && \
    ! grep -Fq -- '--branch=NAME' "$ci_watch_help" && \
    ! grep -Fq -- '--poll-seconds=SECONDS' "$ci_watch_help" && \
    ! grep -Fq -- '--timeout=SECONDS' "$ci_watch_help"; then
    test_pass "ci-watch help shows strict value syntax"
  else
    test_fail "ci-watch help shows strict value syntax"
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
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pending","state":"IN_PROGRESS","workflow":"ci"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-status --pr=123 --machine-json > "$ci_status_pr_json"
  ) && python3 -m json.tool "$ci_status_pr_json" >/dev/null && \
    smoke_json_assert "$ci_status_pr_json" 'data.get("mode") == "pr" and data.get("overall_status") == "pending" and len(data.get("checks", [])) == 1'; then
    test_pass "ci-status pr machine-json is parseable"
  else
    test_fail "ci-status pr machine-json is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pass","state":"SUCCESS","workflow":"ci"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-status --pr=123 > "$ci_status_pr_human" 2>&1
  ) && [ "$(cat "$ci_status_pr_human")" = "pass" ]; then
    test_pass "ci-status default human output is compact"
  else
    test_fail "ci-status default human output is compact"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pass","state":"SUCCESS","workflow":"ci"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-status --pr=123 --quiet > "$ci_status_pr_quiet" 2>&1
  ) && [ ! -s "$ci_status_pr_quiet" ]; then
    test_pass "ci-status quiet success is silent"
  else
    test_fail "ci-status quiet success is silent"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pass","state":"SUCCESS","workflow":"ci"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-status --pr=123 --explain > "$ci_status_pr_explain" 2>&1
  ) && grep -Eq '^Target: PR #123$' "$ci_status_pr_explain" && grep -Eq '^Overall status: pass$' "$ci_status_pr_explain" && grep -Eq '^Checks:$' "$ci_status_pr_explain"; then
    test_pass "ci-status explain output is detailed"
  else
    test_fail "ci-status explain output is detailed"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_LIST_JSON='[]' GH_STUB_RUN_LIST_JSON='[{"number":99,"name":"ci","status":"completed","conclusion":"success"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-status --branch=feature/demo --machine-json > "$ci_status_branch_json"
  ) && python3 -m json.tool "$ci_status_branch_json" >/dev/null && \
    smoke_json_assert "$ci_status_branch_json" 'data.get("mode") == "branch" and data.get("overall_status") == "pass" and data.get("latest_run", {}).get("number") == 99'; then
    test_pass "ci-status branch machine-json is parseable"
  else
    test_fail "ci-status branch machine-json is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_CHECKS_JSON='[]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-status --pr 123 --machine-json > /dev/null 2> "$ci_status_pr_format_stderr"
  ); then
    test_fail "ci-status rejects --pr <number>"
    status=1
  elif smoke_assert_flag_error_shape "$ci_status_pr_format_stderr" "flag format not accepted" "--pr" "use --pr=<number>"; then
    test_pass "ci-status rejects --pr <number>"
  else
    test_fail "ci-status rejects --pr <number>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-status --pr --machine-json > /dev/null 2> "$ci_status_pr_missing_stderr"
  ); then
    test_fail "ci-status rejects missing --pr value"
    status=1
  elif smoke_assert_flag_error_shape "$ci_status_pr_missing_stderr" "missing flag value" "--pr" "use --pr=<number>"; then
    test_pass "ci-status rejects missing --pr value"
  else
    test_fail "ci-status rejects missing --pr value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-status --pr= --machine-json > /dev/null 2> "$ci_status_pr_empty_stderr"
  ); then
    test_fail "ci-status rejects empty --pr value"
    status=1
  elif smoke_assert_flag_error_shape "$ci_status_pr_empty_stderr" "empty flag value" "--pr" "use --pr=<number>"; then
    test_pass "ci-status rejects empty --pr value"
  else
    test_fail "ci-status rejects empty --pr value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-status --whatever > /dev/null 2> "$ci_status_unknown_stderr"
  ); then
    test_fail "ci-status rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$ci_status_unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/ci-status --help"; then
    test_pass "ci-status rejects unknown flags"
  else
    test_fail "ci-status rejects unknown flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_LIST_JSON='[]' GH_STUB_RUN_LIST_JSON='[]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-status --branch=feature/missing > /dev/null 2> "$ci_status_failure_stderr"
  ); then
    test_fail "ci-status missing branch fails cleanly"
    status=1
  elif grep -Eq 'no pull request or workflow run found' "$ci_status_failure_stderr"; then
    test_pass "ci-status missing branch fails cleanly"
  else
    test_fail "ci-status missing branch fails cleanly"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pass","state":"SUCCESS","workflow":"ci"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-watch --pr=123 --poll-seconds=1 --timeout=1 --machine-json > "$ci_watch_pass_json" 2> "$ci_watch_pass_stderr"
  ) && python3 -m json.tool "$ci_watch_pass_json" >/dev/null && \
    smoke_json_assert "$ci_watch_pass_json" 'data.get("overall_status") == "pass"'; then
    test_pass "ci-watch pass exits cleanly"
  else
    test_fail "ci-watch pass exits cleanly"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pass","state":"SUCCESS","workflow":"ci"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-watch --pr=123 --poll-seconds=1 --timeout=1 > "$ci_watch_pass_human" 2>&1
  ) && [ "$(cat "$ci_watch_pass_human")" = "pass" ]; then
    test_pass "ci-watch default human output is compact"
  else
    test_fail "ci-watch default human output is compact"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pass","state":"SUCCESS","workflow":"ci"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-watch --pr=123 --poll-seconds=1 --timeout=1 --quiet > "$ci_watch_pass_quiet" 2>&1
  ) && [ ! -s "$ci_watch_pass_quiet" ]; then
    test_pass "ci-watch quiet success is silent"
  else
    test_fail "ci-watch quiet success is silent"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pass","state":"SUCCESS","workflow":"ci"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-watch --pr=123 --poll-seconds=1 --timeout=1 --explain > "$ci_watch_pass_explain" 2>&1
  ) && grep -Eq '^CI watch status: pass after [0-9]+s$' "$ci_watch_pass_explain"; then
    test_pass "ci-watch explain output is detailed"
  else
    test_fail "ci-watch explain output is detailed"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"fail","state":"FAILURE","workflow":"ci"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-watch --pr=123 --poll-seconds=1 --timeout=1 --machine-json > "$ci_watch_fail_json" 2> "$ci_watch_fail_stderr"
  ); then
    test_fail "ci-watch fail exits nonzero"
    status=1
  elif python3 -m json.tool "$ci_watch_fail_json" >/dev/null && \
    smoke_json_assert "$ci_watch_fail_json" 'data.get("overall_status") == "fail"'; then
    test_pass "ci-watch fail exits nonzero"
  else
    test_fail "ci-watch fail exits nonzero"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pending","state":"IN_PROGRESS","workflow":"ci"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-watch --pr=123 --poll-seconds=1 --timeout=1 > /dev/null 2> "$ci_watch_timeout_stderr"
  ); then
    test_fail "ci-watch timeout fails cleanly"
    status=1
  elif grep -Eq 'timed out after 1s while waiting for CI' "$ci_watch_timeout_stderr"; then
    test_pass "ci-watch timeout fails cleanly"
  else
    test_fail "ci-watch timeout fails cleanly"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pending","state":"IN_PROGRESS","workflow":"ci"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-watch --pr=123 --poll-seconds 1 --timeout=1 > /dev/null 2> "$ci_watch_timeout_format_stderr"
  ); then
    test_fail "ci-watch rejects --poll-seconds <seconds>"
    status=1
  elif smoke_assert_flag_error_shape "$ci_watch_timeout_format_stderr" "flag format not accepted" "--poll-seconds" "use --poll-seconds=<seconds>"; then
    test_pass "ci-watch rejects --poll-seconds <seconds>"
  else
    test_fail "ci-watch rejects --poll-seconds <seconds>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-watch --timeout >/dev/null 2> "$ci_watch_timeout_missing_stderr"
  ); then
    test_fail "ci-watch rejects missing --timeout value"
    status=1
  elif smoke_assert_flag_error_shape "$ci_watch_timeout_missing_stderr" "missing flag value" "--timeout" "use --timeout=<seconds>"; then
    test_pass "ci-watch rejects missing --timeout value"
  else
    test_fail "ci-watch rejects missing --timeout value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-watch --timeout= >/dev/null 2> "$ci_watch_timeout_empty_stderr"
  ); then
    test_fail "ci-watch rejects empty --timeout value"
    status=1
  elif smoke_assert_flag_error_shape "$ci_watch_timeout_empty_stderr" "empty flag value" "--timeout" "use --timeout=<seconds>"; then
    test_pass "ci-watch rejects empty --timeout value"
  else
    test_fail "ci-watch rejects empty --timeout value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-watch --whatever >/dev/null 2> "$ci_watch_unknown_stderr"
  ); then
    test_fail "ci-watch rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$ci_watch_unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/ci-watch --help"; then
    test_pass "ci-watch rejects unknown flags"
  else
    test_fail "ci-watch rejects unknown flags"
    status=1
  fi

  rm -f "$touched_worktree_json" "$touched_range_json" "$ci_status_help" "$ci_watch_help" "$ci_status_pr_json" "$ci_status_branch_json" "$ci_status_pr_human" "$ci_status_pr_quiet" "$ci_status_pr_explain" "$ci_status_failure_stderr" "$ci_watch_timeout_stderr" "$ci_status_pr_format_stderr" "$ci_status_pr_missing_stderr" "$ci_status_pr_empty_stderr" "$ci_status_unknown_stderr" "$ci_watch_timeout_format_stderr" "$ci_watch_timeout_missing_stderr" "$ci_watch_timeout_empty_stderr" "$ci_watch_unknown_stderr" "$ci_watch_pass_json" "$ci_watch_pass_stderr" "$ci_watch_pass_human" "$ci_watch_pass_quiet" "$ci_watch_pass_explain" "$ci_watch_fail_json" "$ci_watch_fail_stderr" >/dev/null 2>&1 || true
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
  local gh_stub_dir="$smoke_test_base/gh-stub-status-packet"
  local status_unknown_stderr="$smoke_test_base/status-packet-unknown-$$.txt"
  local status_packet_config="$smoke_test_dir/.repo-automation.conf"

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
    TMPDIR="$temp_root" PATH="$gh_stub_dir:$PATH" GH_STUB_PR_LIST_JSON='[]' repo-automation/bin/status-packet --final-summary > "$status_final_summary"
  ) && [ "$(wc -l < "$status_final_summary" | tr -d '[:space:]')" -eq 7 ] && grep -Fxq '===== FINAL SUMMARY =====' "$status_final_summary" && grep -Eq '^branch=main$' "$status_final_summary" && grep -Eq '^rc=0$' "$status_final_summary" && grep -Eq '^output_lines=[0-9]+$' "$status_final_summary" && grep -Eq '^url_or_stop=pass$' "$status_final_summary" && grep -Eq '^status_count=[0-9]+$' "$status_final_summary" && grep -Fxq '===== END =====' "$status_final_summary"; then
    test_pass "status-packet final-summary output uses the compact marker contract"
  else
    test_fail "status-packet final-summary output uses the compact marker contract"
    status=1
  fi

  cat >> "$status_packet_config" <<'EOF'
FINAL_SUMMARY_AFTER_START_HOOK="after-start hook"
FINAL_SUMMARY_BEFORE_END_HOOK="before-end hook"
EOF

  if (
    cd "$smoke_test_dir" || return 1
    TMPDIR="$temp_root" PATH="$gh_stub_dir:$PATH" GH_STUB_PR_LIST_JSON='[]' repo-automation/bin/status-packet --final-summary > "$status_final_summary_hooks"
  ) && [ "$(wc -l < "$status_final_summary_hooks" | tr -d '[:space:]')" -eq 9 ] && [ "$(sed -n '2p' "$status_final_summary_hooks")" = 'after-start hook' ] && [ "$(sed -n '8p' "$status_final_summary_hooks")" = 'before-end hook' ] && grep -Fxq '===== FINAL SUMMARY =====' "$status_final_summary_hooks" && grep -Eq '^branch=main$' "$status_final_summary_hooks" && grep -Eq '^rc=0$' "$status_final_summary_hooks" && grep -Eq '^output_lines=[0-9]+$' "$status_final_summary_hooks" && grep -Eq '^url_or_stop=pass$' "$status_final_summary_hooks" && grep -Eq '^status_count=[0-9]+$' "$status_final_summary_hooks" && grep -Fxq '===== END =====' "$status_final_summary_hooks"; then
    test_pass "status-packet final-summary hook lines render in the contract"
  else
    test_fail "status-packet final-summary hook lines render in the contract"
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

  rm -f "$status_human" "$status_json" "$status_final_summary" "$status_final_summary_hooks" "$status_unknown_stderr" >/dev/null 2>&1 || true
  rm -f "$log_root"/run-tests-20260512-140000.log "$log_root"/repo-doctor-20260512-150000.log >/dev/null 2>&1 || true
  rmdir "$log_root" "$temp_root" >/dev/null 2>&1 || true
  return "$status"
}

# repo-automation/tests/lib/contracts/status-diff.sh EOF
