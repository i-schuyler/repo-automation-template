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
    if [ "${GH_STUB_PR_VIEW_EMPTY:-0}" -eq 1 ] 2>/dev/null; then
      exit 1
    fi
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

smoke_write_repo_flow_ssh_stub() {
  local ssh_stub_dir="$1"

  mkdir -p "$ssh_stub_dir" || return 1
  cat > "$ssh_stub_dir/ssh" <<'EOF'
#!/usr/bin/env bash
set -u
if [ "${1:-}" = "-G" ]; then
  case "${2:-}" in
    github-alias)
      printf 'hostname github.com\n'
      ;;
    gitlab-alias)
      printf 'hostname gitlab.com\n'
      ;;
    *)
      printf 'hostname example.com\n'
      ;;
  esac
  exit 0
fi
printf 'ssh stub unexpected args\n' >&2
exit 1
EOF
  chmod +x "$ssh_stub_dir/ssh" || return 1
}

smoke_prepare_repo_flow_branch() {
  local branch_name="$1"

  (
    # shellcheck disable=SC2154 # smoke_test_dir is provided by the smoke harness.
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
    # shellcheck disable=SC2154 # smoke_remote_dir is provided by the smoke harness.
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
    if ! git diff --quiet -- .repo-automation.conf; then
      git add .repo-automation.conf || return 1
      git commit -m "temp repo flow config" >/dev/null || return 1
    fi
    git fetch localorigin main >/dev/null 2>&1 || return 1
  ) || return 1
}

smoke_prepare_repo_flow_submit_remote_validation() {
  local remote_url="$1"
  local expected_remote_url="$2"

  (
    cd "$smoke_test_dir" || return 1
    git remote set-url origin "$remote_url" >/dev/null 2>&1 || git remote add origin "$remote_url" >/dev/null 2>&1 || return 1
    python3 - "$smoke_test_dir/.repo-automation.conf" "$expected_remote_url" <<'PY' || return 1
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
expected = sys.argv[2]
text = path.read_text(encoding='utf-8')
text = re.sub(r'^EXPECTED_REMOTE_URL=".*"$', f'EXPECTED_REMOTE_URL="{expected}"', text, flags=re.M)
text = re.sub(r'^REMOTE_NAME=".*"$', 'REMOTE_NAME="origin"', text, flags=re.M)
path.write_text(text, encoding='utf-8')
PY
    if ! git diff --quiet -- .repo-automation.conf; then
      git add .repo-automation.conf || return 1
      git commit -m "temp repo flow config" >/dev/null || return 1
    fi
  ) || return 1
}

smoke_check_repo_flow_status_card_clean_main() {
  local status=0
  local gh_stub_dir=""
  local human_out=""
  local stderr_file=""
  local create_log_file=""
  local expected_file=""
  local head_before=""
  local head_after=""
  local status_before=""
  local status_after=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  human_out="$smoke_test_base/repo-flow-status-card-main.txt"
  stderr_file="$smoke_test_base/repo-flow-status-card-main.stderr"
  create_log_file="$smoke_test_base/repo-flow-status-card-main-create.log"
  expected_file="$smoke_test_base/repo-flow-status-card-main.expected"
  smoke_write_repo_flow_gh_stub "$gh_stub_dir" || return 1

  head_before="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1
  status_before="$(git -C "$smoke_test_dir" status --porcelain --untracked-files=all)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_VIEW_EMPTY=1 \
    GH_STUB_PR_CREATE_LOG_FILE="$create_log_file" \
    repo-automation/bin/repo-flow status-card > "$human_out" 2> "$stderr_file"
  ) && [ ! -s "$stderr_file" ] && [ ! -f "$create_log_file" ]; then
    cat > "$expected_file" <<'EOF'
branch: main
default: main
worktree: clean
tracked_changed: none
untracked: none
range_vs_default: none
ahead_behind: ahead=0 behind=0
pr: none
checks: no-pr
next: create feature branch
EOF
    head_after="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1
    status_after="$(git -C "$smoke_test_dir" status --porcelain --untracked-files=all)" || return 1
    if cmp -s "$expected_file" "$human_out" &&
      [ "$head_before" = "$head_after" ] &&
      [ "$status_before" = "$status_after" ]; then
      test_pass "repo-flow status-card reports clean main state"
    else
      test_fail "repo-flow status-card reports clean main state"
      status=1
    fi
  else
    test_fail "repo-flow status-card reports clean main state"
    status=1
  fi

  return "$status"
}

