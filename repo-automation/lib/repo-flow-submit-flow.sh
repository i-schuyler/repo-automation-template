#!/usr/bin/env bash
# repo-automation/lib/repo-flow-submit-flow.sh

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh" || {
  printf 'STOP: failed to source shared library\n' >&2
  return 2 2>/dev/null || exit 2
}

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/repo-flow-json.sh" || {
  printf 'STOP: failed to source repo-flow json library\n' >&2
  return 2 2>/dev/null || exit 2
}

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/repo-flow-submit-paths.sh" || {
  printf 'STOP: failed to source repo-flow submit paths library\n' >&2
  return 2 2>/dev/null || exit 2
}

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/repo-flow-submit-body.sh" || {
  printf 'STOP: failed to source repo-flow submit body library\n' >&2
  return 2 2>/dev/null || exit 2
}

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/operator-output.sh" || {
  printf 'STOP: failed to source operator output library\n' >&2
  return 2 2>/dev/null || exit 2
}

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/review-request.sh" || {
  printf 'STOP: failed to source review request library\n' >&2
  return 2 2>/dev/null || exit 2
}

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/repo-flow-submit-preflight.sh" || {
  printf 'STOP: failed to source repo-flow submit preflight library\n' >&2
  return 2 2>/dev/null || exit 2
}

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/repo-flow-submit-pr.sh" || {
  printf 'STOP: failed to source repo-flow submit pr library\n' >&2
  return 2 2>/dev/null || exit 2
}

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/repo-flow-submit-child.sh" || {
  printf 'STOP: failed to source repo-flow submit child library\n' >&2
  return 2 2>/dev/null || exit 2
}

# shellcheck disable=SC2034,SC2154
repo_flow_submit_validate_body_replacement() {
  local existing_pr_number=""

  # shellcheck disable=SC2154
  existing_pr_number=$(gh pr view "$current_branch" --json number --jq '.number' 2>/dev/null || true)
  if [ -n "$existing_pr_number" ]; then
    printf 'fix: supplied full body files replace PR bodies; use --replace-body to intentionally replace the PR body\n' >&2
    # shellcheck disable=SC2034
    repo_flow_submit_stop "existing PR #$existing_pr_number requires --replace-body when --body-file is supplied"
    return 1
  fi

  return 0
}

# shellcheck disable=SC2034,SC2154
repo_flow_submit_stage_and_commit() {
  if [ "$submit_mode" = "all" ]; then
    if ! repo_flow_submit_stage_all; then
      return 1
    fi
  elif [ "$modified" -eq 1 ] && repo_flow_submit_has_new_files; then
    repo_flow_submit_stop "--modified only accepts tracked modified/deleted/renamed paths; use --paths=<path> or --staged for new files"
    return 1
  fi

  if [ "$modified" -eq 1 ]; then
    mapfile -t modified_paths < <(repo_flow_submit_collect_modified_paths) || return 1
  fi

  if [ "${#modified_paths[@]}" -gt 0 ]; then
    modified_paths_csv="$(printf '%s\n' "${modified_paths[@]}" | python3 -c 'import sys; print(",".join(line.strip() for line in sys.stdin if line.strip()))')"
    if ! repo_flow_submit_stage_paths "$modified_paths_csv" 1; then
      return 1
    fi
  fi

  if [ -n "$paths_csv" ]; then
    if ! repo_flow_submit_check_unrequested_changes "$paths_csv"; then
      return 1
    fi
  fi

  if [ -n "$paths_csv" ]; then
    if ! repo_flow_submit_stage_paths "$paths_csv"; then
      return 1
    fi
  fi

  staged_files="$(git diff --cached --name-only)"
  if [ -z "$staged_files" ]; then
    repo_flow_submit_stop "no files are staged"
    return 1
  fi
  staged_count="$(printf '%s\n' "$staged_files" | sed '/^$/d' | wc -l | tr -d '[:space:]')"

  if [ "$submit_mode" = "all" ]; then
    requested_paths_csv="$staged_files"
  elif [ -n "$paths_csv" ]; then
    requested_paths_csv="$paths_csv"
  elif [ "$modified" -eq 1 ] && [ "${#modified_paths[@]}" -gt 0 ]; then
    requested_paths_csv="$modified_paths_csv"
  else
    requested_paths_csv="$(printf '%s\n' "$staged_files" | sed '/^$/d' | paste -sd, -)"
  fi
  if [ "$submit_mode" != "all" ] && [ -n "$requested_paths_csv" ] && ! repo_flow_submit_check_unrequested_changes "$requested_paths_csv"; then
    return 1
  fi

  if [ "$explain" -eq 1 ]; then
    repo_flow_info "mode: submit"
    repo_flow_info "submit mode: $submit_mode"
    repo_flow_info "staged count: $staged_count"
    repo_flow_info "branch: $current_branch"
    repo_flow_info "default branch: $default_branch"
    repo_flow_info "commit message: $message"
    repo_flow_info "staged files:"
    while IFS= read -r staged_file; do
      [ -n "$staged_file" ] || continue
      printf '  %s\n' "$staged_file" >&2
    done <<EOF
$staged_files
EOF
  fi

  if ! git diff --cached --check >/dev/null 2>&1; then
    repo_flow_submit_stop "git diff --cached --check failed"
    return 1
  fi

  if ! git commit --message="$message" >/dev/null 2>&1; then
    repo_flow_submit_stop "git commit failed"
    return 1
  fi

  commit_sha="$(git rev-parse HEAD 2>/dev/null || printf 'none')"
  return 0
}

