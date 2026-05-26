#!/usr/bin/env bash
# repo-automation/lib/repo-flow-main-preflight.sh

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh" || {
  printf 'STOP: failed to source shared library\n' >&2
  return 2 2>/dev/null || exit 2
}

# shellcheck disable=SC2154
repo_flow_main_preflight() {
  repo_auto_require_command git || {
    repo_flow_stop "git is required"
    command_status=1
  }

  if [ "$command_status" -eq 0 ]; then
    repo_root=$(repo_auto_repo_root) || {
      repo_flow_stop "failed to determine repo root"
      command_status=1
    }
  fi

  if [ "$command_status" -eq 0 ]; then
    cd "$repo_root" || {
      repo_flow_stop "failed to enter repo root: $repo_root"
      command_status=1
    }
  fi

  if [ "$command_status" -eq 0 ]; then
    repo_auto_load_config || {
      repo_flow_stop "failed to load .repo-automation.conf"
      command_status=1
    }
  fi

  if [ "$command_status" -eq 0 ]; then
    repo_auto_validate_required_config || {
      repo_flow_stop "invalid .repo-automation.conf"
      command_status=1
    }
  fi

  if [ "$command_status" -eq 0 ]; then
    default_branch="${DEFAULT_BRANCH:-main}"
    remote_name="${REMOTE_NAME:-origin}"
    expected_remote_url="${EXPECTED_REMOTE_URL:-}"
  fi

  if [ "$command_status" -eq 0 ] && [ "${PR_PROVIDER:-none}" != "github" ]; then
    repo_flow_stop "PR_PROVIDER must be github for repo-automation/bin/repo-flow"
    command_status=1
  fi

  if [ "$command_status" -eq 0 ]; then
    repo_auto_require_command gh || {
      repo_flow_stop "gh is required for repo-flow"
      command_status=1
    }
  fi

  if [ "$command_status" -eq 0 ]; then
    remote_url=$(git remote get-url "$remote_name" 2>/dev/null) || {
      repo_flow_stop "failed to read remote URL for $remote_name"
      command_status=1
    }
  fi

  if [ "$command_status" -eq 0 ] && ! repo_auto_remote_matches_upstream "$remote_url" "$expected_remote_url" "${UPSTREAM_REPO_FULL_NAME:-}"; then
    repo_flow_stop "remote URL mismatch for $remote_name: expected $expected_remote_url or GitHub SSH alias for ${UPSTREAM_REPO_FULL_NAME:-unknown}, got $remote_url"
    command_status=1
  fi

  if [ "$command_status" -eq 0 ]; then
    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || {
      repo_flow_stop "failed to determine current branch"
      command_status=1
    }
  fi

  if [ "$command_status" -eq 0 ]; then
    repo_auto_validate_branch_name "$current_branch" || {
      repo_flow_stop "invalid current branch name: $current_branch"
      command_status=1
    }
  fi

  if [ "$command_status" -eq 0 ] && [ "$current_branch" = "$default_branch" ]; then
    repo_flow_stop "current branch is default branch; checkout a feature branch"
    command_status=1
  fi

  if [ "$command_status" -eq 0 ]; then
    worktree_status=$(git status --porcelain)
    if [ -n "$worktree_status" ]; then
      repo_flow_stop "working tree must be clean for repo-flow"
      command_status=1
    fi
  fi

  if [ "$command_status" -eq 0 ]; then
    repo_flow_info "branch status: current=$current_branch default=$default_branch worktree=clean"
    repo_flow_info "ahead/behind: ahead=$ahead_count behind=$behind_count vs $remote_name/$default_branch"
  fi

  return "$command_status"
}

# repo-automation/lib/repo-flow-main-preflight.sh EOF