smoke_check_repo_flow_status_card_feature_no_pr() {
  local status=0
  local gh_stub_dir=""
  local human_out=""
  local stderr_file=""
  local create_log_file=""
  local expected_file=""
  local remote_branch_ref=""
  local head_before=""
  local head_after=""
  local status_before=""
  local status_after=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  human_out="$smoke_test_base/repo-flow-status-card-feature-no-pr.txt"
  stderr_file="$smoke_test_base/repo-flow-status-card-feature-no-pr.stderr"
  create_log_file="$smoke_test_base/repo-flow-status-card-feature-no-pr-create.log"
  expected_file="$smoke_test_base/repo-flow-status-card-feature-no-pr.expected"
  remote_branch_ref="refs/heads/feature/repo-flow-status-card-no-pr"
  smoke_write_repo_flow_gh_stub "$gh_stub_dir" || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-status-card-no-pr" || return 1

  head_before="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1
  status_before="$(git -C "$smoke_test_dir" status --porcelain --untracked-files=all)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_VIEW_EMPTY=1 \
    GH_STUB_PR_CREATE_LOG_FILE="$create_log_file" \
    repo-automation/bin/repo-flow status-card > "$human_out" 2> "$stderr_file"
  ) && [ ! -s "$stderr_file" ] && [ ! -f "$create_log_file" ] && ! git --git-dir="$smoke_remote_dir" rev-parse --verify "$remote_branch_ref" >/dev/null 2>&1; then
    cat > "$expected_file" <<'EOF'
branch: feature/repo-flow-status-card-no-pr
default: main
worktree: clean
tracked_changed: none
untracked: none
range_vs_default: 1
ahead_behind: ahead=1 behind=0
pr: none
checks: no-pr
next: repo-automation/bin/repo-flow --dry-run
EOF
    head_after="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1
    status_after="$(git -C "$smoke_test_dir" status --porcelain --untracked-files=all)" || return 1
    if cmp -s "$expected_file" "$human_out" &&
      [ "$head_before" = "$head_after" ] &&
      [ "$status_before" = "$status_after" ]; then
      test_pass "repo-flow status-card reports a feature branch without a PR"
    else
      test_fail "repo-flow status-card reports a feature branch without a PR"
      status=1
    fi
  else
    test_fail "repo-flow status-card reports a feature branch without a PR"
    status=1
  fi

  return "$status"
}

smoke_check_repo_flow_status_card_existing_pr() {
  local status=0
  local gh_stub_dir=""
  local human_out=""
  local json_out=""
  local json_stderr_file=""
  local stderr_file=""
  local create_log_file=""
  local expected_file=""
  local remote_branch_ref=""
  local head_before=""
  local head_after=""
  local status_before=""
  local status_after=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  human_out="$smoke_test_base/repo-flow-status-card-existing-pr.txt"
  json_out="$smoke_test_base/repo-flow-status-card-existing-pr.json"
  json_stderr_file="$smoke_test_base/repo-flow-status-card-existing-pr-json.stderr"
  stderr_file="$smoke_test_base/repo-flow-status-card-existing-pr.stderr"
  create_log_file="$smoke_test_base/repo-flow-status-card-existing-pr-create.log"
  expected_file="$smoke_test_base/repo-flow-status-card-existing-pr.expected"
  remote_branch_ref="refs/heads/feature/repo-flow-status-card-pr"
  smoke_write_gh_stub "$gh_stub_dir" || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-status-card-pr" || return 1

  head_before="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1
  status_before="$(git -C "$smoke_test_dir" status --porcelain --untracked-files=all)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_VIEW_NUMBER=901 \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/901' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pending","state":"IN_PROGRESS","workflow":"ci"}]' \
    GH_STUB_PR_CREATE_LOG_FILE="$create_log_file" \
    repo-automation/bin/repo-flow status-card > "$human_out" 2> "$stderr_file"
  ) && [ ! -s "$stderr_file" ] && [ ! -f "$create_log_file" ] && ! git --git-dir="$smoke_remote_dir" rev-parse --verify "$remote_branch_ref" >/dev/null 2>&1; then
    cat > "$expected_file" <<'EOF'
