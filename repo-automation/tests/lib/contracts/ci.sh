# repo-automation/tests/lib/contracts/ci.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.



smoke_check_ci_log_dump_contract() {
  local status=0
  local gh_stub_dir="$smoke_test_base/gh-stub-ci-log-dump"
  local ci_log_out_dir="$smoke_test_base/ci-log-dump-out"
  local ci_log_json="$smoke_test_base/ci-log-dump-$$.json"
  local ci_log_human="$smoke_test_base/ci-log-dump-$$.txt"
  local ci_log_help="$smoke_test_base/ci-log-dump-help-$$.txt"
  local ci_log_pr_format_stderr="$smoke_test_base/ci-log-dump-pr-format-$$.stderr"
  local ci_log_pr_missing_stderr="$smoke_test_base/ci-log-dump-pr-missing-$$.stderr"
  local ci_log_pr_empty_stderr="$smoke_test_base/ci-log-dump-pr-empty-$$.stderr"
  local ci_log_repo_empty_stderr="$smoke_test_base/ci-log-dump-repo-empty-$$.stderr"
  local ci_log_out_dir_empty_stderr="$smoke_test_base/ci-log-dump-out-dir-empty-$$.stderr"
  local ci_log_first_failure_value_stderr="$smoke_test_base/ci-log-dump-first-failure-value-$$.stderr"
  local ci_log_unknown_stderr="$smoke_test_base/ci-log-dump-unknown-$$.stderr"
  local ci_log_first_failure_human="$smoke_test_base/ci-log-dump-first-failure-$$.txt"

  smoke_write_gh_stub "$gh_stub_dir" || return 1
  mkdir -p "$ci_log_out_dir" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/ci-log-dump --help > "$ci_log_help"
  ) && \
    grep -Fq -- '--repo=<owner/repo>' "$ci_log_help" && \
    grep -Fq -- '--pr=NUMBER' "$ci_log_help" && \
    grep -Fq -- '--run-id=ID' "$ci_log_help" && \
    grep -Fq -- '--out-dir=PATH' "$ci_log_help" && \
    grep -Fq -- '--tail=LINES' "$ci_log_help" && \
    grep -Fq -- '--first-failure' "$ci_log_help" && \
    ! grep -Fq -- '--pr NUMBER' "$ci_log_help" && \
    ! grep -Fq -- '--run-id ID' "$ci_log_help" && \
    ! grep -Fq -- '--out-dir PATH' "$ci_log_help" && \
    ! grep -Fq -- '--tail LINES' "$ci_log_help"; then
    test_pass "ci-log-dump help shows strict value syntax"
  else
    test_fail "ci-log-dump help shows strict value syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_LIST_JSON='[]' repo-automation/bin/ci-log-dump --pr 123 >/dev/null 2> "$ci_log_pr_format_stderr"
  ); then
    test_fail "ci-log-dump rejects --pr <number>"
    status=1
  elif smoke_assert_flag_error_shape "$ci_log_pr_format_stderr" "flag format not accepted" "--pr" "use --pr=<number>"; then
    test_pass "ci-log-dump rejects --pr <number>"
  else
    test_fail "ci-log-dump rejects --pr <number>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/ci-log-dump --pr >/dev/null 2> "$ci_log_pr_missing_stderr"
  ); then
    test_fail "ci-log-dump rejects missing --pr value"
    status=1
  elif smoke_assert_flag_error_shape "$ci_log_pr_missing_stderr" "missing flag value" "--pr" "use --pr=<number>"; then
    test_pass "ci-log-dump rejects missing --pr value"
  else
    test_fail "ci-log-dump rejects missing --pr value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/ci-log-dump --pr= >/dev/null 2> "$ci_log_pr_empty_stderr"
  ); then
    test_fail "ci-log-dump rejects empty --pr value"
    status=1
  elif smoke_assert_flag_error_shape "$ci_log_pr_empty_stderr" "empty flag value" "--pr" "use --pr=<number>"; then
    test_pass "ci-log-dump rejects empty --pr value"
  else
    test_fail "ci-log-dump rejects empty --pr value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/ci-log-dump --repo= >/dev/null 2> "$ci_log_repo_empty_stderr"
  ); then
    test_fail "ci-log-dump rejects empty --repo value"
    status=1
  elif smoke_assert_flag_error_shape "$ci_log_repo_empty_stderr" "empty flag value" "--repo" "use --repo=<owner/repo>"; then
    test_pass "ci-log-dump rejects empty --repo value"
  else
    test_fail "ci-log-dump rejects empty --repo value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/ci-log-dump --out-dir= >/dev/null 2> "$ci_log_out_dir_empty_stderr"
  ); then
    test_fail "ci-log-dump rejects empty --out-dir value"
    status=1
  elif smoke_assert_flag_error_shape "$ci_log_out_dir_empty_stderr" "empty flag value" "--out-dir" "use --out-dir=<path>"; then
    test_pass "ci-log-dump rejects empty --out-dir value"
  else
    test_fail "ci-log-dump rejects empty --out-dir value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/ci-log-dump --first-failure=true >/dev/null 2> "$ci_log_first_failure_value_stderr"
  ); then
    test_fail "ci-log-dump rejects --first-failure=<value>"
    status=1
  elif smoke_assert_flag_error_shape "$ci_log_first_failure_value_stderr" "flag format not accepted" "--first-failure" "use --first-failure"; then
    test_pass "ci-log-dump rejects --first-failure=<value>"
  else
    test_fail "ci-log-dump rejects --first-failure=<value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/ci-log-dump --whatever >/dev/null 2> "$ci_log_unknown_stderr"
  ); then
    test_fail "ci-log-dump rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$ci_log_unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/ci-log-dump --help"; then
    test_pass "ci-log-dump rejects unknown flags"
  else
    test_fail "ci-log-dump rejects unknown flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_LIST_JSON='[
      {"databaseId":111,"conclusion":"failure","createdAt":"2026-05-12T11:00:00Z","event":"push","headBranch":"branch/old","status":"completed","workflowName":"ci"}
    ]' GH_STUB_RUN_VIEW_FAILED_LOG='shellcheck: repo-automation/bin/pr-finish:42:1: SC2086: Double quote to prevent globbing and word splitting.
