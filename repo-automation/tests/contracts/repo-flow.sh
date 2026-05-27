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
    body=""
    if [ "${GH_STUB_PR_VIEW_EMPTY:-0}" -eq 1 ] 2>/dev/null; then
      exit 1
    fi
    if [ -n "${GH_STUB_PR_STATE_FILE:-}" ] && [ -f "$GH_STUB_PR_STATE_FILE" ]; then
      number="$(repo_flow_stub_field "$GH_STUB_PR_STATE_FILE" 1)"
      url="$(repo_flow_stub_field "$GH_STUB_PR_STATE_FILE" 2)"
      title="$(repo_flow_stub_field "$GH_STUB_PR_STATE_FILE" 3)"
      state="$(repo_flow_stub_field "$GH_STUB_PR_STATE_FILE" 4)"
      body_file="$(repo_flow_stub_field "$GH_STUB_PR_STATE_FILE" 5)"
    elif [ -n "${GH_STUB_PR_VIEW_NUMBER:-}" ]; then
      number="${GH_STUB_PR_VIEW_NUMBER:-}"
      url="${GH_STUB_PR_VIEW_URL:-}"
      title="${GH_STUB_PR_VIEW_TITLE:-}"
      state="${GH_STUB_PR_VIEW_STATE:-OPEN}"
      body_file="${GH_STUB_PR_VIEW_BODY_FILE:-}"
    else
      exit 1
    fi
    if [ -n "${GH_STUB_PR_VIEW_BODY_FILE:-}" ]; then
      body_file="${GH_STUB_PR_VIEW_BODY_FILE:-}"
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
      *' --json body '*|*' --jq .body '*)
        if [ "${GH_STUB_PR_VIEW_BODY_EXIT:-0}" -ne 0 ] 2>/dev/null; then
          printf '%s\n' "${GH_STUB_PR_VIEW_BODY_ERROR:-gh pr view failed}" >&2
          exit "${GH_STUB_PR_VIEW_BODY_EXIT}"
        elif [ -n "${body_file:-}" ] && [ -f "$body_file" ]; then
          cat "$body_file"
        elif [ -n "${GH_STUB_PR_VIEW_BODY_TEXT:-}" ]; then
          printf '%s\n' "${GH_STUB_PR_VIEW_BODY_TEXT:-}"
        else
          printf '%s\n' "$body"
        fi
        ;;
      *' --json headRefName '*|*' --jq .headRefName '*)
        printf '%s\n' "${GH_STUB_PR_VIEW_HEAD_REF:-feature/demo}"
        ;;
      *' --json headRefOid '*|*' --jq .headRefOid '*)
        printf '%s\n' "${GH_STUB_PR_VIEW_HEAD_SHA:-}"
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
    if [ -n "${GH_STUB_PR_CREATE_BODY_COPY_FILE:-}" ] && [ -n "$body_file" ] && [ -f "$body_file" ]; then
      cp "$body_file" "$GH_STUB_PR_CREATE_BODY_COPY_FILE"
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
  'pr edit')
    number="${1:-}"
    body_file=""
    prev=""
    for arg in "$@"; do
      if [ -n "$prev" ]; then
        case "$prev" in
          --body-file)
            body_file="$arg"
            ;;
        esac
        prev=""
        continue
      fi
      case "$arg" in
        --body-file=*)
          body_file="${arg#--body-file=}"
          ;;
        --body-file)
          prev="$arg"
          ;;
      esac
    done
    if [ -n "${GH_STUB_PR_EDIT_LOG_FILE:-}" ]; then
      printf '%s\n' "gh pr edit number=$number body_file=$body_file" >> "$GH_STUB_PR_EDIT_LOG_FILE"
    fi
    if [ "${GH_STUB_PR_EDIT_EXIT:-0}" -ne 0 ] 2>/dev/null; then
      printf '%s\n' "${GH_STUB_PR_EDIT_ERROR:-gh pr edit failed}" >&2
      exit "${GH_STUB_PR_EDIT_EXIT}"
    fi
    if [ -n "${GH_STUB_PR_EDIT_BODY_COPY_FILE:-}" ] && [ -n "$body_file" ] && [ -f "$body_file" ]; then
      cp "$body_file" "$GH_STUB_PR_EDIT_BODY_COPY_FILE"
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

smoke_write_repo_flow_gh_body_wrapper() {
  local wrapper_dir="$1"
  local real_gh="$2"

  mkdir -p "$wrapper_dir" || return 1
  cat > "$wrapper_dir/gh" <<EOF
#!/usr/bin/env bash
set -u
cmd="\${1:-}"
sub="\${2:-}"
shift 2 >/dev/null 2>&1 || true

if [ "\$cmd \$sub" = 'pr view' ]; then
  case " \$* " in
    *' --json body '*|*' --jq .body '*)
      if [ -n "\${GH_STUB_PR_VIEW_BODY_FILE:-}" ] && [ -f "\${GH_STUB_PR_VIEW_BODY_FILE:-}" ]; then
        cat "\${GH_STUB_PR_VIEW_BODY_FILE}"
      elif [ -n "\${GH_STUB_PR_VIEW_BODY_TEXT:-}" ]; then
        printf '%s\n' "\${GH_STUB_PR_VIEW_BODY_TEXT}"
      else
        exit 1
      fi
      exit 0
      ;;
  esac
fi

exec "$real_gh" "\$cmd" "\$sub" "\$@"
EOF
  chmod +x "$wrapper_dir/gh" || return 1
}

smoke_assert_single_final_summary_block() {
  local summary_file="$1"

  [ "$(grep -Fc '===== FINAL SUMMARY =====' "$summary_file" 2>/dev/null || printf '0')" = "1" ] &&
    grep -Fxq '===== FINAL SUMMARY =====' "$summary_file" &&
    grep -Fxq '===== END =====' "$summary_file"
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

smoke_write_repo_flow_git_sync_stub() {
  local git_stub_dir="$1"
  local git_log_file="$2"

  mkdir -p "$git_stub_dir" || return 1
  cat > "$git_stub_dir/git" <<'EOF'
#!/usr/bin/env bash
set -u
case "${1:-}" in
  checkout)
    if [ -n "${SMOKE_GIT_LOG_FILE:-}" ]; then
      printf '%s\n' "git $*" >> "$SMOKE_GIT_LOG_FILE"
    fi
    exec "${SMOKE_REAL_GIT:?missing SMOKE_REAL_GIT}" "$@"
    ;;
  push)
    if [ -n "${SMOKE_GIT_LOG_FILE:-}" ]; then
      printf '%s\n' "git $*" >> "$SMOKE_GIT_LOG_FILE"
    fi
    if [ -n "${SMOKE_GIT_PUSH_MARKER_FILE:-}" ]; then
      : > "$SMOKE_GIT_PUSH_MARKER_FILE"
    fi
    exec "${SMOKE_REAL_GIT:?missing SMOKE_REAL_GIT}" "$@"
    ;;
  pull)
    if [ -n "${SMOKE_GIT_LOG_FILE:-}" ]; then
      printf '%s\n' "git $*" >> "$SMOKE_GIT_LOG_FILE"
    fi
    exit 0
    ;;
esac
exec "${SMOKE_REAL_GIT:?missing SMOKE_REAL_GIT}" "$@"
EOF
  chmod +x "$git_stub_dir/git" || return 1
  printf '%s\n' "$git_log_file"
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

smoke_check_repo_flow_status_card_helper_contract() {
  local status=0
  local helper_file=""

  smoke_setup_temp_repo || return 1
  helper_file="$smoke_test_dir/repo-automation/lib/repo-flow-status.sh"

  if (
    cd "$smoke_test_dir" || return 1
    # shellcheck source=/dev/null
    source "$helper_file" || return 1
    [ "$(repo_flow_status_card_classify_checks '[{"name":"build","bucket":"pending","state":"IN_PROGRESS"}]')" = "pending" ] &&
      [ "$(repo_flow_status_card_classify_checks '[{"name":"build","bucket":"fail","state":"FAILED"}]')" = "blocked" ] &&
      [ "$(repo_flow_status_card_classify_checks '[{"name":"build","bucket":"pass","state":"SUCCESS"}]')" = "green" ] &&
      [ "$(repo_flow_status_card_classify_checks '[]')" = "unknown" ]
  ); then
    test_pass "repo-flow status-card helper classifies checks deterministically"
  else
    test_fail "repo-flow status-card helper classifies checks deterministically"
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
  ) && grep -Fq -- '--explain' "$help_out" && grep -Fq -- '--dry-run' "$help_out" && grep -Fq -- '--timeout=<seconds>' "$help_out"; then
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
  ) && [ ! -s "$explain_out" ] && grep -Fq 'final status:' "$explain_err" && grep -Fxq '===== FINAL SUMMARY =====' "$explain_err" && grep -Fxq '===== END =====' "$explain_err" && grep -Fq 'repo-automation/bin/repo-flow merge' "$help_out"; then
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

smoke_check_repo_flow_existing_pr_body_refresh() {
  local status=0
  local gh_stub_dir=""
  local state_file=""
  local create_log_file=""
  local create_log_file_second=""
  local edit_log_file=""
  local first_body_file=""
  local refreshed_body_file=""
  local stdout_file=""
  local stderr_file=""
  local second_stdout_file=""
  local second_stderr_file=""
  local local_bash_path=""

  smoke_setup_temp_repo || return 1
  smoke_prepare_repo_flow_remote || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  state_file="$smoke_test_base/repo-flow-existing-pr-refresh.txt"
  create_log_file="$smoke_test_base/repo-flow-existing-pr-refresh-create.log"
  create_log_file_second="$smoke_test_base/repo-flow-existing-pr-refresh-second-create.log"
  edit_log_file="$smoke_test_base/repo-flow-existing-pr-refresh-edit.log"
  first_body_file="$smoke_test_base/repo-flow-existing-pr-refresh-body-first.md"
  refreshed_body_file="$smoke_test_base/repo-flow-existing-pr-refresh-body-refreshed.md"
  stdout_file="$smoke_test_base/repo-flow-existing-pr-refresh.stdout"
  stderr_file="$smoke_test_base/repo-flow-existing-pr-refresh.stderr"
  second_stdout_file="$smoke_test_base/repo-flow-existing-pr-refresh-second.stdout"
  second_stderr_file="$smoke_test_base/repo-flow-existing-pr-refresh-second.stderr"
  smoke_write_repo_flow_gh_stub "$gh_stub_dir" || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-existing-refresh" || return 1
  local_bash_path="$(command -v bash)" || return 1

  printf '\nrepo-flow submit existing pr refresh old path\n' >> "$smoke_test_dir/README.md" || return 1
  git -C "$smoke_test_dir" add README.md || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    REMOTE_NAME=localorigin \
    EXPECTED_REMOTE_URL="" \
    GH_STUB_PR_STATE_FILE="$state_file" \
    GH_STUB_PR_CREATE_LOG_FILE="$create_log_file" \
    GH_STUB_PR_CREATE_BODY_COPY_FILE="$first_body_file" \
    GH_STUB_PR_CREATE_NUMBER=812 \
    GH_STUB_PR_CREATE_URL='https://github.com/i-schuyler/repo-automation-template/pull/812' \
    GH_STUB_PR_VIEW_EMPTY=1 \
    "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message='repo-flow submit existing pr refresh old commit' > "$stdout_file" 2> "$stderr_file"
  ); then
    if [ "$(cat "$stdout_file")" = 'https://github.com/i-schuyler/repo-automation-template/pull/812' ] &&
      [ -s "$create_log_file" ] &&
      grep -Fq 'README.md' "$first_body_file" &&
      grep -Fq 'Commit subject: repo-flow submit existing pr refresh old commit' "$first_body_file"; then
      :
    else
      test_fail "repo-flow submit creates the initial PR body for refresh reuse"
      status=1
    fi
  else
    test_fail "repo-flow submit creates the initial PR body for refresh reuse"
    status=1
  fi

  printf '\nrepo-flow submit existing pr refresh new path\n' >> "$smoke_test_dir/docs/testing.md" || return 1
  git -C "$smoke_test_dir" add docs/testing.md || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    REMOTE_NAME=localorigin \
    EXPECTED_REMOTE_URL="" \
    GH_STUB_PR_STATE_FILE="$state_file" \
    GH_STUB_PR_CREATE_LOG_FILE="$create_log_file_second" \
    GH_STUB_PR_EDIT_LOG_FILE="$edit_log_file" \
    GH_STUB_PR_EDIT_BODY_COPY_FILE="$refreshed_body_file" \
    GH_STUB_PR_VIEW_BODY_FILE="$first_body_file" \
    GH_STUB_PR_CREATE_NUMBER=812 \
    GH_STUB_PR_CREATE_URL='https://github.com/i-schuyler/repo-automation-template/pull/812' \
    "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message='repo-flow submit existing pr refresh new commit' > "$second_stdout_file" 2> "$second_stderr_file"
  ); then
    if [ "$(cat "$second_stdout_file")" = 'https://github.com/i-schuyler/repo-automation-template/pull/812' ] &&
      [ ! -s "$create_log_file_second" ] &&
      grep -Fq 'gh pr edit number=812 body_file=' "$edit_log_file" &&
      grep -Fq 'Commit subject: repo-flow submit existing pr refresh old commit' "$refreshed_body_file" &&
      grep -Fq 'README.md' "$refreshed_body_file" &&
      grep -Fq 'Commit subject: repo-flow submit existing pr refresh new commit' "$refreshed_body_file" &&
      grep -Fq 'docs/testing.md' "$refreshed_body_file" &&
      grep -Fq '## Update log' "$refreshed_body_file" &&
      [ "$(grep -Fc '## Update log' "$refreshed_body_file")" = "1" ] &&
      [ "$(grep -Fc '## Scope' "$refreshed_body_file")" = "1" ] &&
      [ "$(grep -Fc '## What changed' "$refreshed_body_file")" = "1" ] &&
      [ "$(grep -Fc '## What did not change' "$refreshed_body_file")" = "1" ] &&
      [ "$(grep -Fc '## Verification status' "$refreshed_body_file")" = "1" ] &&
      [ "$(grep -Fc '## User-visible behavior changes' "$refreshed_body_file")" = "1" ] &&
      [ "$(grep -Fc '## Stop conditions encountered' "$refreshed_body_file")" = "1" ] &&
      [ "$(grep -Fc '## Re-entry hint' "$refreshed_body_file")" = "1" ]; then
      test_pass "repo-flow submit appends an update log to an existing PR body"
    else
      test_fail "repo-flow submit appends an update log to an existing PR body"
      status=1
    fi
  else
    test_fail "repo-flow submit appends an update log to an existing PR body"
    status=1
  fi

  return "$status"
}

smoke_check_repo_flow_existing_pr_body_refresh_failure() {
  local status=0
  local gh_stub_dir=""
  local state_file=""
  local create_log_file=""
  local first_body_file=""
  local edit_log_file=""
  local stdout_file=""
  local stderr_file=""
  local local_bash_path=""

  smoke_setup_temp_repo || return 1
  smoke_prepare_repo_flow_remote || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  state_file="$smoke_test_base/repo-flow-existing-pr-refresh-fail.txt"
  create_log_file="$smoke_test_base/repo-flow-existing-pr-refresh-fail-create.log"
  first_body_file="$smoke_test_base/repo-flow-existing-pr-refresh-fail-body-first.md"
  edit_log_file="$smoke_test_base/repo-flow-existing-pr-refresh-fail-edit.log"
  stdout_file="$smoke_test_base/repo-flow-existing-pr-refresh-fail.stdout"
  stderr_file="$smoke_test_base/repo-flow-existing-pr-refresh-fail.stderr"
  smoke_write_repo_flow_gh_stub "$gh_stub_dir" || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-existing-refresh-fail" || return 1
  local_bash_path="$(command -v bash)" || return 1

  printf '\nrepo-flow submit existing pr refresh fail old path\n' >> "$smoke_test_dir/README.md" || return 1
  git -C "$smoke_test_dir" add README.md || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    REMOTE_NAME=localorigin \
    EXPECTED_REMOTE_URL="" \
    GH_STUB_PR_STATE_FILE="$state_file" \
    GH_STUB_PR_CREATE_LOG_FILE="$create_log_file" \
    GH_STUB_PR_CREATE_BODY_COPY_FILE="$first_body_file" \
    GH_STUB_PR_CREATE_NUMBER=813 \
    GH_STUB_PR_CREATE_URL='https://github.com/i-schuyler/repo-automation-template/pull/813' \
    GH_STUB_PR_VIEW_EMPTY=1 \
    "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message='repo-flow submit existing pr refresh fail old commit' > "$stdout_file" 2> "$stderr_file"
  ); then
    :
  else
    test_fail "repo-flow submit prepares an existing PR for refresh failure"
    status=1
  fi

  printf '\nrepo-flow submit existing pr refresh fail new path\n' >> "$smoke_test_dir/docs/testing.md" || return 1
  git -C "$smoke_test_dir" add docs/testing.md || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    REMOTE_NAME=localorigin \
    EXPECTED_REMOTE_URL="" \
    GH_STUB_PR_STATE_FILE="$state_file" \
    GH_STUB_PR_EDIT_LOG_FILE="$edit_log_file" \
    GH_STUB_PR_VIEW_BODY_FILE="$first_body_file" \
    GH_STUB_PR_EDIT_EXIT=1 \
    GH_STUB_PR_EDIT_ERROR='gh pr edit failed: permission denied' \
    "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message='repo-flow submit existing pr refresh fail new commit' --explain > "$stdout_file" 2> "$stderr_file"
  ); then
    test_fail "repo-flow submit stops when refreshing an existing PR body fails"
    status=1
  elif grep -Fxq 'STOP: failed to refresh existing PR #813 body: gh pr edit failed: permission denied' "$stderr_file" &&
    grep -Fxq '===== FINAL SUMMARY =====' "$stderr_file" &&
    grep -Fxq 'url_or_stop=failed to refresh existing PR #813 body: gh pr edit failed: permission denied' "$stderr_file" &&
    grep -Fxq '===== END =====' "$stderr_file" &&
    grep -Fq 'gh pr edit number=813 body_file=' "$edit_log_file"; then
    test_pass "repo-flow submit stops when refreshing an existing PR body fails"
  else
    test_fail "repo-flow submit stops when refreshing an existing PR body fails"
    status=1
  fi

  return "$status"
}