branch: feature/repo-flow-status-card-pr
default: main
worktree: clean
tracked_changed: none
untracked: none
range_vs_default: 1
ahead_behind: ahead=1 behind=0
pr: #901 open https://github.com/i-schuyler/repo-automation-template/pull/901
checks: pending
next: repo-automation/bin/ci-watch --pr=901 --poll-seconds=5 --timeout=900
EOF
    head_after="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1
    status_after="$(git -C "$smoke_test_dir" status --porcelain --untracked-files=all)" || return 1
    if cmp -s "$expected_file" "$human_out" &&
      [ "$head_before" = "$head_after" ] &&
      [ "$status_before" = "$status_after" ] &&
      (
        cd "$smoke_test_dir" || return 1
        PATH="$gh_stub_dir:$PATH" \
        GH_STUB_PR_VIEW_NUMBER=901 \
        GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/901' \
        GH_STUB_PR_VIEW_STATE='OPEN' \
        GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pending","state":"IN_PROGRESS","workflow":"ci"}]' \
        repo-automation/bin/repo-flow status-card --json > "$json_out" 2> "$json_stderr_file"
      ) && [ ! -s "$json_stderr_file" ] && python3 -m json.tool "$json_out" >/dev/null && smoke_json_assert "$json_out" 'data.get("mode") == "status-card" and data.get("branch") == "feature/repo-flow-status-card-pr" and data.get("pr_number") == 901 and data.get("checks_state") == "pending" and data.get("next_action") == "repo-automation/bin/ci-watch --pr=901 --poll-seconds=5 --timeout=900" and data.get("overall_status") == "pass"'; then
      test_pass "repo-flow status-card reports an open PR and parseable JSON"
    else
      test_fail "repo-flow status-card reports an open PR and parseable JSON"
      status=1
    fi
  else
    test_fail "repo-flow status-card reports an open PR and parseable JSON"
    status=1
  fi

  return "$status"
}

smoke_check_repo_flow_status_card_skipped_checks() {
  local status=0
  local gh_stub_dir=""
  local human_out=""
  local stderr_file=""
  local create_log_file=""
  local expected_file=""
  local head_before=""
  local head_after=""
  local status_before=""
  local status_after=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  human_out="$smoke_test_base/repo-flow-status-card-skipped-checks.txt"
  stderr_file="$smoke_test_base/repo-flow-status-card-skipped-checks.stderr"
  create_log_file="$smoke_test_base/repo-flow-status-card-skipped-checks-create.log"
  expected_file="$smoke_test_base/repo-flow-status-card-skipped-checks.expected"
  smoke_write_gh_stub "$gh_stub_dir" || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-status-card-skipped" || return 1

  head_before="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1
  status_before="$(git -C "$smoke_test_dir" status --porcelain --untracked-files=all)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_VIEW_NUMBER=902 \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/902' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_CHECKS_JSON='[{"name":"docs","bucket":"skipped","state":"SKIPPED","workflow":"ci"}]' \
    GH_STUB_PR_CREATE_LOG_FILE="$create_log_file" \
    repo-automation/bin/repo-flow status-card > "$human_out" 2> "$stderr_file"
  ) && [ ! -s "$stderr_file" ] && [ ! -f "$create_log_file" ]; then
    cat > "$expected_file" <<'EOF'
branch: feature/repo-flow-status-card-skipped
default: main
worktree: clean
tracked_changed: none
untracked: none
range_vs_default: 1
ahead_behind: ahead=1 behind=0
pr: #902 open https://github.com/i-schuyler/repo-automation-template/pull/902
checks: unknown
next: inspect CI status
EOF
    head_after="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1
    status_after="$(git -C "$smoke_test_dir" status --porcelain --untracked-files=all)" || return 1
    if cmp -s "$expected_file" "$human_out" &&
      [ "$head_before" = "$head_after" ] &&
      [ "$status_before" = "$status_after" ]; then
      test_pass "repo-flow status-card treats skipped-only checks as non-blocking"
    else
      test_fail "repo-flow status-card treats skipped-only checks as non-blocking"
      status=1
    fi
  else
    test_fail "repo-flow status-card treats skipped-only checks as non-blocking"
    status=1
  fi

  return "$status"
}

