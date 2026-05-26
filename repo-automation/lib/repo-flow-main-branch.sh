#!/usr/bin/env bash
# repo-automation/lib/repo-flow-main-branch.sh

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh" || {
  printf 'STOP: failed to source shared library\n' >&2
  return 2 2>/dev/null || exit 2
}

# shellcheck disable=SC2034,SC2154
repo_flow_main_branch() {
  if [ "$command_status" -eq 0 ]; then
    branch_ahead_behind=$(git rev-list --left-right --count "$remote_name/$default_branch...HEAD" 2>/dev/null) || {
      repo_flow_stop "failed to compute ahead/behind against $remote_name/$default_branch"
      command_status=1
    }
  fi

  if [ "$command_status" -eq 0 ]; then
    # shellcheck disable=SC2086 # Intentional split of two numeric ahead/behind fields.
    set -- $branch_ahead_behind
    behind_count="${1:-0}"
    ahead_count="${2:-0}"
    staged_files="$(git diff --name-only "$default_branch...HEAD" 2>/dev/null || true)"
  fi

  if [ "$command_status" -eq 0 ] && [ "$json" -eq 0 ]; then
    repo_flow_info "branch status: current=$current_branch default=$default_branch worktree=clean"
    repo_flow_info "ahead/behind: ahead=$ahead_count behind=$behind_count vs $remote_name/$default_branch"
  fi

  if [ "$command_status" -eq 0 ]; then
    branch_head=$(git rev-parse HEAD 2>/dev/null) || branch_head=""
    if git rev-parse --verify "refs/remotes/$remote_name/$current_branch" >/dev/null 2>&1; then
      remote_head=$(git rev-parse "refs/remotes/$remote_name/$current_branch" 2>/dev/null) || remote_head=""
      if [ -n "$remote_head" ] && [ "$remote_head" = "$branch_head" ]; then
        push_status="up-to-date"
      else
        push_status="needed"
      fi
    else
      push_status="needed"
    fi
  fi

  if [ "$command_status" -eq 0 ] && [ "$dry_run" -eq 1 ]; then
    if [ "$push_status" = "needed" ]; then
      repo_flow_info "push status: would push $current_branch to $remote_name"
    else
      repo_flow_info "push status: skipped"
    fi
  fi

  if [ "$command_status" -eq 0 ] && [ "$dry_run" -eq 0 ] && [ "$push_status" = "needed" ]; then
    if git push -u "$remote_name" "$current_branch" >/dev/null 2>&1; then
      push_status="pushed"
      action_taken="pushed-branch"
    else
      repo_flow_stop "git push failed for $current_branch"
      command_status=1
    fi
  fi

  if [ "$command_status" -eq 0 ] && [ "$dry_run" -eq 0 ] && [ "$push_status" = "up-to-date" ]; then
    repo_flow_info "push status: skipped"
  elif [ "$command_status" -eq 0 ] && [ "$dry_run" -eq 0 ] && [ "$push_status" = "pushed" ]; then
    repo_flow_info "push status: pushed $current_branch to $remote_name"
  fi

  return "$command_status"
}

# repo-automation/lib/repo-flow-main-branch.sh EOF
