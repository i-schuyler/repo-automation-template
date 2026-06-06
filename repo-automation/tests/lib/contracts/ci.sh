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
  local ci_log_pr_current_json="$smoke_test_base/ci-log-dump-pr-current-$$.json"
  local ci_log_pr_current_err="$smoke_test_base/ci-log-dump-pr-current-$$.stderr"
  local ci_log_repo_empty_stderr="$smoke_test_base/ci-log-dump-repo-empty-$$.stderr"
  local ci_log_out_dir_empty_stderr="$smoke_test_base/ci-log-dump-out-dir-empty-$$.stderr"
  local ci_log_first_failure_value_stderr="$smoke_test_base/ci-log-dump-first-failure-value-$$.stderr"
  local ci_log_unknown_stderr="$smoke_test_base/ci-log-dump-unknown-$$.stderr"
  local ci_log_first_failure_human="$smoke_test_base/ci-log-dump-first-failure-$$.txt"
  local ci_log_quiet="$smoke_test_base/ci-log-dump-quiet-$$.txt"
  local ci_log_quiet_err="$smoke_test_base/ci-log-dump-quiet-$$.stderr"
  local ci_log_infer_stop="$smoke_test_base/ci-log-dump-infer-stop-$$.txt"
  local ci_log_infer_json="$smoke_test_base/ci-log-dump-infer-json-$$.json"
  local ci_log_infer_json_err="$smoke_test_base/ci-log-dump-infer-json-$$.stderr"
  local ci_log_run_view_log="$smoke_test_base/ci-log-dump-run-view-$$.log"
  local ci_log_run_list_log="$smoke_test_base/ci-log-dump-run-list-$$.log"
  local ci_log_latest_pr_json="$smoke_test_base/ci-log-dump-latest-pr-$$.json"
  local ci_log_latest_pr_err="$smoke_test_base/ci-log-dump-latest-pr-$$.stderr"
  local ci_log_latest_pr_view_log="$smoke_test_base/ci-log-dump-latest-pr-view-$$.log"
  local ci_log_latest_pr_run_log="$smoke_test_base/ci-log-dump-latest-pr-run-$$.log"
  local ci_log_latest_pr_no_open_json="$smoke_test_base/ci-log-dump-latest-no-open-$$.json"
  local ci_log_latest_pr_no_open_err="$smoke_test_base/ci-log-dump-latest-no-open-$$.stderr"
  local ci_log_latest_pr_quiet_err="$smoke_test_base/ci-log-dump-latest-no-open-quiet-$$.stderr"
  local ci_log_pr_no_run_json="$smoke_test_base/ci-log-dump-pr-no-run-$$.json"
  local ci_log_pr_no_run_err="$smoke_test_base/ci-log-dump-pr-no-run-$$.stderr"
  local ci_log_repo_infer_json="$smoke_test_base/ci-log-dump-repo-infer-$$.json"
  local ci_log_conflict_json="$smoke_test_base/ci-log-dump-conflict-$$.json"
  local ci_log_conflict_err="$smoke_test_base/ci-log-dump-conflict-$$.stderr"
  local ci_log_unknown_json="$smoke_test_base/ci-log-dump-unknown-$$.json"
  local ci_log_unknown_err="$smoke_test_base/ci-log-dump-unknown-$$.stderr"
  local ci_log_machine_invalid_tail_json="$smoke_test_base/ci-log-dump-invalid-tail-$$.json"
  local ci_log_machine_invalid_tail_err="$smoke_test_base/ci-log-dump-invalid-tail-$$.stderr"
  local ci_log_machine_invalid_run_id_json="$smoke_test_base/ci-log-dump-invalid-run-id-$$.json"
  local ci_log_machine_invalid_run_id_err="$smoke_test_base/ci-log-dump-invalid-run-id-$$.stderr"
  local ci_log_quiet_no_run_err="$smoke_test_base/ci-log-dump-no-run-quiet-$$.stderr"
  local ci_log_quiet_api_err="$smoke_test_base/ci-log-dump-api-quiet-$$.stderr"
  local ci_log_quiet_out_dir_err="$smoke_test_base/ci-log-dump-out-dir-quiet-$$.stderr"
  local ci_log_blocked_out_dir="$smoke_test_base/ci-log-dump-blocked-out-dir-$$"
  local ci_log_machine_api_json="$smoke_test_base/ci-log-dump-api-json-$$.json"
  local ci_log_machine_api_err="$smoke_test_base/ci-log-dump-api-json-$$.stderr"
  local ci_log_machine_view_json="$smoke_test_base/ci-log-dump-view-json-$$.json"
  local ci_log_machine_view_err="$smoke_test_base/ci-log-dump-view-json-$$.stderr"

  smoke_write_gh_stub "$gh_stub_dir" || return 1
  mkdir -p "$ci_log_out_dir" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/ci-log-dump --help > "$ci_log_help"
  ) && \
    ci_log_legacy_flag="--machine" && \
    ci_log_legacy_flag="$ci_log_legacy_flag-json" && \
    grep -Fq -- '--repo=<owner/repo>' "$ci_log_help" && \
    grep -Fq -- '--pr=<number|latest>' "$ci_log_help" && \
    ! grep -Fq -- '--pr=<number|current|latest>' "$ci_log_help" && \
    ! grep -Fq -- '--pr=current' "$ci_log_help" && \
    grep -Fq -- '--json' "$ci_log_help" && \
    ! grep -Fq -- "$ci_log_legacy_flag" "$ci_log_help" && \
    grep -Fq -- '--run-id=<id>' "$ci_log_help" && \
    grep -Fq -- '--out-dir=<path>' "$ci_log_help" && \
    grep -Fq -- '--tail=<lines>' "$ci_log_help" && \
    grep -Fq -- '--first-failure' "$ci_log_help" && \
    grep -Fq -- '--quiet' "$ci_log_help" && \
    grep -Fq -- '--explain' "$ci_log_help" && \
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
    rm -f "$ci_log_latest_pr_view_log" "$ci_log_latest_pr_run_log" >/dev/null 2>&1 || true
    GH_STUB_PR_VIEW_LOG_FILE="$ci_log_latest_pr_view_log" \
    GH_STUB_RUN_LIST_LOG_FILE="$ci_log_latest_pr_run_log" \
    GH_STUB_PR_LIST_JSON='[
      {"number":101,"updatedAt":"2026-05-12T11:00:00Z","state":"OPEN","isDraft":false},
      {"number":202,"updatedAt":"2026-05-12T13:00:00Z","state":"OPEN","isDraft":true},
      {"number":303,"updatedAt":"2026-05-12T15:00:00Z","state":"OPEN","isDraft":false}
    ]' \
    GH_STUB_PR_VIEW_HEAD_REF='feature/latest-pr' \
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-303' \
    GH_STUB_RUN_LIST_SHA_PR_JSON='[
      {"databaseId":903,"conclusion":"failure","createdAt":"2026-05-12T15:30:00Z","event":"pull_request","headBranch":"feature/latest-pr","headSha":"current-sha-303","status":"completed","workflowName":"ci"}
    ]' \
    GH_STUB_RUN_VIEW_FAILED_LOG='FAIL: smoke:slice-handoff-contract' \
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --pr=latest --first-failure --out-dir="$ci_log_out_dir" --json > "$ci_log_latest_pr_json" 2> "$ci_log_latest_pr_err"
  ); then
    test_pass "ci-log-dump latest PR json command succeeds"
  else
    test_fail "ci-log-dump latest PR json command succeeds"
    status=1
  fi

  if [ ! -s "$ci_log_latest_pr_err" ] && python3 -m json.tool "$ci_log_latest_pr_json" >/dev/null && \
    smoke_json_assert "$ci_log_latest_pr_json" 'data.get("schema") == "repo-automation-helper-output/v1" and data.get("script") == "ci-log-dump" and data.get("mode") == "json" and data.get("result") == "pass" and data.get("status") == "pass" and data.get("overall_status") == "pass" and data.get("pr") == "303" and data.get("run_id") == "903" and data.get("first_failure_label") == "fail: contract/smoke" and data.get("file_size_bytes", 0) > 0 and data.get("log_path", "").startswith("'"$ci_log_out_dir"'/actions_run_903_")'; then
    test_pass "ci-log-dump latest PR json reports the selected PR and run"
  else
    test_fail "ci-log-dump latest PR json reports the selected PR and run"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    grep -Fq -- 'gh pr view 303' "$ci_log_latest_pr_view_log" && ! grep -Eq -- 'gh pr view 101|gh pr view 202' "$ci_log_latest_pr_view_log"
  ); then
    test_pass "ci-log-dump latest PR bypasses older PRs"
  else
    test_fail "ci-log-dump latest PR bypasses older PRs"
    status=1
  fi

  if grep -Fq -- '--commit current-sha-303' "$ci_log_latest_pr_run_log"; then
    test_pass "ci-log-dump latest PR fetches the selected PR run"
  else
    test_fail "ci-log-dump latest PR fetches the selected PR run"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    rm -f "$ci_log_latest_pr_view_log" "$ci_log_latest_pr_run_log" >/dev/null 2>&1 || true
    GH_STUB_PR_VIEW_LOG_FILE="$ci_log_latest_pr_view_log" \
    GH_STUB_RUN_LIST_LOG_FILE="$ci_log_latest_pr_run_log" \
    GH_STUB_PR_LIST_JSON='[]' \
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --pr=latest --out-dir="$ci_log_out_dir" --json > "$ci_log_latest_pr_no_open_json" 2> "$ci_log_latest_pr_no_open_err"
  ); then
    test_fail "ci-log-dump latest PR json fails cleanly when no open PR exists"
    status=1
  elif [ ! -s "$ci_log_latest_pr_no_open_err" ] && python3 -m json.tool "$ci_log_latest_pr_no_open_json" >/dev/null && \
    smoke_json_assert "$ci_log_latest_pr_no_open_json" 'data.get("schema") == "repo-automation-helper-output/v1" and data.get("script") == "ci-log-dump" and data.get("mode") == "json" and data.get("result") == "fail" and data.get("status") == "fail" and data.get("overall_status") == "fail" and data.get("code") == "no-pr-found" and data.get("step") == "pr-lookup" and data.get("reason") == "no open non-draft PR found for repository i-schuyler/repo-automation-template" and data.get("fix") == "pass --pr=<number> or open/update a non-draft PR, then rerun" and data.get("artifact_path") == "'"$ci_log_out_dir"'" and data.get("log_path") == ""' && \
    [ ! -e "$ci_log_latest_pr_view_log" ] && [ ! -e "$ci_log_latest_pr_run_log" ]; then
    test_pass "ci-log-dump latest PR json fails cleanly when no open PR exists"
  else
    test_fail "ci-log-dump latest PR json fails cleanly when no open PR exists"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    rm -f "$ci_log_latest_pr_view_log" "$ci_log_latest_pr_run_log" >/dev/null 2>&1 || true
    GH_STUB_PR_VIEW_LOG_FILE="$ci_log_latest_pr_view_log" \
    GH_STUB_RUN_LIST_LOG_FILE="$ci_log_latest_pr_run_log" \
    GH_STUB_PR_LIST_JSON='[]' \
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --pr=latest --out-dir="$ci_log_out_dir" --quiet > /dev/null 2> "$ci_log_latest_pr_quiet_err"
  ); then
    test_fail "ci-log-dump latest PR quiet fails cleanly when no open PR exists"
    status=1
  elif smoke_assert_quiet_failure_envelope "$ci_log_latest_pr_quiet_err" "no-pr-found" "pr-lookup" "no open non-draft PR found for repository i-schuyler/repo-automation-template" "pass --pr=<number> or open/update a non-draft PR, then rerun" "" "$ci_log_out_dir" "" "" && [ ! -e "$ci_log_latest_pr_view_log" ] && [ ! -e "$ci_log_latest_pr_run_log" ]; then
    test_pass "ci-log-dump latest PR quiet fails cleanly when no open PR exists"
  else
    test_fail "ci-log-dump latest PR quiet fails cleanly when no open PR exists"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_VIEW_LOG_FILE="$ci_log_latest_pr_view_log" \
    GH_STUB_RUN_LIST_LOG_FILE="$ci_log_latest_pr_run_log" \
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --pr=current --json > "$ci_log_pr_current_json" 2> "$ci_log_pr_current_err"
  ); then
    test_fail "ci-log-dump rejects --pr=current"
    status=1
  elif [ ! -s "$ci_log_pr_current_err" ] && python3 -m json.tool "$ci_log_pr_current_json" >/dev/null && \
    smoke_json_assert "$ci_log_pr_current_json" 'data.get("result") == "fail" and data.get("code") == "flag-parse-failed" and data.get("step") == "flag-parse" and data.get("reason") == "unsupported --pr alias: current" and data.get("fix") == "use --pr=<number> or --pr=latest" and data.get("log_path") == ""' && \
    [ ! -e "$ci_log_latest_pr_view_log" ] && [ ! -e "$ci_log_latest_pr_run_log" ]; then
    test_pass "ci-log-dump rejects --pr=current"
  else
    test_fail "ci-log-dump rejects --pr=current"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_VIEW_CALLED_FILE="$ci_log_run_view_log" \
    GH_STUB_RUN_LIST_LOG_FILE="$ci_log_run_list_log" \
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --run-id=123 --json --quiet > "$ci_log_conflict_json" 2> "$ci_log_conflict_err"
  ); then
    test_fail "ci-log-dump rejects --json --quiet"
    status=1
  elif [ ! -s "$ci_log_conflict_err" ] && python3 -m json.tool "$ci_log_conflict_json" >/dev/null && \
    smoke_json_assert "$ci_log_conflict_json" 'data.get("result") == "fail" and data.get("code") == "output-mode-conflict" and data.get("step") == "output-mode-parse" and "incompatible output mode flags: --json --quiet" in data.get("reason", "") and "use only one of --json, --quiet, or --explain" in data.get("fix", "")' && \
    [ ! -e "$ci_log_run_view_log" ] && [ ! -e "$ci_log_run_list_log" ]; then
    test_pass "ci-log-dump rejects --json --quiet"
  else
    test_fail "ci-log-dump rejects --json --quiet"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_VIEW_CALLED_FILE="$ci_log_run_view_log" \
    GH_STUB_RUN_LIST_LOG_FILE="$ci_log_run_list_log" \
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --not-a-real-flag > "$ci_log_unknown_json" 2> "$ci_log_unknown_err"
  ); then
    test_fail "ci-log-dump rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$ci_log_unknown_err" "unknown flag" "--not-a-real-flag" "run repo-automation/bin/ci-log-dump --help" && [ ! -s "$ci_log_unknown_json" ] && [ ! -e "$ci_log_run_view_log" ] && [ ! -e "$ci_log_run_list_log" ]; then
    test_pass "ci-log-dump rejects unknown flags"
  else
    test_fail "ci-log-dump rejects unknown flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_VIEW_CALLED_FILE="$ci_log_run_view_log" \
    GH_STUB_RUN_LIST_LOG_FILE="$ci_log_run_list_log" \
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --run-id=123 --json --explain > "$ci_log_conflict_json" 2> "$ci_log_conflict_err"
  ); then
    test_fail "ci-log-dump rejects --json --explain"
    status=1
  elif [ ! -s "$ci_log_conflict_err" ] && python3 -m json.tool "$ci_log_conflict_json" >/dev/null && \
    smoke_json_assert "$ci_log_conflict_json" 'data.get("result") == "fail" and data.get("code") == "output-mode-conflict" and data.get("step") == "output-mode-parse" and "incompatible output mode flags: --json --explain" in data.get("reason", "") and "use only one of --json, --quiet, or --explain" in data.get("fix", "")' && \
    [ ! -e "$ci_log_run_view_log" ] && [ ! -e "$ci_log_run_list_log" ]; then
    test_pass "ci-log-dump rejects --json --explain"
  else
    test_fail "ci-log-dump rejects --json --explain"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_VIEW_CALLED_FILE="$ci_log_run_view_log" \
    GH_STUB_RUN_LIST_LOG_FILE="$ci_log_run_list_log" \
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --run-id=123 --quiet --explain > "$ci_log_conflict_json" 2> "$ci_log_conflict_err"
  ); then
    test_fail "ci-log-dump rejects --quiet --explain"
    status=1
  elif smoke_assert_quiet_failure_envelope "$ci_log_conflict_err" "output-mode-conflict" "output-mode-parse" "incompatible output mode flags: --quiet --explain" "use only one of --json, --quiet, or --explain" "" "" "" && [ ! -s "$ci_log_conflict_json" ] && [ ! -e "$ci_log_run_view_log" ] && [ ! -e "$ci_log_run_list_log" ]; then
    test_pass "ci-log-dump rejects --quiet --explain"
  else
    test_fail "ci-log-dump rejects --quiet --explain"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --run-id=abc --json > "$ci_log_machine_invalid_run_id_json" 2> "$ci_log_machine_invalid_run_id_err"
  ); then
    test_fail "ci-log-dump json rejects invalid --run-id"
    status=1
  elif [ ! -s "$ci_log_machine_invalid_run_id_err" ] && python3 -m json.tool "$ci_log_machine_invalid_run_id_json" >/dev/null && \
    smoke_json_assert "$ci_log_machine_invalid_run_id_json" 'data.get("result") == "fail" and data.get("code") == "flag-parse-failed" and data.get("step") == "flag-parse" and data.get("reason") == "invalid --run-id value: abc" and data.get("fix") == "use --run-id=<id>"'; then
    test_pass "ci-log-dump json rejects invalid --run-id"
  else
    test_fail "ci-log-dump json rejects invalid --run-id"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --tail=abc --json > "$ci_log_machine_invalid_tail_json" 2> "$ci_log_machine_invalid_tail_err"
  ); then
    test_fail "ci-log-dump json rejects invalid --tail"
    status=1
  elif [ ! -s "$ci_log_machine_invalid_tail_err" ] && python3 -m json.tool "$ci_log_machine_invalid_tail_json" >/dev/null && \
    smoke_json_assert "$ci_log_machine_invalid_tail_json" 'data.get("result") == "fail" and data.get("code") == "flag-parse-failed" and data.get("step") == "flag-parse" and data.get("reason") == "invalid --tail value: abc" and data.get("fix") == "use --tail=<lines>"'; then
    test_pass "ci-log-dump json rejects invalid --tail"
  else
    test_fail "ci-log-dump json rejects invalid --tail"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --run-id=abc --quiet > /dev/null 2> "$ci_log_quiet_err"
  ); then
    test_fail "ci-log-dump quiet rejects invalid --run-id"
    status=1
  elif smoke_assert_quiet_failure_envelope "$ci_log_quiet_err" "flag-parse-failed" "flag-parse" "invalid --run-id value: abc" "use --run-id=<id>" "" "" "" ""; then
    test_pass "ci-log-dump quiet rejects invalid --run-id"
  else
    test_fail "ci-log-dump quiet rejects invalid --run-id"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_LIST_JSON='[]' repo-automation/bin/ci-log-dump --pr 123 >/dev/null 2> "$ci_log_pr_format_stderr"
  ); then
    test_fail "ci-log-dump rejects --pr <number>"
    status=1
  elif smoke_assert_flag_error_shape "$ci_log_pr_format_stderr" "flag format not accepted" "--pr" "use --pr=<number|latest>"; then
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
  elif smoke_assert_flag_error_shape "$ci_log_pr_missing_stderr" "missing flag value" "--pr" "use --pr=<number|latest>"; then
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
  elif smoke_assert_flag_error_shape "$ci_log_pr_empty_stderr" "empty flag value" "--pr" "use --pr=<number|latest>"; then
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
  ) && [ "$(wc -l < "$ci_log_first_failure_human")" -eq 1 ] && grep -Eq "^$ci_log_out_dir/actions_run_111_[0-9]{8}-[0-9]{6}\.log$" "$ci_log_first_failure_human"; then
    test_pass "ci-log-dump default human output is path-only"
  else
    test_fail "ci-log-dump default human output is path-only"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_LIST_JSON='[
      {"databaseId":222,"conclusion":"failure","createdAt":"2026-05-12T13:00:00Z","event":"schedule","headBranch":"branch/new","status":"completed","workflowName":"ci"}
    ]' GH_STUB_RUN_VIEW_FAILED_LOG='shellcheck: repo-automation/bin/pr-finish:42:1: SC2086: Double quote to prevent globbing and word splitting.
