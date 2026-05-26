#!/usr/bin/env bash
# repo-automation/lib/repo-flow-main-result.sh

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh" || {
  printf 'STOP: failed to source shared library\n' >&2
  return 2 2>/dev/null || exit 2
}

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/repo-flow-submit-child.sh" || {
  printf 'STOP: failed to source repo-flow submit child library\n' >&2
  return 2 2>/dev/null || exit 2
}

# shellcheck disable=SC2034,SC2154
repo_flow_main_watch_completion() {
  if [ "$command_status" -eq 0 ] && [ "$dry_run" -eq 0 ] && [ "$watch" -eq 1 ]; then
    if [ "$json" -eq 0 ]; then
      repo_flow_info "completion timeout: ${watch_timeout_seconds}s"
    fi
    if [ "$diagnose_on_fail" -eq 1 ]; then
      if [ "$repo_flow_explain" -eq 1 ]; then
        if repo_flow_submit_run_child_explain "$script_dir/pr-finish" --watch --merge --delete-branch --sync-main --pr=current --timeout="$watch_timeout_seconds" --diagnose-on-fail --explain; then
          action_taken="completed-pr"
          final_status="completed"
          merged="true"
        else
          repo_flow_stop "pr-finish completion failed for PR #$pr_number"
          command_status=1
          final_status="blocked"
        fi
      elif "$script_dir/pr-finish" --watch --merge --delete-branch --sync-main --pr=current --timeout="$watch_timeout_seconds" --diagnose-on-fail; then
        action_taken="completed-pr"
        final_status="completed"
        merged="true"
      else
        repo_flow_stop "pr-finish completion failed for PR #$pr_number"
        command_status=1
        final_status="blocked"
      fi
    else
      if [ "$repo_flow_explain" -eq 1 ]; then
        if repo_flow_submit_run_child_explain "$script_dir/pr-finish" --watch --merge --delete-branch --sync-main --pr=current --timeout="$watch_timeout_seconds" --explain; then
          action_taken="completed-pr"
          final_status="completed"
          merged="true"
        else
          repo_flow_stop "pr-finish completion failed for PR #$pr_number"
          command_status=1
          final_status="blocked"
        fi
      elif "$script_dir/pr-finish" --watch --merge --delete-branch --sync-main --pr=current --timeout="$watch_timeout_seconds"; then
        action_taken="completed-pr"
        final_status="completed"
        merged="true"
      else
        repo_flow_stop "pr-finish completion failed for PR #$pr_number"
        command_status=1
        final_status="blocked"
      fi
    fi
  fi
}

# shellcheck disable=SC2034,SC2154
repo_flow_main_render_result() {
  branch_after="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf '%s' "$current_branch")"
  status_count="$(git status --short 2>/dev/null | sed '/^$/d' | wc -l | tr -d '[:space:]')"

  if [ "$repo_flow_json" -eq 1 ]; then
    repo_flow_print_json \
      "$mode" \
      "${current_branch:-}" \
      "${default_branch:-}" \
      "${worktree_status:-}" \
      "${ahead_count:-}" \
      "${behind_count:-}" \
      "$push_status" \
      "$pr_status" \
      "${pr_number:-}" \
      "${pr_url:-}" \
      "$final_status" \
      "$action_taken" \
      "$repo_flow_stop_reason"
  elif [ "$repo_flow_explain" -eq 1 ]; then
    if [ "$command_status" -eq 0 ]; then
      repo_flow_info "final status: $final_status"
    fi
    if [ "$mode" = "submit" ]; then
      repo_flow_submit_print_final_summary \
        submit \
        "$branch_before" \
        "$branch_after" \
        "${pr_number:-}" \
        "${pr_url:-}" \
        "$commit_sha" \
        "$pushed" \
        "$merged" \
        "$status_count" \
        "false" \
        "unknown" \
        "$command_status" \
        "$repo_flow_stop_reason"
    else
      repo_auto_print_final_summary \
        "branch=$current_branch" \
        "rc=$command_status" \
        "mode=$mode" \
        "url_or_stop=${pr_url:-${repo_flow_stop_reason:-$final_status}}" >&2
    fi
  elif [ "$command_status" -eq 0 ]; then
    if [ "$dry_run" -eq 1 ]; then
      printf 'plan\n'
    elif [ -n "$pr_url" ]; then
      printf '%s\n' "$pr_url"
    else
      printf 'pass\n'
    fi
  fi

  if [ -n "${REPO_FLOW_CHILD_STATE_FILE:-}" ]; then
    cat > "$REPO_FLOW_CHILD_STATE_FILE" <<EOF
push_status=$push_status
pr_status=$pr_status
pr_url=$pr_url
pr_number=$pr_number
final_status=$final_status
rc=$command_status
EOF
  fi

  return "$command_status"
}

# repo-automation/lib/repo-flow-main-result.sh EOF