# shellcheck disable=SC2034,SC2154
repo_flow_submit_watch_existing_pr() {
  local existing_pr_number=""

  existing_pr_number=$(gh pr view "$current_branch" --json number --jq '.number' 2>/dev/null || true)
  if [ -n "$existing_pr_number" ]; then
    pr_status="existing"
    pr_number="$existing_pr_number"
    pr_url=$(gh pr view "$current_branch" --json url --jq '.url' 2>/dev/null || true)
    if ! repo_flow_submit_refresh_existing_pr_body repo_flow_submit_stop "$pr_number" "$current_branch" "$default_branch" "$message" "$staged_files" "None" "$custom_body_file" "$replace_body"; then
      pr_url=""
      return 1
    elif [ "$explain" -eq 1 ] && [ "$json" -eq 0 ]; then
      repo_flow_info "PR body refreshed: existing #$pr_number"
    fi
    if [ "$explain" -eq 1 ] && [ "$json" -eq 0 ]; then
      repo_flow_info "PR status: existing #$pr_number ${pr_url:-}"
    fi
  fi

  return 0
}

# shellcheck disable=SC2034,SC2154
repo_flow_submit_apply_child_result() {
  if [ -n "$repo_flow_submit_child_pr_url" ]; then
    pr_url="$repo_flow_submit_child_pr_url"
  fi
  if [ -n "$repo_flow_submit_child_pr_number" ]; then
    pr_number="$repo_flow_submit_child_pr_number"
  fi
  if [ "$command_status" -eq 0 ] && [ "$repo_flow_submit_child_pr_status" = "existing" ] && [ -n "$repo_flow_submit_child_pr_number" ]; then
    if ! repo_flow_submit_refresh_existing_pr_body repo_flow_submit_stop "$repo_flow_submit_child_pr_number" "$current_branch" "$default_branch" "$message" "$staged_files" "None" "$custom_body_file" "$replace_body"; then
      pr_url=""
      return 1
    elif [ "$explain" -eq 1 ] && [ "$json" -eq 0 ]; then
      repo_flow_info "PR body refreshed: existing #$repo_flow_submit_child_pr_number"
    fi
  fi

  if [ -n "$repo_flow_submit_child_summary_value" ]; then
    case "$repo_flow_submit_child_summary_value" in
      pushed)
        pushed="true"
        ;;
      up-to-date)
        pushed="false"
        ;;
      '')
        if [ "$command_status" -eq 0 ]; then
          pushed="unknown"
        fi
        ;;
      *)
        [ "$command_status" -ne 0 ] && repo_flow_stop_reason="$repo_flow_submit_child_summary_value"
        [ "$command_status" -eq 0 ] && pushed="unknown"
        ;;
    esac
  elif [ "$command_status" -eq 0 ]; then
    pushed="unknown"
  fi

  return 0
}