smoke_check_repo_flow_existing_pr_body_append_validation_failure() {
  local status=0
  local gh_stub_dir=""
  local state_file=""
  local invalid_body_file=""
  local edit_log_file=""
  local stdout_file=""
  local stderr_file=""
  local head_before=""
  local head_after=""
  local local_bash_path=""

  smoke_setup_temp_repo || return 1
  smoke_prepare_repo_flow_remote || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  state_file="$smoke_test_base/repo-flow-existing-pr-append-invalid.txt"
  invalid_body_file="$smoke_test_base/repo-flow-existing-pr-append-invalid-body.md"
  edit_log_file="$smoke_test_base/repo-flow-existing-pr-append-invalid-edit.log"
  stdout_file="$smoke_test_base/repo-flow-existing-pr-append-invalid.stdout"
  stderr_file="$smoke_test_base/repo-flow-existing-pr-append-invalid.stderr"
  smoke_write_repo_flow_gh_stub "$gh_stub_dir" || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-existing-append-invalid" || return 1
  local_bash_path="$(command -v bash)" || return 1

  cat > "$invalid_body_file" <<'EOF'
## Scope

Branch: feature/repo-flow-existing-append-invalid
Base: main
Ahead: 1
Behind: 0

## Scope

Branch: feature/repo-flow-existing-append-invalid
Base: main
Ahead: 1
Behind: 0

## What changed

Branch: feature/repo-flow-existing-append-invalid
Base: main
Ahead: 1
Behind: 0

## What did not change

Branch: feature/repo-flow-existing-append-invalid
Base: main
Ahead: 1
Behind: 0

## Verification status

Branch: feature/repo-flow-existing-append-invalid
Base: main
Ahead: 1
Behind: 0

## User-visible behavior changes

Branch: feature/repo-flow-existing-append-invalid
Base: main
Ahead: 1
Behind: 0

## Stop conditions encountered

Branch: feature/repo-flow-existing-append-invalid
Base: main
Ahead: 1
Behind: 0

## Re-entry hint

Branch: feature/repo-flow-existing-append-invalid
Base: main
Ahead: 1
Behind: 0
EOF

  printf '\nrepo-flow submit existing pr append validation fail line\n' >> "$smoke_test_dir/README.md" || return 1
  git -C "$smoke_test_dir" add README.md || return 1
  head_before="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    REMOTE_NAME=localorigin \
    EXPECTED_REMOTE_URL="" \
    GH_STUB_PR_STATE_FILE="$state_file" \
    GH_STUB_PR_VIEW_NUMBER=815 \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/815' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_BODY_FILE="$invalid_body_file" \
    GH_STUB_PR_EDIT_LOG_FILE="$edit_log_file" \
    "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message='repo-flow submit existing pr append validation fail commit' > "$stdout_file" 2> "$stderr_file"
  ); then
    test_fail "repo-flow submit stops before PR edit when an existing PR body fails validation"
    status=1
  elif grep -Fxq 'fail: heading appears more than once: ## Scope' "$stderr_file" &&
    grep -Fxq 'fix: keep each required heading exactly once' "$stderr_file" &&
    grep -Fxq 'fix: rerun with --replace-body only if intentional full PR body replacement is desired' "$stderr_file" &&
    grep -Fxq 'STOP: failed to refresh existing PR #815 body: fail: heading appears more than once: ## Scope' "$stderr_file" &&
    [ ! -s "$edit_log_file" ]; then
    head_after="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1
    if [ "$head_before" != "$head_after" ]; then
      test_pass "repo-flow submit stops before PR edit when an existing PR body fails validation"
    else
      test_fail "repo-flow submit stops before PR edit when an existing PR body fails validation"
      status=1
    fi
  else
    test_fail "repo-flow submit stops before PR edit when an existing PR body fails validation"
    status=1
  fi

  return "$status"
}

smoke_check_repo_flow_existing_pr_body_fetch_failure() {
  local status=0
  local gh_stub_dir=""
  local state_file=""
  local edit_log_file=""
  local stdout_file=""
  local stderr_file=""
  local local_bash_path=""

  smoke_setup_temp_repo || return 1
  smoke_prepare_repo_flow_remote || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  state_file="$smoke_test_base/repo-flow-existing-pr-body-fetch-fail.txt"
  edit_log_file="$smoke_test_base/repo-flow-existing-pr-body-fetch-fail-edit.log"
  stdout_file="$smoke_test_base/repo-flow-existing-pr-body-fetch-fail.stdout"
  stderr_file="$smoke_test_base/repo-flow-existing-pr-body-fetch-fail.stderr"
  smoke_write_repo_flow_gh_stub "$gh_stub_dir" || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-existing-body-fetch-fail" || return 1
  local_bash_path="$(command -v bash)" || return 1

  printf '\nrepo-flow submit existing pr body fetch fail line\n' >> "$smoke_test_dir/README.md" || return 1
  git -C "$smoke_test_dir" add README.md || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    REMOTE_NAME=localorigin \
    EXPECTED_REMOTE_URL="" \
    GH_STUB_PR_STATE_FILE="$state_file" \
    GH_STUB_PR_VIEW_NUMBER=814 \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/814' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_BODY_EXIT=1 \
    GH_STUB_PR_VIEW_BODY_ERROR='gh pr view failed: permission denied' \
    GH_STUB_PR_EDIT_LOG_FILE="$edit_log_file" \
    "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message='repo-flow submit existing pr body fetch fail commit' > "$stdout_file" 2> "$stderr_file"
  ); then
    test_fail "repo-flow submit stops when fetching an existing PR body fails"
    status=1
  elif grep -Fxq 'fix: rerun with --replace-body only if intentional full PR body replacement is desired' "$stderr_file" &&
    grep -Fxq 'STOP: failed to fetch existing PR #814 body: gh pr view failed: permission denied' "$stderr_file" &&
    [ ! -s "$edit_log_file" ]; then
    test_pass "repo-flow submit stops when fetching an existing PR body fails"
  else
    test_fail "repo-flow submit stops when fetching an existing PR body fails"
    status=1
  fi

  return "$status"
}

smoke_check_repo_flow_submit_watch_existing_pr_body_refresh_failure() {
  local status=0
  local gh_stub_dir=""
  local pr_finish_stub_dir=""
  local pr_finish_log_file=""
  local state_file=""
  local body_file=""
  local edit_log_file=""
  local stdout_file=""
  local stderr_file=""
  local local_bash_path=""

  smoke_setup_temp_repo || return 1
  smoke_prepare_repo_flow_remote || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  pr_finish_stub_dir="$smoke_test_base/pr-finish-stub"
  pr_finish_log_file="$smoke_test_base/repo-flow-submit-watch-existing-refresh-finish.log"
  state_file="$smoke_test_base/repo-flow-submit-watch-existing-refresh.txt"
  body_file="$smoke_test_base/repo-flow-submit-watch-existing-refresh-body.md"
  edit_log_file="$smoke_test_base/repo-flow-submit-watch-existing-refresh-edit.log"
  stdout_file="$smoke_test_base/repo-flow-submit-watch-existing-refresh.out"
  stderr_file="$smoke_test_base/repo-flow-submit-watch-existing-refresh.stderr"
  smoke_write_repo_flow_gh_stub "$gh_stub_dir" || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-watch-existing-refresh" || return 1
  local_bash_path="$(command -v bash)" || return 1

  cat > "$body_file" <<'EOF'
## Scope

Existing watch PR body.

## What changed

- repo-flow submit watch refresh failure body

## What did not change

- The watch path stays the same.

## Verification status

- repo-flow submit watch existing PR body refresh failure

## User-visible behavior changes

None

## Stop conditions encountered

None

## Re-entry hint

Review the PR, then run `repo-automation/bin/repo-flow merge --explain`.
EOF
  printf '813\nhttps://github.com/i-schuyler/repo-automation-template/pull/813\nrepo-flow submit watch existing refresh\nOPEN\n%s\n' "$body_file" > "$state_file" || return 1
  printf '\nrepo-flow submit watch existing pr refresh fail line\n' >> "$smoke_test_dir/README.md" || return 1
  git -C "$smoke_test_dir" add README.md || return 1

  mkdir -p "$pr_finish_stub_dir" || return 1
  cat > "$pr_finish_stub_dir/pr-finish" <<EOF
#!/usr/bin/env bash
set -u
if [ -n "\${SMOKE_PR_FINISH_LOG_FILE:-}" ]; then
  printf '%s\n' "pr-finish \$*" >> "\$SMOKE_PR_FINISH_LOG_FILE"
fi
exit 0
EOF
  chmod +x "$pr_finish_stub_dir/pr-finish" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$pr_finish_stub_dir:$gh_stub_dir:$PATH" \
    REMOTE_NAME=localorigin \
    EXPECTED_REMOTE_URL="" \
    GH_STUB_PR_STATE_FILE="$state_file" \
    GH_STUB_PR_EDIT_LOG_FILE="$edit_log_file" \
    GH_STUB_PR_EDIT_EXIT=1 \
    GH_STUB_PR_EDIT_ERROR='gh pr edit failed: permission denied' \
    SMOKE_PR_FINISH_LOG_FILE="$pr_finish_log_file" \
    "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message='repo-flow submit watch existing pr refresh fail commit' --watch --explain > "$stdout_file" 2> "$stderr_file"
  ); then
    test_fail "repo-flow submit --watch stops when refreshing an existing PR body fails"
    status=1
  elif grep -Fxq 'STOP: failed to refresh existing PR #813 body: gh pr edit failed: permission denied' "$stderr_file" &&
    grep -Fxq '===== FINAL SUMMARY =====' "$stderr_file" &&
    grep -Fxq 'rc=1' "$stderr_file" &&
    grep -Fxq 'watched=true' "$stderr_file" &&
    grep -Fxq 'ci=unknown' "$stderr_file" &&
    grep -Fxq 'pr=813' "$stderr_file" &&
    grep -Fxq 'url_or_stop=failed to refresh existing PR #813 body: gh pr edit failed: permission denied' "$stderr_file" &&
    ! grep -Fxq 'url_or_stop=https://github.com/i-schuyler/repo-automation-template/pull/813' "$stderr_file" &&
    grep -Fxq '===== END =====' "$stderr_file" &&
    grep -Fq 'gh pr edit number=813 body_file=' "$edit_log_file" &&
    [ ! -s "$pr_finish_log_file" ]; then
    test_pass "repo-flow submit --watch stops when refreshing an existing PR body fails"
  else
    test_fail "repo-flow submit --watch stops when refreshing an existing PR body fails"
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
  local body_copy_file=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  stdout_file="$smoke_test_base/repo-flow-submit-paths.out"
  stderr_file="$smoke_test_base/repo-flow-submit-paths.stderr"
  create_log_file="$smoke_test_base/repo-flow-submit-paths-create.log"
  body_copy_file="$smoke_test_base/repo-flow-submit-paths-body.md"
  smoke_write_repo_flow_gh_stub "$gh_stub_dir" || return 1
  smoke_prepare_repo_flow_remote || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-paths" || return 1

  printf '\nrepo-flow submit paths line\n' >> "$smoke_test_dir/README.md" || return 1
  head_before="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_CREATE_LOG_FILE="$create_log_file" \
    GH_STUB_PR_CREATE_BODY_COPY_FILE="$body_copy_file" \
    GH_STUB_PR_CREATE_URL='https://github.com/i-schuyler/repo-automation-template/pull/701' \
    GH_STUB_PR_VIEW_EMPTY=1 \
    repo-automation/bin/repo-flow submit --paths=README.md --message='repo-flow submit paths commit' > "$stdout_file" 2> "$stderr_file"
  ) && [ "$(cat "$stdout_file")" = 'https://github.com/i-schuyler/repo-automation-template/pull/701' ] && [ -f "$create_log_file" ] && [ -f "$body_copy_file" ]; then
    head_after="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1
    if [ "$head_before" != "$head_after" ] && git -C "$smoke_test_dir" log -1 --pretty=%s | grep -Fxq 'repo-flow submit paths commit' && \
      grep -Fxq '## Scope' "$body_copy_file" && \
      grep -Fq "repo-flow submit for branch \`feature/repo-flow-submit-paths\` against \`main\`." "$body_copy_file" && \
      grep -Fq 'Commit subject: repo-flow submit paths commit' "$body_copy_file" && \
      grep -Fq 'README.md' "$body_copy_file" && \
      grep -Fxq '## Re-entry hint' "$body_copy_file" && \
      grep -Fq "Review the PR, then run \`repo-automation/bin/repo-flow merge --explain\`." "$body_copy_file"; then
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

smoke_check_repo_flow_submit_body_file_create_refresh() {
  local status=0
  local gh_stub_dir=""
  local stdout_file=""
  local stderr_file=""
  local create_log_file=""
  local edit_log_file=""
  local refresh_create_log_file=""
  local create_body_copy_file=""
  local edit_body_copy_file=""
  local body_file=""
  local head_before=""
  local head_after=""
  local local_bash_path=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  stdout_file="$smoke_test_base/repo-flow-submit-body-file.out"
  stderr_file="$smoke_test_base/repo-flow-submit-body-file.stderr"
  create_log_file="$smoke_test_base/repo-flow-submit-body-file-create.log"
  edit_log_file="$smoke_test_base/repo-flow-submit-body-file-edit.log"
  refresh_create_log_file="$smoke_test_base/repo-flow-submit-body-file-refresh-create.log"
  create_body_copy_file="$smoke_test_base/repo-flow-submit-body-file-create-body.md"
  edit_body_copy_file="$smoke_test_base/repo-flow-submit-body-file-edit-body.md"
  body_file="$smoke_test_base/repo-flow-submit-body-file-valid.md"
  smoke_write_repo_flow_gh_stub "$gh_stub_dir" || return 1
  smoke_prepare_repo_flow_remote || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-body-file" || return 1
  local_bash_path="$(command -v bash)" || return 1

  cat > "$body_file" <<'EOF'
## Scope

Human-authored PR body support.

## What changed

- Added submit --body-file support.

## What did not change

- The fallback generated body remains available.

## Verification status

- repo-flow submit body-file smoke test

## User-visible behavior changes

Review-facing PRs can now use a user-authored body.

## Stop conditions encountered

None

## Re-entry hint

Review the PR, then run `repo-automation/bin/repo-flow merge --explain`.
EOF

  printf '\nrepo-flow submit body-file create line\n' >> "$smoke_test_dir/README.md" || return 1
  head_before="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_CREATE_LOG_FILE="$create_log_file" \
    GH_STUB_PR_CREATE_BODY_COPY_FILE="$create_body_copy_file" \
    GH_STUB_PR_CREATE_URL='https://github.com/i-schuyler/repo-automation-template/pull/706' \
    GH_STUB_PR_VIEW_EMPTY=1 \
    repo-automation/bin/repo-flow submit --paths=README.md --message='repo-flow submit body-file create commit' --body-file="$body_file" > "$stdout_file" 2> "$stderr_file"
  ) && [ "$(cat "$stdout_file")" = 'https://github.com/i-schuyler/repo-automation-template/pull/706' ] && [ -f "$create_log_file" ] && [ -f "$create_body_copy_file" ]; then
    head_after="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1
    if [ "$head_before" != "$head_after" ] &&
      git -C "$smoke_test_dir" log -1 --pretty=%s | grep -Fxq 'repo-flow submit body-file create commit' &&
      grep -Fq 'Human-authored PR body support.' "$create_body_copy_file" &&
      grep -Fq 'submit --body-file support' "$create_body_copy_file" &&
      grep -Fq 'Review-facing PRs can now use a user-authored body.' "$create_body_copy_file" &&
      ! grep -Fq 'Commit subject: repo-flow submit body-file create commit' "$create_body_copy_file" &&
      ! grep -Fq 'README.md' "$body_file"; then
      test_pass "repo-flow submit uses a supplied body file when creating a PR"
    else
      test_fail "repo-flow submit uses a supplied body file when creating a PR"
      status=1
    fi
  else
    test_fail "repo-flow submit uses a supplied body file when creating a PR"
    status=1
  fi

  printf '\nrepo-flow submit body-file refresh line\n' >> "$smoke_test_dir/docs/testing.md" || return 1
  git -C "$smoke_test_dir" add docs/testing.md || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_CREATE_LOG_FILE="$refresh_create_log_file" \
    GH_STUB_PR_EDIT_LOG_FILE="$edit_log_file" \
    GH_STUB_PR_EDIT_BODY_COPY_FILE="$edit_body_copy_file" \
    GH_STUB_PR_VIEW_NUMBER=706 \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/706' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    repo-automation/bin/repo-flow submit --staged --message='repo-flow submit body-file refresh commit' --body-file="$body_file" --replace-body > "$stdout_file" 2> "$stderr_file"
  ) && [ "$(cat "$stdout_file")" = 'https://github.com/i-schuyler/repo-automation-template/pull/706' ] && [ -f "$edit_log_file" ] && [ -f "$edit_body_copy_file" ] && [ ! -s "$refresh_create_log_file" ]; then
    if grep -Fq 'Human-authored PR body support.' "$edit_body_copy_file" &&
      grep -Fq 'submit --body-file support' "$edit_body_copy_file" &&
      grep -Fq 'Review-facing PRs can now use a user-authored body.' "$edit_body_copy_file" &&
      ! grep -Fq 'Commit subject: repo-flow submit body-file refresh commit' "$edit_body_copy_file" &&
      ! grep -Fq '## Update log' "$edit_body_copy_file" &&
      grep -Fq 'gh pr edit number=706 body_file=' "$edit_log_file" &&
      ! grep -Fq 'repo-flow submit body-file refresh line' "$edit_body_copy_file"; then
      test_pass "repo-flow submit replaces an existing PR body from a supplied file"
    else
      test_fail "repo-flow submit replaces an existing PR body from a supplied file"
      status=1
    fi
  else
    test_fail "repo-flow submit replaces an existing PR body from a supplied file"
    status=1
  fi

  return "$status"
}

