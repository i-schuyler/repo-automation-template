#!/usr/bin/env bash
# shellcheck disable=SC2154
# repo-automation/tests/contracts/slice-handoff.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/contracts/slice-handoff.sh"

smoke_main_impl() {
  local status=0

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1

  smoke_run_named_check "smoke:slice-handoff-contract" smoke_check_slice_handoff_contract || status=1

  return "$status"
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_main_impl "$@"
}

smoke_check_slice_handoff_contract() {
  local status=0
  local smoke_check_root="$smoke_test_base/slice-handoff"
  local valid_none_file="$smoke_check_root/valid-none.md"
  local valid_submit_file="$smoke_check_root/valid-submit.md"
  local valid_none_out_dir="$smoke_test_base/out-valid-none"
  local valid_submit_out_dir="$smoke_test_base/out-valid-submit"
  local valid_quiet_out_dir="$smoke_test_base/out-quiet"
  local execution_artifact_root="${TMPDIR:-$HOME/.cache}/slice-handoff-execution"
  local execution_none_out_dir="$execution_artifact_root/out-execution-none"
  local execution_submit_out_dir="$execution_artifact_root/out-execution-submit"
  local execution_quiet_out_dir="$execution_artifact_root/out-execution-quiet"
  local invalid_out_dir="$smoke_test_base/out-invalid-validation"
  local inside_repo_out_dir="$smoke_test_dir/slice-handoff-out-inside-repo"
  local expected_none_stdout
  local expected_submit_stdout
  local expected_none_prompt
  local expected_submit_prompt
  local expected_submit_body
  local expected_submit_review_body
  local expected_default_review_request
  local expected_submit_default_review_request
  local expected_planned_run_dir_root
  local expected_none_summary
  local expected_quiet_summary
  local expected_submit_summary
  local expected_submit_noauth_summary
  local expected_none_preview
  local expected_quiet_preview
  local expected_submit_preview
  local expected_submit_noauth_preview
  local expected_none_review_stdout
  local expected_explicit_review_stdout
  local expected_execution_none_preview
  local expected_execution_none_summary
  local expected_execution_submit_preview
  local expected_execution_submit_summary
  local expected_execution_quiet_preview
  local expected_execution_quiet_summary
  local expected_dry_run_repo_root=""
  local expected_execution_repo_root=""
  local missing_schema_file="$smoke_check_root/missing-schema.md"
  local invalid_schema_file="$smoke_check_root/invalid-schema.md"
  local missing_branch_file="$smoke_check_root/missing-branch.md"
  local invalid_branch_file="$smoke_check_root/invalid-branch.md"
  local invalid_profile_file="$smoke_check_root/invalid-profile.md"
  local missing_commit_file="$smoke_check_root/missing-commit.md"
  local missing_pr_body_file="$smoke_check_root/missing-pr-body.md"
  local invalid_submit_file="$smoke_check_root/invalid-submit-pr-body.md"
  local empty_review_request_file="$smoke_check_root/empty-review-request.md"
  local placeholder_file="$smoke_check_root/placeholder.md"
  local lifecycle_file="$smoke_check_root/lifecycle.md"
  local execution_smoke_test_dir=""
  local fake_codex_bin_dir=""
  local fake_codex_args_none_file=""
  local fake_codex_args_submit_file=""
  local fake_repo_flow_args_submit_file=""
  local execution_valid_none_file=""
  local execution_valid_submit_file=""
  local execution_invalid_submit_file=""
  local valid_prompt="Implement the slice exactly as specified."
  local submit_prompt="Implement the slice and prepare the PR body."
  local invalid_submit_body="This PR body is intentionally invalid for pr-body-check."
  local review_request_text
  local submit_body
  local invalid_submit_body_text

  mkdir -p "$smoke_check_root" || return 1

  if smoke_slice_handoff_assert_metadata; then
    test_pass "slice-handoff metadata matches helper object"
  else
    test_fail "slice-handoff metadata matches helper object"
    status=1
  fi

  if smoke_slice_handoff_assert_planned_route; then
    test_pass "slice-handoff dry-run planned route matches helper metadata"
  else
    test_fail "slice-handoff dry-run planned route matches helper metadata"
    status=1
  fi

  submit_body="$(cat <<'EOF'
## Scope

Slice handoff smoke.

## What changed

Nothing.

## What did not change

Nothing.

## Verification status

Validated with slice-handoff and pr-body-check.

## User-visible behavior changes

None.

## Stop conditions encountered

None.

## Re-entry hint

Review the PR and continue the slice.
EOF
)"
  review_request_text="$(cat <<'EOF'
Please review the implementation for correctness and boundary compliance.
EOF
)"
  expected_planned_run_dir_root="${TMPDIR:-$HOME/.cache}/repo-automation/slice-handoff-runs"
  expected_none_prompt="$(printf '%s' "$valid_prompt")"
  expected_submit_prompt="$(printf '%s' "$submit_prompt")"
  expected_submit_body="$(printf '%s' "$submit_body")"
  expected_submit_review_body="$(printf '%s' "$submit_body")"
  invalid_submit_body_text="$(printf '%s' "$invalid_submit_body")"
  expected_dry_run_repo_root="$smoke_test_dir"
  expected_submit_repo_flow_url_or_stop="https://github.com/i-schuyler/repo-automation-template/pull/123"
  expected_default_review_request="$(cat <<EOF
Please review this PR before merge:

<PR_URL>

Slice: Slice handoff smoke
Branch: feature/slice-handoff-smoke

Review the changed files and any related docs, tests, metadata, command contracts, output contracts, and examples for drift.

Return CLEAN, NEEDS REPAIR, BLOCKING, or UNCERTAIN. If repair is needed, describe one same-branch repair direction.
EOF
)"
  expected_submit_default_review_request="$(cat <<EOF
Please review this PR before merge:

<PR_URL>

Slice: Slice handoff submit smoke
Branch: feature/slice-handoff-submit

Review the changed files and any related docs, tests, metadata, command contracts, output contracts, and examples for drift.

