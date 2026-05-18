#!/usr/bin/env bash
# repo-automation/tests/contracts/pr-finish-watch.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/contracts/pr-workflow.sh"

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

smoke_write_pr_finish_ssh_stub() {
  local ssh_stub_dir="$1"

  mkdir -p "$ssh_stub_dir" || return 1
  cat > "$ssh_stub_dir/ssh" <<'EOF'
#!/usr/bin/env bash
set -u
if [ "${1:-}" = "-G" ]; then
  case "${2:-}" in
    github-alias)
      printf 'hostname github.com\n'
      ;;
    gitlab-alias)
      printf 'hostname gitlab.com\n'
      ;;
    *)
      printf 'hostname example.com\n'
      ;;
  esac
  exit 0
fi
printf 'ssh stub unexpected args\n' >&2
exit 1
EOF
  chmod +x "$ssh_stub_dir/ssh" || return 1
}

smoke_check_pr_finish_merge_alias_remote() {
  local status=0
  # shellcheck disable=SC2154 # smoke_test_dir is provided by the smoke harness.
  local gh_stub_dir="$smoke_test_dir/gh-stub"
  local git_stub_dir="$smoke_test_dir/git-stub"
  local ssh_stub_dir="$smoke_test_dir/ssh-stub"
  local stderr_file="$smoke_test_dir/pr-finish-merge-alias.stderr"
  local git_log_file="$smoke_test_dir/pr-finish-merge-alias.git-log"
  local merge_log_file="$smoke_test_dir/pr-finish-merge-alias.gh-log"
  local rejected_stderr="$smoke_test_dir/pr-finish-merge-alias-rejected.stderr"
  local local_bash_path=""
  local real_git=""

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1
  smoke_write_gh_stub "$gh_stub_dir" || return 1
  smoke_write_git_sync_stub "$git_stub_dir" "$git_log_file" >/dev/null || return 1
  smoke_write_pr_finish_ssh_stub "$ssh_stub_dir" || return 1
  local_bash_path="$(command -v bash)" || return 1
  real_git="$(command -v git)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    git checkout -b feature/finish-alias >/dev/null || return 1
    git remote set-url origin 'git@github-alias:i-schuyler/repo-automation-template.git' >/dev/null 2>&1 || return 1
    PATH="$ssh_stub_dir:$git_stub_dir:$gh_stub_dir:$PATH" \
    SMOKE_REAL_GIT="$real_git" \
    SMOKE_GIT_LOG_FILE="$git_log_file" \
    GH_STUB_PR_VIEW_NUMBER=86 \
    GH_STUB_PR_VIEW_TITLE='alias finish title' \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/86' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_IS_DRAFT='false' \
    GH_STUB_PR_VIEW_MERGEABLE='MERGEABLE' \
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pass","state":"SUCCESS","workflow":"ci"}]' \
    GH_STUB_PR_MERGE_LOG_FILE="$merge_log_file" \
    "$local_bash_path" repo-automation/bin/pr-finish --merge --delete-branch --sync-main --pr=86 > /dev/null 2> "$stderr_file"
  ) && grep -Fq 'git checkout main' "$git_log_file" &&
    grep -Fq 'git pull --ff-only' "$git_log_file" &&
    grep -Fq -- '--delete-branch' "$merge_log_file"; then
    test_pass "pr-finish merge accepts a GitHub SSH alias"
  else
    test_fail "pr-finish merge accepts a GitHub SSH alias"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    git remote set-url origin 'git@gitlab-alias:i-schuyler/repo-automation-template.git' >/dev/null 2>&1 || return 1
    PATH="$ssh_stub_dir:$git_stub_dir:$gh_stub_dir:$PATH" \
    SMOKE_REAL_GIT="$real_git" \
    SMOKE_GIT_LOG_FILE="$git_log_file" \
    GH_STUB_PR_VIEW_NUMBER=86 \
    GH_STUB_PR_VIEW_TITLE='alias finish title' \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/86' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_IS_DRAFT='false' \
    GH_STUB_PR_VIEW_MERGEABLE='MERGEABLE' \
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pass","state":"SUCCESS","workflow":"ci"}]' \
    "$local_bash_path" repo-automation/bin/pr-finish --status --pr=86 > /dev/null 2> "$rejected_stderr"
  ); then
    test_fail "pr-finish rejects a non-GitHub SSH alias"
    status=1
  elif grep -Fq 'STOP: remote URL mismatch for origin:' "$rejected_stderr" &&
    grep -Fq 'git@gitlab-alias:i-schuyler/repo-automation-template.git' "$rejected_stderr"; then
    test_pass "pr-finish rejects a non-GitHub SSH alias"
  else
    test_fail "pr-finish rejects a non-GitHub SSH alias"
    status=1
  fi

  return "$status"
}

smoke_main() {
  local status=0

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1

  smoke_run_named_check "smoke:pr-finish-watch-exit" smoke_check_pr_finish_watch_exit || status=1
  smoke_run_named_check "smoke:pr-finish-merge-alias-remote" smoke_check_pr_finish_merge_alias_remote || status=1

  return "$status"
}

smoke_main "$@"
# repo-automation/tests/contracts/pr-finish-watch.sh EOF
