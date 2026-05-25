#!/usr/bin/env bash
# repo-automation/lib/repo-flow-submit-pr.sh

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
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/repo-flow-submit-body.sh" || {
  printf 'STOP: failed to source repo-flow submit body library\n' >&2
  return 2 2>/dev/null || exit 2
}

repo_flow_submit_create_pr() {
  local current_branch="$1"
  local default_branch="$2"
  local staged_files="$3"
  local custom_body_file="$4"
  local explain="${5:-0}"
  local json="${6:-0}"
  local pr_create_title=""
  local pr_create_body_file=""
  local pr_create_json_file=""
  local pr_create_stderr=""
  local pr_create_output=""
  local script_dir=""

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  pr_create_title=$(git log -1 --pretty=%s 2>/dev/null || true)
  [ -n "$pr_create_title" ] || pr_create_title="$current_branch"
  pr_create_body_file="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-flow-pr-body.XXXXXX")" || {
    repo_flow_stop "failed to create temporary body file"
    return 1
  }
  if ! repo_flow_submit_write_pr_body "$pr_create_body_file" "$current_branch" "$default_branch" "$pr_create_title" "$staged_files" "None" "$custom_body_file"; then
    repo_flow_stop "failed to write PR body"
    if [ -n "$pr_create_body_file" ] && [ -f "$pr_create_body_file" ]; then
      rm -f "$pr_create_body_file"
    fi
    return 1
  fi

  pr_create_json_file="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-flow-pr-create.XXXXXX.json")" || {
    repo_flow_stop "failed to create temporary PR output file"
    rm -f "$pr_create_body_file" >/dev/null 2>&1 || true
    return 1
  }
  pr_create_stderr="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-flow-pr-create.XXXXXX.log")" || {
    repo_flow_stop "failed to create temporary PR log file"
    rm -f "$pr_create_body_file" "$pr_create_json_file" >/dev/null 2>&1 || true
    return 1
  }

  if ! "$script_dir/../bin/pr-create" --json --title="$pr_create_title" --body-file="$pr_create_body_file" > "$pr_create_json_file" 2> "$pr_create_stderr"; then
    pr_create_output="$(cat "$pr_create_stderr" 2>/dev/null || true)"
    repo_flow_stop "pr-create failed: $pr_create_output"
    rm -f "$pr_create_body_file" "$pr_create_json_file" "$pr_create_stderr" >/dev/null 2>&1 || true
    return 1
  fi

  # shellcheck disable=SC2034
  pr_number="$(repo_flow_json_field "$pr_create_json_file" pr_number)"
  # shellcheck disable=SC2034
  pr_url="$(repo_flow_json_field "$pr_create_json_file" pr_url)"
  # shellcheck disable=SC2034
  pr_status="created"
  # shellcheck disable=SC2034
  final_status="ready"
  # shellcheck disable=SC2034
  action_taken="created-pr"
  if [ "$explain" -eq 1 ] && [ "$json" -eq 0 ]; then
    repo_flow_info "PR status: created #$pr_number ${pr_url:-}"
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

  return 0
}

# repo-automation/lib/repo-flow-submit-pr.sh EOF