smoke_check_repo_flow_status_card_contract() {
  local status=0
  local help_out=""
  local unknown_stderr=""
  local local_bash_path=""
  local gh_stub_dir=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  help_out="$smoke_test_base/repo-flow-status-card-help.txt"
  unknown_stderr="$smoke_test_base/repo-flow-status-card-unknown.stderr"
  smoke_write_gh_stub "$gh_stub_dir" || return 1
  local_bash_path="$(command -v bash)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow status-card --help > "$help_out"
  ) && grep -Fxq 'Usage: repo-automation/bin/repo-flow status-card [--json] [--help]' "$help_out"; then
    test_pass "repo-flow status-card help shows strict syntax"
  else
    test_fail "repo-flow status-card help shows strict syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow status-card --whatever >/dev/null 2> "$unknown_stderr"
  ); then
    test_fail "repo-flow status-card rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/repo-flow status-card --help"; then
    test_pass "repo-flow status-card rejects unknown flags"
  else
    test_fail "repo-flow status-card rejects unknown flags"
    status=1
  fi

  return "$status"
}

smoke_check_repo_flow_dry_run_json() {
  local status=0
  local gh_stub_dir=""
  local json_file=""
  local stderr_file=""
  local dry_run_out=""
  local dry_run_err=""
  local explain_out=""
  local explain_err=""
  local help_out=""
  local unknown_flag_stderr=""
  local local_bash_path=""

  smoke_setup_temp_repo || return 1
  smoke_prepare_repo_flow_remote || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  json_file="$smoke_test_base/repo-flow-dry-run.json"
  stderr_file="$smoke_test_base/repo-flow-dry-run.stderr"
  dry_run_out="$smoke_test_base/repo-flow-dry-run.out"
  dry_run_err="$smoke_test_base/repo-flow-dry-run.err"
  explain_out="$smoke_test_base/repo-flow-dry-run-explain.out"
  explain_err="$smoke_test_base/repo-flow-dry-run-explain.err"
  help_out="$smoke_test_base/repo-flow-help.txt"
  unknown_flag_stderr="$smoke_test_base/repo-flow-unknown.stderr"
  smoke_write_repo_flow_gh_stub "$gh_stub_dir" || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-plan" || return 1
  local_bash_path="$(command -v bash)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow --help > "$help_out"
  ) && grep -Fq -- '--explain' "$help_out" && grep -Fq -- '--dry-run' "$help_out"; then
    test_pass "repo-flow help shows strict syntax"
  else
    test_fail "repo-flow help shows strict syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" REMOTE_NAME=localorigin EXPECTED_REMOTE_URL="" "$local_bash_path" repo-automation/bin/repo-flow --dry-run > "$dry_run_out" 2> "$dry_run_err"
  ) && [ "$(cat "$dry_run_out")" = "plan" ] && [ ! -s "$dry_run_err" ]; then
    test_pass "repo-flow dry-run output is compact"
  else
    test_fail "repo-flow dry-run output is compact"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" REMOTE_NAME=localorigin EXPECTED_REMOTE_URL="" "$local_bash_path" repo-automation/bin/repo-flow --dry-run --explain > "$explain_out" 2> "$explain_err"
  ) && [ ! -s "$explain_out" ] && grep -Fq 'final status:' "$explain_err"; then
    test_pass "repo-flow explain output is detailed"
  else
    test_fail "repo-flow explain output is detailed"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    REMOTE_NAME=localorigin \
    EXPECTED_REMOTE_URL="" \
    GH_STUB_PR_STATE_FILE="$smoke_test_base/repo-flow-state.txt" \
    "$local_bash_path" repo-automation/bin/repo-flow --dry-run --json > "$json_file" 2> "$stderr_file"
  ) && python3 -m json.tool "$json_file" >/dev/null; then
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

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    REMOTE_NAME=localorigin \
    EXPECTED_REMOTE_URL="" \
    "$local_bash_path" repo-automation/bin/repo-flow --whatever >/dev/null 2> "$unknown_flag_stderr"
  ); then
    test_fail "repo-flow rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$unknown_flag_stderr" "unknown flag" "--whatever" "run repo-automation/bin/repo-flow --help"; then
    test_pass "repo-flow rejects unknown flags"
  else
    test_fail "repo-flow rejects unknown flags"
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
  local stdout_file=""
  local local_bash_path=""

  smoke_setup_temp_repo || return 1
  smoke_prepare_repo_flow_remote || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  state_file="$smoke_test_base/repo-flow-existing-pr.txt"
  create_log_file="$smoke_test_base/repo-flow-existing-pr-create.log"
  stderr_file="$smoke_test_base/repo-flow-existing-pr.stderr"
  stdout_file="$smoke_test_base/repo-flow-existing-pr.out"
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
    "$local_bash_path" repo-automation/bin/repo-flow > "$stdout_file" 2> "$stderr_file"
  ); then
    if [ "$(cat "$stdout_file")" = "https://github.com/i-schuyler/repo-automation-template/pull/777" ] &&
      [ ! -s "$stderr_file" ] &&
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
  local stdout_file=""
  local local_bash_path=""

  smoke_setup_temp_repo || return 1
  smoke_prepare_repo_flow_remote || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  state_file="$smoke_test_base/repo-flow-create-pr.txt"
  create_log_file="$smoke_test_base/repo-flow-create-pr.log"
  stderr_file="$smoke_test_base/repo-flow-create-pr.stderr"
  stdout_file="$smoke_test_base/repo-flow-create-pr.out"
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
    "$local_bash_path" repo-automation/bin/repo-flow > "$stdout_file" 2> "$stderr_file"
  ); then
    if [ "$(cat "$stdout_file")" = "https://github.com/i-schuyler/repo-automation-template/pull/888" ] &&
      [ ! -s "$stderr_file" ] &&
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