tail one
tail two' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --latest-failed --first-failure --quiet --out-dir="$ci_log_out_dir" > "$ci_log_quiet"
  ) && [ ! -s "$ci_log_quiet" ]; then
    test_pass "ci-log-dump quiet success is silent"
  else
    test_fail "ci-log-dump quiet success is silent"
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
  ) && [ "$(wc -l < "$ci_log_human")" -eq 1 ] && grep -Eq "^$ci_log_out_dir/actions_run_222_[0-9]{8}-[0-9]{6}\.log$" "$ci_log_human" && [ -n "$(find "$ci_log_out_dir" -maxdepth 1 -type f -name 'actions_run_222_*.log' -print -quit)" ]; then
    test_pass "ci-log-dump latest-failed reports path-only output"
  else
    test_fail "ci-log-dump latest-failed reports path-only output"
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
tail two' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --latest-failed --tail=2 --out-dir="$ci_log_out_dir" --json > "$ci_log_json"
  ) && python3 -m json.tool "$ci_log_json" >/dev/null &&     smoke_json_assert "$ci_log_json" 'data.get("script") == "ci-log-dump" and data.get("repo") == "i-schuyler/repo-automation-template" and data.get("run_id") == "222" and "actions_run_222_" in data.get("log_path", "") and data.get("log_path", "").endswith(".log") and data.get("file_size_bytes", 0) > 0 and data.get("tail_excerpt", []) == ["tail one", "tail two"]'; then
    test_pass "ci-log-dump json reports the saved path and tail excerpt"
  else
    test_fail "ci-log-dump json reports the saved path and tail excerpt"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    : > "$ci_log_run_list_log"
    GH_STUB_PR_VIEW_HEAD_REF='feature/demo' \
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-321' \
    GH_STUB_RUN_LIST_BRANCH_PR_JSON='[]' \
    GH_STUB_RUN_LIST_SHA_PR_JSON='[
      {"databaseId":701,"conclusion":"failure","createdAt":"2026-05-12T11:00:00Z","event":"pull_request","headBranch":"feature/demo","headSha":"old-sha-321","status":"completed","workflowName":"ci"},
      {"databaseId":702,"conclusion":"failure","createdAt":"2026-05-12T13:00:00Z","event":"pull_request","headBranch":"feature/demo","headSha":"current-sha-321","status":"completed","workflowName":"ci"}
    ]' \
    GH_STUB_RUN_LIST_LOG_FILE="$ci_log_run_list_log" \
    GH_STUB_RUN_VIEW_FAILED_LOG='FAIL: smoke:slice-handoff-contract' \
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --pr=123 --first-failure --out-dir="$ci_log_out_dir" --json > "$ci_log_json"
  ) && python3 -m json.tool "$ci_log_json" >/dev/null && \
    smoke_json_assert "$ci_log_json" 'data.get("pr") == "123" and data.get("run_id") == "702" and data.get("first_failure_label") == "fail: contract/smoke" and "FAIL: smoke:slice-handoff-contract" in data.get("first_failure_excerpt", "")' && \
    grep -Fq -- '--commit current-sha-321' "$ci_log_run_list_log"; then
    test_pass "ci-log-dump PR lookup resolves failed run by head SHA"
  else
    test_fail "ci-log-dump PR lookup resolves failed run by head SHA"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    : > "$ci_log_run_list_log"
    rm -f "$ci_log_run_view_log" >/dev/null 2>&1 || true
    GH_STUB_PR_VIEW_HEAD_REF='feature/demo' \
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-321' \
    GH_STUB_RUN_LIST_BRANCH_PR_JSON='[]' \
    GH_STUB_RUN_LIST_SHA_PR_JSON='[]' \
    GH_STUB_RUN_LIST_SHA_JSON='[]' \
    GH_STUB_RUN_LIST_JSON='[]' \
    GH_STUB_RUN_LIST_LOG_FILE="$ci_log_run_list_log" \
    GH_STUB_RUN_VIEW_CALLED_FILE="$ci_log_run_view_log" \
    GH_STUB_RUN_VIEW_FAILED_LOG='should not fetch logs' \
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --pr=123 --first-failure --out-dir="$ci_log_out_dir" --json > "$ci_log_pr_no_run_json" 2> "$ci_log_pr_no_run_err"
  ); then
    test_fail "ci-log-dump PR no-run json explains lookup modes"
    status=1
  elif [ ! -s "$ci_log_pr_no_run_err" ] && python3 -m json.tool "$ci_log_pr_no_run_json" >/dev/null && \
    smoke_json_assert "$ci_log_pr_no_run_json" 'data.get("schema") == "repo-automation-helper-output/v1" and data.get("script") == "ci-log-dump" and data.get("mode") == "json" and data.get("result") == "fail" and data.get("status") == "fail" and data.get("overall_status") == "fail" and data.get("code") == "no-failed-run-found" and data.get("step") == "run-lookup" and data.get("reason", "").startswith("no failed run found for PR #123") and "lookup_modes_tried=sha-pull_request,branch-pull_request,sha-any,repo-failed-head-sha" in data.get("reason", "") and data.get("fix", "").startswith("rerun with --run-id=<id> or inspect the PR") and data.get("artifact_path") == "'"$ci_log_out_dir"'"' && \
    [ ! -e "$ci_log_run_view_log" ]; then
    test_pass "ci-log-dump PR no-run json explains lookup modes"
  else
    test_fail "ci-log-dump PR no-run json explains lookup modes"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_LIST_JSON='[]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --latest-failed --out-dir="$ci_log_out_dir" --quiet > /dev/null 2> "$ci_log_quiet_no_run_err"
  ); then
    test_fail "ci-log-dump latest-failed quiet no-run fails quietly"
    status=1
  elif smoke_assert_quiet_failure_envelope "$ci_log_quiet_no_run_err" "no-failed-run-found" "run-lookup" "no failed run found for repository i-schuyler/repo-automation-template" "rerun with --run-id=<id> or inspect GitHub Actions for the missing failure" "" "$ci_log_out_dir" "" ""; then
    test_pass "ci-log-dump latest-failed quiet no-run fails quietly"
  else
    test_fail "ci-log-dump latest-failed quiet no-run fails quietly"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    : > "$ci_log_run_list_log"
    : > "$ci_log_run_view_log"
    GH_STUB_RUN_LIST_LOG_FILE="$ci_log_run_list_log" \
    GH_STUB_RUN_VIEW_CALLED_FILE="$ci_log_run_view_log" \
    GH_STUB_RUN_VIEW_FAILED_LOG='FAIL: smoke:slice-handoff-contract' \
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --pr=123 --run-id=777 --first-failure --out-dir="$ci_log_out_dir" --json > "$ci_log_json"
  ) && python3 -m json.tool "$ci_log_json" >/dev/null && \
    smoke_json_assert "$ci_log_json" 'data.get("run_id") == "777" and data.get("first_failure_label") == "fail: contract/smoke"' && \
    [ ! -s "$ci_log_run_list_log" ] && [ -e "$ci_log_run_view_log" ]; then
    test_pass "ci-log-dump run-id bypasses PR lookup and fetches logs directly"
  else
    test_fail "ci-log-dump run-id bypasses PR lookup and fetches logs directly"
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
  ) && [ -e "$ci_log_retry_run_list_marker" ] && [ -e "$ci_log_retry_run_view_marker" ] && [ "$(wc -l < "$ci_log_human")" -eq 1 ] && grep -Eq "^$ci_log_out_dir/actions_run_222_[0-9]{8}-[0-9]{6}\.log$" "$ci_log_human"; then
    test_pass "ci-log-dump retries transient gh failures before dumping the log"
  else
    test_fail "ci-log-dump retries transient gh failures before dumping the log"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_LIST_JSON='[
      {"databaseId":111,"conclusion":"failure","createdAt":"2026-05-12T11:00:00Z","event":"push","headBranch":"branch/old","status":"completed","workflowName":"ci"}
    ]' GH_STUB_RUN_VIEW_FAILED_LOG='shellcheck: repo-automation/bin/pr-finish:42:1: SC2086: Double quote to prevent globbing and word splitting.