smoke_check_repo_flow_submit_body_file_existing_pr_requires_replace_body() {
  local status=0
  local gh_stub_dir=""
  local state_file=""
  local body_file=""
  local stdout_file=""
  local stderr_file=""
  local head_before=""
  local head_after=""
  local local_bash_path=""

  smoke_setup_temp_repo || return 1
  smoke_prepare_repo_flow_remote || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  state_file="$smoke_test_base/repo-flow-submit-body-file-requires-replace.txt"
  body_file="$smoke_test_base/repo-flow-submit-body-file-requires-replace.md"
  stdout_file="$smoke_test_base/repo-flow-submit-body-file-requires-replace.out"
  stderr_file="$smoke_test_base/repo-flow-submit-body-file-requires-replace.stderr"
  smoke_write_repo_flow_gh_stub "$gh_stub_dir" || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-body-file-requires-replace" || return 1
  local_bash_path="$(command -v bash)" || return 1

  cat > "$body_file" <<'EOF'
## Scope

Human-authored PR body support.

## What changed

- Added submit --body-file support.

## What did not change

- The fallback generated body remains available.

## Verification status

- repo-flow submit body-file smoke test

## User-visible behavior changes

Review-facing PRs can now use a user-authored body.

## Stop conditions encountered

None

## Re-entry hint

Review the PR, then run `repo-automation/bin/repo-flow merge --explain`.
EOF

  printf '\nrepo-flow submit body-file requires replace\n' >> "$smoke_test_dir/README.md" || return 1
  git -C "$smoke_test_dir" add README.md || return 1
  head_before="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    REMOTE_NAME=localorigin \
    EXPECTED_REMOTE_URL="" \
    GH_STUB_PR_STATE_FILE="$state_file" \
    GH_STUB_PR_VIEW_NUMBER=707 \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/707' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_CREATE_LOG_FILE="$smoke_test_base/repo-flow-submit-body-file-requires-replace-create.log" \
    GH_STUB_PR_EDIT_LOG_FILE="$smoke_test_base/repo-flow-submit-body-file-requires-replace-edit.log" \
    repo-automation/bin/repo-flow submit --staged --message='repo-flow submit body-file requires replace commit' --body-file="$body_file" > "$stdout_file" 2> "$stderr_file"
  ); then
    test_fail "repo-flow submit stops before commit when an existing PR body file lacks --replace-body"
    status=1
  elif grep -Fxq 'fix: supplied full body files replace PR bodies; use --replace-body to intentionally replace the PR body' "$stderr_file" &&
    grep -Fxq 'STOP: existing PR #707 requires --replace-body when --body-file is supplied' "$stderr_file"; then
    head_after="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1
    if [ "$head_before" = "$head_after" ] &&
      [ ! -s "$smoke_test_base/repo-flow-submit-body-file-requires-replace-create.log" ] &&
      [ ! -s "$smoke_test_base/repo-flow-submit-body-file-requires-replace-edit.log" ]; then
      test_pass "repo-flow submit stops before commit when an existing PR body file lacks --replace-body"
    else
      test_fail "repo-flow submit stops before commit when an existing PR body file lacks --replace-body"
      status=1
    fi
  else
    test_fail "repo-flow submit stops before commit when an existing PR body file lacks --replace-body"
    status=1
  fi

  return "$status"
}

smoke_check_repo_flow_submit_replace_body_flag_rejected() {
  local status=0
  local gh_stub_dir=""
  local stdout_file=""
  local stderr_file=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  stdout_file="$smoke_test_base/repo-flow-submit-replace-body-rejected.out"
  stderr_file="$smoke_test_base/repo-flow-submit-replace-body-rejected.stderr"
  smoke_write_repo_flow_gh_stub "$gh_stub_dir" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    repo-automation/bin/repo-flow submit --staged --message='repo-flow submit replace-body rejected' --replace-body=maybe > "$stdout_file" 2> "$stderr_file"
  ); then
    test_fail "repo-flow submit rejects --replace-body=<value>"
    status=1
  elif grep -Fxq 'fail: flag format not accepted' "$stderr_file" &&
    grep -Fxq 'flag: --replace-body' "$stderr_file" &&
    grep -Fxq 'fix: use --replace-body' "$stderr_file"; then
    test_pass "repo-flow submit rejects --replace-body=<value>"
  else
    test_fail "repo-flow submit rejects --replace-body=<value>"
    status=1
  fi

  return "$status"
}

smoke_check_repo_flow_submit_body_file_create_refresh() {
  local status=0
  local gh_stub_dir=""
  local stdout_file=""
  local stderr_file=""
  local create_log_file=""
  local edit_log_file=""
  local refresh_create_log_file=""
  local create_body_copy_file=""
  local edit_body_copy_file=""
  local body_file=""
  local head_before=""
  local head_after=""
  local local_bash_path=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  stdout_file="$smoke_test_base/repo-flow-submit-body-file.out"
  stderr_file="$smoke_test_base/repo-flow-submit-body-file.stderr"
  create_log_file="$smoke_test_base/repo-flow-submit-body-file-create.log"
  edit_log_file="$smoke_test_base/repo-flow-submit-body-file-edit.log"
  refresh_create_log_file="$smoke_test_base/repo-flow-submit-body-file-refresh-create.log"
  create_body_copy_file="$smoke_test_base/repo-flow-submit-body-file-create-body.md"
  edit_body_copy_file="$smoke_test_base/repo-flow-submit-body-file-edit-body.md"
  body_file="$smoke_test_base/repo-flow-submit-body-file-valid.md"
  smoke_write_repo_flow_gh_stub "$gh_stub_dir" || return 1
  smoke_prepare_repo_flow_remote || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-body-file" || return 1
  local_bash_path="$(command -v bash)" || return 1

  cat > "$body_file" <<'EOF'
## Scope

Human-authored PR body support.

## What changed

- Added submit --body-file support.

## What did not change

- The fallback generated body remains available.

## Verification status

- repo-flow submit body-file smoke test

## User-visible behavior changes

Review-facing PRs can now use a user-authored body.

## Stop conditions encountered

None

## Re-entry hint

Review the PR, then run `repo-automation/bin/repo-flow merge --explain`.
EOF

  printf '\nrepo-flow submit body-file create line\n' >> "$smoke_test_dir/README.md" || return 1
  head_before="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_CREATE_LOG_FILE="$create_log_file" \
    GH_STUB_PR_CREATE_BODY_COPY_FILE="$create_body_copy_file" \
    GH_STUB_PR_CREATE_URL='https://github.com/i-schuyler/repo-automation-template/pull/706' \
    GH_STUB_PR_VIEW_EMPTY=1 \
    repo-automation/bin/repo-flow submit --paths=README.md --message='repo-flow submit body-file create commit' --body-file="$body_file" > "$stdout_file" 2> "$stderr_file"
  ) && [ "$(cat "$stdout_file")" = 'https://github.com/i-schuyler/repo-automation-template/pull/706' ] && [ -f "$create_log_file" ] && [ -f "$create_body_copy_file" ]; then
    head_after="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1
    if [ "$head_before" != "$head_after" ] &&
      git -C "$smoke_test_dir" log -1 --pretty=%s | grep -Fxq 'repo-flow submit body-file create commit' &&
      grep -Fq 'Human-authored PR body support.' "$create_body_copy_file" &&
      grep -Fq 'Added submit --body-file support.' "$create_body_copy_file" &&
      grep -Fq 'Review-facing PRs can now use a user-authored body.' "$create_body_copy_file" &&
      ! grep -Fq 'Commit subject: repo-flow submit body-file create commit' "$create_body_copy_file"; then
      test_pass "repo-flow submit uses a supplied body file when creating a PR"
    else
      test_fail "repo-flow submit uses a supplied body file when creating a PR"
      status=1
    fi
  else
    test_fail "repo-flow submit uses a supplied body file when creating a PR"
    status=1
  fi

  printf '\nrepo-flow submit body-file refresh line\n' >> "$smoke_test_dir/docs/testing.md" || return 1
  git -C "$smoke_test_dir" add docs/testing.md || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_CREATE_LOG_FILE="$refresh_create_log_file" \
    GH_STUB_PR_EDIT_LOG_FILE="$edit_log_file" \
    GH_STUB_PR_EDIT_BODY_COPY_FILE="$edit_body_copy_file" \
    GH_STUB_PR_VIEW_NUMBER=706 \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/706' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    repo-automation/bin/repo-flow submit --staged --message='repo-flow submit body-file refresh commit' --body-file="$body_file" --replace-body > "$stdout_file" 2> "$stderr_file"
  ) && [ "$(cat "$stdout_file")" = 'https://github.com/i-schuyler/repo-automation-template/pull/706' ] && [ -f "$edit_log_file" ] && [ -f "$edit_body_copy_file" ] && [ ! -s "$refresh_create_log_file" ]; then
    if grep -Fq 'Human-authored PR body support.' "$edit_body_copy_file" &&
      grep -Fq 'Review-facing PRs can now use a user-authored body.' "$edit_body_copy_file" &&
      ! grep -Fq 'Commit subject: repo-flow submit body-file refresh commit' "$edit_body_copy_file" &&
      ! grep -Fq '## Update log' "$edit_body_copy_file" &&
      grep -Fq 'gh pr edit number=706 body_file=' "$edit_log_file" &&
      ! grep -Fq 'repo-flow submit body-file refresh line' "$edit_body_copy_file"; then
      test_pass "repo-flow submit replaces an existing PR body from a supplied file"
    else
      test_fail "repo-flow submit replaces an existing PR body from a supplied file"
      status=1
    fi
  else
    test_fail "repo-flow submit replaces an existing PR body from a supplied file"
    status=1
  fi

  return "$status"
}

smoke_check_repo_flow_submit_staged_watch() {
  local status=0
  local gh_stub_dir=""
  local gh_body_wrapper_dir=""
  local git_stub_dir=""
  local stdout_file=""
  local stderr_file=""
  local git_log_file=""
  local gh_log_file=""
  local head_before=""
  local head_after=""
  local local_bash_path=""
  local real_git=""
  local pr_body_file=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  gh_body_wrapper_dir="$smoke_test_base/gh-body-wrapper"
  git_stub_dir="$smoke_test_base/git-stub"
  stdout_file="$smoke_test_base/repo-flow-submit-staged-watch.out"
  stderr_file="$smoke_test_base/repo-flow-submit-staged-watch.stderr"
  git_log_file="$smoke_test_base/repo-flow-submit-staged-watch.git-log"
  gh_log_file="$smoke_test_base/repo-flow-submit-staged-watch.gh-log"
  pr_body_file="$smoke_test_base/repo-flow-submit-staged-watch-body.md"
  smoke_write_gh_stub "$gh_stub_dir" || return 1
  smoke_write_repo_flow_gh_body_wrapper "$gh_body_wrapper_dir" "$gh_stub_dir/gh" || return 1
  smoke_write_repo_flow_git_sync_stub "$git_stub_dir" "$git_log_file" >/dev/null || return 1
  local_bash_path="$(command -v bash)" || return 1
  real_git="$(command -v git)" || return 1
  smoke_prepare_repo_flow_remote || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-staged-watch" || return 1

  printf '\nrepo-flow submit staged line\n' >> "$smoke_test_dir/docs/testing.md" || return 1
  git -C "$smoke_test_dir" add docs/testing.md || return 1
  head_before="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1
  cat > "$pr_body_file" <<'EOF'
## Scope

Existing watch PR body.

## What changed

- repo-flow submit watch test body

## What did not change

- The watch path stays the same.

## Verification status

- repo-flow submit watches CI and stops before merge

## User-visible behavior changes

None

## Stop conditions encountered

None

## Re-entry hint

Review the PR, then run `repo-automation/bin/repo-flow merge --explain`.
EOF

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$git_stub_dir:$gh_body_wrapper_dir:$gh_stub_dir:$PATH" \
    SMOKE_REAL_GIT="$real_git" \
    SMOKE_GIT_LOG_FILE="$git_log_file" \
    GH_STUB_PR_MERGE_LOG_FILE="$gh_log_file" \
    GH_STUB_PR_VIEW_NUMBER=702 \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/702' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_BODY_FILE="$pr_body_file" \
    GH_STUB_PR_VIEW_MERGEABLE='MERGEABLE' \
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-702' \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":601,"conclusion":"failure","createdAt":"2026-05-12T13:00:00Z","event":"pull_request","headBranch":"feature/repo-flow-submit-staged-watch","headSha":"old-sha-702","status":"completed","workflowName":"ci"},{"databaseId":602,"conclusion":"success","createdAt":"2026-05-12T13:05:00Z","event":"pull_request","headBranch":"feature/repo-flow-submit-staged-watch","headSha":"current-sha-702","status":"completed","workflowName":"ci"}]' \
    "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message='repo-flow submit staged commit' --watch --timeout=30 --diagnose-on-fail > "$stdout_file" 2> "$stderr_file"
  ) && [ "$(cat "$stdout_file")" = 'pass' ]; then
    head_after="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1
    if [ "$head_before" != "$head_after" ] &&
      git -C "$smoke_test_dir" log -1 --pretty=%s | grep -Fxq 'repo-flow submit staged commit' &&
      ! grep -q 'git checkout main' "$git_log_file" &&
      ! grep -q 'git pull --ff-only' "$git_log_file" &&
      ! grep -Fq 'gh pr merge' "$gh_log_file"; then
      test_pass "repo-flow submit watches CI and stops before merge"
    else
      test_fail "repo-flow submit watches CI and stops before merge"
      status=1
    fi
  else
    test_fail "repo-flow submit watches CI and stops before merge"
    status=1
  fi

  return "$status"
}

