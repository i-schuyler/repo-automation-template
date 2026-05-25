#!/usr/bin/env bash
# repo-automation/lib/repo-flow-submit-body.sh

# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh" || {
  printf 'STOP: failed to source shared library\n' >&2
  return 2 2>/dev/null || exit 2
}

repo_flow_submit_validate_custom_body_file() {
  local body_source_file="$1"
  local validation_output=""
  local validation_failure=""
  local script_dir=""

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

  if [ ! -e "$body_source_file" ]; then
    printf 'fix: provide an existing PR body file\n' >&2
    repo_flow_submit_stop "body file does not exist: $body_source_file"
    return 1
  fi
  if [ -d "$body_source_file" ]; then
    printf 'fix: provide a regular readable PR body file\n' >&2
    repo_flow_submit_stop "body file is a directory: $body_source_file"
    return 1
  fi
  if [ ! -f "$body_source_file" ]; then
    printf 'fix: provide a regular readable PR body file\n' >&2
    repo_flow_submit_stop "body file is not a regular file: $body_source_file"
    return 1
  fi
  if [ ! -r "$body_source_file" ]; then
    printf 'fix: fix file permissions or choose a readable PR body file\n' >&2
    repo_flow_submit_stop "body file is not readable: $body_source_file"
    return 1
  fi

  if ! validation_output="$("$script_dir/../bin/pr-body-check" --quiet --body-file="$body_source_file" 2>&1)"; then
    validation_failure="$(printf '%s\n' "$validation_output" | sed -n '1p')"
    [ -n "$validation_failure" ] || validation_failure="PR body validation failed"
    [ -n "$validation_output" ] && printf '%s\n' "$validation_output" >&2
    repo_flow_submit_stop "$validation_failure"
    return 1
  fi

  return 0
}

repo_flow_submit_write_pr_body() {
  local body_file="$1"
  local branch_name="$2"
  local default_branch="$3"
  local commit_subject="$4"
  local staged_files="$5"
  local stop_reason="${6:-None}"
  local body_source_file="${7:-}"

  if [ -n "$body_source_file" ]; then
    if ! repo_flow_submit_validate_custom_body_file "$body_source_file"; then
      return 1
    fi

    cp -- "$body_source_file" "$body_file" || {
      repo_flow_submit_stop "failed to copy PR body file: $body_source_file"
      return 1
    }
    return 0
  fi

  REPO_FLOW_SUBMIT_BODY_FILE="$body_file" \
  REPO_FLOW_SUBMIT_BRANCH="$branch_name" \
  REPO_FLOW_SUBMIT_DEFAULT_BRANCH="$default_branch" \
  REPO_FLOW_SUBMIT_COMMIT_SUBJECT="$commit_subject" \
  REPO_FLOW_SUBMIT_STAGED_FILES="$staged_files" \
  REPO_FLOW_SUBMIT_STOP_REASON="$stop_reason" \
  python3 - <<'PY'
from pathlib import Path
import os

body_file = Path(os.environ["REPO_FLOW_SUBMIT_BODY_FILE"])
branch_name = os.environ["REPO_FLOW_SUBMIT_BRANCH"]
default_branch = os.environ["REPO_FLOW_SUBMIT_DEFAULT_BRANCH"]
commit_subject = os.environ["REPO_FLOW_SUBMIT_COMMIT_SUBJECT"]
staged_files = [line for line in os.environ.get("REPO_FLOW_SUBMIT_STAGED_FILES", "").splitlines() if line.strip()]
stop_reason = os.environ.get("REPO_FLOW_SUBMIT_STOP_REASON", "None").strip() or "None"

staged_lines = "\n".join(f"- {path}" for path in staged_files) if staged_files else "- none"
body = "\n".join([
    "## Scope",
    "",
    f"repo-flow submit for branch `{branch_name}` against `{default_branch}`.",
    "",
    "## What changed",
    "",
    f"- Commit subject: {commit_subject}",
    "- Staged paths:",
    staged_lines,
    "",
    "## What did not change",
    "",
    "- No unrelated files were changed.",
    "",
    "## Verification status",
    "",
    "- branch and remote validation",
    "- staged file selection and worktree checks",
    "- git diff --cached --check",
    "- git commit --message",
    "",
    "## User-visible behavior changes",
    "",
    "See changed files and the commit message.",
    "",
    "## Stop conditions encountered",
    "",
    stop_reason,
    "",
    "## Re-entry hint",
    "",
    "Review the PR, then run `repo-automation/bin/repo-flow merge --explain`.",
    "",
])
body_file.write_text(body, encoding="utf-8")
PY
}

# repo-automation/lib/repo-flow-submit-body.sh EOF
