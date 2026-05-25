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

repo_flow_submit_refresh_existing_pr_body() {
  local stop_fn="$1"
  local pr_number="$2"
  local branch_name="$3"
  local default_branch="$4"
  local commit_subject="$5"
  local staged_files="$6"
  local stop_reason="${7:-None}"
  local body_source_file="${8:-}"
  local replace_body="${9:-0}"
  local body_file=""
  local current_body_file=""
  local current_body_stderr=""
  local pr_edit_output=""
  local script_dir=""

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  body_file="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-flow-pr-body.XXXXXX")" || {
    "$stop_fn" "failed to create temporary body file"
    return 1
  }

  if [ "$replace_body" -eq 1 ]; then
    if ! repo_flow_submit_write_pr_body "$body_file" "$branch_name" "$default_branch" "$commit_subject" "$staged_files" "$stop_reason" "$body_source_file"; then
      rm -f "$body_file" >/dev/null 2>&1 || true
      "$stop_fn" "failed to write PR body"
      return 1
    fi
  else
    if [ -n "$body_source_file" ]; then
      printf 'fix: supplied full body files replace PR bodies; use --replace-body to intentionally replace the PR body\n' >&2
      rm -f "$body_file" >/dev/null 2>&1 || true
      "$stop_fn" "existing PR #$pr_number requires --replace-body when --body-file is supplied"
      return 1
    fi

    current_body_file="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-flow-pr-current-body.XXXXXX")" || {
      rm -f "$body_file" >/dev/null 2>&1 || true
      "$stop_fn" "failed to create temporary body file"
      return 1
    }
    current_body_stderr="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-flow-pr-current-body.XXXXXX.log")" || {
      rm -f "$body_file" "$current_body_file" >/dev/null 2>&1 || true
      "$stop_fn" "failed to create temporary body file"
      return 1
    }
    if ! gh pr view "$pr_number" --json body --jq .body > "$current_body_file" 2> "$current_body_stderr"; then
      local pr_view_output=""
      pr_view_output="$(cat "$current_body_stderr" 2>/dev/null || true)"
      pr_view_output="${pr_view_output//$'\n'/ }"
      pr_view_output="${pr_view_output//$'\r'/ }"
      rm -f "$body_file" "$current_body_file" "$current_body_stderr" >/dev/null 2>&1 || true
      printf 'fix: rerun with --replace-body only if intentional full PR body replacement is desired\n' >&2
      "$stop_fn" "failed to fetch existing PR #$pr_number body: $pr_view_output"
      return 1
    fi
    REPO_FLOW_SUBMIT_BODY_FILE="$body_file" \
    REPO_FLOW_SUBMIT_CURRENT_BODY_FILE="$current_body_file" \
    REPO_FLOW_SUBMIT_BRANCH="$branch_name" \
    REPO_FLOW_SUBMIT_DEFAULT_BRANCH="$default_branch" \
    REPO_FLOW_SUBMIT_COMMIT_SUBJECT="$commit_subject" \
    REPO_FLOW_SUBMIT_STAGED_FILES="$staged_files" \
    REPO_FLOW_SUBMIT_STOP_REASON="$stop_reason" \
    python3 - <<'PY'
from pathlib import Path
import os

body_file = Path(os.environ["REPO_FLOW_SUBMIT_BODY_FILE"])
current_body_file = Path(os.environ["REPO_FLOW_SUBMIT_CURRENT_BODY_FILE"])
branch_name = os.environ["REPO_FLOW_SUBMIT_BRANCH"]
default_branch = os.environ["REPO_FLOW_SUBMIT_DEFAULT_BRANCH"]
commit_subject = os.environ["REPO_FLOW_SUBMIT_COMMIT_SUBJECT"]
staged_files = [line for line in os.environ.get("REPO_FLOW_SUBMIT_STAGED_FILES", "").splitlines() if line.strip()]
stop_reason = os.environ.get("REPO_FLOW_SUBMIT_STOP_REASON", "").strip()

existing_body = current_body_file.read_text(encoding="utf-8")
staged_lines = "\n".join(f"  - {path}" for path in staged_files) if staged_files else "  - none"
entry_lines = [
    "- Added by `repo-flow submit`.",
    f"- Commit subject: {commit_subject}",
    "- Staged paths:",
    staged_lines,
]
if stop_reason and stop_reason != "None":
    entry_lines.extend([
        f"- Stop reason: {stop_reason}",
    ])
entry_lines.extend([
    "- Re-entry hint: Review the PR, then run `repo-automation/bin/repo-flow merge --explain`.",
])
entry = "\n".join(entry_lines)
if "## Update log" in existing_body:
    new_body = existing_body.rstrip("\n") + "\n\n" + entry + "\n"
else:
    new_body = existing_body.rstrip("\n") + "\n\n## Update log\n\n" + entry + "\n"
body_file.write_text(new_body, encoding="utf-8")
PY
    rm -f "$current_body_file" "$current_body_stderr" >/dev/null 2>&1 || true
  fi

  if [ "$replace_body" -eq 0 ]; then
    validation_output=""
    if ! validation_output="$("$script_dir/../bin/pr-body-check" --quiet --body-file="$body_file" 2>&1)"; then
      local validation_failure=""
      validation_failure="$(printf '%s\n' "$validation_output" | sed -n '1p')"
      [ -n "$validation_failure" ] || validation_failure="PR body validation failed"
      [ -n "$validation_output" ] && printf '%s\n' "$validation_output" >&2
      printf 'fix: rerun with --replace-body only if intentional full PR body replacement is desired\n' >&2
      rm -f "$body_file" >/dev/null 2>&1 || true
      "$stop_fn" "failed to refresh existing PR #$pr_number body: $validation_failure"
      return 1
    fi
  fi

  if ! pr_edit_output="$(gh pr edit "$pr_number" --body-file="$body_file" 2>&1)"; then
    pr_edit_output="${pr_edit_output//$'\n'/ }"
    pr_edit_output="${pr_edit_output//$'\r'/ }"
    rm -f "$body_file" >/dev/null 2>&1 || true
    "$stop_fn" "failed to refresh existing PR #$pr_number body: $pr_edit_output"
    return 1
  fi

  rm -f "$body_file" >/dev/null 2>&1 || true
}

# repo-automation/lib/repo-flow-submit-body.sh EOF
