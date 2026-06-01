#!/usr/bin/env bash
# repo-automation/lib/review-request.sh

repo_review_request_is_valid_id() {
  case "${1:-}" in
    ''|.*|*/*|*'..'*|*[!A-Za-z0-9_-]*)
      return 1
      ;;
  esac

  case "$1" in
    [A-Za-z0-9]*)
      return 0
      ;;
  esac

  return 1
}

repo_review_request_preset_path() {
  local repo_root="$1"
  local preset_id="$2"

  printf '%s/.prompts/%s.md\n' "$repo_root" "$preset_id"
}

repo_review_request_template_problem() {
  local source_path="$1"
  local label="$2"

  if [ ! -e "$source_path" ]; then
    printf '%s does not exist: %s\n' "$label" "$source_path"
    return 1
  fi
  if [ -d "$source_path" ]; then
    printf '%s is a directory: %s\n' "$label" "$source_path"
    return 1
  fi
  if [ ! -f "$source_path" ]; then
    printf '%s is not a regular file: %s\n' "$label" "$source_path"
    return 1
  fi
  if [ ! -r "$source_path" ]; then
    printf '%s is not readable: %s\n' "$label" "$source_path"
    return 1
  fi
  if [ ! -s "$source_path" ]; then
    printf '%s is empty: %s\n' "$label" "$source_path"
    return 1
  fi

  return 0
}

repo_review_request_render_template() {
  local source_path="$1"
  local output_path="$2"
  local pr_url="$3"
  local title="$4"
  local branch="$5"

  REPO_REVIEW_REQUEST_SOURCE="$source_path" \
  REPO_REVIEW_REQUEST_OUTPUT="$output_path" \
  REPO_REVIEW_REQUEST_PR_URL="$pr_url" \
  REPO_REVIEW_REQUEST_TITLE="$title" \
  REPO_REVIEW_REQUEST_BRANCH="$branch" \
  python3 - <<'PY'
from pathlib import Path
import os

source = Path(os.environ["REPO_REVIEW_REQUEST_SOURCE"])
output = Path(os.environ["REPO_REVIEW_REQUEST_OUTPUT"])
pr_url = os.environ["REPO_REVIEW_REQUEST_PR_URL"]
title = os.environ["REPO_REVIEW_REQUEST_TITLE"]
branch = os.environ["REPO_REVIEW_REQUEST_BRANCH"]

text = source.read_text(encoding="utf-8")
text = text.replace("<PR_URL>", pr_url)
text = text.replace("<TITLE>", title)
text = text.replace("<BRANCH>", branch)

if pr_url and pr_url not in text:
    if text and not text.endswith("\n"):
        text += "\n"
    if text:
        text += "\n"
    text += f"PR URL: {pr_url}\n"

output.write_text(text, encoding="utf-8")
PY
}

# repo-automation/lib/review-request.sh EOF
