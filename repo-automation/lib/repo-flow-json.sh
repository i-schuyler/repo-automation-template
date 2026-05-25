#!/usr/bin/env bash
# repo-automation/lib/repo-flow-json.sh

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh" || {
  printf 'STOP: failed to source shared library\n' >&2
  return 2 2>/dev/null || exit 2
}

repo_flow_json_escape() {
  local value="${1:-}"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

repo_flow_print_json() {
  local mode="$1"
  local current_branch="$2"
  local default_branch="$3"
  local worktree_status="$4"
  local ahead_count="$5"
  local behind_count="$6"
  local push_status="$7"
  local pr_status="$8"
  local pr_number="$9"
  local pr_url="${10}"
  local final_status="${11}"
  local action_taken="${12}"
  local stop_reason="${13}"

  printf '{'
  printf '"mode":"%s",' "$(repo_flow_json_escape "$mode")"
  printf '"current_branch":"%s",' "$(repo_flow_json_escape "$current_branch")"
  printf '"default_branch":"%s",' "$(repo_flow_json_escape "$default_branch")"
  printf '"worktree_status":"%s",' "$(repo_flow_json_escape "$worktree_status")"
  printf '"ahead_count":"%s",' "$(repo_flow_json_escape "$ahead_count")"
  printf '"behind_count":"%s",' "$(repo_flow_json_escape "$behind_count")"
  printf '"push_status":"%s",' "$(repo_flow_json_escape "$push_status")"
  printf '"pr_status":"%s",' "$(repo_flow_json_escape "$pr_status")"
  printf '"pr_number":"%s",' "$(repo_flow_json_escape "$pr_number")"
  printf '"pr_url":"%s",' "$(repo_flow_json_escape "$pr_url")"
  printf '"final_status":"%s",' "$(repo_flow_json_escape "$final_status")"
  printf '"action_taken":"%s",' "$(repo_flow_json_escape "$action_taken")"
  printf '"stop_reason":"%s"' "$(repo_flow_json_escape "$stop_reason")"
  printf '}\n'
}

repo_flow_json_field() {
  local json_file="$1"
  local field="$2"
  python3 - "$json_file" "$field" <<'PY'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
value = data.get(sys.argv[2], '')
if value is None:
    value = ''
print(value)
PY
}

# repo-automation/lib/repo-flow-json.sh EOF
