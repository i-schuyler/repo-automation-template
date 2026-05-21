#!/usr/bin/env bash
# repo-automation/tests/contracts/pr-finish-extensions.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"

smoke_write_git_sync_stub() {
  local git_stub_dir="$1"
  local git_log_file="$2"

  mkdir -p "$git_stub_dir" || return 1
  cat > "$git_stub_dir/git" <<'EOF'
#!/usr/bin/env bash
set -u
case "${1:-}" in
  checkout|pull)
    if [ -n "${SMOKE_GIT_LOG_FILE:-}" ]; then
      printf '%s\n' "git $*" >> "$SMOKE_GIT_LOG_FILE"
    fi
    exit 0
    ;;
esac
exec "${SMOKE_REAL_GIT:?missing SMOKE_REAL_GIT}" "$@"
EOF
  chmod +x "$git_stub_dir/git" || return 1
  printf '%s\n' "$git_log_file"
}

smoke_check_pr_finish_watch_latest() {
  local status=0
  # shellcheck disable=SC2154 # smoke_test_dir is provided by the smoke harness.
  local gh_stub_dir="$smoke_test_dir/gh-stub"
  local git_stub_dir="$smoke_test_dir/git-stub"
  local stderr_file="$smoke_test_dir/pr-finish-watch-latest.stderr"
  local git_log_file="$smoke_test_dir/pr-finish-watch-latest.git-log"
  local local_bash_path=""
  local real_git=""

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1
  smoke_write_gh_stub "$gh_stub_dir" || return 1
  smoke_write_git_sync_stub "$git_stub_dir" "$git_log_file" >/dev/null || return 1
  local_bash_path="$(command -v bash)" || return 1
  real_git="$(command -v git)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$git_stub_dir:$gh_stub_dir:$PATH" \
    SMOKE_REAL_GIT="$real_git" \
    SMOKE_GIT_LOG_FILE="$git_log_file" \
    GH_STUB_PR_LIST_NUMBER=901 \
    GH_STUB_PR_LIST_JSON='[{"number":901}]' \
    GH_STUB_PR_VIEW_TITLE='watch latest title' \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/901' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_IS_DRAFT='false' \
    GH_STUB_PR_VIEW_MERGEABLE='MERGEABLE' \
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-901' \
    GH_STUB_PR_VIEW_HEAD_REF='feature/watch-latest' \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":901,"conclusion":"success","createdAt":"2026-05-12T10:00:00Z","event":"pull_request","headBranch":"feature/watch-latest","headSha":"current-sha-901","status":"completed","workflowName":"ci"}]' \
    "$local_bash_path" repo-automation/bin/pr-finish --watch --pr=latest --explain > /dev/null 2> "$stderr_file"
  ); then
    if grep -q 'mode: watch' "$stderr_file"; then
      test_pass "pr-finish watch selects latest PR without syncing main"
    else
      test_fail "pr-finish watch selects latest PR without syncing main"
      status=1
    fi
  else
    test_fail "pr-finish watch selects latest PR without syncing main"
    status=1
  fi

  return "$status"
}

