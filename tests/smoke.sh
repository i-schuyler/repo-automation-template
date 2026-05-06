#!/usr/bin/env bash
# tests/smoke.sh

set -u
set -o pipefail

smoke_info() {
  printf 'PASS: %s\n' "$1"
}

smoke_fail() {
  printf 'FAIL: %s\n' "$1" >&2
}

smoke_json_assert() {
  local json_file="$1"
  local check_code="$2"
  if python - "$json_file" "$check_code" <<'PY'
import json
import pathlib
import sys

json_path = pathlib.Path(sys.argv[1])
check_code = sys.argv[2]
data = json.loads(json_path.read_text(encoding="utf-8"))
globals_dict = {"data": data}
ok = eval(check_code, {}, globals_dict)  # controlled local test expression
sys.exit(0 if ok else 1)
PY
  then
    return 0
  fi

  return 1
}

smoke_main() {
  local repo_root
  local test_base
  local test_dir=""
  local remote_dir
  local expected_origin_url="git@github.com:i-schuyler/repo-automation-template.git"
  local start_branch
  local branch_json
  local preflight_json
  local status=0

  repo_root="$(cd "$(dirname "$0")/.." && pwd)"
  test_base="${TMPDIR:-$HOME/.cache}/repo-automation-template-tests"
  test_dir="$test_base/smoke-$$"
  remote_dir="$test_dir/remote.git"
  mkdir -p "$test_dir" || return 1
  trap '[ -n "${test_dir:-}" ] && rm -rf "$test_dir"' EXIT INT TERM

  mkdir -p "$test_dir/scripts/lib" || return 1
  cp "$repo_root/scripts/lib/repo-automation-common.sh" "$test_dir/scripts/lib/repo-automation-common.sh" || return 1
  cp "$repo_root/scripts/branch-cleanup" "$test_dir/scripts/branch-cleanup" || return 1
  cp "$repo_root/scripts/codex-slice-preflight" "$test_dir/scripts/codex-slice-preflight" || return 1
  chmod +x "$test_dir/scripts/branch-cleanup" "$test_dir/scripts/codex-slice-preflight" || return 1

  (
    cd "$test_dir" || return 1
    git init -b main >/dev/null || return 1
    git config user.name "repo-automation-test" || return 1
    git config user.email "repo-automation-test@example.com" || return 1
    echo "# smoke" > README.md
    git add README.md || return 1
    git commit -m "init" >/dev/null || return 1
    git init --bare --initial-branch=main "$remote_dir" >/dev/null || return 1
    git remote add origin "$remote_dir" || return 1
    git push -u origin main >/dev/null || return 1
    git remote set-url origin "$expected_origin_url" || return 1
    git update-ref refs/remotes/origin/main "$(git rev-parse main)" || return 1
    cat > .repo-automation.conf <<EOF
# .repo-automation.conf
REPO_AUTOMATION_CONF_VERSION="0.1"
REPO_AUTOMATION_VERSION="0.1.0"
UPSTREAM_REPO_FULL_NAME="i-schuyler/repo-automation-template"
UPSTREAM_ISSUE_URL="https://github.com/i-schuyler/repo-automation-template/issues/new/choose"
INSTALLED_FROM="i-schuyler/repo-automation-template"
INSTALLED_VERSION_OR_REF="0.1.0"
INSTALLED_AT="2026-05-06"
LOCAL_OVERRIDES_DOC="docs/repo-automation/local-overrides.md"
DEFAULT_BRANCH="main"
DOCS_DIR="docs"
DOCS_INDEX="docs/INDEX.md"
STATE_DIR_NAME="repo-automation-template-tests"
REMOTE_NAME="origin"
EXPECTED_REMOTE_URL="$expected_origin_url"
PREFLIGHT_REQUIRE_CLEAN_WORKTREE="true"
CI_PROVIDER="github"
PR_PROVIDER="github"
MERGE_MODE="squash"
DOC_PR_TIMEOUT_SECONDS=60
DOC_PR_POLL_SECONDS=10
IMPLEMENTATION_PR_TIMEOUT_SECONDS=300
IMPLEMENTATION_PR_POLL_SECONDS=15
DOC_BRANCH_PREFIX="docs"
FEATURE_BRANCH_PREFIX="feature"
FIX_BRANCH_PREFIX="fix"
CHECK_PROFILE_DEFAULT="docs"
CHECK_PROFILE_DOCS_COMMANDS=("git diff --check")
CHECK_PROFILE_NONE_COMMANDS=()
# .repo-automation.conf EOF
EOF
    git add .repo-automation.conf scripts >/dev/null || return 1
    git commit -m "add test automation files" >/dev/null || return 1
    git update-ref refs/remotes/origin/main "$(git rev-parse main)" || return 1
    return 0
  ) || return 1

  if (
    cd "$test_dir" || return 1
    scripts/branch-cleanup --plan >/dev/null
  ); then
    smoke_info "branch-cleanup plan succeeds"
  else
    smoke_fail "branch-cleanup plan succeeds"
    status=1
  fi

  branch_json="$test_dir/branch-cleanup.json"
  if (
    cd "$test_dir" || return 1
    scripts/branch-cleanup --json --plan > "$branch_json"
  ) && python -m json.tool "$branch_json" >/dev/null; then
    smoke_info "branch-cleanup json is parseable"
  else
    smoke_fail "branch-cleanup json is parseable"
    status=1
  fi

  (
    cd "$test_dir" || return 1
    git checkout -b docs/merged-branch >/dev/null || return 1
    echo "merged" >> README.md
    git add README.md || return 1
    git commit -m "merged branch commit" >/dev/null || return 1
    git checkout main >/dev/null || return 1
    git merge --no-ff docs/merged-branch -m "merge docs branch" >/dev/null || return 1
    git update-ref refs/remotes/origin/main "$(git rev-parse main)" || return 1
    git checkout -b feature/unique-branch >/dev/null || return 1
    echo "unique" >> README.md
    git add README.md || return 1
    git commit -m "unique branch commit" >/dev/null || return 1
    start_branch="$(git branch --show-current)"
    [ "$start_branch" = "feature/unique-branch" ]
  ) || status=1

  (
    cd "$test_dir" || return 1
    scripts/branch-cleanup --json --plan > "$branch_json"
  ) || status=1

  if smoke_json_assert "$branch_json" '"docs/merged-branch" in data.get("candidates", [])'; then
    smoke_info "merged local branch classified as candidate"
  else
    smoke_fail "merged local branch classified as candidate"
    status=1
  fi

  if smoke_json_assert "$branch_json" 'any(item.get("branch") == "feature/unique-branch" and item.get("reason") == "current-branch" for item in data.get("skipped", []))'; then
    smoke_info "current branch skipped with current-branch reason"
  else
    smoke_fail "current branch skipped with current-branch reason"
    status=1
  fi

  if smoke_json_assert "$branch_json" 'any(item.get("branch") == "main" and item.get("reason") == "default-branch" for item in data.get("skipped", []))'; then
    smoke_info "default branch skipped with default-branch reason"
  else
    smoke_fail "default branch skipped with default-branch reason"
    status=1
  fi

  if smoke_json_assert "$branch_json" 'any(item.get("branch") == "feature/unique-branch" and item.get("reason") in ("current-branch", "has-unique-commits", "not-merged-into-origin-default") for item in data.get("skipped", []))'; then
    smoke_info "unique branch shows expected non-candidate reason"
  else
    smoke_fail "unique branch shows expected non-candidate reason"
    status=1
  fi

  if (
    cd "$test_dir" || return 1
    git checkout main >/dev/null || return 1
    scripts/codex-slice-preflight --check-only --branch feature/preflight-smoke >/dev/null
  ); then
    smoke_info "preflight check-only succeeds"
  else
    smoke_fail "preflight check-only succeeds"
    status=1
  fi

  preflight_json="$test_dir/preflight.json"
  if (
    cd "$test_dir" || return 1
    scripts/codex-slice-preflight --json --check-only --branch feature/preflight-smoke > "$preflight_json"
  ) && python -m json.tool "$preflight_json" >/dev/null; then
    smoke_info "preflight json is parseable"
  else
    smoke_fail "preflight json is parseable"
    status=1
  fi

  return "$status"
}

smoke_main "$@"
# tests/smoke.sh EOF