smoke_check_repo_flow_submit_watch_publishes_branch() {
  local status=0
  local gh_base_dir=""
  local gh_wrapper_dir=""
  local git_stub_dir=""
  local stdout_file=""
  local stderr_file=""
  local git_log_file=""
  local gh_log_file=""
  local create_log_file=""
  local sequence_log_file=""
  local push_marker_file=""
  local pr_state_file=""
  local local_bash_path=""
  local real_git=""
  local push_line=""
  local create_line=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_base_dir="$smoke_test_base/gh-base-stub"
  gh_wrapper_dir="$smoke_test_base/gh-wrapper-stub"
  git_stub_dir="$smoke_test_base/git-watch-stub"
  stdout_file="$smoke_test_base/repo-flow-submit-watch-publish.out"
  stderr_file="$smoke_test_base/repo-flow-submit-watch-publish.stderr"
  git_log_file="$smoke_test_base/repo-flow-submit-watch-publish.git-log"
  gh_log_file="$smoke_test_base/repo-flow-submit-watch-publish.gh-log"
  create_log_file="$smoke_test_base/repo-flow-submit-watch-publish-create.log"
  sequence_log_file="$smoke_test_base/repo-flow-submit-watch-publish-sequence.log"
  push_marker_file="$smoke_test_base/repo-flow-submit-watch-publish.pushed"
  pr_state_file="$smoke_test_base/repo-flow-submit-watch-publish.pr-state"
  smoke_write_gh_stub "$gh_base_dir" || return 1
  local_bash_path="$(command -v bash)" || return 1
  real_git="$(command -v git)" || return 1

  mkdir -p "$gh_wrapper_dir" "$git_stub_dir" || return 1
  cat > "$gh_wrapper_dir/gh" <<EOF
#!/usr/bin/env bash
set -u
cmd="\${1:-}"
sub="\${2:-}"
shift 2 >/dev/null 2>&1 || true

  log_gh() {
    if [ -n "\${SMOKE_GH_LOG_FILE:-}" ]; then
      printf '%s\n' "gh \$cmd \$sub \$*" >> "\$SMOKE_GH_LOG_FILE"
    fi
    if [ -n "\${SMOKE_SEQUENCE_LOG_FILE:-}" ]; then
      printf '%s\n' "gh \$cmd \$sub \$*" >> "\$SMOKE_SEQUENCE_LOG_FILE"
    fi
  }

require_pushed() {
  if [ ! -f "\${SMOKE_GIT_PUSH_MARKER_FILE:-}" ]; then
    printf '%s\n' "gh stub: Head sha can't be blank" >&2
    exit 1
  fi
}

case "\$cmd \$sub" in
  'pr view')
    require_pushed
    if [ ! -f "\${GH_STUB_PR_STATE_FILE:-}" ]; then
      exit 1
    fi
    number="\$(sed -n '1p' "\${GH_STUB_PR_STATE_FILE}" 2>/dev/null || true)"
    url="\$(sed -n '2p' "\${GH_STUB_PR_STATE_FILE}" 2>/dev/null || true)"
    title="\$(sed -n '3p' "\${GH_STUB_PR_STATE_FILE}" 2>/dev/null || true)"
    state="\$(sed -n '4p' "\${GH_STUB_PR_STATE_FILE}" 2>/dev/null || true)"
    if [[ " \$* " == *' --json '* ]] && [[ " \$* " != *' --jq '* ]]; then
      head_sha="\$(git rev-parse HEAD 2>/dev/null || true)"
      head_ref="\${SMOKE_REPO_FLOW_BRANCH:-feature/repo-flow-submit-watch-publish}"
      python3 - "\$number" "\$url" "\$title" "\$state" "\$head_sha" "\$head_ref" <<'PY'
import json
import sys

number, url, title, state, head_sha, head_ref = sys.argv[1:7]
print(json.dumps({
    'number': int(number) if str(number).isdigit() else number,
    'title': title,
    'url': url,
    'state': state,
    'isDraft': False,
    'mergeable': 'MERGEABLE',
    'headRefOid': head_sha,
    'headRefName': head_ref,
}))
PY
      exit 0
    fi
    case " \$* " in
      *' --json number '*|*' --jq .number '*)
        printf '%s\n' "\$number"
        ;;
      *' --json title '*|*' --jq .title '*)
        printf '%s\n' "\$title"
        ;;
      *' --json url '*|*' --jq .url '*)
        printf '%s\n' "\$url"
        ;;
      *' --json state '*|*' --jq .state '*)
        printf '%s\n' "\$state"
        ;;
      *' --json isDraft '*|*' --jq .isDraft '*)
        printf 'false\n'
        ;;
      *' --json mergeable '*|*' --jq .mergeable '*)
        printf 'MERGEABLE\n'
        ;;
      *' --json headRefName '*|*' --jq .headRefName '*)
        printf '%s\n' "\${SMOKE_REPO_FLOW_BRANCH:-feature/repo-flow-submit-watch-publish}"
        ;;
      *' --json headRefOid '*|*' --jq .headRefOid '*)
        git rev-parse HEAD 2>/dev/null || true
        ;;
      *)
        printf '%s\n' "\$number"
        ;;
    esac
    exit 0
    ;;
  'pr create')
    require_pushed
    log_gh
    if [ "${SMOKE_GH_FAIL_PR_CREATE:-0}" = "1" ]; then
      printf '%s\n' "gh pr create failed" >&2
      exit 1
    fi
    title=""
    base=""
    head=""
    body_file=""
    prev=""
    for arg in "\$@"; do
      if [ -n "\$prev" ]; then
        case "\$prev" in
          --title)
            title="\$arg"
            ;;
          --body-file)
            body_file="\$arg"
            ;;
          --base)
            base="\$arg"
            ;;
          --head)
            head="\$arg"
            ;;
        esac
        prev=""
        continue
      fi
      case "\$arg" in
        --title|--body-file|--base|--head)
          prev="\$arg"
          ;;
      esac
    done
    if [ -n "\${GH_STUB_PR_CREATE_LOG_FILE:-}" ]; then
      printf '%s\n' "gh pr create title=\$title base=\$base head=\$head body_file=\$body_file" >> "\${GH_STUB_PR_CREATE_LOG_FILE}"
    fi
    if [ -n "\${SMOKE_SEQUENCE_LOG_FILE:-}" ]; then
      printf '%s\n' "gh pr create title=\$title base=\$base head=\$head body_file=\$body_file" >> "\${SMOKE_SEQUENCE_LOG_FILE}"
    fi
    if [ -n "\${GH_STUB_PR_STATE_FILE:-}" ]; then
      number="\${GH_STUB_PR_CREATE_NUMBER:-401}"
      url="\${GH_STUB_PR_CREATE_URL:-https://github.com/i-schuyler/repo-automation-template/pull/\$number}"
      printf '%s\n%s\n%s\nOPEN\n' "\$number" "\$url" "repo-flow title" > "\${GH_STUB_PR_STATE_FILE}"
      printf '%s\n' "\$url"
    else
      printf '%s\n' "\${GH_STUB_PR_CREATE_URL:-https://github.com/i-schuyler/repo-automation-template/pull/401}"
    fi
    ;;
  'run list')
    if [ -n "\${SMOKE_GH_LOG_FILE:-}" ]; then
      printf '%s\n' "gh \$cmd \$sub \$*" >> "\$SMOKE_GH_LOG_FILE"
    fi
    if [ -n "\${SMOKE_SEQUENCE_LOG_FILE:-}" ]; then
      printf '%s\n' "gh \$cmd \$sub \$*" >> "\$SMOKE_SEQUENCE_LOG_FILE"
    fi
    printf '[{"databaseId":901,"conclusion":"success","createdAt":"2026-05-19T00:00:00Z","event":"pull_request","headBranch":"%s","headSha":"%s","status":"completed","workflowName":"ci"}]\n' "\${SMOKE_REPO_FLOW_BRANCH:-feature/repo-flow-submit-watch-publish}" "\$(git rev-parse HEAD 2>/dev/null || true)"
    ;;
  *)
    exec "\${SMOKE_REAL_GH_STUB:?missing SMOKE_REAL_GH_STUB}" "\$cmd" "\$sub" "\$@"
    ;;
esac
EOF
  chmod +x "$gh_wrapper_dir/gh" || return 1
cat > "$git_stub_dir/git" <<EOF
#!/usr/bin/env bash
set -u
case "\${1:-}" in
  checkout)
    if [ -n "\${SMOKE_GIT_LOG_FILE:-}" ]; then
      printf '%s\n' "git \$*" >> "\$SMOKE_GIT_LOG_FILE"
    fi
    if [ -n "\${SMOKE_SEQUENCE_LOG_FILE:-}" ]; then
      printf '%s\n' "git \$*" >> "\$SMOKE_SEQUENCE_LOG_FILE"
    fi
    exec "\${SMOKE_REAL_GIT:?missing SMOKE_REAL_GIT}" "\$@"
    ;;
  pull)
    if [ -n "\${SMOKE_GIT_LOG_FILE:-}" ]; then
      printf '%s\n' "git \$*" >> "\$SMOKE_GIT_LOG_FILE"
    fi
    if [ -n "\${SMOKE_SEQUENCE_LOG_FILE:-}" ]; then
      printf '%s\n' "git \$*" >> "\$SMOKE_SEQUENCE_LOG_FILE"
    fi
    exit 0
    ;;
esac
  if [ "\${1:-}" = "push" ]; then
    if [ -n "\${SMOKE_GIT_LOG_FILE:-}" ]; then
      printf '%s\n' "git \$*" >> "\$SMOKE_GIT_LOG_FILE"
    fi
    if [ -n "\${SMOKE_SEQUENCE_LOG_FILE:-}" ]; then
      printf '%s\n' "git \$*" >> "\$SMOKE_SEQUENCE_LOG_FILE"
    fi
    if "\${SMOKE_REAL_GIT:?missing SMOKE_REAL_GIT}" "\$@"; then
      : > "\${SMOKE_GIT_PUSH_MARKER_FILE:?missing SMOKE_GIT_PUSH_MARKER_FILE}"
      exit 0
  fi
  exit \$?
fi
exec "\${SMOKE_REAL_GIT:?missing SMOKE_REAL_GIT}" "\$@"
EOF
  chmod +x "$git_stub_dir/git" || return 1

  smoke_prepare_repo_flow_remote || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-watch-publish" || return 1
  printf '\nrepo-flow submit watch publish line\n' >> "$smoke_test_dir/docs/testing.md" || return 1
  git -C "$smoke_test_dir" add docs/testing.md || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_wrapper_dir:$gh_base_dir:$git_stub_dir:$PATH" \
    SMOKE_REAL_GH_STUB="$gh_base_dir/gh" \
    SMOKE_REAL_GIT="$real_git" \
    SMOKE_GIT_LOG_FILE="$git_log_file" \
    SMOKE_GIT_PUSH_MARKER_FILE="$push_marker_file" \
    SMOKE_SEQUENCE_LOG_FILE="$sequence_log_file" \
    SMOKE_REPO_FLOW_BRANCH="feature/repo-flow-submit-watch-publish" \
    GH_STUB_PR_STATE_FILE="$pr_state_file" \
    GH_STUB_PR_CREATE_LOG_FILE="$create_log_file" \
    GH_STUB_PR_MERGE_LOG_FILE="$gh_log_file" \
    GH_STUB_PR_CREATE_URL='https://github.com/i-schuyler/repo-automation-template/pull/801' \
    GH_STUB_PR_CREATE_NUMBER=801 \
    "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message='repo-flow submit watch publish commit' --watch --timeout=30 --explain > "$stdout_file" 2> "$stderr_file"
  ) && [ ! -s "$stdout_file" ]; then
    summary_count="$(grep -Fc '===== FINAL SUMMARY =====' "$stderr_file" 2>/dev/null || printf '0')"
    if [ "$summary_count" = "1" ] &&
      grep -Fq 'git push -u localorigin feature/repo-flow-submit-watch-publish' "$git_log_file" &&
      grep -Fq 'gh pr create title=' "$create_log_file" &&
      ! grep -Fq 'gh pr merge' "$gh_log_file" &&
      grep -Fxq '===== FINAL SUMMARY =====' "$stderr_file" &&
      grep -Fxq 'script=repo-flow' "$stderr_file" &&
      grep -Fxq 'mode=submit' "$stderr_file" &&
      grep -Fxq 'rc=0' "$stderr_file" &&
      grep -Fxq 'branch_before=feature/repo-flow-submit-watch-publish' "$stderr_file" &&
      grep -Fxq 'branch_after=feature/repo-flow-submit-watch-publish' "$stderr_file" &&
      grep -Fxq 'pr=801' "$stderr_file" &&
      grep -Eq '^commit=[0-9a-f]{7,40}$' "$stderr_file" &&
      grep -Fxq 'pushed=true' "$stderr_file" &&
      grep -Fxq 'merged=false' "$stderr_file" &&
      grep -Fxq 'status_count=0' "$stderr_file" &&
      grep -Fxq 'watched=true' "$stderr_file" &&
      grep -Fxq 'ci=pass' "$stderr_file" &&
      grep -Fxq 'url_or_stop=https://github.com/i-schuyler/repo-automation-template/pull/801' "$stderr_file" &&
      grep -Fxq '===== END =====' "$stderr_file" &&
      ! [ -s "$gh_log_file" ]; then
      push_line="$(grep -n -F 'git push -u localorigin feature/repo-flow-submit-watch-publish' "$sequence_log_file" | head -n1 | cut -d: -f1)"
      create_line="$(grep -n -F 'gh pr create title=' "$sequence_log_file" | head -n1 | cut -d: -f1)"
      if [ -n "$push_line" ] && [ -n "$create_line" ] && [ "$push_line" -le "$create_line" ]; then
        test_pass "repo-flow submit --watch stops before merge and prints explain summary"
      else
        test_fail "repo-flow submit --watch stops before merge and prints explain summary"
        status=1
      fi
    else
      test_fail "repo-flow submit --watch stops before merge and prints explain summary"
      status=1
    fi
  else
    test_fail "repo-flow submit --watch stops before merge and prints explain summary"
    status=1
  fi

  return "$status"
}

smoke_check_repo_flow_submit_watch_explain_failure_summary() {
  local status=0
  local gh_stub_dir=""
  local gh_body_wrapper_dir=""
  local git_stub_dir=""
  local stdout_file=""
  local stderr_file=""
  local git_log_file=""
  local gh_log_file=""
  local create_log_file=""
  local sequence_log_file=""
  local push_marker_file=""
  local local_bash_path=""
  local real_git=""
  local pr_body_file=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  gh_body_wrapper_dir="$smoke_test_base/gh-body-wrapper"
  git_stub_dir="$smoke_test_base/git-watch-stub"
  stdout_file="$smoke_test_base/repo-flow-submit-watch-explain-failure.out"
  stderr_file="$smoke_test_base/repo-flow-submit-watch-explain-failure.stderr"
  git_log_file="$smoke_test_base/repo-flow-submit-watch-explain-failure.git-log"
  gh_log_file="$smoke_test_base/repo-flow-submit-watch-explain-failure.gh-log"
  create_log_file="$smoke_test_base/repo-flow-submit-watch-explain-failure-create.log"
  sequence_log_file="$smoke_test_base/repo-flow-submit-watch-explain-failure-sequence.log"
  push_marker_file="$smoke_test_base/repo-flow-submit-watch-explain-failure.pushed"
  pr_body_file="$smoke_test_base/repo-flow-submit-watch-explain-failure-body.md"
  smoke_write_gh_stub "$gh_stub_dir" || return 1
  smoke_write_repo_flow_gh_body_wrapper "$gh_body_wrapper_dir" "$gh_stub_dir/gh" || return 1
  local_bash_path="$(command -v bash)" || return 1
  real_git="$(command -v git)" || return 1
  mkdir -p "$git_stub_dir" || return 1
  cat > "$git_stub_dir/git" <<EOF
#!/usr/bin/env bash
set -u
case "\${1:-}" in
  checkout)
    if [ -n "\${SMOKE_GIT_LOG_FILE:-}" ]; then
      printf '%s\n' "git \$*" >> "\$SMOKE_GIT_LOG_FILE"
    fi
    if [ -n "\${SMOKE_SEQUENCE_LOG_FILE:-}" ]; then
      printf '%s\n' "git \$*" >> "\$SMOKE_SEQUENCE_LOG_FILE"
    fi
    exec "\${SMOKE_REAL_GIT:?missing SMOKE_REAL_GIT}" "\$@"
    ;;
  pull)
    if [ -n "\${SMOKE_GIT_LOG_FILE:-}" ]; then
      printf '%s\n' "git \$*" >> "\$SMOKE_GIT_LOG_FILE"
    fi
    if [ -n "\${SMOKE_SEQUENCE_LOG_FILE:-}" ]; then
      printf '%s\n' "git \$*" >> "\$SMOKE_SEQUENCE_LOG_FILE"
    fi
    exit 0
    ;;
esac
  if [ "\${1:-}" = "push" ]; then
    if [ -n "\${SMOKE_GIT_LOG_FILE:-}" ]; then
      printf '%s\n' "git \$*" >> "\$SMOKE_GIT_LOG_FILE"
    fi
    if [ -n "\${SMOKE_SEQUENCE_LOG_FILE:-}" ]; then
      printf '%s\n' "git \$*" >> "\$SMOKE_SEQUENCE_LOG_FILE"
    fi
    if "\${SMOKE_REAL_GIT:?missing SMOKE_REAL_GIT}" "\$@"; then
      : > "\${SMOKE_GIT_PUSH_MARKER_FILE:?missing SMOKE_GIT_PUSH_MARKER_FILE}"
      exit 0
    fi
    exit \$?
  fi
exec "\${SMOKE_REAL_GIT:?missing SMOKE_REAL_GIT}" "\$@"
EOF
  chmod +x "$git_stub_dir/git" || return 1

  smoke_prepare_repo_flow_remote || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-watch-explain-failure" || return 1
  printf '\nrepo-flow submit watch explain failure line\n' >> "$smoke_test_dir/docs/testing.md" || return 1
  git -C "$smoke_test_dir" add docs/testing.md || return 1
  cat > "$pr_body_file" <<'EOF'
## Scope

Existing watch PR body.

## What changed

- repo-flow submit watch explain failure body

## What did not change

- The watch path stays the same.

## Verification status

- repo-flow submit watch explain failure summary

## User-visible behavior changes

None

## Stop conditions encountered

None

## Re-entry hint