smoke_check_pr_finish_status_current() {
  local status=0
  local gh_stub_dir="$smoke_test_dir/gh-stub"
  local git_stub_dir="$smoke_test_dir/git-stub"
  local stderr_file="$smoke_test_dir/pr-finish-status-current.stderr"
  local git_log_file="$smoke_test_dir/pr-finish-status-current.git-log"
  local local_bash_path=""
  local real_git=""

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1
  smoke_write_gh_stub "$gh_stub_dir" || return 1
  smoke_write_git_sync_stub "$git_stub_dir" "$git_log_file" >/dev/null || return 1
  local_bash_path="$(command -v bash)" || return 1
  real_git="$(command -v git)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    git checkout -b feature/current-status >/dev/null || return 1
    PATH="$git_stub_dir:$gh_stub_dir:$PATH" \
    SMOKE_REAL_GIT="$real_git" \
    SMOKE_GIT_LOG_FILE="$git_log_file" \
    GH_STUB_PR_VIEW_NUMBER=654 \
    GH_STUB_PR_VIEW_TITLE='current title' \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/654' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_IS_DRAFT='false' \
    GH_STUB_PR_VIEW_MERGEABLE='MERGEABLE' \
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-654' \
    GH_STUB_PR_VIEW_HEAD_REF='feature/current-status' \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":654,"conclusion":"success","createdAt":"2026-05-12T10:00:00Z","event":"pull_request","headBranch":"feature/current-status","headSha":"current-sha-654","status":"completed","workflowName":"ci"}]' \
    "$local_bash_path" repo-automation/bin/pr-finish --status --pr=current --explain > /dev/null 2> "$stderr_file"
  ); then
    if grep -q 'mode: status' "$stderr_file" &&
      grep -q 'pr: #654 current title' "$stderr_file" &&
      [ ! -s "$git_log_file" ]; then
      test_pass "pr-finish status selects the current branch PR without syncing main"
    else
      test_fail "pr-finish status selects the current branch PR without syncing main"
      status=1
    fi
  else
    test_fail "pr-finish status selects the current branch PR without syncing main"
    status=1
  fi

  return "$status"
}

smoke_check_pr_finish_pr_flag_shapes() {
  local status=0
  local help_file="$smoke_test_dir/pr-finish-help.txt"
  local stale_stderr="$smoke_test_dir/pr-finish-pr-stale.stderr"
  local missing_stderr="$smoke_test_dir/pr-finish-pr-missing.stderr"
  local empty_stderr="$smoke_test_dir/pr-finish-pr-empty.stderr"
  local unknown_stderr="$smoke_test_dir/pr-finish-unknown.stderr"
  local local_bash_path=""

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154
  smoke_write_gh_stub "$smoke_test_base/gh-stub" || return 1
  local_bash_path="$(command -v bash)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/pr-finish --help > "$help_file"
  ) && grep -Fq -- '--pr=<number|current|latest>' "$help_file" && grep -Fq -- '--timeout=<seconds>' "$help_file" && ! grep -Fq -- '--pr NUMBER' "$help_file"; then
    test_pass "pr-finish help shows strict pr syntax"
  else
    test_fail "pr-finish help shows strict pr syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$smoke_test_base/gh-stub:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --status --pr 123 >/dev/null 2> "$stale_stderr"
  ); then
    test_fail "pr-finish rejects --pr <value>"
    status=1
  elif smoke_assert_flag_error_shape "$stale_stderr" "flag format not accepted" "--pr" "use --pr=<number|current|latest>"; then
    test_pass "pr-finish rejects --pr <value>"
  else
    test_fail "pr-finish rejects --pr <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$smoke_test_base/gh-stub:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --status --pr >/dev/null 2> "$missing_stderr"
  ); then
    test_fail "pr-finish rejects missing --pr value"
    status=1
  elif smoke_assert_flag_error_shape "$missing_stderr" "missing flag value" "--pr" "use --pr=<number|current|latest>"; then
    test_pass "pr-finish rejects missing --pr value"
  else
    test_fail "pr-finish rejects missing --pr value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$smoke_test_base/gh-stub:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --status --pr= >/dev/null 2> "$empty_stderr"
  ); then
    test_fail "pr-finish rejects empty --pr value"
    status=1
  elif smoke_assert_flag_error_shape "$empty_stderr" "empty flag value" "--pr" "use --pr=<number|current|latest>"; then
    test_pass "pr-finish rejects empty --pr value"
  else
    test_fail "pr-finish rejects empty --pr value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$smoke_test_base/gh-stub:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --status --whatever >/dev/null 2> "$unknown_stderr"
  ); then
    test_fail "pr-finish rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/pr-finish --help"; then
    test_pass "pr-finish rejects unknown flags"
  else
    test_fail "pr-finish rejects unknown flags"
    status=1
  fi

  return "$status"
}