tail one
tail two' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --latest-failed --first-failure --tail=2 --out-dir="$ci_log_out_dir" > "$ci_log_first_failure_human"
  ) && grep -Eq '^Run id: 111$' "$ci_log_first_failure_human" && grep -Eq '^Saved log path: '"$ci_log_out_dir"'/actions_run_111_[0-9]{8}-[0-9]{6}\.log$' "$ci_log_first_failure_human" && grep -Eq '^First failure label: fail: shellcheck$' "$ci_log_first_failure_human" && grep -Eq '^First failure excerpt: shellcheck: repo-automation/bin/pr-finish:42:1: SC2086: Double quote to prevent globbing and word splitting\.$' "$ci_log_first_failure_human" && grep -Eq '^Recommended fix: run shellcheck on the reported file and line$' "$ci_log_first_failure_human" && ! grep -Eq '^Tail excerpt:$' "$ci_log_first_failure_human"; then
    test_pass "ci-log-dump first-failure reports compact shellcheck diagnosis"
  else
    test_fail "ci-log-dump first-failure reports compact shellcheck diagnosis"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_LIST_JSON='[
      {"databaseId":222,"conclusion":"failure","createdAt":"2026-05-12T13:00:00Z","event":"schedule","headBranch":"branch/new","status":"completed","workflowName":"ci"}
    ]' GH_STUB_RUN_VIEW_FAILED_LOG='shellcheck: repo-automation/bin/pr-finish:42:1: SC2086: Double quote to prevent globbing and word splitting.