Return CLEAN, NEEDS REPAIR, BLOCKING, or UNCERTAIN. If repair is needed, describe one same-branch repair direction.
EOF
)"
  expected_none_summary="$(printf 'schema=repo-automation-slice-handoff/v1\nbranch=feature/slice-handoff-smoke\ntitle=Slice handoff smoke\ncodex_profile=default\nsubmit_mode=none\ncommit_message=\ncodex_prompt_path=%s/codex-prompt.md\npr_body_path=\nreview_request_path=%s/review-request.txt' "$valid_none_out_dir" "$valid_none_out_dir")"
  expected_quiet_summary="$(printf 'schema=repo-automation-slice-handoff/v1\nbranch=feature/slice-handoff-smoke\ntitle=Slice handoff smoke\ncodex_profile=default\nsubmit_mode=none\ncommit_message=\ncodex_prompt_path=%s/codex-prompt.md\npr_body_path=\nreview_request_path=%s/review-request.txt' "$valid_quiet_out_dir" "$valid_quiet_out_dir")"
  expected_submit_summary="$(printf 'schema=repo-automation-slice-handoff/v1\nbranch=feature/slice-handoff-submit\ntitle=Slice handoff submit smoke\ncodex_profile=review\nsubmit_mode=repo-flow-submit-all\ncommit_message=chore: slice-handoff smoke\ncodex_prompt_path=%s/codex-prompt.md\npr_body_path=%s/pr-body.md\nreview_request_path=%s/review-request.txt' "$valid_submit_out_dir" "$valid_submit_out_dir" "$valid_submit_out_dir")"
  expected_submit_noauth_summary="$(printf 'schema=repo-automation-slice-handoff/v1\nbranch=feature/slice-handoff-submit\ntitle=Slice handoff submit smoke\ncodex_profile=review\nsubmit_mode=repo-flow-submit-all\ncommit_message=chore: slice-handoff smoke\ncodex_prompt_path=%s/codex-prompt.md\npr_body_path=\nreview_request_path=%s/review-request.txt' "$valid_submit_out_dir" "$valid_submit_out_dir")"
  expected_none_preview="$(cat <<EOF
dry_run_mode=enabled
branch=feature/slice-handoff-smoke
title=Slice handoff smoke
codex_profile=default
submit_mode=none
commit_message=
codex_prompt_path=$valid_none_out_dir/codex-prompt.md
pr_body_path=not_applicable
review_request_path=$valid_none_out_dir/review-request.txt
summary_path=$valid_none_out_dir/slice-handoff-summary.txt
preview_path=$valid_none_out_dir/dry-run-preview.txt
planned_run_dir_root=$expected_planned_run_dir_root
planned_active_run_dir=<active-run-dir>
planned_marker_file_name=.repo-automation-slice-run

Planned execution shapes
planned_run_dir_cleanup_argv:
- repo-automation/bin/slice-run-dir
- --cleanup-stale
- --root=$expected_planned_run_dir_root
- --max-age-days=7
- --keep=10
- --preserve-path=<active-run-dir>
- --json
planned_preflight_argv:
- repo-automation/bin/codex-slice-preflight
- --branch=feature/slice-handoff-smoke
- --clean-test-cache
- --preserve-path=<active-run-dir>
- --json
planned_codex_run_argv:
- repo-automation/bin/codex-run
- --prompt-file=<active-run-dir>/codex-prompt.md
- --out-dir=<active-run-dir>/codex-run
- --profile=default
- --cd=$expected_dry_run_repo_root
planned_pr_body_validation_argv=not_applicable
planned_repo_flow_submit_argv=not_applicable

Planned artifact/log/metadata paths
preflight_log_path=not_created_by_dry_run
codex_run_stdout_path=not_created_by_dry_run
codex_run_stderr_path=not_created_by_dry_run
codex_run_summary_path=not_created_by_dry_run
codex_final_output_path=not_written_by_dry_run
submit_log_path=not_created_by_dry_run

Expected future final outcomes
expected_future_final_outcomes=blocker or review request
EOF
)"
  expected_quiet_preview="$(cat <<EOF
dry_run_mode=enabled
branch=feature/slice-handoff-smoke
title=Slice handoff smoke
codex_profile=default
submit_mode=none
commit_message=
codex_prompt_path=$valid_quiet_out_dir/codex-prompt.md
pr_body_path=not_applicable
review_request_path=$valid_quiet_out_dir/review-request.txt
summary_path=$valid_quiet_out_dir/slice-handoff-summary.txt
preview_path=$valid_quiet_out_dir/dry-run-preview.txt
planned_run_dir_root=$expected_planned_run_dir_root
planned_active_run_dir=<active-run-dir>
planned_marker_file_name=.repo-automation-slice-run

Planned execution shapes
planned_run_dir_cleanup_argv:
- repo-automation/bin/slice-run-dir
- --cleanup-stale
- --root=$expected_planned_run_dir_root
- --max-age-days=7
- --keep=10
- --preserve-path=<active-run-dir>
- --json
planned_preflight_argv:
- repo-automation/bin/codex-slice-preflight
- --branch=feature/slice-handoff-smoke
- --clean-test-cache
- --preserve-path=<active-run-dir>
- --json
planned_codex_run_argv:
- repo-automation/bin/codex-run
- --prompt-file=<active-run-dir>/codex-prompt.md
- --out-dir=<active-run-dir>/codex-run
- --profile=default
- --cd=$expected_dry_run_repo_root
planned_pr_body_validation_argv=not_applicable
planned_repo_flow_submit_argv=not_applicable

Planned artifact/log/metadata paths
preflight_log_path=not_created_by_dry_run
codex_run_stdout_path=not_created_by_dry_run
codex_run_stderr_path=not_created_by_dry_run
codex_run_summary_path=not_created_by_dry_run
codex_final_output_path=not_written_by_dry_run
submit_log_path=not_created_by_dry_run

Expected future final outcomes
expected_future_final_outcomes=blocker or review request
EOF
)"
  expected_submit_preview="$(cat <<EOF
dry_run_mode=enabled
branch=feature/slice-handoff-submit
title=Slice handoff submit smoke
codex_profile=review
submit_mode=repo-flow-submit-all
commit_message=chore: slice-handoff smoke
codex_prompt_path=$valid_submit_out_dir/codex-prompt.md
pr_body_path=$valid_submit_out_dir/pr-body.md
review_request_path=$valid_submit_out_dir/review-request.txt
summary_path=$valid_submit_out_dir/slice-handoff-summary.txt
preview_path=$valid_submit_out_dir/dry-run-preview.txt
planned_run_dir_root=$expected_planned_run_dir_root
planned_active_run_dir=<active-run-dir>
planned_marker_file_name=.repo-automation-slice-run

Planned execution shapes
planned_run_dir_cleanup_argv:
- repo-automation/bin/slice-run-dir
- --cleanup-stale
- --root=$expected_planned_run_dir_root
- --max-age-days=7
- --keep=10
- --preserve-path=<active-run-dir>
- --json
planned_preflight_argv:
- repo-automation/bin/codex-slice-preflight
- --branch=feature/slice-handoff-submit
- --clean-test-cache
- --preserve-path=<active-run-dir>
- --json
planned_codex_run_argv:
- repo-automation/bin/codex-run
- --prompt-file=<active-run-dir>/codex-prompt.md
- --out-dir=<active-run-dir>/codex-run
- --profile=review
- --cd=$expected_dry_run_repo_root
planned_pr_body_validation_argv:
- repo-automation/bin/pr-body-check
- --body-file=$valid_submit_out_dir/pr-body.md
planned_repo_flow_submit_argv:
- repo-automation/bin/repo-flow
- submit
- --all
- --message=chore: slice-handoff smoke
- --body-file=$valid_submit_out_dir/pr-body.md
- --watch
- --timeout=900
- --diagnose-on-fail
- --explain