# shellcheck disable=SC2034,SC2154
repo_flow_submit_validate_review_request_source() {
  local review_request_problem=""

  if [ -n "${review_request_source_file:-}" ]; then
    return 0
  elif [ -n "$review_request_file" ]; then
    if ! review_request_problem="$(repo_review_request_template_problem "$review_request_file" "review request file")"; then
      repo_flow_submit_stop "$review_request_problem"
      printf 'fix: provide a regular readable non-empty review request template file\n' >&2
      return 1
    fi
    review_request_source_file="$review_request_file"
  elif [ -n "$review_request_id" ]; then
    review_request_source_file="$(repo_review_request_preset_path "$repo_root" "$review_request_id")"
    if ! review_request_problem="$(repo_review_request_template_problem "$review_request_source_file" "review request preset")"; then
      repo_flow_submit_stop "$review_request_problem"
      printf 'fix: add .prompts/%s.md or choose an existing review request preset ID\n' "$review_request_id" >&2
      return 1
    fi
  fi

  return 0
}

# shellcheck disable=SC2034,SC2154
repo_flow_submit_render_review_request() {
  local artifact_dir=""

  [ -n "${review_request_source_file:-}" ] || return 0

  if [ -z "${pr_url:-}" ]; then
    repo_flow_submit_stop "review request rendering requires a PR URL"
    return 1
  fi

  artifact_dir="$(mktemp -d "${TMPDIR:-$HOME/.cache}/repo-flow-submit-review.XXXXXX")" || {
    repo_flow_submit_stop "failed to create review request artifact directory"
    return 1
  }
  review_request_text_path="$artifact_dir/review-request.txt"
  review_request_block_path="$artifact_dir/pr-review-request-block.txt"

  if ! repo_review_request_render_template "$review_request_source_file" "$review_request_text_path" "$pr_url" "$message" "$current_branch"; then
    repo_flow_submit_stop "failed to render review request"
    return 1
  fi
  if ! repo_operator_output_write_file_block "PR REVIEW REQUEST" "$review_request_text_path" "$review_request_block_path"; then
    repo_flow_submit_stop "failed to write PR review request block"
    return 1
  fi

  return 0
}

# shellcheck disable=SC2034,SC2154
repo_flow_submit_complete_or_delegate() {
  local repo_flow_submit_child_body_file=""
  local repo_flow_submit_child_body_source_file=""

  if [ "$watch" -eq 1 ]; then
    if [ -z "$pr_number" ]; then
      repo_flow_submit_watch_existing_pr
      command_status=$?
      if [ "$command_status" -ne 0 ]; then
        return "$command_status"
      fi
    fi
    if [ -z "$pr_number" ]; then
      repo_flow_submit_create_pr "$current_branch" "$default_branch" "$staged_files" "$custom_body_file" "$explain" "$json"
      command_status=$?
      if [ "$command_status" -ne 0 ]; then
        return "$command_status"
      fi
    fi
    repo_flow_submit_watch_pr_finish
    command_status=$?
    return "$command_status"
  fi

  if [ -z "$custom_body_file" ]; then
    repo_flow_submit_child_body_file="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-flow-pr-body.XXXXXX")" || {
      repo_flow_submit_stop "failed to create temporary body file"
      command_status=1
      return "$command_status"
    }
    if ! repo_flow_submit_write_pr_body "$repo_flow_submit_child_body_file" "$current_branch" "$default_branch" "$(git log -1 --pretty=%s 2>/dev/null || true)" "$staged_files" "None"; then
      rm -f "$repo_flow_submit_child_body_file" >/dev/null 2>&1 || true
      return 1
    fi
    repo_flow_submit_child_body_source_file="$repo_flow_submit_child_body_file"
  else
    repo_flow_submit_child_body_source_file="$custom_body_file"
  fi

  if repo_flow_submit_run_child_repo_flow_main "$repo_flow_submit_child_body_source_file"; then
    :
  else
    command_status=$?
  fi

  if [ -n "$repo_flow_submit_child_body_file" ] && [ -f "$repo_flow_submit_child_body_file" ]; then
    rm -f "$repo_flow_submit_child_body_file" >/dev/null 2>&1 || true
  fi

  if ! repo_flow_submit_apply_child_result; then
    command_status=1
  fi

  return "$command_status"
}

