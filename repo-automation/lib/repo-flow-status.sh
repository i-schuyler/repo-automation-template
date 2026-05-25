#!/usr/bin/env bash
# repo-automation/lib/repo-flow-status.sh

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh" || {
  printf 'STOP: failed to source shared library\n' >&2
  return 2 2>/dev/null || exit 2
}

repo_flow_status_card_usage() {
  printf 'Usage: repo-automation/bin/repo-flow status-card [--json] [--help]\n'
}

repo_flow_status_card_json_escape() {
  local value="${1:-}"

  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

repo_flow_status_card_classify_checks() {
  local checks_json="${1:-}"
  local checks_state="unknown"

  if command -v python3 >/dev/null 2>&1; then
    checks_state="$(STATUS_CARD_CHECKS_JSON="$checks_json" python3 - <<'PY'
from __future__ import annotations

import json
import os

raw = os.environ.get("STATUS_CARD_CHECKS_JSON", "")
try:
    data = json.loads(raw) if raw else []
except Exception:
    print("unknown")
    raise SystemExit(0)

if not isinstance(data, list) or len(data) == 0:
    print("unknown")
    raise SystemExit(0)

pending_states = {"pending", "queued", "in_progress", "requested", "waiting", "action_required"}
blocked_states = {"fail", "failed", "failure", "cancel", "cancelled", "canceled", "timed_out", "timeout", "error"}
green_states = {"pass", "passed", "success", "succeeded", "completed"}
pending = False
blocked = False
green = False

for item in data:
    if not isinstance(item, dict):
        continue
    bucket = str(item.get("bucket", "")).lower()
    state = str(item.get("state", "")).lower()
    if bucket == "pending" or state in pending_states:
        pending = True
    elif bucket in {"fail", "failed", "failure", "cancel"} or state in blocked_states:
        blocked = True
    elif bucket in {"pass", "success"} or state in green_states:
        green = True

if blocked:
    print("blocked")
elif pending:
    print("pending")
elif green:
    print("green")
else:
    print("unknown")
PY
)"
  fi

  printf '%s' "$checks_state"
}

repo_flow_status_card_main() {
  local json=0
  local arg=""
  local repo_root=""
  local current_branch=""
  local default_branch="main"
  local worktree_status="clean"
  local tracked_changed_files=0
  local untracked_files=0
  local range_vs_default_files=0
  local ahead_count=0
  local behind_count=0
  local pr_number=""
  local pr_url=""
  local pr_state="none"
  local checks_state="no-pr"
  local next_action=""
  local checks_output=""
  local status_line=""
  local branch_status=""
  local config_path=""
  local pr_state_lower=""

  while [ "$#" -gt 0 ]; do
    arg="$1"
    case "$arg" in
      --help)
        repo_flow_status_card_usage
        return 0
        ;;
      --json)
        json=1
        ;;
      *)
        if [ "${arg#--}" != "$arg" ]; then
          repo_auto_flag_error "unknown flag" "$arg" "run repo-automation/bin/repo-flow status-card --help"
        else
          repo_auto_stop "unknown argument: $arg"
        fi
        return 1
        ;;
    esac
    shift
  done

  repo_auto_require_command git || return 1
  repo_root=$(repo_auto_repo_root) || return 1
  cd "$repo_root" || return 1

  config_path="$repo_root/.repo-automation.conf"
  if [ -f "$config_path" ]; then
    # shellcheck source=/dev/null
    . "$config_path" || return 1
  fi
  default_branch="${DEFAULT_BRANCH:-main}"

  current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || return 1

  branch_status="$(git status --porcelain 2>/dev/null)" || branch_status=""
  if [ -n "$branch_status" ]; then
    worktree_status="dirty"
    while IFS= read -r status_line; do
      [ -n "$status_line" ] || continue
      case "$status_line" in
        '?? '*)
          untracked_files=$((untracked_files + 1))
          ;;
        *)
          tracked_changed_files=$((tracked_changed_files + 1))
          ;;
      esac
    done <<EOF
