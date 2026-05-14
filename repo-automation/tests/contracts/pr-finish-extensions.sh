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
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pass","state":"SUCCESS","workflow":"ci"}]' \
    "$local_bash_path" repo-automation/bin/pr-finish --watch --pr=latest > /dev/null 2> "$stderr_file"
  ); then
    if grep -q 'mode: watch' "$stderr_file" &&
      grep -q 'pr: #901 watch latest title' "$stderr_file" &&
      [ ! -s "$git_log_file" ]; then
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
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pass","state":"SUCCESS","workflow":"ci"}]' \
    "$local_bash_path" repo-automation/bin/pr-finish --status --pr=current > /dev/null 2> "$stderr_file"
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
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pass","state":"SUCCESS","workflow":"ci"}]' \
    GH_STUB_PR_MERGE_LOG_FILE="$merge_log_file" \
    "$local_bash_path" repo-automation/bin/pr-finish --merge --pr=current --sync-main --delete-branch > /dev/null 2> "$stderr_file"
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
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pass","state":"SUCCESS","workflow":"ci"}]' \
    GH_STUB_PR_MERGE_LOG_FILE="$merge_log_file" \
    GH_STUB_PR_MERGE_EXIT=1 \
    GH_STUB_PR_MERGE_ERROR='merge boom' \
    "$local_bash_path" repo-automation/bin/pr-finish --merge --pr 777 --sync-main > /dev/null 2> "$stderr_file"
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

smoke_main() {
  local status=0

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1

  smoke_run_named_check "smoke:pr-finish-watch-latest" smoke_check_pr_finish_watch_latest || status=1
  smoke_run_named_check "smoke:pr-finish-status-current" smoke_check_pr_finish_status_current || status=1
  smoke_run_named_check "smoke:pr-finish-merge-current-sync-main" smoke_check_pr_finish_merge_current_sync_main || status=1
  smoke_run_named_check "smoke:pr-finish-merge-failure-skips-sync-main" smoke_check_pr_finish_merge_failure_skips_sync_main || status=1

  return "$status"
}

smoke_main "$@"
# repo-automation/tests/contracts/pr-finish-extensions.sh EOF