smoke_check_pr_finish_merge_current_sync_main() {
  local status=0
  local gh_stub_dir="$smoke_test_dir/gh-stub"
  local git_stub_dir="$smoke_test_dir/git-stub"
  local stderr_file="$smoke_test_dir/pr-finish-merge-current-sync.stderr"
  local git_log_file="$smoke_test_dir/pr-finish-merge-current-sync.git-log"
  local merge_log_file="$smoke_test_dir/pr-finish-merge-current-sync.gh-log"
  local local_bash_path=""
  local real_git=""

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1
  smoke_write_gh_stub "$gh_stub_dir" || return 1
  smoke_write_git_sync_stub "$git_stub_dir" "$git_log_file" >/dev/null || return 1
  local_bash_path="$(command -v bash)" || return 1
  real_git="$(command -v git)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    git checkout -b feature/current-sync >/dev/null || return 1
    PATH="$git_stub_dir:$gh_stub_dir:$PATH" \
    SMOKE_REAL_GIT="$real_git" \
    SMOKE_GIT_LOG_FILE="$git_log_file" \
    GH_STUB_PR_VIEW_NUMBER=655 \
    GH_STUB_PR_VIEW_TITLE='current sync title' \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/655' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_IS_DRAFT='false' \
    GH_STUB_PR_VIEW_MERGEABLE='MERGEABLE' \
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-655' \
    GH_STUB_PR_VIEW_HEAD_REF='feature/current-sync' \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":655,"conclusion":"success","createdAt":"2026-05-12T10:00:00Z","event":"pull_request","headBranch":"feature/current-sync","headSha":"current-sha-655","status":"completed","workflowName":"ci"}]' \
    GH_STUB_PR_MERGE_LOG_FILE="$merge_log_file" \
    "$local_bash_path" repo-automation/bin/pr-finish --merge --pr=current --sync-main --delete-branch --explain > /dev/null 2> "$stderr_file"
  ); then
    if grep -q 'merge completed for PR #655' "$stderr_file" &&
      grep -q 'synced main with git pull --ff-only' "$stderr_file" &&
      grep -q 'git checkout main' "$git_log_file" &&
      grep -q 'git pull --ff-only' "$git_log_file" &&
      grep -q -- '--delete-branch' "$merge_log_file"; then
      test_pass "pr-finish merge syncs main after a current-branch merge"
    else
      test_fail "pr-finish merge syncs main after a current-branch merge"
      status=1
    fi
  else
    test_fail "pr-finish merge syncs main after a current-branch merge"
    status=1
  fi

  return "$status"
}

