#!/usr/bin/env bash
# repo-automation/lib/repo-flow-main-pr.sh

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh" || {
  printf 'STOP: failed to source shared library\n' >&2
  return 2 2>/dev/null || exit 2
}

# shellcheck disable=SC2034,SC2154
repo_flow_main_pr() {
  local pr_create_title=""
  local pr_create_body_file=""
  local pr_create_json_file=""
  local pr_create_stderr=""
  local pr_create_output=""
  local existing_pr_number=""

  if [ "$command_status" -eq 0 ]; then
    existing_pr_number=$(gh pr view "$current_branch" --json number --jq '.number' 2>/dev/null || true)
    if [ -n "$existing_pr_number" ]; then
      pr_status="existing"
      pr_number="$existing_pr_number"
      pr_url=$(gh pr view "$current_branch" --json url --jq '.url' 2>/dev/null || true)
      if [ "$json" -eq 0 ]; then
        repo_flow_info "PR status: existing #$pr_number ${pr_url:-}"
      fi
      final_status="ready"
    else
      if [ "${ahead_count:-0}" -eq 0 ]; then
        repo_flow_stop "no commits ahead of $remote_name/$default_branch; nothing to create"
        command_status=1
      elif [ "$dry_run" -eq 1 ]; then
        pr_status="would-create"
        final_status="dry-run"
        if [ "$json" -eq 0 ]; then
          repo_flow_info "PR status: would create a PR via repo-automation/bin/pr-create"
        fi
      else
        pr_create_title=$(git log -1 --pretty=%s 2>/dev/null || true)
        [ -n "$pr_create_title" ] || pr_create_title="$current_branch"
        pr_create_body_file="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-flow-pr-body.XXXXXX")" || {
          repo_flow_stop "failed to create temporary body file"
          command_status=1
        }
        if [ "$command_status" -eq 0 ]; then
          repo_flow_submit_write_pr_body "$pr_create_body_file" "$current_branch" "$default_branch" "$pr_create_title" "$staged_files" "None" "${REPO_FLOW_PR_BODY_FILE:-}" || {
            repo_flow_stop "failed to write PR body"
            command_status=1
          }
        fi
        if [ "$command_status" -eq 0 ]; then
          pr_create_json_file="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-flow-pr-create.XXXXXX.json")" || {
            repo_flow_stop "failed to create temporary PR output file"
            command_status=1
          }
        fi
        if [ "$command_status" -eq 0 ]; then
          pr_create_stderr="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-flow-pr-create.XXXXXX.log")" || {
            repo_flow_stop "failed to create temporary PR log file"
            command_status=1
          }
        fi
        if [ "$command_status" -eq 0 ]; then
          if ! "$script_dir/pr-create" --json --title="$pr_create_title" --body-file="$pr_create_body_file" > "$pr_create_json_file" 2> "$pr_create_stderr"; then
            pr_create_output="$(cat "$pr_create_stderr" 2>/dev/null || true)"
            repo_flow_stop "pr-create failed: $pr_create_output"
            command_status=1
          fi
        fi
        if [ "$command_status" -eq 0 ]; then
          pr_number="$(repo_flow_json_field "$pr_create_json_file" pr_number)"
          pr_url="$(repo_flow_json_field "$pr_create_json_file" pr_url)"
          pr_status="created"
          final_status="ready"
          action_taken="created-pr"
          if [ "$json" -eq 0 ]; then
            repo_flow_info "PR status: created #$pr_number ${pr_url:-}"
          fi
        fi
        if [ -n "$pr_create_body_file" ] && [ -f "$pr_create_body_file" ]; then
          rm -f "$pr_create_body_file"
        fi
        if [ -n "$pr_create_json_file" ] && [ -f "$pr_create_json_file" ]; then
          rm -f "$pr_create_json_file"
        fi
        if [ -n "$pr_create_stderr" ] && [ -f "$pr_create_stderr" ]; then
          rm -f "$pr_create_stderr"
        fi
      fi
    fi
  fi

  return "$command_status"
}

# repo-automation/lib/repo-flow-main-pr.sh EOF