tail one
tail two' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --latest-failed --first-failure --tail=2 --out-dir="$ci_log_out_dir" --explain > "$ci_log_first_failure_human"
  ) && grep -Eq '^Target repo: i-schuyler/repo-automation-template$' "$ci_log_first_failure_human" && grep -Eq '^Run id: 111$' "$ci_log_first_failure_human" && grep -Eq '^Saved log path: '"$ci_log_out_dir"'/actions_run_111_[0-9]{8}-[0-9]{6}\.log$' "$ci_log_first_failure_human" && grep -Eq '^First failure label: fail: shellcheck$' "$ci_log_first_failure_human" && grep -Eq '^First failure excerpt: shellcheck: repo-automation/bin/pr-finish:42:1: SC2086: Double quote to prevent globbing and word splitting\.$' "$ci_log_first_failure_human" && grep -Eq '^Recommended fix: run shellcheck on the reported file and line$' "$ci_log_first_failure_human" && ! grep -Eq '^Tail excerpt:$' "$ci_log_first_failure_human" && [ "$(grep -Fc '===== FINAL SUMMARY =====' "$ci_log_first_failure_human")" -eq 1 ] && grep -Fxq 'script=ci-log-dump' "$ci_log_first_failure_human" && grep -Eq '^rc=0$' "$ci_log_first_failure_human" && grep -Fxq 'repo=i-schuyler/repo-automation-template' "$ci_log_first_failure_human" && grep -Fxq 'pr=none' "$ci_log_first_failure_human" && grep -Fxq 'run_id=111' "$ci_log_first_failure_human" && grep -Eq '^log_path='"$ci_log_out_dir"'/actions_run_111_[0-9]{8}-[0-9]{6}\.log$' "$ci_log_first_failure_human" && grep -Fxq 'first_failure=fail: shellcheck' "$ci_log_first_failure_human" && grep -Eq '^url_or_stop='"$ci_log_out_dir"'/actions_run_111_[0-9]{8}-[0-9]{6}\.log$' "$ci_log_first_failure_human" && grep -Fxq '===== END =====' "$ci_log_first_failure_human"; then
    test_pass "ci-log-dump explain output is detailed"
  else
    test_fail "ci-log-dump explain output is detailed"
    status=1
  fi

  local ci_log_remote_url=""
  local ci_log_infer_ok=1
  for ci_log_remote_url in \
    'git@github.com:owner/repo.git' \
    'https://github.com/owner/repo.git' \
    'git@github.com-work:owner/repo.git' \
    'ssh://git@github.com/owner/repo.git'
  do
    if (
      cd "$smoke_test_dir" || return 1
      git remote set-url origin "$ci_log_remote_url" || return 1
      GH_STUB_RUN_LIST_JSON='[
        {"databaseId":333,"conclusion":"failure","createdAt":"2026-05-12T13:00:00Z","event":"push","headBranch":"branch/new","headSha":"sha-333","status":"completed","workflowName":"ci"}
      ]' GH_STUB_RUN_VIEW_FAILED_LOG='FAIL: smoke:slice-handoff-contract' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --latest-failed --out-dir="$ci_log_out_dir" --json > "$ci_log_repo_infer_json"
    ) && python3 -m json.tool "$ci_log_repo_infer_json" >/dev/null && \
      smoke_json_assert "$ci_log_repo_infer_json" 'data.get("schema") == "repo-automation-helper-output/v1" and data.get("script") == "ci-log-dump" and data.get("mode") == "json" and data.get("result") == "pass" and data.get("status") == "pass" and data.get("overall_status") == "pass" and data.get("repo") == "owner/repo" and data.get("run_id") == "333"'; then
      :
    else
      ci_log_infer_ok=0
    fi
  done
  if [ "$ci_log_infer_ok" -eq 1 ]; then
    test_pass "ci-log-dump infers repo from GitHub remote forms"
  else
    test_fail "ci-log-dump infers repo from GitHub remote forms"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    git remote remove origin >/dev/null 2>&1 || true
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --explain > "$ci_log_infer_stop" 2>&1
  ); then
    test_fail "ci-log-dump explain early STOP ends with one final summary"
    status=1
  elif [ "$(grep -Fc '===== FINAL SUMMARY =====' "$ci_log_infer_stop")" -eq 1 ] && [ "$(grep -Fc '===== END =====' "$ci_log_infer_stop")" -eq 1 ] && grep -Fxq 'script=ci-log-dump' "$ci_log_infer_stop" && grep -Eq '^rc=1$' "$ci_log_infer_stop" && grep -Fxq 'repo=unknown' "$ci_log_infer_stop" && grep -Fxq 'pr=none' "$ci_log_infer_stop" && grep -Fxq 'run_id=none' "$ci_log_infer_stop" && grep -Fxq 'log_path=none' "$ci_log_infer_stop" && grep -Fxq 'first_failure=none' "$ci_log_infer_stop" && grep -Fxq 'url_or_stop=STOP: unable to infer --repo from origin remote; pass --repo=<owner/repo>' "$ci_log_infer_stop"; then
    test_pass "ci-log-dump explain early STOP ends with one final summary"
  else
    test_fail "ci-log-dump explain early STOP ends with one final summary"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    git remote remove origin >/dev/null 2>&1 || true
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --json > "$ci_log_infer_json" 2> "$ci_log_infer_json_err"
  ); then
    test_fail "ci-log-dump json early STOP stays JSON-only"
    status=1
  elif [ ! -s "$ci_log_infer_json_err" ] && python3 -m json.tool "$ci_log_infer_json" >/dev/null && grep -Fq '"stop_reason":"unable to infer --repo from origin remote; pass --repo=<owner/repo>"' "$ci_log_infer_json" && ! grep -Fq 'FINAL SUMMARY' "$ci_log_infer_json"; then
    test_pass "ci-log-dump json early STOP stays JSON-only"
  else
    test_fail "ci-log-dump json early STOP stays JSON-only"
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

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_LIST_JSON='not-json' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --latest-failed --out-dir="$ci_log_out_dir" --json > "$ci_log_machine_api_json" 2> "$ci_log_machine_api_err"
  ); then
    test_fail "ci-log-dump json stays pure on gh API failure"
    status=1
  elif [ ! -s "$ci_log_machine_api_err" ] && python3 -m json.tool "$ci_log_machine_api_json" >/dev/null && \
    smoke_json_assert "$ci_log_machine_api_json" 'data.get("schema") == "repo-automation-helper-output/v1" and data.get("script") == "ci-log-dump" and data.get("mode") == "json" and data.get("result") == "fail" and data.get("status") == "fail" and data.get("overall_status") == "fail" and data.get("code") == "github-api-failure" and data.get("step") == "gh-api" and data.get("log_path") == "" and data.get("artifact_path") == "'"$ci_log_out_dir"'" and data.get("reason", "").startswith("BLOCKER: GitHub API failure while listing latest failed runs for repository i-schuyler/repo-automation-template after 3 attempts:") and data.get("fix") == "check gh auth status and your network, then rerun"'; then
    test_pass "ci-log-dump json stays pure on gh API failure"
  else
    test_fail "ci-log-dump json stays pure on gh API failure"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_LIST_JSON='not-json' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --latest-failed --out-dir="$ci_log_out_dir" --quiet > /dev/null 2> "$ci_log_quiet_api_err"
  ); then
    test_fail "ci-log-dump quiet gh API failure stays compact"
    status=1
  elif smoke_assert_quiet_failure_envelope "$ci_log_quiet_api_err" "github-api-failure" "gh-api" "BLOCKER: GitHub API failure while listing latest failed runs for repository i-schuyler/repo-automation-template after 3 attempts: not-json" "check gh auth status and your network, then rerun" "" "$ci_log_out_dir" "" ""; then
    test_pass "ci-log-dump quiet gh API failure stays compact"
  else
    test_fail "ci-log-dump quiet gh API failure stays compact"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_VIEW_ALWAYS_FAIL_STDERR='net/http: TLS handshake timeout' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --run-id=777 --out-dir="$ci_log_out_dir" --json > "$ci_log_machine_view_json" 2> "$ci_log_machine_view_err"
  ); then
    test_fail "ci-log-dump json stays pure on log fetch failure"
    status=1
  elif [ ! -s "$ci_log_machine_view_err" ] && python3 -m json.tool "$ci_log_machine_view_json" >/dev/null && \
    smoke_json_assert "$ci_log_machine_view_json" 'data.get("schema") == "repo-automation-helper-output/v1" and data.get("script") == "ci-log-dump" and data.get("mode") == "json" and data.get("result") == "fail" and data.get("status") == "fail" and data.get("overall_status") == "fail" and data.get("code") == "github-api-failure" and data.get("step") == "gh-api" and data.get("artifact_path") == "'"$ci_log_out_dir"'" and data.get("fix") == "check gh auth status and your network, then rerun" and data.get("reason", "").startswith("BLOCKER: GitHub API failure while fetching failed log for run 777 after 3 attempts:")'; then
    test_pass "ci-log-dump json stays pure on log fetch failure"
  else
    test_fail "ci-log-dump json stays pure on log fetch failure"
    status=1
  fi

  : > "$ci_log_blocked_out_dir"
  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_RUN_VIEW_FAILED_LOG='tail one