smoke_check_pr_finish_state_file_and_watch_reuse() {
  local status=0
  local gh_stub_dir="$smoke_test_dir/gh-stub"
  local git_stub_dir="$smoke_test_dir/git-stub"
  local stderr_file="$smoke_test_dir/pr-finish-state-file.stderr"
  local git_log_file="$smoke_test_dir/pr-finish-state-file.git-log"
  local run_list_log_file="$smoke_test_dir/pr-finish-state-file.run-list.log"
  local state_file="$smoke_test_dir/pr-finish-state-file.state"
  local local_bash_path=""
  local real_git=""

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1
  smoke_write_gh_stub "$gh_stub_dir" || return 1
  smoke_write_git_sync_stub "$git_stub_dir" "$git_log_file" >/dev/null || return 1
  local_bash_path="$(command -v bash)" || return 1
  real_git="$(command -v git)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    git checkout -b feature/state-file-reuse >/dev/null || return 1
    PATH="$git_stub_dir:$gh_stub_dir:$PATH" \
    SMOKE_REAL_GIT="$real_git" \
    SMOKE_GIT_LOG_FILE="$git_log_file" \
    GH_STUB_PR_VIEW_NUMBER=655 \
    GH_STUB_PR_VIEW_TITLE='state file title' \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/655' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_IS_DRAFT='false' \
    GH_STUB_PR_VIEW_MERGEABLE='MERGEABLE' \
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-655' \
    GH_STUB_PR_VIEW_HEAD_REF='feature/state-file-reuse' \
    GH_STUB_PR_MERGE_LOG_FILE="$smoke_test_base/pr-finish-state-file.gh-log" \
    GH_STUB_PR_MERGE_UPDATE_MAIN=1 \
    GH_STUB_RUN_LIST_LOG_FILE="$run_list_log_file" \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":655,"conclusion":"success","createdAt":"2026-05-12T10:00:00Z","event":"pull_request","headBranch":"feature/state-file-reuse","headSha":"current-sha-655","status":"completed","workflowName":"ci"}]' \
    PR_FINISH_STATE_FILE="$state_file" \
    "$local_bash_path" repo-automation/bin/pr-finish --watch --merge --pr=current --sync-main --delete-branch --explain > /dev/null 2> "$stderr_file"
  ); then
    if grep -Fq 'timing: pr_lookup=' "$stderr_file" &&
      grep -Fxq 'pr_number=655' "$state_file" &&
      grep -Fxq 'pr_url=https://github.com/i-schuyler/repo-automation-template/pull/655' "$state_file" &&
      grep -Fxq 'checks_status=green' "$state_file" &&
      grep -Fxq 'action_taken=merged' "$state_file" &&
      grep -Fxq 'head_sha=current-sha-655' "$state_file" &&
      grep -Fxq 'merged=true' "$state_file" &&
      grep -Eq '^elapsed_seconds=[0-9]+$' "$state_file" &&
      grep -Eq '^timing_pr_lookup_seconds=[0-9]+$' "$state_file" &&
      grep -Eq '^timing_ci_watch_seconds=[0-9]+$' "$state_file" &&
      grep -Eq '^timing_checks_reuse_seconds=[0-9]+$' "$state_file" &&
      grep -Eq '^timing_merge_seconds=[0-9]+$' "$state_file" &&
      grep -Eq '^timing_sync_main_seconds=[0-9]+$' "$state_file" &&
      [ "$(grep -Fc 'gh run list ' "$run_list_log_file" 2>/dev/null || printf '0')" = "1" ]; then
      test_pass "pr-finish writes state file and reuses watch green status"
    else
      test_fail "pr-finish writes state file and reuses watch green status"
      status=1
    fi
  else
    test_fail "pr-finish writes state file and reuses watch green status"
    status=1
  fi

  return "$status"
}

