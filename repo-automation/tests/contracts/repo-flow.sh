#!/usr/bin/env bash
# repo-automation/tests/contracts/repo-flow.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"

smoke_write_repo_flow_gh_stub() {
  local gh_stub_dir="$1"

  mkdir -p "$gh_stub_dir" || return 1
  cat > "$gh_stub_dir/gh" <<'EOF'
#!/usr/bin/env bash
set -u
cmd="${1:-}"
sub="${2:-}"
shift 2 >/dev/null 2>&1 || true

repo_flow_stub_field() {
  local file="$1"
  local line_no="$2"
  sed -n "${line_no}p" "$file" 2>/dev/null || true
}

case "$cmd $sub" in
  'auth status')
    exit 0
    ;;
  'pr view')
    number=""
    url=""
    title=""
    state=""
    if [ -n "${GH_STUB_PR_STATE_FILE:-}" ] && [ -f "$GH_STUB_PR_STATE_FILE" ]; then
      number="$(repo_flow_stub_field "$GH_STUB_PR_STATE_FILE" 1)"
      url="$(repo_flow_stub_field "$GH_STUB_PR_STATE_FILE" 2)"
      title="$(repo_flow_stub_field "$GH_STUB_PR_STATE_FILE" 3)"
      state="$(repo_flow_stub_field "$GH_STUB_PR_STATE_FILE" 4)"
    elif [ -n "${GH_STUB_PR_VIEW_NUMBER:-}" ]; then
      number="${GH_STUB_PR_VIEW_NUMBER:-}"
      url="${GH_STUB_PR_VIEW_URL:-}"
      title="${GH_STUB_PR_VIEW_TITLE:-}"
      state="${GH_STUB_PR_VIEW_STATE:-OPEN}"
    else
      exit 1
    fi
    case " $* " in
      *' --json number '*|*' --jq .number '*)
        printf '%s\n' "$number"
        ;;
      *' --json url '*|*' --jq .url '*)
        printf '%s\n' "$url"
        ;;
      *' --json title '*|*' --jq .title '*)
        printf '%s\n' "$title"
        ;;
      *' --json state '*|*' --jq .state '*)
        printf '%s\n' "$state"
        ;;
      *)
        printf '%s\n' "$number"
        ;;
    esac
    ;;
  'pr create')
    body_file=""
    title=""
    base=""
    head=""
    prev=""
    for arg in "$@"; do
      if [ -n "$prev" ]; then
        case "$prev" in
          --title)
            title="$arg"
            ;;
          --body-file)
            body_file="$arg"
            ;;
          --base)
            base="$arg"
            ;;
          --head)
            head="$arg"
            ;;
        esac
        prev=""
        continue
      fi
      case "$arg" in
        --title|--body-file|--base|--head)
          prev="$arg"
          ;;
      esac
    done
    if [ -n "${GH_STUB_PR_CREATE_LOG_FILE:-}" ]; then
      printf '%s\n' "gh pr create title=$title base=$base head=$head body_file=$body_file" >> "$GH_STUB_PR_CREATE_LOG_FILE"
    fi
    if [ -n "${GH_STUB_PR_STATE_FILE:-}" ]; then
      number="${GH_STUB_PR_CREATE_NUMBER:-401}"
      url="${GH_STUB_PR_CREATE_URL:-https://github.com/i-schuyler/repo-automation-template/pull/$number}"
      title="${title:-repo-flow title}"
      printf '%s\n%s\n%s\nOPEN\n' "$number" "$url" "$title" > "$GH_STUB_PR_STATE_FILE"
      printf '%s\n' "$url"
    else
      printf '%s\n' "${GH_STUB_PR_CREATE_URL:-https://github.com/i-schuyler/repo-automation-template/pull/401}"
    fi
    ;;
  *)
    printf 'gh stub unexpected command: %s %s\n' "$cmd" "$sub" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "$gh_stub_dir/gh" || return 1
}

smoke_prepare_repo_flow_branch() {
  local branch_name="$1"

  (
    cd "$smoke_test_dir" || return 1
    git checkout -b "$branch_name" >/dev/null || return 1
    printf '%s\n' "repo-flow branch $branch_name" >> README.md || return 1
    git add README.md || return 1
    git commit -m "repo-flow branch commit" >/dev/null || return 1
  ) || return 1
}

smoke_prepare_repo_flow_remote() {
  (
    cd "$smoke_test_dir" || return 1
    git remote add localorigin "$smoke_remote_dir" >/dev/null 2>&1 || git remote set-url localorigin "$smoke_remote_dir" || return 1
    python3 - "$smoke_test_dir/.repo-automation.conf" <<'PY' || return 1
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding='utf-8')
text = text.replace('REMOTE_NAME="origin"', 'REMOTE_NAME="localorigin"')
text = text.replace('EXPECTED_REMOTE_URL="git@github.com:i-schuyler/repo-automation-template.git"', 'EXPECTED_REMOTE_URL=""')
path.write_text(text, encoding='utf-8')
PY
    git add .repo-automation.conf || return 1
    git commit -m "temp repo flow config" >/dev/null || return 1
    git fetch localorigin main >/dev/null 2>&1 || return 1
  ) || return 1
}

