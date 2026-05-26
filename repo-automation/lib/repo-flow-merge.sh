#!/usr/bin/env bash
# repo-automation/lib/repo-flow-merge.sh

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
repo_flow_merge_finish_pr() {
  # shellcheck disable=SC2154
  pr_finish_args=(--watch --merge --delete-branch --sync-main --pr="$pr_selector" --timeout="$watch_timeout_seconds")
  # shellcheck disable=SC2154
  if [ "$diagnose_on_fail" -eq 1 ]; then
    pr_finish_args+=(--diagnose-on-fail)
  fi

  # shellcheck disable=SC2154
  pr_finish_state_file="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-flow-pr-finish.XXXXXX.state")" || {
    repo_flow_stop "failed to create temporary PR finish state file"
    command_status=1
    return "$command_status"
  }

  # shellcheck disable=SC2154
  if [ "$explain" -eq 1 ]; then
    if PR_FINISH_STATE_FILE="$pr_finish_state_file" repo_flow_submit_run_child_explain "$script_dir/pr-finish" "${pr_finish_args[@]}" --explain; then
      merged="$(repo_flow_submit_extract_child_state_value "$pr_finish_state_file" merged)"
      pr_number="$(repo_flow_submit_extract_child_state_value "$pr_finish_state_file" pr_number)"
      pr_url="$(repo_flow_submit_extract_child_state_value "$pr_finish_state_file" pr_url)"
      ci_state="pass"
      action_taken="merged-pr"
      final_status="completed"
    else
      repo_flow_stop "pr-finish completion failed for PR $pr_selector"
      command_status=1
      final_status="blocked"
    fi
  elif [ "$json" -eq 1 ]; then
    if PR_FINISH_STATE_FILE="$pr_finish_state_file" repo_flow_run_child_quiet "$script_dir/pr-finish" "${pr_finish_args[@]}"; then
      merged="$(repo_flow_submit_extract_child_state_value "$pr_finish_state_file" merged)"
      pr_number="$(repo_flow_submit_extract_child_state_value "$pr_finish_state_file" pr_number)"
      pr_url="$(repo_flow_submit_extract_child_state_value "$pr_finish_state_file" pr_url)"
      ci_state="pass"
      action_taken="merged-pr"
      final_status="completed"
    else
      repo_flow_stop "pr-finish completion failed for PR $pr_selector"
      command_status=1
      final_status="blocked"
    fi
  elif PR_FINISH_STATE_FILE="$pr_finish_state_file" "$script_dir/pr-finish" "${pr_finish_args[@]}"; then
    merged="$(repo_flow_submit_extract_child_state_value "$pr_finish_state_file" merged)"
    pr_number="$(repo_flow_submit_extract_child_state_value "$pr_finish_state_file" pr_number)"
    pr_url="$(repo_flow_submit_extract_child_state_value "$pr_finish_state_file" pr_url)"
    ci_state="pass"
    action_taken="merged-pr"
    final_status="completed"
  else
    repo_flow_stop "pr-finish completion failed for PR $pr_selector"
    command_status=1
    final_status="blocked"
  fi

  # shellcheck disable=SC2154
  if [ -n "$pr_finish_state_file" ] && [ -f "$pr_finish_state_file" ]; then
    pr_finish_state_pr_number="$(repo_flow_submit_extract_child_state_value "$pr_finish_state_file" pr_number)"
    pr_finish_state_pr_url="$(repo_flow_submit_extract_child_state_value "$pr_finish_state_file" pr_url)"
    pr_finish_state_merged="$(repo_flow_submit_extract_child_state_value "$pr_finish_state_file" merged)"
    pr_finish_state_elapsed_seconds="$(repo_flow_submit_extract_child_state_value "$pr_finish_state_file" elapsed_seconds)"

    if [ -n "$pr_finish_state_pr_number" ] && [ -z "$pr_number" ]; then
      pr_number="$pr_finish_state_pr_number"
    fi
    if [ -n "$pr_finish_state_pr_url" ] && [ -z "$pr_url" ]; then
      pr_url="$pr_finish_state_pr_url"
    fi
    if [ -n "$pr_finish_state_merged" ]; then
      merged="$pr_finish_state_merged"
    fi
  fi

  return "$command_status"
}

# shellcheck disable=SC2034,SC2154
repo_flow_merge_render_result() {
  branch_after="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf '%s' "$current_branch")"

  if [ "$repo_flow_json" -eq 1 ]; then
    repo_flow_print_json \
      "$mode" \
      "${current_branch:-}" \
      "${default_branch:-}" \
      "clean" \
      "0" \
      "0" \
      "skipped" \
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
    repo_flow_submit_print_final_summary \
      "$mode" \
      "$branch_before" \
      "$branch_after" \
      "${pr_number:-}" \
      "${pr_url:-}" \
      "none" \
      "false" \
      "$merged" \
      "$(git status --short 2>/dev/null | sed '/^$/d' | wc -l | tr -d '[:space:]')" \
      "false" \
      "$ci_state" \
      "$command_status" \
      "$repo_flow_stop_reason" \
      "${pr_finish_state_elapsed_seconds:-}"
  elif [ "$command_status" -eq 0 ]; then
    if [ -n "$pr_url" ]; then
      printf '%s\n' "$pr_url"
    else
      printf 'pass\n'
    fi
  fi

  if [ -n "$pr_finish_state_file" ] && [ -f "$pr_finish_state_file" ]; then
    rm -f "$pr_finish_state_file" >/dev/null 2>&1 || true
  fi

  return "$command_status"
}

# repo-automation/lib/repo-flow-merge.sh EOF