$branch_status
EOF
  fi

  if [ -n "${default_branch:-}" ] && git rev-parse --verify "$default_branch" >/dev/null 2>&1; then
    range_vs_default_files="$(git diff --name-only "$default_branch...HEAD" 2>/dev/null | sed '/^$/d' | wc -l | tr -d '[:space:]')"
    branch_ahead_behind="$(git rev-list --left-right --count "$default_branch...HEAD" 2>/dev/null || printf '0 0')"
    # shellcheck disable=SC2086
    set -- $branch_ahead_behind
    behind_count="${1:-0}"
    ahead_count="${2:-0}"
  fi

  if command -v gh >/dev/null 2>&1; then
    pr_number="$(gh pr view "$current_branch" --json number --jq .number 2>/dev/null || true)"
    pr_url="$(gh pr view "$current_branch" --json url --jq .url 2>/dev/null || true)"
    pr_state="$(gh pr view "$current_branch" --json state --jq .state 2>/dev/null || true)"
    pr_state_lower="$(printf '%s' "$pr_state" | tr '[:upper:]' '[:lower:]')"
    if [ -n "$pr_number" ] && [ -n "$pr_url" ] && [ "$pr_state_lower" = "open" ]; then
      pr_state="$pr_state_lower"
      checks_output="$(gh pr checks "$pr_number" --required --json name,state,bucket 2>/dev/null || true)"
      if [ -n "$checks_output" ]; then
        checks_state="$(repo_flow_status_card_classify_checks "$checks_output")"
      else
        checks_state="unknown"
      fi
    else
      pr_number=""
      pr_url=""
      pr_state="none"
      checks_state="no-pr"
    fi
  fi

  if [ "$worktree_status" = "dirty" ]; then
    next_action="review changes and commit"
  elif [ "$current_branch" = "$default_branch" ] && [ "$worktree_status" = "clean" ]; then
    next_action="create feature branch"
  elif [ -n "$pr_number" ]; then
    case "$checks_state" in
      pending)
        next_action="repo-automation/bin/ci-watch --pr=$pr_number --poll-seconds=5 --timeout=900"
        ;;
      green)
        next_action="repo-automation/bin/repo-flow merge --pr=$pr_number"
        ;;
      blocked)
        next_action="inspect CI failure"
        ;;
      *)
        next_action="inspect CI status"
        ;;
    esac
  elif [ "$ahead_count" -gt 0 ] && [ "$worktree_status" = "clean" ]; then
    next_action="repo-automation/bin/repo-flow --dry-run"
  else
    next_action="make changes or return to main"
  fi

  if [ "$json" -eq 1 ]; then
    printf '{'
    printf '"mode":"status-card",'
    printf '"branch":"%s",' "$(repo_flow_status_card_json_escape "$current_branch")"
    printf '"default_branch":"%s",' "$(repo_flow_status_card_json_escape "$default_branch")"
    printf '"worktree":"%s",' "$(repo_flow_status_card_json_escape "$worktree_status")"
    printf '"tracked_changed_files":%s,' "$tracked_changed_files"
    printf '"untracked_files":%s,' "$untracked_files"
    printf '"range_vs_default_files":%s,' "$range_vs_default_files"
    printf '"ahead_count":%s,' "$ahead_count"
    printf '"behind_count":%s,' "$behind_count"
    if [ -n "$pr_number" ]; then
      printf '"pr_number":%s,' "$pr_number"
      printf '"pr_url":"%s",' "$(repo_flow_status_card_json_escape "$pr_url")"
      printf '"pr_state":"%s",' "$(repo_flow_status_card_json_escape "$pr_state")"
    else
      printf '"pr_number":null,'
      printf '"pr_url":null,'
      printf '"pr_state":null,'
    fi
    printf '"checks_state":"%s",' "$(repo_flow_status_card_json_escape "$checks_state")"
    printf '"next_action":"%s",' "$(repo_flow_status_card_json_escape "$next_action")"
    printf '"overall_status":"pass"'
    printf '}\n'
    return 0
  fi

  printf 'branch: %s\n' "$current_branch"
  printf 'default: %s\n' "$default_branch"
  printf 'worktree: %s\n' "$worktree_status"
  if [ "$tracked_changed_files" -eq 0 ]; then
    printf 'tracked_changed: none\n'
  else
    printf 'tracked_changed: %s\n' "$tracked_changed_files"
  fi
  if [ "$untracked_files" -eq 0 ]; then
    printf 'untracked: none\n'
  else
    printf 'untracked: %s\n' "$untracked_files"
  fi
  if [ "$range_vs_default_files" -eq 0 ]; then
    printf 'range_vs_default: none\n'
  else
    printf 'range_vs_default: %s\n' "$range_vs_default_files"
  fi
  printf 'ahead_behind: ahead=%s behind=%s\n' "$ahead_count" "$behind_count"
  if [ -n "$pr_number" ]; then
    printf 'pr: #%s %s %s\n' "$pr_number" "$pr_state" "$pr_url"
  else
    printf 'pr: none\n'
  fi
  printf 'checks: %s\n' "$checks_state"
  printf 'next: %s\n' "$next_action"
  return 0
}

# repo-automation/lib/repo-flow-status.sh EOF