smoke_check_repo_flow_submit_paths() {
  local status=0
  local gh_stub_dir=""
  local stdout_file=""
  local stderr_file=""
  local head_before=""
  local head_after=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  stdout_file="$smoke_test_base/repo-flow-submit-paths.out"
  stderr_file="$smoke_test_base/repo-flow-submit-paths.stderr"
  create_log_file="$smoke_test_base/repo-flow-submit-paths-create.log"
  smoke_write_repo_flow_gh_stub "$gh_stub_dir" || return 1
  smoke_prepare_repo_flow_remote || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-paths" || return 1

  printf '\nrepo-flow submit paths line\n' >> "$smoke_test_dir/README.md" || return 1
  head_before="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_CREATE_LOG_FILE="$create_log_file" \
    GH_STUB_PR_CREATE_URL='https://github.com/i-schuyler/repo-automation-template/pull/701' \
    GH_STUB_PR_VIEW_EMPTY=1 \
    repo-automation/bin/repo-flow submit --paths=README.md --message='repo-flow submit paths commit' > "$stdout_file" 2> "$stderr_file"
  ) && [ "$(cat "$stdout_file")" = 'https://github.com/i-schuyler/repo-automation-template/pull/701' ] && [ -f "$create_log_file" ]; then
    head_after="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1
    if [ "$head_before" != "$head_after" ] && git -C "$smoke_test_dir" log -1 --pretty=%s | grep -Fxq 'repo-flow submit paths commit'; then
      test_pass "repo-flow submit stages explicit paths and creates a PR"
    else
      test_fail "repo-flow submit stages explicit paths and creates a PR"
      status=1
    fi
  else
    test_fail "repo-flow submit stages explicit paths and creates a PR"
    status=1
  fi

  return "$status"
}

smoke_check_repo_flow_submit_staged_watch() {
  local status=0
  local gh_stub_dir=""
  local stdout_file=""
  local stderr_file=""
  local head_before=""
  local head_after=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  stdout_file="$smoke_test_base/repo-flow-submit-staged-watch.out"
  stderr_file="$smoke_test_base/repo-flow-submit-staged-watch.stderr"
  smoke_write_gh_stub "$gh_stub_dir" || return 1
  smoke_prepare_repo_flow_remote || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-staged-watch" || return 1

  printf '\nrepo-flow submit staged line\n' >> "$smoke_test_dir/docs/testing.md" || return 1
  git -C "$smoke_test_dir" add docs/testing.md || return 1
  head_before="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_VIEW_NUMBER=702 \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/702' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_MERGEABLE='MERGEABLE' \
    GH_STUB_PR_CHECKS_JSON='[{"name":"build","bucket":"pass","state":"SUCCESS","workflow":"ci"}]' \
    repo-automation/bin/repo-flow submit --staged --message='repo-flow submit staged commit' --watch --diagnose-on-fail > "$stdout_file" 2> "$stderr_file"
  ) && [ "$(cat "$stdout_file")" = 'https://github.com/i-schuyler/repo-automation-template/pull/702' ]; then
    head_after="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1
    if [ "$head_before" != "$head_after" ] && git -C "$smoke_test_dir" log -1 --pretty=%s | grep -Fxq 'repo-flow submit staged commit'; then
      test_pass "repo-flow submit commits staged changes and watches the PR"
    else
      test_fail "repo-flow submit commits staged changes and watches the PR"
      status=1
    fi
  else
    test_fail "repo-flow submit commits staged changes and watches the PR"
    status=1
  fi

  return "$status"
}