tail one
tail two' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --latest-failed --first-failure --machine-json --out-dir="$ci_log_out_dir" > "$ci_log_json"
  ) && python -m json.tool "$ci_log_json" >/dev/null && smoke_json_assert "$ci_log_json" 'data.get("first_failure_label") == "fail: shellcheck" and "SC2086" in data.get("first_failure_excerpt", "") and data.get("recommended_fix") == "run shellcheck on the reported file and line" and data.get("log_path", "").endswith(".log") and data.get("overall_status") == "pass" and data.get("run_id") == "222"'; then
    test_pass "ci-log-dump first-failure machine-json is parseable"
  else
    test_fail "ci-log-dump first-failure machine-json is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_LIST_JSON='[
      {"databaseId":111,"conclusion":"failure","createdAt":"2026-05-12T11:00:00Z","event":"push","headBranch":"branch/old","status":"completed","workflowName":"ci"},
      {"databaseId":222,"conclusion":"failure","createdAt":"2026-05-12T13:00:00Z","event":"schedule","headBranch":"branch/new","status":"completed","workflowName":"ci"},
      {"databaseId":333,"conclusion":"success","createdAt":"2026-05-12T14:00:00Z","event":"push","headBranch":"branch/other","status":"completed","workflowName":"ci"}
    ]' GH_STUB_RUN_VIEW_FAILED_LOG='line one
line two
line three
FAIL: ci run failed
tail one
tail two' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --latest-failed --tail=2 --out-dir="$ci_log_out_dir" > "$ci_log_human"
  ) && grep -Eq '^Run id: 222$' "$ci_log_human" && grep -Eq "^Saved log path: $ci_log_out_dir/actions_run_222_[0-9]{8}-[0-9]{6}\.log$" "$ci_log_human" && grep -Eq '^tail one$' "$ci_log_human" && grep -Eq '^tail two$' "$ci_log_human" && [ -n "$(find "$ci_log_out_dir" -maxdepth 1 -type f -name 'actions_run_222_*.log' -print -quit)" ]; then
    test_pass "ci-log-dump latest-failed selects the newest failed run and saves the log"
  else
    test_fail "ci-log-dump latest-failed selects the newest failed run and saves the log"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_LIST_JSON='[
      {"databaseId":111,"conclusion":"failure","createdAt":"2026-05-12T11:00:00Z","event":"push","headBranch":"branch/old","status":"completed","workflowName":"ci"},
      {"databaseId":222,"conclusion":"failure","createdAt":"2026-05-12T13:00:00Z","event":"schedule","headBranch":"branch/new","status":"completed","workflowName":"ci"}
    ]' GH_STUB_RUN_VIEW_FAILED_LOG='line one
line two
line three
FAIL: ci run failed
tail one
tail two' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --latest-failed --tail=2 --out-dir="$ci_log_out_dir" --machine-json > "$ci_log_json"
  ) && python -m json.tool "$ci_log_json" >/dev/null &&     smoke_json_assert "$ci_log_json" 'data.get("script") == "ci-log-dump" and data.get("repo") == "i-schuyler/repo-automation-template" and data.get("run_id") == "222" and "actions_run_222_" in data.get("log_path", "") and data.get("log_path", "").endswith(".log") and data.get("file_size_bytes", 0) > 0 and data.get("tail_excerpt", []) == ["tail one", "tail two"]'; then
    test_pass "ci-log-dump machine-json reports the saved path and tail excerpt"
  else
    test_fail "ci-log-dump machine-json reports the saved path and tail excerpt"
    status=1
  fi

  local ci_log_retry_run_list_marker="$smoke_test_base/ci-log-dump-run-list-retry-$$.marker"
  local ci_log_retry_run_view_marker="$smoke_test_base/ci-log-dump-run-view-retry-$$.marker"
  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_LIST_FAIL_ONCE_FILE="$ci_log_retry_run_list_marker" GH_STUB_RUN_VIEW_FAIL_ONCE_FILE="$ci_log_retry_run_view_marker" GH_STUB_RUN_LIST_JSON='[
      {"databaseId":111,"conclusion":"failure","createdAt":"2026-05-12T11:00:00Z","event":"push","headBranch":"branch/old","status":"completed","workflowName":"ci"},
      {"databaseId":222,"conclusion":"failure","createdAt":"2026-05-12T13:00:00Z","event":"schedule","headBranch":"branch/new","status":"completed","workflowName":"ci"}
    ]' GH_STUB_RUN_VIEW_FAILED_LOG='line one