Planned artifact/log/metadata paths
preflight_log_path=not_created_by_dry_run
codex_run_stdout_path=not_created_by_dry_run
codex_run_stderr_path=not_created_by_dry_run
codex_run_summary_path=not_created_by_dry_run
codex_final_output_path=not_written_by_dry_run
submit_log_path=not_created_by_dry_run

Expected future final outcomes
expected_future_final_outcomes=blocker or PR URL / FINAL SUMMARY / review request
EOF
)"
  expected_submit_noauth_preview="$(cat <<EOF
dry_run_mode=enabled
branch=feature/slice-handoff-submit
title=Slice handoff submit smoke
codex_profile=review
submit_mode=repo-flow-submit-all
commit_message=chore: slice-handoff smoke
codex_prompt_path=$valid_submit_out_dir/codex-prompt.md
pr_body_path=not_applicable
review_request_path=$valid_submit_out_dir/review-request.txt
summary_path=$valid_submit_out_dir/slice-handoff-summary.txt
preview_path=$valid_submit_out_dir/dry-run-preview.txt
planned_run_dir_root=$expected_planned_run_dir_root
planned_active_run_dir=<active-run-dir>
planned_marker_file_name=.repo-automation-slice-run

Planned execution shapes
planned_run_dir_cleanup_argv:
- repo-automation/bin/slice-run-dir
- --cleanup-stale
- --root=$expected_planned_run_dir_root
- --max-age-days=7
- --keep=10
- --preserve-path=<active-run-dir>
- --json
planned_preflight_argv:
- repo-automation/bin/codex-slice-preflight
- --branch=feature/slice-handoff-submit
- --clean-test-cache
- --preserve-path=<active-run-dir>
- --json
planned_codex_run_argv:
- repo-automation/bin/codex-run
- --prompt-file=<active-run-dir>/codex-prompt.md
- --out-dir=<active-run-dir>/codex-run
- --profile=review
- --cd=$expected_dry_run_repo_root
planned_pr_body_validation_argv=not_applicable
planned_repo_flow_submit_argv=not_applicable

Planned artifact/log/metadata paths
preflight_log_path=not_created_by_dry_run
codex_run_stdout_path=not_created_by_dry_run
codex_run_stderr_path=not_created_by_dry_run
codex_run_summary_path=not_created_by_dry_run
codex_final_output_path=not_written_by_dry_run
submit_log_path=not_created_by_dry_run