smoke_check_repo_flow_submit_contract() {
  local status=0
  local gh_stub_dir=""
  local help_out=""
  local invalid_abs_stderr=""
  local invalid_dotdot_stderr=""
  local missing_stderr=""
  local staged_guard_stderr=""
  local unrequested_dirty_stderr=""
  local canonical_remote_stderr=""
  local alias_remote_stderr=""
  local rejected_remote_stderr=""
  local local_bash_path=""
  local ssh_stub_dir=""
  local status_before=""
  local status_after=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  help_out="$smoke_test_base/repo-flow-submit-help.txt"
  invalid_abs_stderr="$smoke_test_base/repo-flow-submit-invalid-abs.stderr"
  invalid_dotdot_stderr="$smoke_test_base/repo-flow-submit-invalid-dotdot.stderr"
  missing_stderr="$smoke_test_base/repo-flow-submit-missing.stderr"
  staged_guard_stderr="$smoke_test_base/repo-flow-submit-staged-guard.stderr"
  unrequested_dirty_stderr="$smoke_test_base/repo-flow-submit-unrequested-dirty.stderr"
  canonical_remote_stderr="$smoke_test_base/repo-flow-submit-canonical-remote.stderr"
  alias_remote_stderr="$smoke_test_base/repo-flow-submit-alias-remote.stderr"
  rejected_remote_stderr="$smoke_test_base/repo-flow-submit-rejected-remote.stderr"
  ssh_stub_dir="$smoke_test_base/ssh-stub"
  smoke_write_gh_stub "$gh_stub_dir" || return 1
  local_bash_path="$(command -v bash)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --help > "$help_out"
  ) && grep -Fxq 'Usage: repo-automation/bin/repo-flow submit [--paths=<path[,path...]>|--staged] --message=<text> [--watch] [--diagnose-on-fail] [--explain] [--help]' "$help_out"; then
    test_pass "repo-flow submit help shows strict syntax"
  else
    test_fail "repo-flow submit help shows strict syntax"
    status=1
  fi

  smoke_prepare_repo_flow_remote || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-validation" || return 1

  smoke_write_repo_flow_ssh_stub "$ssh_stub_dir" || return 1
  smoke_prepare_repo_flow_submit_remote_validation 'git@github.com:i-schuyler/repo-automation-template.git' 'git@github.com:i-schuyler/repo-automation-template.git' || return 1
  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --paths=missing.txt --message=hi >/dev/null 2> "$canonical_remote_stderr"
  ); then
    test_fail "repo-flow submit accepts the exact canonical remote"
    status=1
  elif grep -Fq 'STOP: missing untracked path: missing.txt' "$canonical_remote_stderr"; then
    test_pass "repo-flow submit accepts the exact canonical remote"
  else
    test_fail "repo-flow submit accepts the exact canonical remote"
    status=1
  fi

  smoke_prepare_repo_flow_submit_remote_validation 'git@github-alias:i-schuyler/repo-automation-template.git' 'git@github.com:i-schuyler/repo-automation-template.git' || return 1
  if (
    cd "$smoke_test_dir" || return 1
    PATH="$ssh_stub_dir:$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --paths=missing.txt --message=hi >/dev/null 2> "$alias_remote_stderr"
  ); then
    test_fail "repo-flow submit accepts a GitHub SSH alias"
    status=1
  elif grep -Fq 'STOP: missing untracked path: missing.txt' "$alias_remote_stderr"; then
    test_pass "repo-flow submit accepts a GitHub SSH alias"
  else
    test_fail "repo-flow submit accepts a GitHub SSH alias"
    status=1
  fi

  smoke_prepare_repo_flow_submit_remote_validation 'git@gitlab-alias:i-schuyler/repo-automation-template.git' 'git@github.com:i-schuyler/repo-automation-template.git' || return 1
  if (
    cd "$smoke_test_dir" || return 1
    PATH="$ssh_stub_dir:$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --paths=docs/testing.md --message=hi >/dev/null 2> "$rejected_remote_stderr"
  ); then
    test_fail "repo-flow submit rejects a non-GitHub SSH alias"
    status=1
  elif grep -Fq 'STOP: remote URL mismatch for origin:' "$rejected_remote_stderr" && grep -Fq 'git@gitlab-alias:i-schuyler/repo-automation-template.git' "$rejected_remote_stderr"; then
    test_pass "repo-flow submit rejects a non-GitHub SSH alias"
  else
    test_fail "repo-flow submit rejects a non-GitHub SSH alias"
    status=1
  fi

  smoke_prepare_repo_flow_submit_remote_validation 'git@github.com:i-schuyler/repo-automation-template.git' 'git@github.com:i-schuyler/repo-automation-template.git' || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --paths=/tmp/example --message=hi >/dev/null 2> "$invalid_abs_stderr"
  ); then
    test_fail "repo-flow submit rejects absolute paths"
    status=1
  elif grep -Fxq 'STOP: absolute paths are not allowed: /tmp/example' "$invalid_abs_stderr"; then
    test_pass "repo-flow submit rejects absolute paths"
  else
    test_fail "repo-flow submit rejects absolute paths"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --paths=docs/../README.md --message=hi >/dev/null 2> "$invalid_dotdot_stderr"
  ); then
    test_fail "repo-flow submit rejects .. paths"
    status=1
  elif grep -Fxq 'STOP: path contains ..: docs/../README.md' "$invalid_dotdot_stderr"; then
    test_pass "repo-flow submit rejects .. paths"
  else
    test_fail "repo-flow submit rejects .. paths"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --paths=missing.txt --message=hi >/dev/null 2> "$missing_stderr"
  ); then
    test_fail "repo-flow submit rejects missing untracked paths"
    status=1
  elif grep -Fxq 'STOP: missing untracked path: missing.txt' "$missing_stderr"; then
    test_pass "repo-flow submit rejects missing untracked paths"
  else
    test_fail "repo-flow submit rejects missing untracked paths"
    status=1
  fi

  smoke_prepare_repo_flow_remote || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-staged-guard" || return 1
  printf '\nrepo-flow submit staged guard line\n' >> "$smoke_test_dir/docs/testing.md" || return 1
  git -C "$smoke_test_dir" add docs/testing.md || return 1
  printf '\nrepo-flow submit extra staged line\n' >> "$smoke_test_dir/README.md" || return 1
  git -C "$smoke_test_dir" add README.md || return 1
  status_before="$(git -C "$smoke_test_dir" status --porcelain --untracked-files=all)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --paths=docs/testing.md --message=hi >/dev/null 2> "$staged_guard_stderr"
  ); then
    test_fail "repo-flow submit rejects unrequested changes before staging when using --paths"
    status=1
  elif grep -Fxq 'STOP: unrequested working tree changes remain; commit a clean explicit submit' "$staged_guard_stderr"; then
    status_after="$(git -C "$smoke_test_dir" status --porcelain --untracked-files=all)" || return 1
    if [ "$status_before" = "$status_after" ]; then
      test_pass "repo-flow submit rejects unrequested changes before staging when using --paths"
    else
      test_fail "repo-flow submit rejects unrequested changes before staging when using --paths"
      status=1
    fi
  else
    test_fail "repo-flow submit rejects unrequested changes before staging when using --paths"
    status=1
  fi

  smoke_prepare_repo_flow_remote || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-unrequested-dirty" || return 1
  printf '\nrepo-flow submit requested line\n' >> "$smoke_test_dir/docs/testing.md" || return 1
  printf '\nrepo-flow submit unrequested line\n' >> "$smoke_test_dir/README.md" || return 1
  status_before="$(git -C "$smoke_test_dir" status --porcelain --untracked-files=all)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --paths=docs/testing.md --message=hi >/dev/null 2> "$unrequested_dirty_stderr"
  ); then
    test_fail "repo-flow submit rejects unrequested dirty changes before staging"
    status=1
  elif grep -Fxq 'STOP: unrequested working tree changes remain; commit a clean explicit submit' "$unrequested_dirty_stderr"; then
    status_after="$(git -C "$smoke_test_dir" status --porcelain --untracked-files=all)" || return 1
    if [ "$status_before" = "$status_after" ] && [ -z "$(git -C "$smoke_test_dir" diff --cached --name-only)" ]; then
      test_pass "repo-flow submit rejects unrequested dirty changes before staging"
    else
      test_fail "repo-flow submit rejects unrequested dirty changes before staging"
      status=1
    fi
  else
    test_fail "repo-flow submit rejects unrequested dirty changes before staging"
    status=1
  fi

  return "$status"
}