Review the PR, then run `repo-automation/bin/repo-flow merge --explain`.
EOF

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_body_wrapper_dir:$gh_stub_dir:$git_stub_dir:$PATH" \
    SMOKE_REAL_GIT="$real_git" \
    SMOKE_GIT_LOG_FILE="$git_log_file" \
    SMOKE_GIT_PUSH_MARKER_FILE="$push_marker_file" \
    SMOKE_SEQUENCE_LOG_FILE="$sequence_log_file" \
    GH_STUB_PR_CREATE_LOG_FILE="$create_log_file" \
    GH_STUB_PR_MERGE_LOG_FILE="$gh_log_file" \
    GH_STUB_PR_VIEW_HEAD_REF='feature/repo-flow-submit-watch-explain-failure' \
    GH_STUB_PR_VIEW_HEAD_SHA='current-sha-902' \
    GH_STUB_PR_VIEW_NUMBER=902 \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/902' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_BODY_FILE="$pr_body_file" \
    GH_STUB_PR_VIEW_MERGEABLE='MERGEABLE' \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":902,"conclusion":"failure","createdAt":"2026-05-12T13:00:00Z","event":"pull_request","headBranch":"feature/repo-flow-submit-watch-explain-failure","headSha":"current-sha-902","status":"completed","workflowName":"ci"}]' \
    GH_STUB_RUN_VIEW_FAILED_LOG='fail: CI checks failed
path: repo-automation/tests/contracts/repo-flow.sh
fix: inspect the failing CI log and rerun the focused test' \
    "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message='repo-flow submit watch explain failure commit' --watch --timeout=30 --diagnose-on-fail --explain > "$stdout_file" 2> "$stderr_file"
  ); then
    test_fail "repo-flow submit --watch explain diagnoses blocked checks"
    status=1
  elif summary_count="$(grep -Fc '===== FINAL SUMMARY =====' "$stderr_file" 2>/dev/null || printf '0')" &&
    [ "$summary_count" = "1" ] &&
    grep -Fq 'git push -u localorigin feature/repo-flow-submit-watch-explain-failure' "$git_log_file" &&
    [ ! -s "$stdout_file" ] &&
    grep -Fxq '===== FINAL SUMMARY =====' "$stderr_file" &&
    grep -Fxq 'script=repo-flow' "$stderr_file" &&
    grep -Fxq 'mode=submit' "$stderr_file" &&
    grep -Fxq 'rc=1' "$stderr_file" &&
    grep -Fxq 'branch_before=feature/repo-flow-submit-watch-explain-failure' "$stderr_file" &&
    grep -Fxq 'branch_after=feature/repo-flow-submit-watch-explain-failure' "$stderr_file" &&
    grep -Fxq 'pr=902' "$stderr_file" &&
    grep -Eq '^commit=[0-9a-f]{7,40}$' "$stderr_file" &&
    grep -Fxq 'pushed=true' "$stderr_file" &&
    grep -Fxq 'merged=false' "$stderr_file" &&
    grep -Fxq 'status_count=0' "$stderr_file" &&
    grep -Fxq 'watched=true' "$stderr_file" &&
    grep -Fxq 'ci=fail' "$stderr_file" &&
    grep -Fxq 'url_or_stop=https://github.com/i-schuyler/repo-automation-template/pull/902' "$stderr_file" &&
    grep -Fxq '===== END =====' "$stderr_file" &&
    grep -Fq 'fail: CI checks failed' "$stderr_file" &&
    [ ! -s "$create_log_file" ] &&
    ! [ -s "$gh_log_file" ]; then
    test_pass "repo-flow submit --watch explain diagnoses blocked checks"
  else
    test_fail "repo-flow submit --watch explain diagnoses blocked checks"
    status=1
  fi

  return "$status"
}

smoke_check_repo_flow_docs_check_quiet_details() {
  local status=0
  local quiet_out=""
  local quiet_err=""
  local fail_out=""
  local fail_err=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  quiet_out="$smoke_test_base/docs-check-quiet.out"
  quiet_err="$smoke_test_base/docs-check-quiet.stderr"
  fail_out="$smoke_test_base/docs-check-fail.out"
  fail_err="$smoke_test_base/docs-check-fail.stderr"

  if (
    # shellcheck disable=SC2154 # smoke_repo_root is provided by the smoke harness.
    cd "$smoke_repo_root" || return 1
    repo-automation/tests/docs-check.sh --quiet > "$quiet_out" 2> "$quiet_err"
  ) && [ ! -s "$quiet_out" ] && [ ! -s "$quiet_err" ]; then
    test_pass "docs-check quiet success is silent"
  else
    test_fail "docs-check quiet success is silent"
    status=1
  fi

  printf '\n[broken](does-not-exist.md)\n' >> "$smoke_test_dir/repo-automation/docs/testing.md" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/tests/docs-check.sh --quiet > "$fail_out" 2> "$fail_err"
  ); then
    test_fail "docs-check quiet failure reports actionable details"
    status=1
  elif [ -s "$fail_err" ] || \
    ! grep -Fq 'FAIL: docs-check: local links:' "$fail_out" || \
    ! grep -Fq 'repo-automation/docs/testing.md -> does-not-exist.md -> missing' "$fail_out" || \
    grep -Fq 'PASS:' "$fail_out"; then
    test_fail "docs-check quiet failure reports actionable details"
    status=1
  else
    test_pass "docs-check quiet failure reports actionable details"
  fi

  return "$status"
}

smoke_check_repo_flow_version_consistency_quiet_details() {
  local status=0
  local quiet_out=""
  local quiet_err=""
  local fail_out=""
  local fail_err=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  quiet_out="$smoke_test_base/version-consistency-quiet.out"
  quiet_err="$smoke_test_base/version-consistency-quiet.stderr"
  fail_out="$smoke_test_base/version-consistency-fail.out"
  fail_err="$smoke_test_base/version-consistency-fail.stderr"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/tests/version-consistency.sh --quiet > "$quiet_out" 2> "$quiet_err"
  ) && [ ! -s "$quiet_out" ] && [ ! -s "$quiet_err" ]; then
    test_pass "version-consistency quiet success is silent"
  else
    test_fail "version-consistency quiet success is silent"
    status=1
  fi

  (
    cd "$smoke_test_dir" || return 1
    chmod -x repo-automation/bin/prepare-release >/dev/null 2>&1 || true
    printf '9.9.9\n' > VERSION || return 1
  ) || return 1

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/tests/version-consistency.sh --quiet > "$fail_out" 2> "$fail_err"
  ); then
    test_fail "version-consistency quiet failure reports actionable details"
    status=1
  elif [ -s "$fail_out" ] || \
    ! grep -Fq 'FAIL: version-consistency: installed automation config REPO_AUTOMATION_VERSION matches VERSION' "$fail_err" || \
    grep -Fq 'PASS:' "$fail_err"; then
    test_fail "version-consistency quiet failure reports actionable details"
    status=1
  else
    test_pass "version-consistency quiet failure reports actionable details"
  fi

  return "$status"
}

smoke_check_repo_flow_merge_contract() {
  local status=0
  local gh_stub_dir=""
  local git_stub_dir=""
  local stdout_file=""
  local stderr_file=""
  local git_log_file=""
  local gh_merge_log_file=""
  local gh_wrapper_dir=""
  local sequence_log_file=""
  local help_out=""
  local watch_stderr="$smoke_test_base/repo-flow-merge-watch.stderr"
  local local_bash_path=""
  local real_git=""
  local head_sha=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  git_stub_dir="$smoke_test_base/git-stub"
  stdout_file="$smoke_test_base/repo-flow-merge.out"
  stderr_file="$smoke_test_base/repo-flow-merge.stderr"
  git_log_file="$smoke_test_base/repo-flow-merge.git-log"
  gh_merge_log_file="$smoke_test_base/repo-flow-merge-gh.log"
  gh_view_log_file="$smoke_test_base/repo-flow-merge-gh-view.log"
  run_list_log_file="$smoke_test_base/repo-flow-merge-run-list.log"
  gh_wrapper_dir="$smoke_test_base/gh-wrapper"
  sequence_log_file="$smoke_test_base/repo-flow-merge-sequence.log"
  smoke_write_gh_stub "$gh_stub_dir" || return 1
  smoke_write_repo_flow_git_sync_stub "$git_stub_dir" "$git_log_file" >/dev/null || return 1
  local_bash_path="$(command -v bash)" || return 1
  real_git="$(command -v git)" || return 1
  smoke_prepare_repo_flow_remote || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-merge" || return 1
  printf '\nrepo-flow merge line\n' >> "$smoke_test_dir/docs/testing.md" || return 1
  git -C "$smoke_test_dir" add docs/testing.md || return 1
  git -C "$smoke_test_dir" commit -m "repo-flow merge test" >/dev/null || return 1
  head_sha="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1

  # shellcheck disable=SC2154 # smoke_repo_root is provided by the smoke harness.
  if python3 - "$smoke_repo_root/repo-automation/helper-metadata.json" <<'PY'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))
planned = {entry.get('name') for entry in data.get('planned_routes', []) if isinstance(entry, dict)}
raise SystemExit(0 if 'merge' in planned else 1)
PY
  then
    test_pass "repo-flow helper metadata includes merge planned route"
  else
    test_fail "repo-flow helper metadata includes merge planned route"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    "$local_bash_path" repo-automation/bin/repo-flow merge --watch >/dev/null 2> "$watch_stderr"
  ); then
    test_fail "repo-flow merge rejects --watch"
    status=1
  elif smoke_assert_flag_error_shape "$watch_stderr" "unknown flag" "--watch" "run repo-automation/bin/repo-flow merge --help"; then
    test_pass "repo-flow merge rejects --watch"
  else
    test_fail "repo-flow merge rejects --watch"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$git_stub_dir:$gh_stub_dir:$PATH" \
    SMOKE_REAL_GIT="$real_git" \
    SMOKE_GIT_LOG_FILE="$git_log_file" \
    SMOKE_SEQUENCE_LOG_FILE="$sequence_log_file" \
    GH_STUB_PR_VIEW_HEAD_SHA="$head_sha" \
    GH_STUB_PR_VIEW_HEAD_REF="feature/repo-flow-merge" \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_NUMBER=903 \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/903' \
    GH_STUB_PR_VIEW_TITLE='repo-flow merge test PR' \
    GH_STUB_PR_VIEW_MERGEABLE='MERGEABLE' \
    GH_STUB_PR_MERGE_LOG_FILE="$gh_merge_log_file" \
    GH_STUB_PR_MERGE_UPDATE_MAIN=1 \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":903,"conclusion":"success","createdAt":"2026-05-12T13:00:00Z","event":"pull_request","headBranch":"feature/repo-flow-merge","headSha":"'"$head_sha"'","status":"completed","workflowName":"ci"}]' \
    "$local_bash_path" repo-automation/bin/repo-flow merge --pr=903 --json > "$stdout_file" 2> "$stderr_file"
  ) && [ -s "$stdout_file" ] && python3 -m json.tool "$stdout_file" >/dev/null && [ ! -s "$stderr_file" ]; then
    if grep -Fq 'merged-pr' "$stdout_file" && grep -Fq '"mode":"merge"' "$stdout_file"; then
      test_pass "repo-flow merge --json emits parseable JSON only"
    else
      test_fail "repo-flow merge --json emits parseable JSON only"
      status=1
    fi
  else
    test_fail "repo-flow merge --json emits parseable JSON only"
    status=1
  fi

  git -C "$smoke_test_dir" checkout -B feature/repo-flow-merge "$head_sha" >/dev/null || return 1
  : > "$git_log_file"
  : > "$gh_merge_log_file"
  : > "$gh_view_log_file"
  : > "$run_list_log_file"
  : > "$sequence_log_file"
  mkdir -p "$gh_wrapper_dir" || return 1
  cat > "$gh_wrapper_dir/gh" <<'EOF'
#!/usr/bin/env bash
set -u
if [ "${1:-}" = "pr" ] && [ "${2:-}" = "view" ] && [ "${3:-}" = "feature/repo-flow-merge" ]; then
  printf 'gh pr view feature/repo-flow-merge should not be used for merge summary\n' >&2
  exit 1