line two
tail one
tail two' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --latest-failed --tail=2 --out-dir="$ci_log_out_dir" > "$ci_log_human"
  ) && [ -e "$ci_log_retry_run_list_marker" ] && [ -e "$ci_log_retry_run_view_marker" ] && grep -Eq '^Run id: 222$' "$ci_log_human" && grep -Eq '^tail one$' "$ci_log_human" && grep -Eq '^tail two$' "$ci_log_human"; then
    test_pass "ci-log-dump retries transient gh failures before dumping the log"
  else
    test_fail "ci-log-dump retries transient gh failures before dumping the log"
    status=1
  fi

  local ci_log_invalid_json_stderr="$smoke_test_base/ci-log-dump-invalid-json-$$.txt"
  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_LIST_JSON='not-json' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --latest-failed --out-dir="$ci_log_out_dir" > "$ci_log_human" 2> "$ci_log_invalid_json_stderr"
  ); then
    test_fail "ci-log-dump stops cleanly on invalid gh JSON"
    status=1
  elif grep -Eq '^STOP: BLOCKER: GitHub API failure while listing latest failed runs for repository i-schuyler/repo-automation-template after 3 attempts: not-json$' "$ci_log_invalid_json_stderr" && ! grep -Eq 'JSONDecodeError|Traceback' "$ci_log_invalid_json_stderr"; then
    test_pass "ci-log-dump stops cleanly on invalid gh JSON"
  else
    test_fail "ci-log-dump stops cleanly on invalid gh JSON"
    status=1
  fi

  local ci_log_empty_marker="$smoke_test_base/ci-log-dump-run-view-called-$$.marker"
  local ci_log_empty_status=0
  (
    cd "$smoke_test_dir" || exit 1
    GH_STUB_RUN_LIST_JSON='[]' GH_STUB_RUN_VIEW_CALLED_FILE="$ci_log_empty_marker" PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --latest-failed --out-dir="$ci_log_out_dir" > "$ci_log_human" 2>&1
  ) || ci_log_empty_status=$?
  if [ "$ci_log_empty_status" -ne 0 ] && grep -Eq '^STOP: no failed run found for repository i-schuyler/repo-automation-template$' "$ci_log_human" && [ ! -e "$ci_log_empty_marker" ]; then
    test_pass "ci-log-dump latest-failed stops when no failed runs exist"
  else
    test_fail "ci-log-dump latest-failed stops when no failed runs exist"
    status=1
  fi

  rm -f "$ci_log_human" "$ci_log_json" "$ci_log_empty_marker" "$ci_log_help" "$ci_log_pr_format_stderr" "$ci_log_pr_missing_stderr" "$ci_log_pr_empty_stderr" "$ci_log_repo_empty_stderr" "$ci_log_out_dir_empty_stderr" "$ci_log_first_failure_value_stderr" "$ci_log_unknown_stderr" "$ci_log_first_failure_human" >/dev/null 2>&1 || true
  find "$ci_log_out_dir" -maxdepth 1 -type f -name 'actions_run_222_*.log' -delete >/dev/null 2>&1 || true
  rmdir "$ci_log_out_dir" >/dev/null 2>&1 || true
  return "$status"
}

# repo-automation/tests/lib/contracts/ci.sh EOF