smoke_main() {
  local status=0
  local smoke_output_capture=""

  # shellcheck disable=SC2034 # Used by shared test_finish_output/test_render_json.
  TEST_OUTPUT_SCRIPT="repo-flow"
  smoke_help_requested=0
  smoke_parse_output_mode "$@" || return 1
  if [ "$smoke_help_requested" -eq 1 ]; then
    return 0
  fi
  if [ "$TEST_OUTPUT_MODE" = "explain" ]; then
    trap 'test_cleanup' EXIT INT TERM

    smoke_setup_temp_repo || return 1

    smoke_run_named_check "smoke:repo-flow-status-card-clean-main" smoke_check_repo_flow_status_card_clean_main || status=1
    smoke_run_named_check "smoke:repo-flow-status-card-feature-no-pr" smoke_check_repo_flow_status_card_feature_no_pr || status=1
    smoke_run_named_check "smoke:repo-flow-status-card-existing-pr" smoke_check_repo_flow_status_card_existing_pr || status=1
    smoke_run_named_check "smoke:repo-flow-status-card-skipped-checks" smoke_check_repo_flow_status_card_skipped_checks || status=1
    smoke_run_named_check "smoke:repo-flow-status-card-contract" smoke_check_repo_flow_status_card_contract || status=1
    smoke_run_named_check "smoke:repo-flow-dry-run-json" smoke_check_repo_flow_dry_run_json || status=1
    smoke_run_named_check "smoke:repo-flow-existing-pr" smoke_check_repo_flow_existing_pr || status=1
    smoke_run_named_check "smoke:repo-flow-create-pr" smoke_check_repo_flow_create_pr || status=1
    smoke_run_named_check "smoke:repo-flow-submit-paths" smoke_check_repo_flow_submit_paths || status=1
    smoke_run_named_check "smoke:repo-flow-submit-staged-watch" smoke_check_repo_flow_submit_staged_watch || status=1
    smoke_run_named_check "smoke:repo-flow-submit-contract" smoke_check_repo_flow_submit_contract || status=1
  else
    mkdir -p "$TEST_TEMP_ROOT" || return 1
    smoke_output_capture="$(mktemp "$TEST_TEMP_ROOT/repo-flow.XXXXXX")" || return 1
    exec 3>&1 4>&2
    exec >"$smoke_output_capture" 2>&1
    trap 'test_cleanup' EXIT INT TERM

    smoke_setup_temp_repo || status=1
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-status-card-clean-main" smoke_check_repo_flow_status_card_clean_main || status=1
    fi
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-status-card-feature-no-pr" smoke_check_repo_flow_status_card_feature_no_pr || status=1
    fi
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-status-card-existing-pr" smoke_check_repo_flow_status_card_existing_pr || status=1
    fi
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-status-card-skipped-checks" smoke_check_repo_flow_status_card_skipped_checks || status=1
    fi
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-status-card-contract" smoke_check_repo_flow_status_card_contract || status=1
    fi
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-dry-run-json" smoke_check_repo_flow_dry_run_json || status=1
    fi
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-existing-pr" smoke_check_repo_flow_existing_pr || status=1
    fi
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-create-pr" smoke_check_repo_flow_create_pr || status=1
    fi
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-submit-paths" smoke_check_repo_flow_submit_paths || status=1
    fi
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-submit-staged-watch" smoke_check_repo_flow_submit_staged_watch || status=1
    fi
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-submit-contract" smoke_check_repo_flow_submit_contract || status=1
    fi

    exec 1>&3 2>&4
    rm -f -- "$smoke_output_capture" >/dev/null 2>&1 || true
  fi

  smoke_finish_output "$status"
  return "$status"
}

smoke_main "$@"
# repo-automation/tests/contracts/repo-flow.sh EOF
