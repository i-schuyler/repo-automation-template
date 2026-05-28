#!/usr/bin/env bash
# repo-automation/lib/repo-flow-submit-child.sh

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh" || {
  printf 'STOP: failed to source shared library\n' >&2
  return 2 2>/dev/null || exit 2
}

repo_flow_submit_print_final_summary() {
  local mode="$1"
  local branch_before="$2"
  local branch_after="$3"
  local pr_number="$4"
  local pr_url="$5"
  local commit_sha="$6"
  local pushed="$7"
  local merged="$8"
  local status_count="$9"
  local watched="${10}"
  local ci_state="${11}"
  local rc="${12}"
  local stop_reason="${13}"
  local elapsed_seconds="${14:-}"
  local submit_mode="${15:-}"
  local staged_count="${16:-}"
  local pr_summary="unknown"
  local url_or_stop="pass"

  [ -n "$pr_number" ] && pr_summary="$pr_number"
  if [ -n "$pr_url" ]; then
    url_or_stop="$pr_url"
  elif [ -n "$stop_reason" ]; then
    url_or_stop="$stop_reason"
  fi
  local -a summary_args=(
    "script=repo-flow" \
    "mode=$mode" \
    "rc=$rc" \
    "branch_before=$branch_before" \
    "branch_after=$branch_after" \
    "pr=$pr_summary" \
    "commit=$commit_sha" \
    "pushed=$pushed" \
    "merged=$merged" \
    "status_count=$status_count" \
    "watched=$watched" \
    "ci=$ci_state" \
    "url_or_stop=$url_or_stop"
  )
  if [ -n "$elapsed_seconds" ]; then
    summary_args+=("elapsed_seconds=$elapsed_seconds")
  fi
  if [ -n "$submit_mode" ]; then
    summary_args+=("submit_mode=$submit_mode")
  fi
  if [ -n "$staged_count" ]; then
    summary_args+=("staged_count=$staged_count")
  fi
  repo_auto_print_final_summary "${summary_args[@]}" >&2
}

repo_flow_submit_filter_child_explain_summary() {
  local stderr_file="$1"

  awk '
    $0 == "===== FINAL SUMMARY =====" { in_summary = 1; next }
    in_summary && $0 == "===== END =====" { in_summary = 0; next }
    !in_summary { print }
  ' "$stderr_file"
}

repo_flow_submit_run_child_explain() {
  local child_stdout_file=""
  local child_stderr_file=""
  local child_status=0

  child_stdout_file="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-flow-child.XXXXXX.stdout")" || return 1
  child_stderr_file="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-flow-child.XXXXXX.stderr")" || {
    rm -f "$child_stdout_file" >/dev/null 2>&1 || true
    return 1
  }

  if "$@" >"$child_stdout_file" 2>"$child_stderr_file"; then
    child_status=0
  else
    child_status=$?
  fi

  cat "$child_stdout_file"
  repo_flow_submit_filter_child_explain_summary "$child_stderr_file" >&2

  rm -f "$child_stdout_file" "$child_stderr_file" >/dev/null 2>&1 || true
  return "$child_status"
}

repo_flow_run_child_quiet() {
  local child_stdout_file=""
  local child_stderr_file=""
  local child_status=0

  child_stdout_file="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-flow-child.XXXXXX.stdout")" || return 1
  child_stderr_file="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-flow-child.XXXXXX.stderr")" || {
    rm -f "$child_stdout_file" >/dev/null 2>&1 || true
    return 1
  }

  if "$@" >"$child_stdout_file" 2>"$child_stderr_file"; then
    child_status=0
  else
    child_status=$?
  fi

  rm -f "$child_stdout_file" "$child_stderr_file" >/dev/null 2>&1 || true
  return "$child_status"
}

repo_flow_submit_extract_child_summary_value() {
  local stderr_file="$1"

  awk -F= '/^url_or_stop=/{sub(/^url_or_stop=/, "", $0); print $0; exit}' "$stderr_file"
}

repo_flow_submit_extract_child_state_value() {
  local state_file="$1"
  local key="$2"

  awk -F= -v key="$key" '$1 == key {sub("^[^=]*=", "", $0); print $0; exit}' "$state_file"
}

repo_flow_submit_run_child_repo_flow_main() {
  local body_source_file="${1:-}"
  local child_stdout_file=""
  local child_stderr_file=""
  local child_state_file=""
  local child_status=0

  child_stdout_file="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-flow-child.XXXXXX.stdout")" || return 1
  child_stderr_file="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-flow-child.XXXXXX.stderr")" || {
    rm -f "$child_stdout_file" >/dev/null 2>&1 || true
    return 1
  }
  child_state_file="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-flow-child.XXXXXX.state")" || {
    rm -f "$child_stdout_file" "$child_stderr_file" >/dev/null 2>&1 || true
    return 1
  }

  if REPO_FLOW_CHILD_STATE_FILE="$child_state_file" REPO_FLOW_PR_BODY_FILE="$body_source_file" repo_flow_main >"$child_stdout_file" 2>"$child_stderr_file"; then
    child_status=0
  else
    child_status=$?
  fi

  # shellcheck disable=SC2034
  repo_flow_submit_child_stdout="$(cat "$child_stdout_file")"
  repo_flow_submit_filter_child_explain_summary "$child_stderr_file" >&2
  # shellcheck disable=SC2034
  repo_flow_submit_child_summary_value="$(repo_flow_submit_extract_child_state_value "$child_state_file" push_status)"
  # shellcheck disable=SC2034
  repo_flow_submit_child_pr_status="$(repo_flow_submit_extract_child_state_value "$child_state_file" pr_status)"
  # shellcheck disable=SC2034
  repo_flow_submit_child_pr_url="$(repo_flow_submit_extract_child_state_value "$child_state_file" pr_url)"
  # shellcheck disable=SC2034
  repo_flow_submit_child_pr_number="$(repo_flow_submit_extract_child_state_value "$child_state_file" pr_number)"

  rm -f "$child_stdout_file" "$child_stderr_file" "$child_state_file" >/dev/null 2>&1 || true
  return "$child_status"
}

# repo-automation/lib/repo-flow-submit-child.sh EOF