# shellcheck disable=SC2034,SC2154
repo_flow_submit_render_result() {
  local summary_submit_mode=""
  local summary_staged_count=""

  if [ "$command_status" -eq 0 ]; then
    branch_after="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || printf '%s' "$current_branch")"
    status_count="$(git status --short 2>/dev/null | sed '/^$/d' | wc -l | tr -d '[:space:]')"
    summary_submit_mode="$submit_mode"
    summary_staged_count="$staged_count"
  else
    branch_after="${current_branch:-}"
    status_count="$(git status --short 2>/dev/null | sed '/^$/d' | wc -l | tr -d '[:space:]')"
  fi

  if [ "$repo_flow_explain" -eq 1 ]; then
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
      "$watched" \
      "$ci_state" \
      "$command_status" \
      "$repo_flow_stop_reason" \
      "" \
      "$summary_submit_mode" \
      "$summary_staged_count" \
      "${review_request_text_path:-}" \
      "${review_request_block_path:-}"
    if [ "$command_status" -eq 0 ] && [ -n "${review_request_block_path:-}" ]; then
      printf '\n' >&2
      repo_operator_output_emit_file_block "PR REVIEW REQUEST" "$review_request_text_path" 0 >&2
    fi
  fi

  if [ "$repo_flow_explain" -eq 0 ] && [ "$command_status" -eq 0 ] && [ -n "$repo_flow_submit_child_stdout" ]; then
    printf '%s\n' "$repo_flow_submit_child_stdout"
  fi

  return "$command_status"
}

# shellcheck disable=SC2034,SC2154
repo_flow_submit_flow() {
  repo_flow_submit_preflight

  if [ "$command_status" -eq 0 ] && ! repo_flow_submit_validate_review_request_source; then
    command_status=1
  fi

  if [ "$command_status" -eq 0 ]; then
    if [ "$all" -eq 1 ]; then
      submit_mode="all"
    elif [ "$modified" -eq 1 ]; then
      submit_mode="modified"
    elif [ -n "$paths_csv" ]; then
      submit_mode="paths"
    else
      submit_mode="staged"
    fi
  fi

  if [ "$command_status" -eq 0 ] && [ "$replace_body" -eq 0 ] && [ -n "$custom_body_file" ]; then
    if ! repo_flow_submit_validate_body_replacement; then
      command_status=1
    fi
  fi

  branch_before="$current_branch"

  if [ "$command_status" -eq 0 ] && ! repo_flow_submit_stage_and_commit; then
    command_status=1
  fi

  if [ "$command_status" -eq 0 ] && [ "$watch" -eq 1 ]; then
    watched="true"
    if ! git push -u "$remote_name" "$current_branch" >/dev/null 2>&1; then
      repo_flow_submit_stop "git push failed for $current_branch"
      command_status=1
    else
      pushed="true"
    fi
  fi

  if [ "$command_status" -eq 0 ] && [ "$explain" -eq 1 ]; then
    repo_flow_info "commit created: $(git rev-parse --short HEAD 2>/dev/null)"
    repo_flow_info "delegating to repo-native PR completion path"
    if [ "$watch" -eq 1 ]; then
      repo_flow_info "watch: enabled"
    fi
    if [ -n "$custom_body_file" ]; then
      repo_flow_info "PR body: supplied from $custom_body_file"
    else
      repo_flow_info "PR body: generated fallback"
    fi
  fi

  if [ "$command_status" -eq 0 ]; then
    repo_flow_submit_complete_or_delegate
    command_status=$?
  fi

  if [ "$command_status" -eq 0 ] && ! repo_flow_submit_render_review_request; then
    command_status=1
  fi

  repo_flow_submit_render_result
  return "$command_status"
}

# repo-automation/lib/repo-flow-submit-flow.sh EOF