fi
exec "${SMOKE_REAL_GH_STUB:?missing SMOKE_REAL_GH_STUB}" "$@"
EOF
  chmod +x "$gh_wrapper_dir/gh" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_wrapper_dir:$git_stub_dir:$gh_stub_dir:$PATH" \
    SMOKE_REAL_GIT="$real_git" \
    SMOKE_REAL_GH_STUB="$gh_stub_dir/gh" \
    SMOKE_GIT_LOG_FILE="$git_log_file" \
    SMOKE_SEQUENCE_LOG_FILE="$sequence_log_file" \
    GH_STUB_PR_VIEW_LOG_FILE="$gh_view_log_file" \
    GH_STUB_PR_VIEW_HEAD_SHA="$head_sha" \
    GH_STUB_PR_VIEW_HEAD_REF="feature/repo-flow-merge" \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_NUMBER=903 \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/903' \
    GH_STUB_PR_VIEW_TITLE='repo-flow merge test PR' \
    GH_STUB_PR_VIEW_MERGEABLE='MERGEABLE' \
    GH_STUB_PR_MERGE_LOG_FILE="$gh_merge_log_file" \
    GH_STUB_PR_MERGE_UPDATE_MAIN=1 \
    GH_STUB_RUN_LIST_LOG_FILE="$run_list_log_file" \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":903,"conclusion":"success","createdAt":"2026-05-12T13:00:00Z","event":"pull_request","headBranch":"feature/repo-flow-merge","headSha":"'"$head_sha"'","status":"completed","workflowName":"ci"}]' \
    "$local_bash_path" repo-automation/bin/repo-flow merge --pr=current --explain > "$stdout_file" 2> "$stderr_file"
  ) && [ ! -s "$stdout_file" ]; then
    summary_count="$(grep -Fc '===== FINAL SUMMARY =====' "$stderr_file" 2>/dev/null || printf '0')"
    if [ "$summary_count" = "1" ] &&
      grep -Fq 'INFO: timing:' "$stderr_file" &&
      grep -Fxq 'script=repo-flow' "$stderr_file" &&
      grep -Fxq 'mode=merge' "$stderr_file" &&
      grep -Fxq 'rc=0' "$stderr_file" &&
      grep -Fxq 'branch_before=feature/repo-flow-merge' "$stderr_file" &&
      grep -Fxq 'branch_after=main' "$stderr_file" &&
      grep -Fxq 'pr=903' "$stderr_file" &&
      ! grep -Fxq 'pr=unknown' "$stderr_file" &&
      grep -Fxq 'merged=true' "$stderr_file" &&
      grep -Fxq 'ci=pass' "$stderr_file" &&
      grep -Fxq 'url_or_stop=https://github.com/i-schuyler/repo-automation-template/pull/903' "$stderr_file" &&
      grep -Eq '^elapsed_seconds=[0-9]+$' "$stderr_file" &&
      grep -Fxq '===== END =====' "$stderr_file" &&
      [ "$(grep -Fc 'gh run list ' "$run_list_log_file" 2>/dev/null || printf '0')" = "1" ] &&
      ! grep -Fq 'gh pr view feature/repo-flow-merge' "$gh_view_log_file" &&
      grep -Fq 'gh pr view --json number,title,url,state,isDraft,mergeable,headRefOid,headRefName' "$gh_view_log_file" &&
      grep -Fq 'gh pr merge 903 --squash --delete-branch' "$gh_merge_log_file" &&
      grep -Fq 'git checkout main' "$git_log_file" &&
      grep -Fq 'git pull --ff-only' "$git_log_file"; then
      test_pass "repo-flow merge uses the explicit merge/delete/sync path"
    else
      test_fail "repo-flow merge uses the explicit merge/delete/sync path"
      status=1
    fi
  else
    test_fail "repo-flow merge uses the explicit merge/delete/sync path"
    status=1
  fi

  : > "$git_log_file"
  : > "$gh_merge_log_file"
  : > "$gh_view_log_file"
  : > "$run_list_log_file"
  git -C "$smoke_test_dir" checkout -B feature/repo-flow-merge "$head_sha" >/dev/null || return 1
  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_wrapper_dir:$git_stub_dir:$gh_stub_dir:$PATH" \
    SMOKE_REAL_GIT="$real_git" \
    SMOKE_REAL_GH_STUB="$gh_stub_dir/gh" \
    SMOKE_GIT_LOG_FILE="$git_log_file" \
    SMOKE_SEQUENCE_LOG_FILE="$sequence_log_file" \
    GH_STUB_PR_VIEW_FAIL_ONCE_FILE="$smoke_test_base/repo-flow-merge-view.fail" \
    GH_STUB_PR_VIEW_FAIL_ONCE_STDERR='net/http: TLS handshake timeout' \
    GH_STUB_PR_VIEW_LOG_FILE="$gh_view_log_file" \
    GH_STUB_PR_VIEW_HEAD_SHA="$head_sha" \
    GH_STUB_PR_VIEW_HEAD_REF="feature/repo-flow-merge" \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_NUMBER=903 \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/903' \
    GH_STUB_PR_VIEW_TITLE='repo-flow merge test PR' \
    GH_STUB_PR_VIEW_MERGEABLE='MERGEABLE' \
    GH_STUB_PR_MERGE_LOG_FILE="$gh_merge_log_file" \
    GH_STUB_PR_MERGE_UPDATE_MAIN=1 \
    GH_STUB_RUN_LIST_LOG_FILE="$run_list_log_file" \
    GH_STUB_RUN_LIST_JSON='[{"databaseId":903,"conclusion":"success","createdAt":"2026-05-12T13:00:00Z","event":"pull_request","headBranch":"feature/repo-flow-merge","headSha":"'"$head_sha"'","status":"completed","workflowName":"ci"}]' \
    "$local_bash_path" repo-automation/bin/repo-flow merge --pr=current --explain > "$stdout_file" 2> "$stderr_file"
  ); then
    test_fail "repo-flow merge fails when pr-finish fails"
    status=1
  elif grep -Fq 'pr-finish completion failed for PR current' "$stderr_file" &&
    ! grep -Fq 'gh pr merge 903' "$gh_merge_log_file"; then
    test_pass "repo-flow merge fails when pr-finish fails"
  else
    test_fail "repo-flow merge fails when pr-finish fails"
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
  local missing_mode_stderr=""
  local staged_guard_stderr=""
  local modified_new_file_stderr=""
  local unrequested_dirty_stderr=""
  local canonical_remote_stderr=""
  local alias_remote_stderr=""
  local rejected_remote_stderr=""
  local body_file_help_stderr=""
  local body_file_empty_stderr=""
  local body_file_missing_stderr=""
  local body_file_directory_stderr=""
  local body_file_invalid_stderr=""
  local alias_create_stdout=""
  local alias_create_stderr=""
  local alias_create_log_file=""
  local alias_reuse_stdout=""
  local alias_reuse_stderr=""
  local repo_flow_gh_stub_dir=""
  local review_pack_contract_explain_stdout=""
  local review_pack_contract_explain_stderr=""
  local local_bash_path=""
  local ssh_stub_dir=""
  local all_stdout=""
  local all_stderr=""
  local all_status_before=""
  local all_status_after=""
  local all_head_before=""
  local all_head_after=""
  local all_summary_block=""
  local all_summary_line=""
  local all_mode_line=""
  local all_count_line=""
  local all_failure_reason=""
  local all_gh_stub_dir=""
  local isolated_repo_dir=""
  local status_before=""
  local status_after=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  help_out="$smoke_test_base/repo-flow-submit-help.txt"
  missing_mode_stderr="$smoke_test_base/repo-flow-submit-missing-mode.stderr"
  invalid_abs_stderr="$smoke_test_base/repo-flow-submit-invalid-abs.stderr"
  invalid_dotdot_stderr="$smoke_test_base/repo-flow-submit-invalid-dotdot.stderr"
  missing_stderr="$smoke_test_base/repo-flow-submit-missing.stderr"
  staged_guard_stderr="$smoke_test_base/repo-flow-submit-staged-guard.stderr"
  modified_new_file_stderr="$smoke_test_base/repo-flow-submit-modified-new-file.stderr"
  unrequested_dirty_stderr="$smoke_test_base/repo-flow-submit-unrequested-dirty.stderr"
  canonical_remote_stderr="$smoke_test_base/repo-flow-submit-canonical-remote.stderr"
  alias_remote_stderr="$smoke_test_base/repo-flow-submit-alias-remote.stderr"
  rejected_remote_stderr="$smoke_test_base/repo-flow-submit-rejected-remote.stderr"
  body_file_help_stderr="$smoke_test_base/repo-flow-submit-body-file-help.stderr"
  body_file_empty_stderr="$smoke_test_base/repo-flow-submit-body-file-empty.stderr"
  body_file_missing_stderr="$smoke_test_base/repo-flow-submit-body-file-missing.stderr"
  body_file_directory_stderr="$smoke_test_base/repo-flow-submit-body-file-directory.stderr"
  body_file_invalid_stderr="$smoke_test_base/repo-flow-submit-body-file-invalid.stderr"
  review_pack_contract_explain_stdout="$smoke_test_base/review-pack-contract-explain.out"
  review_pack_contract_explain_stderr="$smoke_test_base/review-pack-contract-explain.stderr"
  ssh_stub_dir="$smoke_test_base/ssh-stub"
  smoke_write_gh_stub "$gh_stub_dir" || return 1
  local_bash_path="$(command -v bash)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --help > "$help_out"
  ) && grep -Fxq 'Usage: repo-automation/bin/repo-flow submit [--all|--modified|--paths=<path[,path...]>|--staged] --message=<text> [--body-file=<path>] [--replace-body] [--watch] [--timeout=<seconds>] [--diagnose-on-fail] [--explain] [--help]' "$help_out"; then
    if ! grep -Fq 'pr-finish --merge' "$help_out" && ! grep -Fq 'repo-flow merge' "$help_out"; then
      test_pass "repo-flow submit help shows strict syntax"
    else
      test_fail "repo-flow submit help shows strict syntax"
      status=1
    fi
  else
    test_fail "repo-flow submit help shows strict syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --message=hi --explain >/dev/null 2> "$missing_mode_stderr"
  ); then
    test_fail "repo-flow submit omits submit mode summary fields when no submit mode is selected"
    status=1
  elif grep -Fxq 'STOP: either --all, --modified, --paths or --staged is required' "$missing_mode_stderr" &&
    grep -Fxq '===== FINAL SUMMARY =====' "$missing_mode_stderr" &&
    ! grep -Fq 'submit_mode=' "$missing_mode_stderr" &&
    ! grep -Fq 'staged_count=' "$missing_mode_stderr"; then
    test_pass "repo-flow submit omits submit mode summary fields when no submit mode is selected"
  else
    test_fail "repo-flow submit omits submit mode summary fields when no submit mode is selected"
    status=1
  fi

  smoke_prepare_repo_flow_remote || return 1
  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-all" || return 1
  isolated_repo_dir="$(mktemp -d "${TMPDIR:-$HOME/.cache}/repo-flow-submit-all.XXXXXX")" || return 1
  git clone --quiet "$smoke_test_dir" "$isolated_repo_dir" || return 1
  git -C "$isolated_repo_dir" checkout feature/repo-flow-submit-all >/dev/null 2>&1 || return 1
  smoke_test_dir="$isolated_repo_dir" smoke_prepare_repo_flow_remote || return 1
  printf '\nrepo-flow submit all modified line\n' >> "$isolated_repo_dir/README.md" || return 1
  rm -f "$isolated_repo_dir/repo-automation/docs/repo-flow.md" || return 1
  printf 'repo-flow submit all new file\n' > "$isolated_repo_dir/docs/repo-flow-submit-all.md" || return 1
  all_gh_stub_dir="$smoke_test_base/repo-flow-submit-all-gh-stub"
  mkdir -p "$all_gh_stub_dir" || return 1
  cat > "$all_gh_stub_dir/gh" <<'EOF'
#!/usr/bin/env bash
set -u
cmd="${1:-}"
sub="${2:-}"
shift 2 >/dev/null 2>&1 || true
case "$cmd $sub" in
  'auth status')
    exit 0
    ;;
  'pr view')
    exit 1
    ;;
  'pr create')
    printf '%s\n' "${GH_STUB_PR_CREATE_URL:-https://github.com/i-schuyler/repo-automation-template/pull/801}"
    ;;
  'pr edit')
    exit 0
    ;;
  *)
    printf 'unexpected %s %s\n' "$cmd" "$sub" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "$all_gh_stub_dir/gh" || return 1
  all_stdout="$smoke_test_base/repo-flow-submit-all.out"
  all_stderr="$smoke_test_base/repo-flow-submit-all.stderr"
  all_status_before="$(git -C "$isolated_repo_dir" status --porcelain --untracked-files=all)" || return 1
  all_head_before="$(git -C "$isolated_repo_dir" rev-parse HEAD)" || return 1

  if (
    cd "$isolated_repo_dir" || return 1
    env -i \
      HOME="$HOME" \
      TMPDIR="${TMPDIR:-$HOME/.cache}" \
      PATH="$all_gh_stub_dir:$PATH" \
      GH_STUB_PR_CREATE_URL='https://github.com/i-schuyler/repo-automation-template/pull/801' \
      "$local_bash_path" repo-automation/bin/repo-flow submit --all --message='repo-flow submit all commit' --explain > "$all_stdout" 2> "$all_stderr"
  ); then
    all_status_after="$(git -C "$isolated_repo_dir" status --porcelain --untracked-files=all)" || return 1
    all_head_after="$(git -C "$isolated_repo_dir" rev-parse HEAD)" || return 1
    all_summary_block="$(awk '/^===== FINAL SUMMARY =====$/ { in_summary = 1; next } /^===== END =====$/ { in_summary = 0 } in_summary { print }' "$all_stderr")"
    all_summary_line="$(grep -n -m1 '^===== FINAL SUMMARY =====$' "$all_stderr" | cut -d: -f1)"
    all_mode_line="$(grep -n -m1 '^INFO: submit mode: all$' "$all_stderr" | cut -d: -f1)"
    all_count_line="$(grep -n -m1 '^INFO: staged count: 3$' "$all_stderr" | cut -d: -f1)"
    if [ "$all_status_before" = "$all_status_after" ]; then
      all_failure_reason="worktree status did not change"
    elif [ "$all_head_before" = "$all_head_after" ]; then
      all_failure_reason="head did not advance"
    elif [ -n "$all_status_after" ]; then
      all_failure_reason="worktree not clean after submit"
    elif [ -z "$all_summary_line" ]; then
      all_failure_reason="missing final summary"
    elif [ -z "$all_mode_line" ]; then
      all_failure_reason="missing submit mode explain line"
    elif [ -z "$all_count_line" ]; then
      all_failure_reason="missing staged count explain line"
    elif [ "$all_mode_line" -ge "$all_summary_line" ]; then
      all_failure_reason="submit mode line appeared after final summary"
    elif [ "$all_count_line" -ge "$all_summary_line" ]; then
      all_failure_reason="staged count line appeared after final summary"
    elif ! grep -Fxq 'submit_mode=all' "$all_stderr"; then
      all_failure_reason="final summary missing submit_mode=all"
    elif ! grep -Fxq 'staged_count=3' "$all_stderr"; then
      all_failure_reason="final summary missing staged_count=3"
    elif ! grep -Fq 'INFO: staged files:' "$all_stderr"; then
      all_failure_reason="missing staged files explain section"
    elif ! grep -Fq '  README.md' "$all_stderr"; then
      all_failure_reason="missing README.md explain entry"
    elif ! grep -Fq '  repo-automation/docs/repo-flow.md' "$all_stderr"; then
      all_failure_reason="missing deleted path explain entry"
    elif ! grep -Fq '  docs/repo-flow-submit-all.md' "$all_stderr"; then
      all_failure_reason="missing new file explain entry"
    elif grep -Eq 'README\.md|repo-automation/docs/repo-flow\.md|docs/repo-flow-submit-all\.md' <<<"$all_summary_block"; then
      all_failure_reason="final summary includes staged filenames"
    elif ! grep -Fxq 'INFO: PR body: generated fallback' "$all_stderr"; then
      all_failure_reason="missing generated-fallback PR body explain line"
    else
      test_pass "repo-flow submit --all stages tracked, deleted, and new files"
      all_failure_reason=""
    fi
    if [ -n "$all_failure_reason" ]; then
      test_fail "repo-flow submit --all stages tracked, deleted, and new files ($all_failure_reason)"
      status=1
    else
      :
    fi
  else
    all_failure_reason="$(test_extract_first_actionable_failure "$all_stderr" 2>/dev/null || true)"
    if [ -z "$all_failure_reason" ]; then
      all_failure_reason="$(sed -n '1,8p' "$all_stderr" 2>/dev/null | tr '\n' '; ' | sed 's/[;[:space:]]*$//')"
    fi
    [ -n "$all_failure_reason" ] || all_failure_reason="command failed"
    test_fail "repo-flow submit --all stages tracked, deleted, and new files ($all_failure_reason)"
    if [ -s "$all_stderr" ]; then
      printf '%s\n' "$all_failure_reason" >&2
    fi
    status=1
  fi

  rm -rf "$isolated_repo_dir" >/dev/null 2>&1 || true

  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-all-conflicts" || return 1
  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --all --modified --message=hi >/dev/null 2> "$invalid_abs_stderr"
  ); then
    test_fail "repo-flow submit rejects --all with --modified"
    status=1
  elif grep -Fxq 'STOP: use either --all or --modified, not both' "$invalid_abs_stderr" &&
    ! grep -Fq 'submit_mode=' "$invalid_abs_stderr" &&
    ! grep -Fq 'staged_count=' "$invalid_abs_stderr"; then
    test_pass "repo-flow submit rejects --all with --modified"
  else
    test_fail "repo-flow submit rejects --all with --modified"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --all --paths=README.md --message=hi >/dev/null 2> "$invalid_dotdot_stderr"
  ); then
    test_fail "repo-flow submit rejects --all with --paths"
    status=1
  elif grep -Fxq 'STOP: use either --all or --paths, not both' "$invalid_dotdot_stderr" &&
    ! grep -Fq 'submit_mode=' "$invalid_dotdot_stderr" &&
    ! grep -Fq 'staged_count=' "$invalid_dotdot_stderr"; then
    test_pass "repo-flow submit rejects --all with --paths"
  else
    test_fail "repo-flow submit rejects --all with --paths"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --all --staged --message=hi >/dev/null 2> "$missing_stderr"
  ); then
    test_fail "repo-flow submit rejects --all with --staged"
    status=1
  elif grep -Fxq 'STOP: use either --all or --staged, not both' "$missing_stderr" &&
    ! grep -Fq 'submit_mode=' "$missing_stderr" &&
    ! grep -Fq 'staged_count=' "$missing_stderr"; then
    test_pass "repo-flow submit rejects --all with --staged"
  else
    test_fail "repo-flow submit rejects --all with --staged"
    status=1
  fi

  cat > "$smoke_test_base/repo-flow-submit-body-file-valid.md" <<'EOF'
## Scope

Human-authored PR body smoke test.

## What changed

- Added body-file submit support.

## What did not change

- The fallback generated body remains available.

## Verification status

- repo-flow submit body-file smoke test

## User-visible behavior changes

Review-facing PRs can now use a user-authored body.

## Stop conditions encountered

None

## Re-entry hint

Review the PR, then run `repo-automation/bin/repo-flow merge --explain`.
EOF
  cat > "$smoke_test_base/repo-flow-submit-body-file-invalid.md" <<'EOF'
## Scope

Branch: feature/demo
Base: main
Ahead: 1
Behind: 0

## What changed

Branch: feature/demo
Base: main
Ahead: 1
Behind: 0

## What did not change

Branch: feature/demo
Base: main
Ahead: 1
Behind: 0

## Verification status

Branch: feature/demo
Base: main
Ahead: 1
Behind: 0

## User-visible behavior changes

Branch: feature/demo
Base: main
Ahead: 1
Behind: 0

## Stop conditions encountered

Branch: feature/demo
Base: main
Ahead: 1
Behind: 0

## Re-entry hint