smoke_check_repo_flow_dry_run_json() {
  local status=0
  local gh_stub_dir=""
  local json_file=""
  local stderr_file=""
  local local_bash_path=""

  smoke_setup_temp_repo || return 1
  smoke_prepare_repo_flow_remote || return 1
  gh_stub_dir="$smoke_test_base/gh-stub"
  json_file="$smoke_test_base/repo-flow-dry-run.json"
  stderr_file="$smoke_test_base/repo-flow-dry-run.stderr"
  smoke_write_repo_flow_gh_stub "$gh_stub_dir" || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-plan" || return 1
  local_bash_path="$(command -v bash)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    REMOTE_NAME=localorigin \
    EXPECTED_REMOTE_URL="" \
    GH_STUB_PR_STATE_FILE="$smoke_test_base/repo-flow-state.txt" \
    "$local_bash_path" repo-automation/bin/repo-flow --dry-run --json > "$json_file" 2> "$stderr_file"
  ) && python -m json.tool "$json_file" >/dev/null; then
    if smoke_json_assert "$json_file" 'data.get("final_status") == "dry-run" and data.get("pr_status") == "would-create" and data.get("push_status") == "needed"'; then
      if [ ! -f "$smoke_test_base/repo-flow-state.txt" ] && ! git -C "$smoke_test_dir" rev-parse --verify refs/remotes/origin/feature/repo-flow-plan >/dev/null 2>&1; then
        test_pass "repo-flow dry-run/json reports a non-mutating create plan"
      else
        test_fail "repo-flow dry-run/json reports a non-mutating create plan"
        status=1
      fi
    else
      test_fail "repo-flow dry-run/json reports a non-mutating create plan"
      status=1
    fi
  else
    test_fail "repo-flow dry-run/json reports a non-mutating create plan"
    status=1
  fi

  return "$status"
}

smoke_check_repo_flow_existing_pr() {
  local status=0
  local gh_stub_dir=""
  local state_file=""
  local create_log_file=""
  local stderr_file=""
  local local_bash_path=""

  smoke_setup_temp_repo || return 1
  smoke_prepare_repo_flow_remote || return 1
  gh_stub_dir="$smoke_test_base/gh-stub"
  state_file="$smoke_test_base/repo-flow-existing-pr.txt"
  create_log_file="$smoke_test_base/repo-flow-existing-pr-create.log"
  stderr_file="$smoke_test_base/repo-flow-existing-pr.stderr"
  smoke_write_repo_flow_gh_stub "$gh_stub_dir" || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-existing" || return 1
  local_bash_path="$(command -v bash)" || return 1
  printf '%s\n%s\n%s\nOPEN\n' \
    '777' \
    'https://github.com/i-schuyler/repo-automation-template/pull/777' \
    'existing repo-flow PR' > "$state_file"

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    REMOTE_NAME=localorigin \
    EXPECTED_REMOTE_URL="" \
    GH_STUB_PR_STATE_FILE="$state_file" \
    GH_STUB_PR_CREATE_LOG_FILE="$create_log_file" \
    "$local_bash_path" repo-automation/bin/repo-flow > /dev/null 2> "$stderr_file"
  ); then
    if grep -q 'PR status: existing #777 https://github.com/i-schuyler/repo-automation-template/pull/777' "$stderr_file" &&
      grep -q 'final status: ready' "$stderr_file" &&
      [ ! -s "$create_log_file" ] &&
      git -C "$smoke_test_dir" rev-parse --verify refs/remotes/localorigin/feature/repo-flow-existing >/dev/null 2>&1; then
      test_pass "repo-flow reuses an existing PR"
    else
      test_fail "repo-flow reuses an existing PR"
      status=1
    fi
  else
    test_fail "repo-flow reuses an existing PR"
    status=1
  fi

  return "$status"
}

smoke_check_repo_flow_create_pr() {
  local status=0
  local gh_stub_dir=""
  local state_file=""
  local create_log_file=""
  local stderr_file=""
  local local_bash_path=""

  smoke_setup_temp_repo || return 1
  smoke_prepare_repo_flow_remote || return 1
  gh_stub_dir="$smoke_test_base/gh-stub"
  state_file="$smoke_test_base/repo-flow-create-pr.txt"
  create_log_file="$smoke_test_base/repo-flow-create-pr.log"
  stderr_file="$smoke_test_base/repo-flow-create-pr.stderr"
  smoke_write_repo_flow_gh_stub "$gh_stub_dir" || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-create" || return 1
  local_bash_path="$(command -v bash)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    REMOTE_NAME=localorigin \
    EXPECTED_REMOTE_URL="" \
    GH_STUB_PR_STATE_FILE="$state_file" \
    GH_STUB_PR_CREATE_LOG_FILE="$create_log_file" \
    GH_STUB_PR_CREATE_NUMBER=888 \
    GH_STUB_PR_CREATE_URL='https://github.com/i-schuyler/repo-automation-template/pull/888' \
    "$local_bash_path" repo-automation/bin/repo-flow > /dev/null 2> "$stderr_file"
  ); then
    if grep -q 'PR status: created #888 https://github.com/i-schuyler/repo-automation-template/pull/888' "$stderr_file" &&
      grep -q 'final status: ready' "$stderr_file" &&
      grep -q 'gh pr create title=' "$create_log_file" &&
      git -C "$smoke_test_dir" rev-parse --verify refs/remotes/localorigin/feature/repo-flow-create >/dev/null 2>&1 &&
      [ -f "$state_file" ] &&
      grep -q '^888$' "$state_file"; then
      test_pass "repo-flow creates a PR for a new published branch"
    else
      test_fail "repo-flow creates a PR for a new published branch"
      status=1
    fi
  else
    test_fail "repo-flow creates a PR for a new published branch"
    status=1
  fi

  return "$status"
}

smoke_main() {
  local status=0

  smoke_run_named_check "smoke:repo-flow-dry-run-json" smoke_check_repo_flow_dry_run_json || status=1
  smoke_run_named_check "smoke:repo-flow-existing-pr" smoke_check_repo_flow_existing_pr || status=1
  smoke_run_named_check "smoke:repo-flow-create-pr" smoke_check_repo_flow_create_pr || status=1

  return "$status"
}

smoke_main "$@"
# repo-automation/tests/contracts/repo-flow.sh EOF