smoke_check_pr_finish_merge_gate_failures() {
  local status=0
  local gh_stub_dir="$smoke_test_dir/gh-stub"
  local local_bash_path=""
  local pending_stderr="$smoke_test_dir/pr-finish-pending.stderr"
  local failed_stderr="$smoke_test_dir/pr-finish-failed.stderr"
  local dirty_stderr="$smoke_test_dir/pr-finish-dirty.stderr"

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1
  smoke_write_gh_stub "$gh_stub_dir" || return 1
  local_bash_path="$(command -v bash)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_VIEW_NUMBER=889 \
    GH_STUB_PR_VIEW_TITLE='pending title' \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/889' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_IS_DRAFT='false' \
    GH_STUB_PR_VIEW_MERGEABLE='MERGEABLE' \
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-889' \
    GH_STUB_PR_VIEW_HEAD_REF='feature/pending-checks' \
    GH_STUB_RUN_LIST_JSON='[]' \
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --merge --pr=889 >/dev/null 2> "$pending_stderr"
  ); then
    test_fail "pr-finish blocks pending checks"
    status=1
  elif grep -Fq 'checks-pending' "$pending_stderr" &&
    grep -Fq 'merge blocked by current PR state/check gates' "$pending_stderr"; then
    test_pass "pr-finish blocks pending checks"
  else
    test_fail "pr-finish blocks pending checks"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_VIEW_NUMBER=890 \
    GH_STUB_PR_VIEW_TITLE='failed title' \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/890' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_IS_DRAFT='false' \
    GH_STUB_PR_VIEW_MERGEABLE='MERGEABLE' \
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-890' \
    GH_STUB_PR_VIEW_HEAD_REF='feature/failed-checks' \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":890,"conclusion":"failure","createdAt":"2026-05-12T11:00:00Z","event":"pull_request","headBranch":"feature/failed-checks","headSha":"current-sha-890","status":"completed","workflowName":"ci"}]' \
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --merge --pr=890 >/dev/null 2> "$failed_stderr"
  ); then
    test_fail "pr-finish blocks failed checks"
    status=1
  elif grep -Fq 'merge blocked by current PR state/check gates' "$failed_stderr" &&
    grep -Eq 'checks-(failed|blocked|unknown)' "$failed_stderr"; then
    test_pass "pr-finish blocks failed checks"
  else
    test_fail "pr-finish blocks failed checks"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    git checkout -b feature/dirty-worktree >/dev/null || return 1
    printf 'dirty\n' >> repo-automation/tests/dirty-worktree.txt || return 1
    GH_STUB_PR_VIEW_NUMBER=891 \
    GH_STUB_PR_VIEW_TITLE='dirty title' \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/891' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_IS_DRAFT='false' \
    GH_STUB_PR_VIEW_MERGEABLE='MERGEABLE' \
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-891' \
    GH_STUB_PR_VIEW_HEAD_REF='feature/dirty-worktree' \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":891,"conclusion":"success","createdAt":"2026-05-12T12:00:00Z","event":"pull_request","headBranch":"feature/dirty-worktree","headSha":"current-sha-891","status":"completed","workflowName":"ci"}]' \
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --merge --pr=891 >/dev/null 2> "$dirty_stderr"
  ); then
    test_fail "pr-finish blocks dirty worktree"
    status=1
  elif grep -Fq 'merge blocked by current PR state/check gates' "$dirty_stderr"; then
    test_pass "pr-finish blocks dirty worktree"
  else
    test_fail "pr-finish blocks dirty worktree"
    status=1
  fi

  return "$status"
}

smoke_check_pr_finish_merge_failure_skips_sync_main() {
  local status=0
  local gh_stub_dir="$smoke_test_dir/gh-stub"
  local git_stub_dir="$smoke_test_dir/git-stub"
  local stderr_file="$smoke_test_dir/pr-finish-merge-failure.stderr"
  local git_log_file="$smoke_test_dir/pr-finish-merge-failure.git-log"
  local merge_log_file="$smoke_test_dir/pr-finish-merge-failure.gh-log"
  local local_bash_path=""
  local real_git=""

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1
  smoke_write_gh_stub "$gh_stub_dir" || return 1
  smoke_write_git_sync_stub "$git_stub_dir" "$git_log_file" >/dev/null || return 1
  local_bash_path="$(command -v bash)" || return 1
  real_git="$(command -v git)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    git checkout -b feature/current-failure >/dev/null || return 1
    PATH="$git_stub_dir:$gh_stub_dir:$PATH" \
    SMOKE_REAL_GIT="$real_git" \
    SMOKE_GIT_LOG_FILE="$git_log_file" \
    GH_STUB_PR_VIEW_NUMBER=777 \
    GH_STUB_PR_VIEW_TITLE='failure title' \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/777' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_IS_DRAFT='false' \
    GH_STUB_PR_VIEW_MERGEABLE='MERGEABLE' \
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-777' \
    GH_STUB_PR_VIEW_HEAD_REF='feature/current-failure' \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":777,"conclusion":"success","createdAt":"2026-05-12T10:00:00Z","event":"pull_request","headBranch":"feature/current-failure","headSha":"current-sha-777","status":"completed","workflowName":"ci"}]' \
    GH_STUB_PR_MERGE_LOG_FILE="$merge_log_file" \
    GH_STUB_PR_MERGE_EXIT=1 \
    GH_STUB_PR_MERGE_ERROR='merge boom' \
    "$local_bash_path" repo-automation/bin/pr-finish --merge --pr=777 --sync-main > /dev/null 2> "$stderr_file"
  ); then
    test_fail "pr-finish merge failure skips sync-main"
    status=1
  else
    if grep -q 'gh pr merge failed: merge boom' "$stderr_file" &&
      [ ! -s "$git_log_file" ] &&
      grep -q 'gh pr merge 777' "$merge_log_file"; then
      test_pass "pr-finish merge failure skips sync-main"
    else
      test_fail "pr-finish merge failure skips sync-main"
      status=1
    fi
  fi

  return "$status"
}