Branch: feature/demo
Base: main
Ahead: 1
Behind: 0
EOF
  mkdir -p "$smoke_test_base/repo-flow-submit-body-file-directory" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message=hi --body-file > "$help_out" 2> "$body_file_help_stderr"
  ); then
    test_fail "repo-flow submit rejects bare --body-file"
    status=1
  elif smoke_assert_flag_error_shape "$body_file_help_stderr" "missing flag value" "--body-file" "use --body-file=<path>"; then
    test_pass "repo-flow submit rejects bare --body-file"
  else
    test_fail "repo-flow submit rejects bare --body-file"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message=hi --body-file= > "$help_out" 2> "$body_file_empty_stderr"
  ); then
    test_fail "repo-flow submit rejects empty --body-file values"
    status=1
  elif smoke_assert_flag_error_shape "$body_file_empty_stderr" "empty flag value" "--body-file" "use --body-file=<path>"; then
    test_pass "repo-flow submit rejects empty --body-file values"
  else
    test_fail "repo-flow submit rejects empty --body-file values"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message=hi --body-file "$smoke_test_base/repo-flow-submit-body-file-valid.md" > "$help_out" 2> "$body_file_help_stderr"
  ); then
    test_fail "repo-flow submit rejects space-separated --body-file syntax"
    status=1
  elif smoke_assert_flag_error_shape "$body_file_help_stderr" "flag format not accepted" "--body-file" "use --body-file=<path>"; then
    test_pass "repo-flow submit rejects space-separated --body-file syntax"
  else
    test_fail "repo-flow submit rejects space-separated --body-file syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message=hi --body-file="$smoke_test_base/repo-flow-submit-body-file-missing.md" > "$help_out" 2> "$body_file_missing_stderr"
  ); then
    test_fail "repo-flow submit rejects missing body files before PR create/edit"
    status=1
  elif grep -Fxq "STOP: body file does not exist: $smoke_test_base/repo-flow-submit-body-file-missing.md" "$body_file_missing_stderr" &&
    grep -Fxq 'fix: provide an existing PR body file' "$body_file_missing_stderr" &&
    ! grep -Fq 'gh pr create title=' "$body_file_missing_stderr" &&
    ! grep -Fq 'gh pr edit number=' "$body_file_missing_stderr"; then
    test_pass "repo-flow submit rejects missing body files before PR create/edit"
  else
    test_fail "repo-flow submit rejects missing body files before PR create/edit"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message=hi --body-file="$smoke_test_base/repo-flow-submit-body-file-directory" > "$help_out" 2> "$body_file_directory_stderr"
  ); then
    test_fail "repo-flow submit rejects directory body files before PR create/edit"
    status=1
  elif grep -Fxq "STOP: body file is a directory: $smoke_test_base/repo-flow-submit-body-file-directory" "$body_file_directory_stderr" &&
    grep -Fxq 'fix: provide a regular readable PR body file' "$body_file_directory_stderr" &&
    ! grep -Fq 'gh pr create title=' "$body_file_directory_stderr" &&
    ! grep -Fq 'gh pr edit number=' "$body_file_directory_stderr"; then
    test_pass "repo-flow submit rejects directory body files before PR create/edit"
  else
    test_fail "repo-flow submit rejects directory body files before PR create/edit"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message=hi --body-file="$smoke_test_base/repo-flow-submit-body-file-invalid.md" > "$help_out" 2> "$body_file_invalid_stderr"
  ); then
    test_fail "repo-flow submit rejects invalid body files before PR create/edit"
    status=1
  elif grep -Fxq 'fail: body is placeholder-only' "$body_file_invalid_stderr" &&
    grep -Fxq 'fix: replace branch/base/ahead/behind scaffolding with real PR body content' "$body_file_invalid_stderr" &&
    grep -Fxq 'STOP: fail: body is placeholder-only' "$body_file_invalid_stderr" &&
    ! grep -Fq 'gh pr create title=' "$body_file_invalid_stderr" &&
    ! grep -Fq 'gh pr edit number=' "$body_file_invalid_stderr"; then
    test_pass "repo-flow submit rejects invalid body files before PR create/edit"
  else
    test_fail "repo-flow submit rejects invalid body files before PR create/edit"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    "$local_bash_path" repo-automation/tests/contracts/review-pack.sh --explain > "$review_pack_contract_explain_stdout" 2> "$review_pack_contract_explain_stderr"
  ) && smoke_assert_single_final_summary_block "$review_pack_contract_explain_stderr" &&
    grep -Fxq 'script=review-pack-contract' "$review_pack_contract_explain_stderr" &&
    grep -Fxq 'rc=0' "$review_pack_contract_explain_stderr" &&
    grep -Fxq 'mode=explain' "$review_pack_contract_explain_stderr" &&
    grep -Eq '^status_count=[0-9]+$' "$review_pack_contract_explain_stderr" &&
    grep -Fxq 'url_or_stop=pass' "$review_pack_contract_explain_stderr"; then
    test_pass "review-pack contract explain output ends with one final summary block"
  else
    test_fail "review-pack contract explain output ends with one final summary block"
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

  alias_create_stdout="$smoke_test_base/repo-flow-submit-alias-create.out"
  alias_create_stderr="$smoke_test_base/repo-flow-submit-alias-create.stderr"
  alias_create_log_file="$smoke_test_base/repo-flow-submit-alias-create.log"
  alias_reuse_body_file="$smoke_test_base/repo-flow-submit-alias-reuse-body.md"
  printf '\nrepo-flow submit alias create line\n' >> "$smoke_test_dir/README.md" || return 1
  smoke_prepare_repo_flow_submit_remote_validation 'git@github-alias:i-schuyler/repo-automation-template.git' 'git@github.com:i-schuyler/repo-automation-template.git' || return 1
  if (
    cd "$smoke_test_dir" || return 1
    git remote set-url --push origin "$smoke_remote_dir" >/dev/null 2>&1 || return 1
    PATH="$ssh_stub_dir:$gh_stub_dir:$PATH" \
    GH_STUB_PR_VIEW_FAIL_ONCE_FILE="$smoke_test_base/repo-flow-submit-alias-create-view.fail" \
    GH_STUB_PR_VIEW_NUMBER=703 \
    GH_STUB_PR_CREATE_LOG_FILE="$alias_create_log_file" \
    GH_STUB_PR_CREATE_URL='https://github.com/i-schuyler/repo-automation-template/pull/703' \
    repo-automation/bin/repo-flow submit --paths=README.md --message='repo-flow submit alias commit' --explain > "$alias_create_stdout" 2> "$alias_create_stderr"
  ) && [ ! -s "$alias_create_stdout" ] &&
    summary_count="$(grep -Fc '===== FINAL SUMMARY =====' "$alias_create_stderr" 2>/dev/null || printf '0')" &&
    [ "$summary_count" = "1" ] &&
    smoke_assert_single_final_summary_block "$alias_create_stderr" &&
    grep -Fxq 'script=repo-flow' "$alias_create_stderr" &&
    grep -Fxq 'mode=submit' "$alias_create_stderr" &&
    grep -Fxq 'rc=0' "$alias_create_stderr" &&
    grep -Fxq 'branch_before=feature/repo-flow-submit-validation' "$alias_create_stderr" &&
    grep -Fxq 'branch_after=feature/repo-flow-submit-validation' "$alias_create_stderr" &&
    grep -Fxq 'pr=703' "$alias_create_stderr" &&
    grep -Eq '^commit=[0-9a-f]{7,40}$' "$alias_create_stderr" &&
    grep -Fxq 'pushed=true' "$alias_create_stderr" &&
    grep -Fxq 'merged=false' "$alias_create_stderr" &&
    grep -Eq '^status_count=[0-9]+$' "$alias_create_stderr" &&
    grep -Fxq 'url_or_stop=https://github.com/i-schuyler/repo-automation-template/pull/703' "$alias_create_stderr" &&
    grep -Fq 'gh pr create title=' "$alias_create_log_file"; then
    test_pass "repo-flow submit accepts a GitHub SSH alias through the delegated PR create path"
  else
    test_fail "repo-flow submit accepts a GitHub SSH alias through the delegated PR create path"
    status=1
  fi

  alias_reuse_stdout="$smoke_test_base/repo-flow-submit-alias-reuse.out"
  alias_reuse_stderr="$smoke_test_base/repo-flow-submit-alias-reuse.stderr"
  repo_flow_gh_stub_dir="$smoke_test_base/repo-flow-gh-stub"
  smoke_write_repo_flow_gh_stub "$repo_flow_gh_stub_dir" || return 1
  cat > "$alias_reuse_body_file" <<'EOF'
## Scope

GitHub SSH alias reuse path.

## What changed

- Valid existing PR body for reuse path coverage.

## What did not change

- The delegated PR reuse path remains unchanged.

## Verification status

- repo-flow submit alias reuse path

## User-visible behavior changes

None

## Stop conditions encountered

None

## Re-entry hint

Review the PR, then run `repo-automation/bin/repo-flow merge --explain`.
EOF
  printf '\nrepo-flow submit alias reuse line\n' >> "$smoke_test_dir/README.md" || return 1
  smoke_prepare_repo_flow_submit_remote_validation 'git@github-alias:i-schuyler/repo-automation-template.git' 'git@github.com:i-schuyler/repo-automation-template.git' || return 1
  if (
    cd "$smoke_test_dir" || return 1
    git remote set-url --push origin "$smoke_remote_dir" >/dev/null 2>&1 || return 1
    PATH="$ssh_stub_dir:$repo_flow_gh_stub_dir:$gh_stub_dir:$PATH" \
    GH_STUB_PR_VIEW_NUMBER=904 \
    GH_STUB_PR_VIEW_URL='https://github.com/i-schuyler/repo-automation-template/pull/904' \
    GH_STUB_PR_VIEW_STATE='OPEN' \
    GH_STUB_PR_VIEW_BODY_FILE="$alias_reuse_body_file" \
    repo-automation/bin/repo-flow submit --paths=README.md --message='repo-flow submit alias reuse commit' --explain > "$alias_reuse_stdout" 2> "$alias_reuse_stderr"
  ) && [ ! -s "$alias_reuse_stdout" ] &&
    summary_count="$(grep -Fc '===== FINAL SUMMARY =====' "$alias_reuse_stderr" 2>/dev/null || printf '0')" &&
    [ "$summary_count" = "1" ] &&
    smoke_assert_single_final_summary_block "$alias_reuse_stderr" &&
    grep -Fxq 'script=repo-flow' "$alias_reuse_stderr" &&
    grep -Fxq 'mode=submit' "$alias_reuse_stderr" &&
    grep -Fxq 'rc=0' "$alias_reuse_stderr" &&
    grep -Fxq 'branch_before=feature/repo-flow-submit-validation' "$alias_reuse_stderr" &&
    grep -Fxq 'branch_after=feature/repo-flow-submit-validation' "$alias_reuse_stderr" &&
    grep -Fxq 'pr=904' "$alias_reuse_stderr" &&
    grep -Eq '^commit=[0-9a-f]{7,40}$' "$alias_reuse_stderr" &&
    grep -Fxq 'pushed=true' "$alias_reuse_stderr" &&
    grep -Fxq 'merged=false' "$alias_reuse_stderr" &&
    grep -Eq '^status_count=[0-9]+$' "$alias_reuse_stderr" &&
    grep -Fxq 'url_or_stop=https://github.com/i-schuyler/repo-automation-template/pull/904' "$alias_reuse_stderr"; then
    test_pass "repo-flow submit accepts a GitHub SSH alias through the delegated PR reuse path"
  else
    test_fail "repo-flow submit accepts a GitHub SSH alias through the delegated PR reuse path"
    status=1
  fi

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
  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-modified-new-file" || return 1
  mkdir -p "$smoke_test_dir/docs" || return 1
  printf '\nrepo-flow submit modified line\n' >> "$smoke_test_dir/docs/testing.md" || return 1
  git -C "$smoke_test_dir" add docs/testing.md || return 1
  printf 'repo-flow submit new file\n' > "$smoke_test_dir/docs/repo-flow-submit-new-file.md" || return 1
  git -C "$smoke_test_dir" add docs/repo-flow-submit-new-file.md || return 1
  head_before="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1
  status_before="$(git -C "$smoke_test_dir" status --porcelain --untracked-files=all)" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --modified --message=hi >/dev/null 2> "$modified_new_file_stderr"
  ); then
    test_fail "repo-flow submit rejects pre-staged new files when using --modified"
    status=1
  elif grep -Fxq 'STOP: --modified only accepts tracked modified/deleted/renamed paths; use --paths=<path> or --staged for new files' "$modified_new_file_stderr"; then
    status_after="$(git -C "$smoke_test_dir" status --porcelain --untracked-files=all)" || return 1
    head_after="$(git -C "$smoke_test_dir" rev-parse HEAD)" || return 1
    if [ "$status_before" = "$status_after" ] && [ "$head_before" = "$head_after" ]; then
      test_pass "repo-flow submit rejects pre-staged new files when using --modified"
    else
      test_fail "repo-flow submit rejects pre-staged new files when using --modified"
      status=1
    fi
  else
    test_fail "repo-flow submit rejects pre-staged new files when using --modified"
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