tail two' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-log-dump --repo=i-schuyler/repo-automation-template --run-id=777 --out-dir="$ci_log_blocked_out_dir" --quiet > /dev/null 2> "$ci_log_quiet_out_dir_err"
  ); then
    test_fail "ci-log-dump quiet output-dir failure stays compact"
    status=1
  elif smoke_assert_quiet_failure_envelope "$ci_log_quiet_out_dir_err" "output-dir-create-failed" "output-dir" "unable to create output directory: $ci_log_blocked_out_dir" "pick a writable --out-dir or set TMPDIR/HOME to a writable location" "" "$ci_log_blocked_out_dir" "" ""; then
    test_pass "ci-log-dump quiet output-dir failure stays compact"
  else
    test_fail "ci-log-dump quiet output-dir failure stays compact"
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

  rm -f "$ci_log_human" "$ci_log_json" "$ci_log_empty_marker" "$ci_log_help" "$ci_log_pr_format_stderr" "$ci_log_pr_missing_stderr" "$ci_log_pr_empty_stderr" "$ci_log_repo_empty_stderr" "$ci_log_out_dir_empty_stderr" "$ci_log_first_failure_value_stderr" "$ci_log_unknown_stderr" "$ci_log_first_failure_human" "$ci_log_quiet" "$ci_log_quiet_err" "$ci_log_run_view_log" "$ci_log_run_list_log" "$ci_log_pr_no_run_json" "$ci_log_pr_no_run_err" "$ci_log_repo_infer_json" "$ci_log_conflict_json" "$ci_log_conflict_err" "$ci_log_machine_invalid_tail_json" "$ci_log_machine_invalid_tail_err" "$ci_log_machine_invalid_run_id_json" "$ci_log_machine_invalid_run_id_err" "$ci_log_quiet_no_run_err" "$ci_log_quiet_api_err" "$ci_log_quiet_out_dir_err" "$ci_log_machine_api_json" "$ci_log_machine_api_err" "$ci_log_machine_view_json" "$ci_log_machine_view_err" "$ci_log_blocked_out_dir" >/dev/null 2>&1 || true
  find "$ci_log_out_dir" -maxdepth 1 -type f -name 'actions_run_222_*.log' -delete >/dev/null 2>&1 || true
  rmdir "$ci_log_out_dir" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_ci_status_watch_contract() {
  local status=0
  local ci_status_help="$smoke_test_base/ci-status-help-$$.txt"
  local ci_watch_help="$smoke_test_base/ci-watch-help-$$.txt"
  local ci_status_pr_json="$smoke_test_base/ci-status-pr-$$.json"
  local ci_status_branch_json="$smoke_test_base/ci-status-branch-$$.json"
  local ci_status_pr_json_mode="$smoke_test_base/ci-status-pr-json-$$.json"
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
  local ci_watch_pass_json_mode="$smoke_test_base/ci-watch-pass-json-$$.json"
  local ci_watch_pass_stderr="$smoke_test_base/ci-watch-pass-$$.txt"
  local ci_watch_pass_human="$smoke_test_base/ci-watch-pass-human-$$.txt"
  local ci_watch_pass_quiet="$smoke_test_base/ci-watch-pass-quiet-$$.txt"
  local ci_watch_pass_explain="$smoke_test_base/ci-watch-pass-explain-$$.txt"
  local ci_watch_fail_json="$smoke_test_base/ci-watch-fail-$$.json"
  local ci_watch_fail_stderr="$smoke_test_base/ci-watch-fail-$$.txt"
  local ci_watch_no_checks_stderr="$smoke_test_base/ci-watch-no-checks-$$.txt"
  local gh_stub_dir="$smoke_test_base/gh-stub"

  smoke_write_gh_stub "$gh_stub_dir" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/ci-status --help > "$ci_status_help"
  ) && \
    grep -Fq -- '--pr=<number>' "$ci_status_help" && \
    grep -Fq -- '--branch=<name>' "$ci_status_help" && \
    grep -Fq -- '--json' "$ci_status_help" && \
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
    grep -Fq -- '--json' "$ci_watch_help" && \
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
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pending","state":"IN_PROGRESS","workflow":"ci"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-status --pr=123 --json > "$ci_status_pr_json"
  ) && python3 -m json.tool "$ci_status_pr_json" >/dev/null && \
    smoke_json_assert "$ci_status_pr_json" 'data.get("mode") == "pr" and data.get("overall_status") == "pending" and len(data.get("checks", [])) == 1'; then
    test_pass "ci-status pr json is parseable"
  else
    test_fail "ci-status pr json is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pending","state":"IN_PROGRESS","workflow":"ci"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-status --pr=123 --json > "$ci_status_pr_json_mode"
  ) && python3 -m json.tool "$ci_status_pr_json_mode" >/dev/null && \
    smoke_json_assert "$ci_status_pr_json_mode" 'data.get("mode") == "pr" and data.get("overall_status") == "pending" and len(data.get("checks", [])) == 1'; then
    test_pass "ci-status pr json is parseable"
  else
    test_fail "ci-status pr json is parseable"
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
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-321' \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":701,"conclusion":"failure","createdAt":"2026-05-12T11:00:00Z","event":"pull_request","headBranch":"feature/demo","headSha":"old-sha-321","status":"completed","workflowName":"ci"},{"databaseId":702,"conclusion":"success","createdAt":"2026-05-12T12:00:00Z","event":"pull_request","headBranch":"feature/demo","headSha":"current-sha-321","status":"completed","workflowName":"ci"}]' \
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-status --pr=123 --json > "$ci_status_pr_json_mode"
  ) && python3 -m json.tool "$ci_status_pr_json_mode" >/dev/null && \
    smoke_json_assert "$ci_status_pr_json_mode" 'data.get("mode") == "pr" and data.get("overall_status") == "pass" and data.get("matching_run_count") == 1 and data.get("latest_run", {}).get("databaseId") == 702'; then
    test_pass "ci-status ignores stale prior SHA runs"
  else
    test_fail "ci-status ignores stale prior SHA runs"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_LIST_JSON='[]' GH_STUB_RUN_LIST_JSON='[{"number":99,"name":"ci","status":"completed","conclusion":"success"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-status --branch=feature/demo --json > "$ci_status_branch_json"
  ) && python3 -m json.tool "$ci_status_branch_json" >/dev/null && \
    smoke_json_assert "$ci_status_branch_json" 'data.get("mode") == "branch" and data.get("overall_status") == "pass" and data.get("latest_run", {}).get("number") == 99'; then
    test_pass "ci-status branch json is parseable"
  else
    test_fail "ci-status branch json is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_CHECKS_JSON='[]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-status --pr 123 --json > /dev/null 2> "$ci_status_pr_format_stderr"
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
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-status --pr --json > /dev/null 2> "$ci_status_pr_missing_stderr"
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
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-status --pr= --json > /dev/null 2> "$ci_status_pr_empty_stderr"
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
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-321' \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":701,"conclusion":"failure","createdAt":"2026-05-12T11:00:00Z","event":"pull_request","headBranch":"feature/demo","headSha":"old-sha-321","status":"completed","workflowName":"ci"},{"databaseId":702,"conclusion":"success","createdAt":"2026-05-12T12:00:00Z","event":"pull_request","headBranch":"feature/demo","headSha":"current-sha-321","status":"completed","workflowName":"ci"}]' \
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-watch --pr=123 --poll-seconds=1 --timeout=1 --json > "$ci_watch_pass_json" 2> "$ci_watch_pass_stderr"
  ) && python3 -m json.tool "$ci_watch_pass_json" >/dev/null && \
    smoke_json_assert "$ci_watch_pass_json" 'data.get("overall_status") == "pass" and data.get("ci_status", {}).get("mode") == "pr" and data.get("ci_status", {}).get("matching_run_count") == 1 and data.get("ci_status", {}).get("latest_run", {}).get("databaseId") == 702'; then
    test_pass "ci-watch ignores stale prior SHA runs"
  else
    test_fail "ci-watch ignores stale prior SHA runs"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-321' \
    GH_STUB_RUN_LIST_JSON='[]' \
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-watch --pr=123 --poll-seconds=1 --timeout=1 > /dev/null 2> "$ci_watch_no_checks_stderr"
  ); then
    test_fail "ci-watch waits when current head has no runs yet"
    status=1
  elif grep -Eq 'timed out after 1s while waiting for CI' "$ci_watch_no_checks_stderr"; then
    test_pass "ci-watch waits when current head has no runs yet"
  else
    test_fail "ci-watch waits when current head has no runs yet"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pass","state":"SUCCESS","workflow":"ci"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-watch --pr=123 --poll-seconds=1 --timeout=1 --json > "$ci_watch_pass_json" 2> "$ci_watch_pass_stderr"
  ) && python3 -m json.tool "$ci_watch_pass_json" >/dev/null && \
    smoke_json_assert "$ci_watch_pass_json" 'data.get("overall_status") == "pass"'; then
    test_pass "ci-watch pass exits cleanly"
  else
    test_fail "ci-watch pass exits cleanly"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pass","state":"SUCCESS","workflow":"ci"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-watch --pr=123 --poll-seconds=1 --timeout=1 --json > "$ci_watch_pass_json_mode" 2> "$ci_watch_pass_stderr"
  ) && python3 -m json.tool "$ci_watch_pass_json_mode" >/dev/null && \
    smoke_json_assert "$ci_watch_pass_json_mode" 'data.get("overall_status") == "pass"'; then
    test_pass "ci-watch json exits cleanly"
  else
    test_fail "ci-watch json exits cleanly"
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
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"fail","state":"FAILURE","workflow":"ci"}]' PATH="$gh_stub_dir:$PATH" repo-automation/bin/ci-watch --pr=123 --poll-seconds=1 --timeout=1 --json > "$ci_watch_fail_json" 2> "$ci_watch_fail_stderr"
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

  rm -f "$ci_status_help" "$ci_watch_help" "$ci_status_pr_json" "$ci_status_pr_json_mode" "$ci_status_branch_json" "$ci_status_pr_human" "$ci_status_pr_quiet" "$ci_status_pr_explain" "$ci_status_failure_stderr" "$ci_watch_timeout_stderr" "$ci_status_pr_format_stderr" "$ci_status_pr_missing_stderr" "$ci_status_pr_empty_stderr" "$ci_status_unknown_stderr" "$ci_watch_timeout_format_stderr" "$ci_watch_timeout_missing_stderr" "$ci_watch_timeout_empty_stderr" "$ci_watch_unknown_stderr" "$ci_watch_pass_json" "$ci_watch_pass_json_mode" "$ci_watch_pass_stderr" "$ci_watch_pass_human" "$ci_watch_pass_quiet" "$ci_watch_pass_explain" "$ci_watch_fail_json" "$ci_watch_fail_stderr" "$ci_watch_no_checks_stderr" >/dev/null 2>&1 || true
  return "$status"
}
# repo-automation/tests/lib/contracts/ci.sh EOF