smoke_check_pr_finish_merge_blocks_until_current_head() {
  local status=0
  local gh_stub_dir="$smoke_test_dir/gh-stub"
  local merge_log_file="$smoke_test_dir/pr-finish-merge-blocked.gh-log"
  local stderr_file="$smoke_test_dir/pr-finish-merge-blocked.stderr"
  local local_bash_path=""

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1
  smoke_write_gh_stub "$gh_stub_dir" || return 1
  local_bash_path="$(command -v bash)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    GH_STUB_PR_VIEW_NUMBER=888 \
    GH_STUB_PR_VIEW_TITLE='merge blocked title' \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/888' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_IS_DRAFT='false' \
    GH_STUB_PR_VIEW_MERGEABLE='MERGEABLE' \
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-888' \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":900,"conclusion":"failure","createdAt":"2026-05-12T11:00:00Z","event":"pull_request","headBranch":"feature/demo","headSha":"old-sha-888","status":"completed","workflowName":"ci"}]' \
    GH_STUB_PR_MERGE_LOG_FILE="$merge_log_file" \
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/pr-finish --merge --pr=888 >/dev/null 2> "$stderr_file"
  ); then
    test_fail "pr-finish merge blocks until current head checks exist"
    status=1
  elif grep -q 'merge blocked by current PR state/check gates' "$stderr_file" &&
    grep -q 'checks-pending' "$stderr_file" &&
    [ ! -s "$merge_log_file" ]; then
    test_pass "pr-finish merge blocks until current head checks exist"
  else
    test_fail "pr-finish merge blocks until current head checks exist"
    status=1
  fi

  return "$status"
}

smoke_main() {
  local status=0

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1

  smoke_run_named_check "smoke:pr-finish-watch-latest" smoke_check_pr_finish_watch_latest || status=1
  smoke_run_named_check "smoke:pr-finish-status-current" smoke_check_pr_finish_status_current || status=1
  smoke_run_named_check "smoke:pr-finish-pr-flag-shapes" smoke_check_pr_finish_pr_flag_shapes || status=1
  smoke_run_named_check "smoke:pr-finish-merge-current-sync-main" smoke_check_pr_finish_merge_current_sync_main || status=1
  smoke_run_named_check "smoke:pr-finish-state-file-and-reuse" smoke_check_pr_finish_state_file_and_watch_reuse || status=1
  smoke_run_named_check "smoke:pr-finish-merge-gate-failures" smoke_check_pr_finish_merge_gate_failures || status=1
  smoke_run_named_check "smoke:pr-finish-merge-failure-skips-sync-main" smoke_check_pr_finish_merge_failure_skips_sync_main || status=1
  smoke_run_named_check "smoke:pr-finish-merge-blocks-until-current-head" smoke_check_pr_finish_merge_blocks_until_current_head || status=1

  return "$status"
}

smoke_main "$@"
# repo-automation/tests/contracts/pr-finish-extensions.sh EOF