Expected future final outcomes
expected_future_final_outcomes=blocker or review request
EOF
)"
  expected_none_stdout="$(printf 'pass\nout_dir=%s\ncodex_prompt_path=%s/codex-prompt.md\npreview_path=%s/dry-run-preview.txt\nreview_request_path=%s/review-request.txt\nsummary_path=%s/slice-handoff-summary.txt' "$valid_none_out_dir" "$valid_none_out_dir" "$valid_none_out_dir" "$valid_none_out_dir" "$valid_none_out_dir")"
  expected_none_review_stdout="$(printf 'pass\nout_dir=%s\ncodex_prompt_path=%s/codex-prompt.md\npreview_path=%s/dry-run-preview.txt\nreview_request_path=%s/review-request.txt\nsummary_path=%s/slice-handoff-summary.txt' "$valid_quiet_out_dir" "$valid_quiet_out_dir" "$valid_quiet_out_dir" "$valid_quiet_out_dir" "$valid_quiet_out_dir")"
  expected_submit_stdout="$(printf 'pass\nout_dir=%s\ncodex_prompt_path=%s/codex-prompt.md\npreview_path=%s/dry-run-preview.txt\nreview_request_path=%s/review-request.txt\nsummary_path=%s/slice-handoff-summary.txt' "$valid_submit_out_dir" "$valid_submit_out_dir" "$valid_submit_out_dir" "$valid_submit_out_dir" "$valid_submit_out_dir")"
  expected_explicit_review_stdout="$(printf 'pass\nout_dir=%s\ncodex_prompt_path=%s/codex-prompt.md\npreview_path=%s/dry-run-preview.txt\npr_body_path=%s/pr-body.md\nreview_request_path=%s/review-request.txt\nsummary_path=%s/slice-handoff-summary.txt' "$valid_submit_out_dir" "$valid_submit_out_dir" "$valid_submit_out_dir" "$valid_submit_out_dir" "$valid_submit_out_dir" "$valid_submit_out_dir")"
  expected_execution_none_summary="${expected_none_summary//$valid_none_out_dir/$execution_none_out_dir}"
  expected_execution_quiet_summary="${expected_quiet_summary//$valid_quiet_out_dir/$execution_quiet_out_dir}"

  smoke_slice_handoff_write_file "$valid_none_file" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "$valid_prompt" || return 1
  smoke_slice_handoff_write_file "$valid_submit_file" "feature/slice-handoff-submit" "Slice handoff submit smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$submit_prompt" "$submit_body" || return 1
  smoke_slice_handoff_write_file "$invalid_submit_file" "feature/slice-handoff-submit" "Slice handoff submit smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$submit_prompt" "$invalid_submit_body_text" || return 1

  if smoke_slice_handoff_expect_success "valid-none" "pass" "" --file="$valid_none_file" --dry-run; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_success "quiet-success" "" "" --file="$valid_none_file" --dry-run --quiet; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_success "valid-submit" "pass" "" --file="$valid_submit_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    rm -rf -- "$valid_none_out_dir" &&
      smoke_slice_handoff_expect_success "out-dir-none" "$expected_none_stdout" "" --file="$valid_none_file" --dry-run --out-dir="$valid_none_out_dir" &&
      smoke_slice_handoff_assert_text_file "$valid_none_out_dir/codex-prompt.md" "$expected_none_prompt" &&
      smoke_slice_handoff_assert_text_file "$valid_none_out_dir/dry-run-preview.txt" "$expected_none_preview" &&
      smoke_slice_handoff_assert_text_file "$valid_none_out_dir/review-request.txt" "$expected_default_review_request" &&
      smoke_slice_handoff_assert_text_file "$valid_none_out_dir/slice-handoff-summary.txt" "$expected_none_summary"
  ); then
    :
  else
    test_fail "out-dir-none artifacts"
    status=1
  fi

  if (
    rm -rf -- "$valid_submit_out_dir" &&
      smoke_slice_handoff_expect_success "out-dir-submit" "$expected_submit_stdout" "" --file="$valid_submit_file" --dry-run --out-dir="$valid_submit_out_dir" &&
      smoke_slice_handoff_assert_text_file "$valid_submit_out_dir/codex-prompt.md" "$expected_submit_prompt" &&
      smoke_slice_handoff_assert_text_file "$valid_submit_out_dir/dry-run-preview.txt" "$expected_submit_noauth_preview" &&
      smoke_slice_handoff_assert_text_file "$valid_submit_out_dir/review-request.txt" "$expected_submit_default_review_request" &&
      smoke_slice_handoff_assert_text_file "$valid_submit_out_dir/slice-handoff-summary.txt" "$expected_submit_noauth_summary" &&
      [ ! -e "$valid_submit_out_dir/pr-body.md" ]
  ); then
    :
  else
    test_fail "out-dir-submit artifacts"
    status=1
  fi

  if (
    rm -rf -- "$invalid_out_dir" &&
      smoke_slice_handoff_expect_failure "out-dir-submit-invalid-pr-body" "missing required heading: ## Scope" "use .github/pull_request_template.md or run repo-automation/bin/pr-body-check --print-template" --file="$invalid_submit_file" --dry-run --out-dir="$invalid_out_dir" &&
      [ ! -e "$invalid_out_dir" ]
  ); then
    :
  else
    test_fail "out-dir-submit-invalid-pr-body artifacts"
    status=1
  fi

  if (
    rm -rf -- "$valid_submit_out_dir" &&
      smoke_slice_handoff_write_file "$valid_submit_file" "feature/slice-handoff-submit" "Slice handoff submit smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$submit_prompt" "$submit_body" "$review_request_text" &&
      smoke_slice_handoff_expect_success "out-dir-submit-review-request" "$expected_explicit_review_stdout" "" --file="$valid_submit_file" --dry-run --submit --out-dir="$valid_submit_out_dir" &&
      smoke_slice_handoff_assert_text_file "$valid_submit_out_dir/codex-prompt.md" "$expected_submit_prompt" &&
      smoke_slice_handoff_assert_text_file "$valid_submit_out_dir/dry-run-preview.txt" "$expected_submit_preview" &&
      smoke_slice_handoff_assert_text_file "$valid_submit_out_dir/pr-body.md" "$expected_submit_review_body" &&
      smoke_slice_handoff_assert_text_file "$valid_submit_out_dir/review-request.txt" "$review_request_text" &&
      ! grep -Fq -- "$review_request_text" "$valid_submit_out_dir/codex-prompt.md" &&
      ! grep -Fq -- "$review_request_text" "$valid_submit_out_dir/pr-body.md" &&
      ! grep -Fq -- 'PR Review Request' "$valid_submit_out_dir/codex-prompt.md" &&
      smoke_slice_handoff_assert_text_file "$valid_submit_out_dir/slice-handoff-summary.txt" "$expected_submit_summary" &&
      ! grep -Fq -- 'PR Review Request' "$valid_submit_out_dir/pr-body.md"
  ); then
    :
  else
    test_fail "out-dir-submit-review-request artifacts"
    status=1
  fi

  if (
    rm -rf -- "$valid_quiet_out_dir" &&
      smoke_slice_handoff_write_file "$valid_none_file" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "$valid_prompt" "" "$review_request_text" &&
      smoke_slice_handoff_run "$smoke_test_base/slice-handoff-quiet-out-review.out" "$smoke_test_base/slice-handoff-quiet-out-review.err" --file="$valid_none_file" --dry-run --quiet --out-dir="$valid_quiet_out_dir" &&
      [ ! -s "$smoke_test_base/slice-handoff-quiet-out-review.out" ] &&
      [ ! -s "$smoke_test_base/slice-handoff-quiet-out-review.err" ] &&
      smoke_slice_handoff_assert_text_file "$valid_quiet_out_dir/codex-prompt.md" "$expected_none_prompt" &&
      smoke_slice_handoff_assert_text_file "$valid_quiet_out_dir/dry-run-preview.txt" "$expected_quiet_preview" &&
      smoke_slice_handoff_assert_text_file "$valid_quiet_out_dir/review-request.txt" "$review_request_text" &&
      smoke_slice_handoff_assert_text_file "$valid_quiet_out_dir/slice-handoff-summary.txt" "$expected_quiet_summary" &&
      smoke_slice_handoff_expect_success "out-dir-none-review-request-stdout" "$expected_none_review_stdout" "" --file="$valid_none_file" --dry-run --out-dir="$valid_quiet_out_dir"
  ); then
    :
  else
    test_fail "out-dir-none-review-request artifacts"
    status=1
  fi

  if (
    rm -rf -- "$valid_quiet_out_dir" &&
      smoke_slice_handoff_write_file "$valid_none_file" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "$valid_prompt" &&
      smoke_slice_handoff_run "$smoke_test_base/slice-handoff-quiet-out.out" "$smoke_test_base/slice-handoff-quiet-out.err" --file="$valid_none_file" --dry-run --quiet --out-dir="$valid_quiet_out_dir" &&
      [ ! -s "$smoke_test_base/slice-handoff-quiet-out.out" ] &&
      [ ! -s "$smoke_test_base/slice-handoff-quiet-out.err" ] &&
      smoke_slice_handoff_assert_text_file "$valid_quiet_out_dir/codex-prompt.md" "$expected_none_prompt" &&
      smoke_slice_handoff_assert_text_file "$valid_quiet_out_dir/dry-run-preview.txt" "$expected_quiet_preview" &&
      smoke_slice_handoff_assert_text_file "$valid_quiet_out_dir/review-request.txt" "$expected_default_review_request" &&
      smoke_slice_handoff_assert_text_file "$valid_quiet_out_dir/slice-handoff-summary.txt" "$expected_quiet_summary"
  ); then
    :
  else
    test_fail "out-dir-quiet artifacts"
    status=1
  fi

  smoke_slice_handoff_write_file "$valid_none_file" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "$valid_prompt" || return 1
  smoke_slice_handoff_write_file "$valid_submit_file" "feature/slice-handoff-submit" "Slice handoff submit smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$submit_prompt" "$submit_body" || return 1
  execution_smoke_test_dir="$(mktemp -d "${TMPDIR:-$HOME/.cache}/repo-automation-slice-handoff-fixture.XXXXXX")" || return 1
  cp -R "$smoke_test_dir"/. "$execution_smoke_test_dir" || return 1
  smoke_test_dir="$execution_smoke_test_dir"
  expected_execution_repo_root="$smoke_test_dir"
  expected_execution_none_preview="${expected_none_preview//$valid_none_out_dir/$execution_none_out_dir}"
  expected_execution_none_preview="${expected_execution_none_preview//$expected_dry_run_repo_root/$expected_execution_repo_root}"
  expected_execution_submit_preview="${expected_submit_preview//$valid_submit_out_dir/$execution_submit_out_dir}"
  expected_execution_submit_preview="${expected_execution_submit_preview//$expected_dry_run_repo_root/$expected_execution_repo_root}"
  expected_execution_submit_summary="${expected_submit_summary//$valid_submit_out_dir/$execution_submit_out_dir}"
  expected_execution_quiet_preview="${expected_quiet_preview//$valid_quiet_out_dir/$execution_quiet_out_dir}"
  expected_execution_quiet_preview="${expected_execution_quiet_preview//$expected_dry_run_repo_root/$expected_execution_repo_root}"
  smoke_slice_handoff_prepare_execution_repo || return 1
  fake_codex_bin_dir="$execution_artifact_root/fake-codex-bin"
  smoke_slice_handoff_write_fake_codex "$fake_codex_bin_dir" || return 1
  fake_codex_args_none_file="$execution_artifact_root/fake-codex-none.args"
  fake_codex_args_submit_file="$execution_artifact_root/fake-codex-submit.args"
  fake_codex_args_quiet_file="$execution_artifact_root/fake-codex-quiet.args"
  fake_repo_flow_args_submit_file="$execution_artifact_root/fake-repo-flow-submit.args"
  execution_valid_none_file="$execution_artifact_root/valid-none.md"
  execution_valid_submit_file="$execution_artifact_root/valid-submit.md"
  execution_invalid_submit_file="$execution_artifact_root/invalid-submit-pr-body.md"
  rm -f -- "$fake_repo_flow_args_submit_file" >/dev/null 2>&1 || true
  inside_repo_out_dir="$smoke_test_dir/slice-handoff-out-inside-repo"
  smoke_slice_handoff_write_file "$execution_valid_none_file" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "$valid_prompt" || return 1
  smoke_slice_handoff_write_file "$execution_valid_submit_file" "feature/slice-handoff-submit" "Slice handoff submit smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$submit_prompt" "$submit_body" || return 1
  smoke_slice_handoff_write_file "$execution_invalid_submit_file" "feature/slice-handoff-submit" "Slice handoff submit smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$submit_prompt" "$submit_body" || return 1

  if (
    rm -f -- "$fake_codex_args_submit_file" "$fake_repo_flow_args_submit_file" &&
      PATH="$fake_codex_bin_dir:$PATH" FAKE_CODEX_ARGS_FILE="$fake_codex_args_submit_file" smoke_slice_handoff_run "$execution_artifact_root/slice-handoff-submit-requires-mode.out" "$execution_artifact_root/slice-handoff-submit-requires-mode.err" --file="$execution_valid_none_file" --submit --out-dir="$execution_submit_out_dir"
  ); then
    test_fail "submit-requires-mode"
    status=1
  else
    if smoke_slice_handoff_assert_error_shape "$execution_artifact_root/slice-handoff-submit-requires-mode.err" "--submit requires submit_mode: repo-flow-submit-all in the handoff envelope" "set submit_mode: repo-flow-submit-all or remove --submit" &&
      [ ! -s "$fake_codex_args_submit_file" ] &&
      [ ! -s "$fake_repo_flow_args_submit_file" ]; then
      test_pass "submit-requires-mode"
    else
      test_fail "submit-requires-mode"
      status=1
    fi
  fi

  if (
    rm -rf -- "$execution_none_out_dir" &&
      smoke_slice_handoff_assert_execution_repo_ready &&
      smoke_slice_handoff_assert_clean_worktree &&
      PATH="$fake_codex_bin_dir:$PATH" FAKE_CODEX_ARGS_FILE="$fake_codex_args_none_file" FAKE_CODEX_STDOUT_TEXT='fake codex stdout' FAKE_CODEX_STDERR_TEXT='fake codex stderr' FAKE_CODEX_FINAL_TEXT='fake final output' smoke_slice_handoff_run "$execution_artifact_root/slice-handoff-execution-none.out" "$execution_artifact_root/slice-handoff-execution-none.err" --file="$valid_none_file" --out-dir="$execution_none_out_dir" &&
      run_dir="$(smoke_slice_handoff_assert_execution_stdout "$execution_artifact_root/slice-handoff-execution-none.out" "$execution_artifact_root/slice-handoff-execution-none.err" "feature/slice-handoff-smoke")" &&
      grep -Fxq "codex_final_output_path=$run_dir/codex-run/codex-final.txt" "$execution_artifact_root/slice-handoff-execution-none.out" &&
      smoke_slice_handoff_assert_execution_run_dir "$run_dir" "none" "feature/slice-handoff-smoke" "Slice handoff smoke" "$expected_none_prompt" "$expected_default_review_request" "" "$smoke_test_dir" &&
      smoke_slice_handoff_assert_text_file "$fake_codex_args_none_file" "$(cat <<EOF
exec
--cd
$smoke_test_dir
--sandbox
workspace-write
--output-last-message
$run_dir/codex-run/codex-final.txt
-
EOF
)" &&
      smoke_slice_handoff_assert_text_file "$execution_none_out_dir/codex-prompt.md" "$expected_none_prompt" &&
      smoke_slice_handoff_assert_text_file "$execution_none_out_dir/dry-run-preview.txt" "$expected_execution_none_preview" &&
      smoke_slice_handoff_assert_text_file "$execution_none_out_dir/review-request.txt" "$expected_default_review_request" &&
      smoke_slice_handoff_assert_text_file "$execution_none_out_dir/slice-handoff-summary.txt" "$expected_execution_none_summary"
  ); then
    :
  else
    test_fail "execution-none artifacts"
    status=1
  fi

  if (
    rm -rf -- "$execution_submit_out_dir" &&
      smoke_slice_handoff_write_file "$execution_valid_submit_file" "feature/slice-handoff-submit" "Slice handoff submit smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$submit_prompt" "$submit_body" "$review_request_text" &&
      smoke_slice_handoff_assert_execution_repo_ready &&
      smoke_slice_handoff_assert_clean_worktree &&
      PATH="$fake_codex_bin_dir:$PATH" FAKE_CODEX_ARGS_FILE="$fake_codex_args_submit_file" FAKE_CODEX_STDOUT_TEXT='fake codex stdout' FAKE_CODEX_STDERR_TEXT='fake codex stderr' FAKE_CODEX_FINAL_TEXT='fake final output' FAKE_REPO_FLOW_ARGS_FILE="$fake_repo_flow_args_submit_file" FAKE_REPO_FLOW_STDOUT_TEXT='fake repo-flow stdout' FAKE_REPO_FLOW_STDERR_TEXT='fake repo-flow stderr' FAKE_REPO_FLOW_URL_OR_STOP="$expected_submit_repo_flow_url_or_stop" smoke_slice_handoff_run "$execution_artifact_root/slice-handoff-execution-submit.out" "$execution_artifact_root/slice-handoff-execution-submit.err" --file="$execution_valid_submit_file" --submit --out-dir="$execution_submit_out_dir" &&
      run_dir="$(smoke_slice_handoff_assert_execution_stdout "$execution_artifact_root/slice-handoff-execution-submit.out" "$execution_artifact_root/slice-handoff-execution-submit.err" "feature/slice-handoff-submit" "execution-submit" "review PR before merge" "$expected_submit_repo_flow_url_or_stop")" &&
      grep -Fxq "codex_final_output_path=$run_dir/codex-run/codex-final.txt" "$execution_artifact_root/slice-handoff-execution-submit.out" &&
      smoke_slice_handoff_assert_execution_run_dir "$run_dir" "repo-flow-submit-all" "feature/slice-handoff-submit" "Slice handoff submit smoke" "$expected_submit_prompt" "$review_request_text" "$expected_submit_body" "$smoke_test_dir" "execution-submit" "review PR before merge" "$expected_submit_repo_flow_url_or_stop" &&
      smoke_slice_handoff_assert_text_file "$fake_codex_args_submit_file" "$(cat <<EOF
exec
--profile
review
--cd
$smoke_test_dir
--sandbox
workspace-write
--output-last-message
$run_dir/codex-run/codex-final.txt
-
EOF
)" &&
      smoke_slice_handoff_assert_text_file "$fake_repo_flow_args_submit_file" "$(cat <<EOF