smoke_check_repo_flow_submit_unrequested_paths_contract() {
  local status=0
  local gh_stub_dir=""
  local clean_stdout=""
  local clean_stderr=""
  local paths_stderr=""
  local explain_stderr=""
  local cap_stderr=""
  local local_bash_path=""
  local isolated_repo_dir=""
  local status_before=""
  local status_after=""
  local cached_before=""
  local cached_after=""
  local head_before=""
  local head_after=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154 # smoke_test_base is provided by the smoke harness.
  gh_stub_dir="$smoke_test_base/gh-stub"
  clean_stdout="$smoke_test_base/repo-flow-submit-unrequested-paths-clean.out"
  clean_stderr="$smoke_test_base/repo-flow-submit-unrequested-paths-clean.stderr"
  paths_stderr="$smoke_test_base/repo-flow-submit-unrequested-paths-paths.stderr"
  explain_stderr="$smoke_test_base/repo-flow-submit-unrequested-paths-explain.stderr"
  cap_stderr="$smoke_test_base/repo-flow-submit-unrequested-paths-cap.stderr"
  smoke_write_gh_stub "$gh_stub_dir" || return 1
  local_bash_path="$(command -v bash)" || return 1

  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-unrequested-paths-clean" || return 1
  isolated_repo_dir="$(mktemp -d "${TMPDIR:-$HOME/.cache}/repo-flow-submit-isolated.XXXXXX")" || return 1
  git clone --quiet "$smoke_test_dir" "$isolated_repo_dir" || return 1
  git -C "$isolated_repo_dir" checkout feature/repo-flow-submit-unrequested-paths-clean >/dev/null 2>&1 || return 1
  smoke_test_dir="$isolated_repo_dir" smoke_prepare_repo_flow_remote || return 1
  printf 'repo-flow submit clean requested a\n' > "$isolated_repo_dir/tracked-requested-a.md" || return 1
  printf 'repo-flow submit clean requested b\n' > "$isolated_repo_dir/tracked-requested-b.md" || return 1
  git -C "$isolated_repo_dir" add tracked-requested-a.md tracked-requested-b.md || return 1
  git -C "$isolated_repo_dir" commit -m "repo-flow submit unrequested path fixtures" >/dev/null || return 1

  printf '\nrepo-flow submit clean requested change a\n' >> "$isolated_repo_dir/tracked-requested-a.md" || return 1
  printf '\nrepo-flow submit clean requested change b\n' >> "$isolated_repo_dir/tracked-requested-b.md" || return 1
  git -C "$isolated_repo_dir" add tracked-requested-a.md tracked-requested-b.md || return 1

  if (
    cd "$isolated_repo_dir" || return 1
    PATH="$gh_stub_dir:$PATH" \
    GH_STUB_PR_VIEW_FAIL_ONCE_FILE="$smoke_test_base/repo-flow-submit-unrequested-paths-clean-view.fail" \
    GH_STUB_PR_VIEW_FAIL_ONCE_STDERR='net/http: TLS handshake timeout' \
    GH_STUB_PR_CREATE_NUMBER=905 \
    GH_STUB_PR_CREATE_URL='https://github.com/i-schuyler/repo-automation-template/pull/905' \
    "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message=hi --explain > "$clean_stdout" 2> "$clean_stderr"
  ); then
    if [ ! -s "$clean_stdout" ] &&
      grep -Fxq '===== FINAL SUMMARY =====' "$clean_stderr" &&
      grep -Fxq 'status_count=0' "$clean_stderr" &&
      grep -Fxq 'url_or_stop=https://github.com/i-schuyler/repo-automation-template/pull/905' "$clean_stderr" &&
      ! grep -Fq 'unrequested_paths=' "$clean_stderr"; then
      test_pass "repo-flow submit --staged with multiple staged requested files succeeds without unrequested paths"
    else
      test_fail "repo-flow submit --staged with multiple staged requested files succeeds without unrequested paths"
      status=1
    fi
  else
    test_fail "repo-flow submit --staged with multiple staged requested files succeeds without unrequested paths"
    status=1
  fi

  rm -rf "$isolated_repo_dir" >/dev/null 2>&1 || true

  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-unrequested-paths-dirty" || return 1
  isolated_repo_dir="$(mktemp -d "${TMPDIR:-$HOME/.cache}/repo-flow-submit-isolated.XXXXXX")" || return 1
  git clone --quiet "$smoke_test_dir" "$isolated_repo_dir" || return 1
  git -C "$isolated_repo_dir" checkout feature/repo-flow-submit-unrequested-paths-dirty >/dev/null 2>&1 || return 1
  smoke_test_dir="$isolated_repo_dir" smoke_prepare_repo_flow_remote || return 1
  printf 'repo-flow submit dirty requested a\n' > "$isolated_repo_dir/tracked-requested-a.md" || return 1
  printf 'repo-flow submit dirty requested b\n' > "$isolated_repo_dir/tracked-requested-b.md" || return 1
  git -C "$isolated_repo_dir" add tracked-requested-a.md tracked-requested-b.md || return 1
  git -C "$isolated_repo_dir" commit -m "repo-flow submit unrequested path dirty fixtures" >/dev/null || return 1
  printf '\nrepo-flow submit dirty requested change a\n' >> "$isolated_repo_dir/tracked-requested-a.md" || return 1
  printf '\nrepo-flow submit dirty requested change b\n' >> "$isolated_repo_dir/tracked-requested-b.md" || return 1
  git -C "$isolated_repo_dir" add tracked-requested-a.md tracked-requested-b.md || return 1
  printf '\nrepo-flow submit dirty unrelated change\n' >> "$isolated_repo_dir/README.md" || return 1
  printf 'repo-flow submit dirty unrelated new file\n' > "$isolated_repo_dir/unrequested-new.md" || return 1
  status_before="$(git -C "$isolated_repo_dir" status --porcelain --untracked-files=all)" || return 1
  cached_before="$(git -C "$isolated_repo_dir" diff --cached --name-only)" || return 1
  head_before="$(git -C "$isolated_repo_dir" rev-parse HEAD)" || return 1

  if (
    cd "$isolated_repo_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message=hi --explain >/dev/null 2> "$explain_stderr"
  ); then
    test_fail "repo-flow submit --staged reports only unrelated dirty paths"
    status=1
  elif grep -Fxq 'STOP: unrequested working tree changes remain; commit a clean explicit submit' "$explain_stderr" &&
    grep -Fxq 'unrequested_paths=README.md,unrequested-new.md' "$explain_stderr" &&
    grep -Fxq 'status_count=4' "$explain_stderr" &&
    grep -Fxq 'url_or_stop=unrequested working tree changes remain; commit a clean explicit submit' "$explain_stderr"; then
    status_after="$(git -C "$isolated_repo_dir" status --porcelain --untracked-files=all)" || return 1
    cached_after="$(git -C "$isolated_repo_dir" diff --cached --name-only)" || return 1
    head_after="$(git -C "$isolated_repo_dir" rev-parse HEAD)" || return 1
    if [ "$status_before" = "$status_after" ] && [ "$cached_before" = "$cached_after" ] && [ "$head_before" = "$head_after" ]; then
      test_pass "repo-flow submit --staged reports only unrelated dirty paths"
    else
      test_fail "repo-flow submit --staged reports only unrelated dirty paths"
      status=1
    fi
  else
    test_fail "repo-flow submit --staged reports only unrelated dirty paths"
    status=1
  fi

  rm -rf "$isolated_repo_dir" >/dev/null 2>&1 || true

  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-unrequested-paths-paths" || return 1
  isolated_repo_dir="$(mktemp -d "${TMPDIR:-$HOME/.cache}/repo-flow-submit-isolated.XXXXXX")" || return 1
  git clone --quiet "$smoke_test_dir" "$isolated_repo_dir" || return 1
  git -C "$isolated_repo_dir" checkout feature/repo-flow-submit-unrequested-paths-paths >/dev/null 2>&1 || return 1
  smoke_test_dir="$isolated_repo_dir" smoke_prepare_repo_flow_remote || return 1
  printf '\nrepo-flow submit paths requested line\n' >> "$isolated_repo_dir/docs/testing.md" || return 1
  printf '\nrepo-flow submit paths dirty line\n' >> "$isolated_repo_dir/README.md" || return 1
  printf 'repo-flow submit paths unrequested new file\n' > "$isolated_repo_dir/unrequested-new.md" || return 1
  status_before="$(git -C "$isolated_repo_dir" status --porcelain --untracked-files=all)" || return 1
  cached_before="$(git -C "$isolated_repo_dir" diff --cached --name-only)" || return 1
  head_before="$(git -C "$isolated_repo_dir" rev-parse HEAD)" || return 1

  if (
    cd "$isolated_repo_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --paths=docs/testing.md --message=hi --explain >/dev/null 2> "$paths_stderr"
  ); then
    test_fail "repo-flow submit --paths --explain reports and preserves unrequested paths"
    status=1
  elif grep -Fxq 'STOP: unrequested working tree changes remain; commit a clean explicit submit' "$paths_stderr" &&
    grep -Fxq 'unrequested_paths=README.md,unrequested-new.md' "$paths_stderr" &&
    grep -Fxq 'url_or_stop=unrequested working tree changes remain; commit a clean explicit submit' "$paths_stderr"; then
    status_after="$(git -C "$isolated_repo_dir" status --porcelain --untracked-files=all)" || return 1
    cached_after="$(git -C "$isolated_repo_dir" diff --cached --name-only)" || return 1
    head_after="$(git -C "$isolated_repo_dir" rev-parse HEAD)" || return 1
    if [ "$status_before" = "$status_after" ] && [ "$cached_before" = "$cached_after" ] && [ "$head_before" = "$head_after" ]; then
      test_pass "repo-flow submit --paths --explain reports and preserves unrequested paths"
    else
      test_fail "repo-flow submit --paths --explain reports and preserves unrequested paths"
      status=1
    fi
  else
    test_fail "repo-flow submit --paths --explain reports and preserves unrequested paths"
    status=1
  fi

  rm -rf "$isolated_repo_dir" >/dev/null 2>&1 || true

  smoke_prepare_repo_flow_branch "feature/repo-flow-submit-unrequested-paths-cap" || return 1
  isolated_repo_dir="$(mktemp -d "${TMPDIR:-$HOME/.cache}/repo-flow-submit-isolated.XXXXXX")" || return 1
  git clone --quiet "$smoke_test_dir" "$isolated_repo_dir" || return 1
  git -C "$isolated_repo_dir" checkout feature/repo-flow-submit-unrequested-paths-cap >/dev/null 2>&1 || return 1
  smoke_test_dir="$isolated_repo_dir" smoke_prepare_repo_flow_submit_remote_validation 'git@github.com:i-schuyler/repo-automation-template.git' 'git@github.com:i-schuyler/repo-automation-template.git' || return 1
  printf 'tracked requested baseline\n' > "$isolated_repo_dir/tracked-requested.md" || return 1
  git -C "$isolated_repo_dir" add tracked-requested.md || return 1
  git -C "$isolated_repo_dir" commit -m "repo-flow submit unrequested path cap fixtures" >/dev/null || return 1
  printf '\nrepo-flow submit requested line\n' >> "$isolated_repo_dir/tracked-requested.md" || return 1
  git -C "$isolated_repo_dir" add tracked-requested.md || return 1
  printf 'repo-flow submit unrequested path a\n' > "$isolated_repo_dir/unrequested-a.md" || return 1
  printf 'repo-flow submit unrequested path b\n' > "$isolated_repo_dir/unrequested-b.md" || return 1
  printf 'repo-flow submit unrequested path c\n' > "$isolated_repo_dir/unrequested-c.md" || return 1
  printf 'repo-flow submit unrequested path d\n' > "$isolated_repo_dir/unrequested-d.md" || return 1

  if (
    cd "$isolated_repo_dir" || return 1
    PATH="$gh_stub_dir:$PATH" "$local_bash_path" repo-automation/bin/repo-flow submit --staged --message=hi --explain >/dev/null 2> "$cap_stderr"
  ); then
    test_fail "repo-flow submit --staged --explain caps unrequested paths"
    status=1
  elif grep -Fxq 'STOP: unrequested working tree changes remain; commit a clean explicit submit' "$cap_stderr" &&
    grep -Eq '^unrequested_paths=unrequested-a\.md,unrequested-b\.md,unrequested-c\.md \(\+1 more\)$' "$cap_stderr" &&
    grep -Fxq 'status_count=5' "$cap_stderr" &&
    grep -Fxq 'url_or_stop=unrequested working tree changes remain; commit a clean explicit submit' "$cap_stderr"; then
    test_pass "repo-flow submit --staged --explain caps unrequested paths"
  else
    test_fail "repo-flow submit --staged --explain caps unrequested paths"
    status=1
  fi

  rm -rf "$isolated_repo_dir" >/dev/null 2>&1 || true

  return "$status"
}

smoke_check_repo_flow_focused_wrapper_failure_diagnostics() {
  local status=0
  local focused_wrapper_script=""
  local focused_quiet_stderr=""
  local focused_default_stderr=""
  local focused_json_stderr=""
  local focused_json_file=""
  local local_bash_path=""

  # shellcheck disable=SC2154 # smoke_test_base and smoke_repo_root are provided by the smoke harness.
  focused_wrapper_script="$smoke_test_base/focused-wrapper-diagnostics.sh"
  focused_quiet_stderr="$smoke_test_base/focused-wrapper-diagnostics.quiet.stderr"
  focused_default_stderr="$smoke_test_base/focused-wrapper-diagnostics.default.stderr"
  focused_json_stderr="$smoke_test_base/focused-wrapper-diagnostics.json.stderr"
  focused_json_file="$smoke_test_base/focused-wrapper-diagnostics.json"
  local_bash_path="$(command -v bash)" || return 1

  cat > "$focused_wrapper_script" <<EOF
#!/usr/bin/env bash
set -u
set -o pipefail

# shellcheck source=/dev/null
source "$smoke_repo_root/repo-automation/tests/lib/smoke-common.sh"

focused_wrapper_inner_check() {
  bash -lc 'printf "FAIL: focused inner failure\n" >&2; exit 1'
}

smoke_main_impl() {
  smoke_run_named_check "smoke:focused-wrapper-inner-check" focused_wrapper_inner_check
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_main_impl "\$@"
}

smoke_main "\$@"
EOF
  chmod +x "$focused_wrapper_script" || return 1

  if "$local_bash_path" "$focused_wrapper_script" --quiet > /dev/null 2> "$focused_quiet_stderr"; then
    test_fail "focused wrapper diagnostics emits a failure in quiet mode"
    status=1
  elif grep -Fxq 'fail: smoke:focused-wrapper-inner-check: focused inner failure' "$focused_quiet_stderr"; then
    test_pass "focused wrapper diagnostics emits a failure in quiet mode"
  else
    test_fail "focused wrapper diagnostics emits a failure in quiet mode"
    status=1
  fi

  if "$local_bash_path" "$focused_wrapper_script" > /dev/null 2> "$focused_default_stderr"; then
    test_fail "focused wrapper diagnostics emits a failure in default mode"
    status=1
  elif grep -Fxq 'fail: smoke:focused-wrapper-inner-check: focused inner failure' "$focused_default_stderr"; then
    test_pass "focused wrapper diagnostics emits a failure in default mode"
  else
    test_fail "focused wrapper diagnostics emits a failure in default mode"
    status=1
  fi

  if "$local_bash_path" "$focused_wrapper_script" --json > "$focused_json_file" 2> "$focused_json_stderr"; then
    test_fail "focused wrapper diagnostics emits a failure in json mode"
    status=1
  elif python3 - "$focused_json_file" <<'PY'
import json
import pathlib
import sys

data = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
sys.exit(0 if data.get("first_failure", {}).get("check") == "smoke:focused-wrapper-inner-check" and data.get("first_failure", {}).get("message") == "focused inner failure" else 1)
PY
  then
    test_pass "focused wrapper diagnostics emits a failure in json mode"
  else
    test_fail "focused wrapper diagnostics emits a failure in json mode"
    status=1
  fi

  rm -f -- "$focused_wrapper_script" "$focused_quiet_stderr" "$focused_default_stderr" "$focused_json_stderr" "$focused_json_file" >/dev/null 2>&1 || true
  return "$status"
}


smoke_main_impl() {
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
    smoke_run_named_check "smoke:repo-flow-status-card-helper" smoke_check_repo_flow_status_card_helper_contract || status=1
    smoke_run_named_check "smoke:repo-flow-status-card-contract" smoke_check_repo_flow_status_card_contract || status=1
    smoke_run_named_check "smoke:repo-flow-dry-run-json" smoke_check_repo_flow_dry_run_json || status=1
    smoke_run_named_check "smoke:repo-flow-existing-pr" smoke_check_repo_flow_existing_pr || status=1
    smoke_run_named_check "smoke:repo-flow-existing-pr-body-refresh" smoke_check_repo_flow_existing_pr_body_refresh || status=1
    smoke_run_named_check "smoke:repo-flow-existing-pr-body-refresh-failure" smoke_check_repo_flow_existing_pr_body_refresh_failure || status=1
    smoke_run_named_check "smoke:repo-flow-existing-pr-body-append-validation-failure" smoke_check_repo_flow_existing_pr_body_append_validation_failure || status=1
    smoke_run_named_check "smoke:repo-flow-existing-pr-body-fetch-failure" smoke_check_repo_flow_existing_pr_body_fetch_failure || status=1
    smoke_run_named_check "smoke:repo-flow-create-pr" smoke_check_repo_flow_create_pr || status=1
    smoke_run_named_check "smoke:repo-flow-submit-paths" smoke_check_repo_flow_submit_paths || status=1
    smoke_run_named_check "smoke:repo-flow-submit-body-file-create-refresh" smoke_check_repo_flow_submit_body_file_create_refresh || status=1
    smoke_run_named_check "smoke:repo-flow-submit-body-file-existing-pr-requires-replace-body" smoke_check_repo_flow_submit_body_file_existing_pr_requires_replace_body || status=1
    smoke_run_named_check "smoke:repo-flow-submit-replace-body-flag-rejected" smoke_check_repo_flow_submit_replace_body_flag_rejected || status=1
    smoke_run_named_check "smoke:repo-flow-submit-staged-watch" smoke_check_repo_flow_submit_staged_watch || status=1
    smoke_run_named_check "smoke:repo-flow-submit-watch-publishes-branch" smoke_check_repo_flow_submit_watch_publishes_branch || status=1
    smoke_run_named_check "smoke:repo-flow-submit-watch-explain-failure-summary" smoke_check_repo_flow_submit_watch_explain_failure_summary || status=1
    smoke_run_named_check "smoke:repo-flow-docs-check-quiet-details" smoke_check_repo_flow_docs_check_quiet_details || status=1
    smoke_run_named_check "smoke:repo-flow-version-consistency-quiet-details" smoke_check_repo_flow_version_consistency_quiet_details || status=1
    smoke_run_named_check "smoke:repo-flow-merge-contract" smoke_check_repo_flow_merge_contract || status=1
    smoke_run_named_check "smoke:repo-flow-submit-contract" smoke_check_repo_flow_submit_contract || status=1
    smoke_run_named_check "smoke:repo-flow-focused-wrapper-failure-diagnostics" smoke_check_repo_flow_focused_wrapper_failure_diagnostics || status=1
    smoke_run_named_check "smoke:repo-flow-submit-unrequested-paths-contract" smoke_check_repo_flow_submit_unrequested_paths_contract || status=1
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
      smoke_run_named_check "smoke:repo-flow-status-card-helper" smoke_check_repo_flow_status_card_helper_contract || status=1
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
      smoke_run_named_check "smoke:repo-flow-existing-pr-body-refresh" smoke_check_repo_flow_existing_pr_body_refresh || status=1
    fi
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-existing-pr-body-refresh-failure" smoke_check_repo_flow_existing_pr_body_refresh_failure || status=1
    fi
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-existing-pr-body-append-validation-failure" smoke_check_repo_flow_existing_pr_body_append_validation_failure || status=1
    fi
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-existing-pr-body-fetch-failure" smoke_check_repo_flow_existing_pr_body_fetch_failure || status=1
    fi
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-create-pr" smoke_check_repo_flow_create_pr || status=1
    fi
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-submit-paths" smoke_check_repo_flow_submit_paths || status=1
    fi
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-submit-body-file-create-refresh" smoke_check_repo_flow_submit_body_file_create_refresh || status=1
    fi
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-submit-body-file-existing-pr-requires-replace-body" smoke_check_repo_flow_submit_body_file_existing_pr_requires_replace_body || status=1
    fi
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-submit-replace-body-flag-rejected" smoke_check_repo_flow_submit_replace_body_flag_rejected || status=1
    fi
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-submit-staged-watch" smoke_check_repo_flow_submit_staged_watch || status=1
      fi
    if [ "$status" -eq 0 ]; then
      smoke_run_named_check "smoke:repo-flow-submit-watch-publishes-branch" smoke_check_repo_flow_submit_watch_publishes_branch || status=1
      fi
      if [ "$status" -eq 0 ]; then
        smoke_run_named_check "smoke:repo-flow-submit-watch-existing-pr-body-refresh-failure" smoke_check_repo_flow_submit_watch_existing_pr_body_refresh_failure || status=1
      fi
      if [ "$status" -eq 0 ]; then
        smoke_run_named_check "smoke:repo-flow-submit-watch-explain-failure-summary" smoke_check_repo_flow_submit_watch_explain_failure_summary || status=1
      fi
      if [ "$status" -eq 0 ]; then
        smoke_run_named_check "smoke:repo-flow-docs-check-quiet-details" smoke_check_repo_flow_docs_check_quiet_details || status=1
      fi
      if [ "$status" -eq 0 ]; then
        smoke_run_named_check "smoke:repo-flow-version-consistency-quiet-details" smoke_check_repo_flow_version_consistency_quiet_details || status=1
      fi
      if [ "$status" -eq 0 ]; then
        smoke_run_named_check "smoke:repo-flow-merge-contract" smoke_check_repo_flow_merge_contract || status=1
      fi
      if [ "$status" -eq 0 ]; then
        smoke_run_named_check "smoke:repo-flow-submit-contract" smoke_check_repo_flow_submit_contract || status=1
      fi
      if [ "$status" -eq 0 ]; then
        smoke_run_named_check "smoke:repo-flow-focused-wrapper-failure-diagnostics" smoke_check_repo_flow_focused_wrapper_failure_diagnostics || status=1
      fi
      if [ "$status" -eq 0 ]; then
        smoke_run_named_check "smoke:repo-flow-submit-unrequested-paths-contract" smoke_check_repo_flow_submit_unrequested_paths_contract || status=1
      fi

    exec 1>&3 2>&4
    rm -f -- "$smoke_output_capture" >/dev/null 2>&1 || true
  fi

  return "$status"
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_main_impl "$@"
}

smoke_main "$@"
# repo-automation/tests/contracts/repo-flow.sh EOF