submit
--all
--message=chore: slice-handoff smoke
--body-file=$run_dir/pr-body.md
--watch
--timeout=900
--diagnose-on-fail
--explain
EOF
)" &&
      grep -Fxq 'fake repo-flow stdout' "$run_dir/repo-flow-submit.stdout" &&
      grep -Fq 'fake repo-flow stderr' "$run_dir/repo-flow-submit.stderr" &&
      grep -Fxq 'pass' "$run_dir/pr-body-check.stdout" &&
      grep -Fxq '===== FINAL SUMMARY =====' "$run_dir/repo-flow-submit.stderr" &&
      grep -Fxq "url_or_stop=$expected_submit_repo_flow_url_or_stop" "$run_dir/repo-flow-submit.stderr" &&
      smoke_slice_handoff_assert_text_file "$execution_submit_out_dir/codex-prompt.md" "$expected_submit_prompt" &&
      smoke_slice_handoff_assert_text_file "$execution_submit_out_dir/dry-run-preview.txt" "$expected_execution_submit_preview" &&
      smoke_slice_handoff_assert_text_file "$execution_submit_out_dir/pr-body.md" "$expected_submit_body" &&
      smoke_slice_handoff_assert_text_file "$execution_submit_out_dir/review-request.txt" "$review_request_text" &&
      grep -Fxq 'mode=execution-submit' "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq 'result=pass' "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq 'next=review PR before merge' "$run_dir/slice-handoff-execution-summary.txt" &&
      smoke_slice_handoff_assert_text_file "$execution_submit_out_dir/slice-handoff-summary.txt" "$expected_execution_submit_summary"
  ); then
    :
  else
    test_fail "execution-submit artifacts"
    status=1
  fi

  if (
    rm -f -- "$fake_repo_flow_args_submit_file" &&
      smoke_slice_handoff_assert_execution_repo_ready &&
      PATH="$fake_codex_bin_dir:$PATH" FAKE_CODEX_ARGS_FILE="$fake_codex_args_submit_file" FAKE_CODEX_STDOUT_TEXT='fake codex stdout' FAKE_CODEX_STDERR_TEXT='fake codex stderr' FAKE_CODEX_FINAL_TEXT='fake final output' FAKE_REPO_FLOW_ARGS_FILE="$fake_repo_flow_args_submit_file" FAKE_PR_BODY_CHECK_EXIT_CODE=1 FAKE_PR_BODY_CHECK_STDERR_TEXT='forced pr-body-check blocker from smoke' smoke_slice_handoff_run "$execution_artifact_root/slice-handoff-execution-submit-pr-body-check.out" "$execution_artifact_root/slice-handoff-execution-submit-pr-body-check.err" --file="$execution_invalid_submit_file" --submit --out-dir="$execution_submit_out_dir"
  ); then
    test_fail "execution-submit pr-body-check failure"
    status=1
  else
    run_dir="$(smoke_slice_handoff_latest_run_dir)"
    if grep -Fxq 'step=pr-body-check' "$execution_artifact_root/slice-handoff-execution-submit-pr-body-check.err" &&
      grep -Fxq 'fix=paste this blocker into ChatGPT' "$execution_artifact_root/slice-handoff-execution-submit-pr-body-check.err" &&
      grep -Fxq 'mode=execution-submit' "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq 'result=fail' "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq "pr_body_check_stdout_path=$run_dir/pr-body-check.stdout" "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq "pr_body_check_stderr_path=$run_dir/pr-body-check.stderr" "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq 'repo_flow_submit_stdout_path=' "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq 'repo_flow_submit_stderr_path=' "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq 'pass' "$run_dir/codex-run.stdout" &&
      grep -Fxq 'fake codex stdout' "$run_dir/codex-run/codex.stdout" &&
      [ ! -s "$fake_repo_flow_args_submit_file" ] &&
      [ ! -s "$run_dir/repo-flow-submit.stdout" ] &&
      [ ! -e "$run_dir/repo-flow-submit.stderr" ]; then
      :
    else
      test_fail "execution-submit pr-body-check failure"
      status=1
    fi
  fi

  if (
    rm -f -- "$fake_repo_flow_args_submit_file" &&
      smoke_slice_handoff_assert_execution_repo_ready &&
      PATH="$fake_codex_bin_dir:$PATH" FAKE_CODEX_ARGS_FILE="$fake_codex_args_submit_file" FAKE_CODEX_STDOUT_TEXT='fake codex stdout' FAKE_CODEX_STDERR_TEXT='fake codex stderr' FAKE_CODEX_FINAL_TEXT='fake final output' FAKE_REPO_FLOW_ARGS_FILE="$fake_repo_flow_args_submit_file" FAKE_REPO_FLOW_STDOUT_TEXT='fake repo-flow stdout' FAKE_REPO_FLOW_STDERR_TEXT='fake repo-flow stderr' FAKE_REPO_FLOW_EXIT_CODE=1 FAKE_REPO_FLOW_STOP_REASON='repo-flow submit blocker from smoke' smoke_slice_handoff_run "$execution_artifact_root/slice-handoff-execution-submit-repo-flow.out" "$execution_artifact_root/slice-handoff-execution-submit-repo-flow.err" --file="$execution_valid_submit_file" --submit --out-dir="$execution_submit_out_dir"
  ); then
    test_fail "execution-submit repo-flow failure"
    status=1
  else
    run_dir="$(smoke_slice_handoff_latest_run_dir)"
    if grep -Fxq 'step=repo-flow-submit' "$execution_artifact_root/slice-handoff-execution-submit-repo-flow.err" &&
      grep -Fxq 'fix=paste this blocker into ChatGPT' "$execution_artifact_root/slice-handoff-execution-submit-repo-flow.err" &&
      grep -Fxq 'mode=execution-submit' "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq 'result=fail' "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq "repo_flow_submit_stdout_path=$run_dir/repo-flow-submit.stdout" "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq "repo_flow_submit_stderr_path=$run_dir/repo-flow-submit.stderr" "$run_dir/slice-handoff-execution-summary.txt" &&
      grep -Fxq 'pass' "$run_dir/codex-run.stdout" &&
      grep -Fxq 'fake codex stdout' "$run_dir/codex-run/codex.stdout" &&
      grep -Fxq 'submit' "$fake_repo_flow_args_submit_file" &&
      grep -Fxq 'fake repo-flow stdout' "$run_dir/repo-flow-submit.stdout" &&
      grep -Fq 'repo-flow submit blocker from smoke' "$run_dir/repo-flow-submit.stderr"; then
      :
    else
      test_fail "execution-submit repo-flow failure"
      status=1
    fi
  fi

  smoke_slice_handoff_write_file "$valid_none_file" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "$valid_prompt" || return 1

  if (
    rm -rf -- "$execution_quiet_out_dir" &&
      smoke_slice_handoff_assert_execution_repo_ready &&
      smoke_slice_handoff_assert_clean_worktree &&
      PATH="$fake_codex_bin_dir:$PATH" FAKE_CODEX_ARGS_FILE="$fake_codex_args_quiet_file" FAKE_CODEX_STDOUT_TEXT='fake codex stdout' FAKE_CODEX_STDERR_TEXT='fake codex stderr' FAKE_CODEX_FINAL_TEXT='fake final output' smoke_slice_handoff_run "$execution_artifact_root/slice-handoff-execution-quiet.out" "$execution_artifact_root/slice-handoff-execution-quiet.err" --file="$valid_none_file" --quiet --out-dir="$execution_quiet_out_dir" &&
      [ ! -s "$execution_artifact_root/slice-handoff-execution-quiet.out" ] &&
      [ ! -s "$execution_artifact_root/slice-handoff-execution-quiet.err" ] &&
      final_output_path="$(awk 'prev == "--output-last-message" { print; exit } { prev = $0 }' "$fake_codex_args_quiet_file")" &&
      run_dir="$(dirname "$(dirname "$final_output_path")")" &&
      smoke_slice_handoff_assert_execution_run_dir "$run_dir" "none" "feature/slice-handoff-smoke" "Slice handoff smoke" "$expected_none_prompt" "$expected_default_review_request" "" "$smoke_test_dir" &&
      smoke_slice_handoff_assert_text_file "$fake_codex_args_quiet_file" "$(cat <<EOF
exec
--cd
$smoke_test_dir
--sandbox
workspace-write
--output-last-message
$run_dir/codex-run/codex-final.txt
-
EOF
)" &&
      smoke_slice_handoff_assert_text_file "$execution_quiet_out_dir/codex-prompt.md" "$expected_none_prompt" &&
      smoke_slice_handoff_assert_text_file "$execution_quiet_out_dir/dry-run-preview.txt" "$expected_execution_quiet_preview" &&
      smoke_slice_handoff_assert_text_file "$execution_quiet_out_dir/review-request.txt" "$expected_default_review_request" &&
      smoke_slice_handoff_assert_text_file "$execution_quiet_out_dir/slice-handoff-summary.txt" "$expected_execution_quiet_summary"
  ); then
    :
  else
    test_fail "execution-quiet artifacts"
    status=1
  fi

  if (smoke_slice_handoff_run_dirty_preflight_regression); then
    :
  else
    test_fail "execution-dirty-preflight artifacts"
    status=1
  fi

  smoke_slice_handoff_write_file "$valid_none_file" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "$valid_prompt" || return 1
  smoke_slice_handoff_write_file "$valid_submit_file" "feature/slice-handoff-submit" "Slice handoff submit smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$submit_prompt" "$submit_body" || return 1

  if (
    rm -rf -- "$inside_repo_out_dir" &&
      smoke_slice_handoff_expect_failure "out-dir-inside-repo" "out-dir must be outside the repo root" "choose a directory outside the current repo root" --file="$valid_none_file" --dry-run --out-dir="$inside_repo_out_dir" &&
      [ ! -e "$inside_repo_out_dir" ]
  ); then
    :
  else
    test_fail "out-dir-inside-repo artifacts"
    status=1
  fi

  if smoke_slice_handoff_expect_failure "missing-file" "missing required --file" "use --file=<path> with a readable handoff file" --dry-run; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_failure "file-format" "missing flag value: --file" "use --file=<path>" --file "$valid_none_file" --dry-run; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_failure "empty-file" "empty flag value: --file" "use --file=<path>" --file= --dry-run; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_failure "missing-out-dir-value" "missing flag value: --out-dir" "use --out-dir=<path>" --file="$valid_none_file" --dry-run --out-dir; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_failure "empty-out-dir" "empty flag value: --out-dir" "use --out-dir=<path>" --file="$valid_none_file" --dry-run --out-dir=; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_failure "submit-value" "unsupported flag: --submit" "use bare --submit with submit_mode: repo-flow-submit-all in the handoff envelope" --file="$valid_submit_file" --dry-run --submit=maybe; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_failure "positional-out-dir" "unknown argument: out-dir" "run repo-automation/bin/slice-handoff --help" --file="$valid_none_file" --dry-run out-dir; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_failure "plan-only-reject" "unsupported flag: --plan-only" "use --dry-run" --file="$valid_none_file" --plan-only; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_failure "unknown-flag" "unknown flag: --whatever" "run repo-automation/bin/slice-handoff --help" --file="$valid_none_file" --dry-run --whatever; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_failure "execute-flag" "unsupported flag: --execute" "use the default execution mode without --execute" --file="$valid_none_file" --dry-run --execute; then
    :
  else
    status=1
  fi

  if smoke_slice_handoff_expect_failure "submit-flag" "unsupported flag: --submit" "use bare --submit with submit_mode: repo-flow-submit-all in the handoff envelope" --file="$valid_none_file" --dry-run --submit=repo-flow-submit-all; then
    :
  else
    status=1
  fi

  smoke_slice_handoff_write_file "$valid_none_file" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "$valid_prompt" || return 1
  smoke_slice_handoff_write_file "$valid_submit_file" "feature/slice-handoff-submit" "Slice handoff submit smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$submit_prompt" "$submit_body" || return 1

  if (
    python3 - "$valid_none_file" "$missing_schema_file" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding='utf-8').splitlines()
filtered = [line for line in source if not line.startswith('schema: ')]
Path(sys.argv[2]).write_text('\n'.join(filtered) + '\n', encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "missing-schema" "missing schema" "set schema: repo-automation-slice-handoff/v1" --file="$missing_schema_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$invalid_schema_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('schema: repo-automation-slice-handoff/v1', 'schema: repo-automation-slice-handoff/v2', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "invalid-schema" "invalid schema" "set schema: repo-automation-slice-handoff/v1" --file="$invalid_schema_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$missing_branch_file" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding='utf-8').splitlines()
filtered = [line for line in source if not line.startswith('branch: ')]
Path(sys.argv[2]).write_text('\n'.join(filtered) + '\n', encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "missing-branch" "missing branch" "set a non-empty branch in the envelope" --file="$missing_branch_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$invalid_branch_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('branch: feature/slice-handoff-smoke', 'branch: -bad branch', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "invalid-branch" "invalid branch: -bad branch" "use a conservative feature branch name without whitespace or shell metacharacters" --file="$invalid_branch_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$invalid_profile_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('codex_profile: default', 'codex_profile: ../profile', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "invalid-profile" "invalid codex_profile: ../profile" "use one of default, lean, medium, high, repair, or review" --file="$invalid_profile_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_submit_file" "$missing_commit_file" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding='utf-8').splitlines()
filtered = [line for line in source if not line.startswith('commit_message: ')]
Path(sys.argv[2]).write_text('\n'.join(filtered) + '\n', encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "missing-commit-message" "missing commit_message" "set commit_message when submit_mode is repo-flow-submit-all" --file="$missing_commit_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_submit_file" "$missing_pr_body_file" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding='utf-8').splitlines()
filtered = []
skip = False
for line in source:
    if line == '## PR Body':
        skip = True
        continue
    if skip:
        continue
    filtered.append(line)
Path(sys.argv[2]).write_text('\n'.join(filtered) + '\n', encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "missing-pr-body" "missing ## PR Body" "add ## PR Body when submit_mode is repo-flow-submit-all" --file="$missing_pr_body_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$empty_review_request_file" <<'PY'
from pathlib import Path
import sys

Path(sys.argv[1]).write_text(
    """schema: repo-automation-slice-handoff/v1
branch: feature/slice-handoff-smoke
title: Slice handoff smoke
codex_profile: default
submit_mode: none

# Slice Handoff

## Codex Prompt
Implement the slice exactly as specified.

## PR Review Request
""",
    encoding='utf-8',
)
PY
  ) && smoke_slice_handoff_expect_failure "empty-review-request" "missing PR Review Request payload" "add text under ## PR Review Request" --file="$empty_review_request_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$placeholder_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('Implement the slice exactly as specified.', 'Use previous chat and do the rest.', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "placeholder-reject" "unsafe placeholder text in Codex Prompt: use previous chat" "replace the placeholder prompt with concrete slice instructions" --file="$placeholder_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$lifecycle_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('Implement the slice exactly as specified.', 'Please create a PR and merge it after checkout.', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "lifecycle-reject" "Codex Prompt contains lifecycle instruction: create a pr" "remove execution and workflow instructions from the prompt" --file="$lifecycle_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$lifecycle_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('Implement the slice exactly as specified.', 'Merge this.', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "lifecycle-merge-this" "Codex Prompt contains lifecycle instruction: merge" "remove execution and workflow instructions from the prompt" --file="$lifecycle_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$lifecycle_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('Implement the slice exactly as specified.', 'Merge the PR.', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "lifecycle-merge-pr" "Codex Prompt contains lifecycle instruction: merge" "remove execution and workflow instructions from the prompt" --file="$lifecycle_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$lifecycle_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('Implement the slice exactly as specified.', 'Merge after CI passes.', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "lifecycle-merge-after-ci" "Codex Prompt contains lifecycle instruction: merge" "remove execution and workflow instructions from the prompt" --file="$lifecycle_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$lifecycle_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('Implement the slice exactly as specified.', 'Run repo-flow submit.', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "lifecycle-run-submit" "Codex Prompt contains lifecycle instruction: repo-flow submit" "remove execution and workflow instructions from the prompt" --file="$lifecycle_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$lifecycle_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('Implement the slice exactly as specified.', 'Branch: feature/foo', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "lifecycle-branch" "Codex Prompt contains lifecycle instruction: branch:" "remove execution and workflow instructions from the prompt" --file="$lifecycle_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$lifecycle_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('Implement the slice exactly as specified.', 'Checkout main.', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "lifecycle-checkout" "Codex Prompt contains lifecycle instruction: checkout" "remove execution and workflow instructions from the prompt" --file="$lifecycle_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$lifecycle_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('Implement the slice exactly as specified.', 'Checkout feature/foo.', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "lifecycle-checkout-feature" "Codex Prompt contains lifecycle instruction: checkout" "remove execution and workflow instructions from the prompt" --file="$lifecycle_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$lifecycle_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('Implement the slice exactly as specified.', 'git checkout main', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "lifecycle-git-checkout" "Codex Prompt contains lifecycle instruction: checkout" "remove execution and workflow instructions from the prompt" --file="$lifecycle_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$lifecycle_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('Implement the slice exactly as specified.', 'repo-flow submit --all', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_failure "lifecycle-submit-all" "Codex Prompt contains lifecycle instruction: repo-flow submit" "remove execution and workflow instructions from the prompt" --file="$lifecycle_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$lifecycle_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('Implement the slice exactly as specified.', '- Do not merge.', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_success "lifecycle-negate-merge" "pass" "" --file="$lifecycle_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$lifecycle_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('Implement the slice exactly as specified.', '- Do not create a PR.', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_success "lifecycle-negate-create" "pass" "" --file="$lifecycle_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$lifecycle_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('Implement the slice exactly as specified.', '- Do not run repo-flow submit.', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_success "lifecycle-negate-run-submit" "pass" "" --file="$lifecycle_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    python3 - "$valid_none_file" "$lifecycle_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding='utf-8').replace('Implement the slice exactly as specified.', '- Do not checkout branches.', 1)
Path(sys.argv[2]).write_text(text, encoding='utf-8')
PY
  ) && smoke_slice_handoff_expect_success "lifecycle-negate-checkout" "pass" "" --file="$lifecycle_file" --dry-run; then
    :
  else
    status=1
  fi

  if (
    rm -rf -- "$invalid_out_dir" &&
      smoke_slice_handoff_expect_failure "out-dir-validation-fail" "unsafe placeholder text in Codex Prompt: use previous chat" "replace the placeholder prompt with concrete slice instructions" --file="$placeholder_file" --dry-run --out-dir="$invalid_out_dir" &&
      [ ! -e "$invalid_out_dir" ]
  ); then
    :
  else
    test_fail "out-dir-validation-fail artifacts"
    status=1
  fi

  return "$status"
}

smoke_main "$@"
# repo-automation/tests/contracts/slice-handoff.sh EOF
