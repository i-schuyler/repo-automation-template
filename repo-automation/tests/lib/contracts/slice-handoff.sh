# repo-automation/tests/lib/contracts/slice-handoff.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.

smoke_slice_handoff_script() {
  if [ -n "${smoke_test_dir:-}" ] && [ -x "$smoke_test_dir/repo-automation/bin/slice-handoff" ]; then
    printf '%s/repo-automation/bin/slice-handoff' "$smoke_test_dir"
    return 0
  fi
  printf '%s/repo-automation/bin/slice-handoff' "$smoke_repo_root"
}

smoke_slice_handoff_assert_metadata() {
  python3 - "$smoke_repo_root/repo-automation/helper-metadata.json" <<'PY'
import json
import pathlib
import sys

metadata_path = pathlib.Path(sys.argv[1])
data = json.loads(metadata_path.read_text(encoding='utf-8'))
for helper in data.get('helpers', []):
    if not isinstance(helper, dict):
        continue
    if helper.get('name') != 'slice-handoff':
        continue
    checks = [
        ('path', 'repo-automation/bin/slice-handoff'),
        ('writes_files', True),
        ('artifact_helper', True),
        ('writes_git', False),
        ('uses_github', False),
        ('supports_json', False),
    ]
    mismatches = [
        f"{key}={helper.get(key)!r} expected {expected!r}"
        for key, expected in checks
        if helper.get(key) != expected
    ]
    if mismatches:
        print('fail: slice-handoff metadata mismatch: ' + '; '.join(mismatches), file=sys.stderr)
        sys.exit(1)
    sys.exit(0)

print('fail: missing slice-handoff metadata object', file=sys.stderr)
sys.exit(1)
PY
}

smoke_slice_handoff_assert_planned_route() {
  python3 - "$smoke_repo_root/repo-automation/helper-metadata.json" <<'PY'
import json
import pathlib
import sys

metadata_path = pathlib.Path(sys.argv[1])
data = json.loads(metadata_path.read_text(encoding='utf-8'))
for entry in data.get('planned_routes', []):
    if isinstance(entry, dict) and entry.get('name') == 'slice-handoff dry-run' and entry.get('route') == 'slice-handoff --dry-run':
        sys.exit(0)

print('fail: missing slice-handoff dry-run planned route row', file=sys.stderr)
sys.exit(1)
PY
}

smoke_slice_handoff_prepare_execution_repo() {
  local config_path="$smoke_test_dir/.repo-automation.conf"
  local execution_remote_dir=""

  execution_remote_dir="$(mktemp -d "${TMPDIR:-$HOME/.cache}/repo-automation-slice-handoff-remote.XXXXXX")" || return 1
  git -C "$smoke_test_dir" init --bare "$execution_remote_dir" >/dev/null 2>&1 || return 1
  git -C "$smoke_test_dir" push "$execution_remote_dir" main:main >/dev/null 2>&1 || return 1

  git -C "$smoke_test_dir" remote set-url origin "$execution_remote_dir" || return 1
  git -C "$smoke_test_dir" update-index --skip-worktree .repo-automation.conf || return 1
  python3 - "$smoke_expected_origin_url" "$config_path" <<'PY' || return 1
from pathlib import Path
import sys

expected = sys.argv[1]
config_path = Path(sys.argv[2])
text = config_path.read_text(encoding='utf-8')
old = f'EXPECTED_REMOTE_URL="{expected}"'
new = 'EXPECTED_REMOTE_URL=""'
if old not in text:
    raise SystemExit(1)
config_path.write_text(text.replace(old, new, 1), encoding='utf-8')
PY
}

smoke_slice_handoff_write_file() {
  local path="$1"
  local branch="$2"
  local title="$3"
  local codex_profile="$4"
  local submit_mode="$5"
  local commit_message="$6"
  local prompt_text="$7"
  local pr_body_text="${8:-}"
  local review_request_text="${9:-}"

  mkdir -p "$(dirname "$path")" || return 1
  {
    printf 'schema: repo-automation-slice-handoff/v1\n'
    if [ -n "$branch" ]; then
      printf 'branch: %s\n' "$branch"
    fi
    if [ -n "$title" ]; then
      printf 'title: %s\n' "$title"
    fi
    if [ -n "$codex_profile" ]; then
      printf 'codex_profile: %s\n' "$codex_profile"
    fi
    if [ -n "$submit_mode" ]; then
      printf 'submit_mode: %s\n' "$submit_mode"
    fi
    if [ -n "$commit_message" ]; then
      printf 'commit_message: %s\n' "$commit_message"
    fi
    printf '\n# Slice Handoff\n\n## Codex Prompt\n'
    printf '%s\n' "$prompt_text"
    if [ -n "$pr_body_text" ]; then
      printf '\n## PR Body\n'
      printf '%s\n' "$pr_body_text"
    fi
    if [ -n "$review_request_text" ]; then
      if [ -z "$pr_body_text" ]; then
        printf '\n## PR Review Request\n'
      else
        printf '\n## PR Review Request\n'
      fi
      printf '%s\n' "$review_request_text"
    fi
  } > "$path"
}

smoke_slice_handoff_assert_error_shape() {
  local stderr_file="$1"
  local reason="$2"
  local fix="$3"

  [ "$(wc -l < "$stderr_file" | tr -d '[:space:]')" = "2" ] &&
    grep -Fxq "fail: $reason" "$stderr_file" &&
    grep -Fxq "fix: $fix" "$stderr_file"
}

smoke_slice_handoff_assert_text_file() {
  local path="$1"
  local expected="$2"

  [ "$(cat "$path" 2>/dev/null || true)" = "$expected" ]
}

smoke_slice_handoff_extract_field() {
  local path="$1"
  local field="$2"

  awk -F= -v field="$field" '$1 == field {sub("^[^=]*=", "", $0); print $0; exit}' "$path"
}

smoke_slice_handoff_assert_execution_stdout() {
  local stdout_file="$1"
  local stderr_file="$2"
  local expected_branch="$3"
  local run_dir=""

  [ ! -s "$stderr_file" ] || return 1
  [ "$(wc -l < "$stdout_file" | tr -d '[:space:]')" = "6" ] || return 1
  grep -Fxq 'pass' "$stdout_file" || return 1
  grep -Fxq 'mode=execution-preflight' "$stdout_file" || return 1
  grep -Fxq "branch=$expected_branch" "$stdout_file" || return 1
  grep -Eq '^run_dir=.+' "$stdout_file" || return 1
  grep -Fxq 'preflight_status=pass' "$stdout_file" || return 1
  grep -Fxq 'next=codex-run not implemented in this slice' "$stdout_file" || return 1

  run_dir="$(smoke_slice_handoff_extract_field "$stdout_file" run_dir)"
  [ -n "$run_dir" ] || return 1
  printf '%s\n' "$run_dir"
}

smoke_slice_handoff_assert_execution_run_dir() {
  local run_dir="$1"
  local submit_mode="$2"
  local branch="$3"
  local title="$4"
  local prompt_text="$5"
  local review_request_text="$6"
  local expected_pr_body="${7:-}"
  local expected_repo_root="${8:-}"

  [ -d "$run_dir" ] || return 1
  for path in \
    slice-run-dir-create.json \
    slice-run-dir-create.stdout \
    slice-run-dir-create.stderr \
    slice-run-dir-cleanup.json \
    slice-run-dir-cleanup.stdout \
    slice-run-dir-cleanup.stderr \
    preflight.json \
    preflight.stdout \
    preflight.stderr \
    slice-handoff-summary.txt \
    slice-handoff-execution-summary.txt \
    codex-prompt.md \
    review-request.txt
  do
    [ -f "$run_dir/$path" ] || return 1
  done

  if [ "$submit_mode" = "repo-flow-submit-all" ]; then
    [ -f "$run_dir/pr-body.md" ] || return 1
    [ -n "$expected_pr_body" ] || return 1
    [ "$(cat "$run_dir/pr-body.md" 2>/dev/null || true)" = "$expected_pr_body" ] || return 1
  else
    [ ! -e "$run_dir/pr-body.md" ] || return 1
  fi
  [ ! -e "$run_dir/dry-run-preview.txt" ] || return 1

  python3 - "$run_dir/slice-run-dir-create.json" "$run_dir/slice-run-dir-cleanup.json" "$run_dir/preflight.json" <<'PY' >/dev/null || return 1
from pathlib import Path
import json
import sys

create_path = Path(sys.argv[1])
cleanup_path = Path(sys.argv[2])
preflight_path = Path(sys.argv[3])
create = json.loads(create_path.read_text(encoding='utf-8'))
cleanup = json.loads(cleanup_path.read_text(encoding='utf-8'))
preflight = json.loads(preflight_path.read_text(encoding='utf-8'))
if not isinstance(create, dict) or not isinstance(cleanup, dict) or not isinstance(preflight, dict):
    raise SystemExit(1)
if create.get('run_dir') != str(create_path.parent):
    raise SystemExit(1)
if cleanup.get('mode') != 'cleanup-stale' or cleanup.get('apply') is not True:
    raise SystemExit(1)
if cleanup.get('preserve_path') != str(cleanup_path.parent):
    raise SystemExit(1)
if preflight.get('rc') != 0:
    raise SystemExit(1)
PY

  smoke_slice_handoff_assert_text_file "$run_dir/codex-prompt.md" "$prompt_text" || return 1
  smoke_slice_handoff_assert_text_file "$run_dir/review-request.txt" "$review_request_text" || return 1
  grep -Fxq "schema=repo-automation-slice-handoff/v1" "$run_dir/slice-handoff-summary.txt" || return 1
  grep -Fxq "branch=$branch" "$run_dir/slice-handoff-summary.txt" || return 1
  grep -Fxq "title=$title" "$run_dir/slice-handoff-summary.txt" || return 1
  grep -Fxq "submit_mode=$submit_mode" "$run_dir/slice-handoff-summary.txt" || return 1
  grep -Fxq "codex_prompt_path=$run_dir/codex-prompt.md" "$run_dir/slice-handoff-summary.txt" || return 1
  grep -Fxq "review_request_path=$run_dir/review-request.txt" "$run_dir/slice-handoff-summary.txt" || return 1
  if [ "$submit_mode" = "repo-flow-submit-all" ]; then
    grep -Fxq "pr_body_path=$run_dir/pr-body.md" "$run_dir/slice-handoff-summary.txt" || return 1
  else
    grep -Fxq "pr_body_path=" "$run_dir/slice-handoff-summary.txt" || return 1
  fi
  grep -Fxq "schema=repo-automation-slice-handoff-execution/v1" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  grep -Fxq "mode=execution-preflight" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  grep -Fxq "branch=$branch" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  grep -Fxq "title=$title" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  grep -Fxq "submit_mode=$submit_mode" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  if [ -n "$expected_repo_root" ]; then
    grep -Fxq "preflight_repo_root=$expected_repo_root" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  fi
  grep -Fxq "cleanup_json_path=$run_dir/slice-run-dir-cleanup.json" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  grep -Fxq "cleanup_stdout_path=$run_dir/slice-run-dir-cleanup.stdout" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  grep -Fxq "cleanup_stderr_path=$run_dir/slice-run-dir-cleanup.stderr" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  grep -Fxq "preflight_json_path=$run_dir/preflight.json" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  grep -Fxq "preflight_stdout_path=$run_dir/preflight.stdout" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  grep -Fxq "preflight_stderr_path=$run_dir/preflight.stderr" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  grep -Fxq "result=pass" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  grep -Fxq "next=codex-run not implemented in this slice" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  return 0
}

smoke_slice_handoff_run() {
  local stdout_file="$1"
  local stderr_file="$2"
  local script_path=""
  local capture_stdout="$stdout_file"
  local capture_stderr="$stderr_file"
  local capture_stdout_tmp=""
  local capture_stderr_tmp=""
  local command_status=0

  shift 2
  mkdir -p "$(dirname "$stdout_file")" "$(dirname "$stderr_file")" || return 1
  script_path="$(smoke_slice_handoff_script)"
  if [ -n "${smoke_test_dir:-}" ] && [ "$script_path" = "$smoke_test_dir/repo-automation/bin/slice-handoff" ]; then
    capture_stdout_tmp="$(mktemp "${TMPDIR:-$HOME/.cache}/slice-handoff-stdout.XXXXXX")" || return 1
    capture_stderr_tmp="$(mktemp "${TMPDIR:-$HOME/.cache}/slice-handoff-stderr.XXXXXX")" || {
      rm -f -- "$capture_stdout_tmp" >/dev/null 2>&1 || true
      return 1
    }
    capture_stdout="$capture_stdout_tmp"
    capture_stderr="$capture_stderr_tmp"
    (
      cd "$smoke_test_dir" || return 1
      "$script_path" "$@"
    ) >"$capture_stdout" 2>"$capture_stderr"
    command_status=$?
    mv -f -- "$capture_stdout" "$stdout_file" || command_status=1
    mv -f -- "$capture_stderr" "$stderr_file" || command_status=1
    return "$command_status"
  else
    "$script_path" "$@" >"$stdout_file" 2>"$stderr_file"
  fi
}

smoke_slice_handoff_expect_failure() {
  local label="$1"
  local reason="$2"
  local fix="$3"
  local stdout_file="$smoke_test_base/slice-handoff-${label}.out"
  local stderr_file="$smoke_test_base/slice-handoff-${label}.err"

  shift 3
  if smoke_slice_handoff_run "$stdout_file" "$stderr_file" "$@"; then
    test_fail "$label"
    return 1
  fi

  if smoke_slice_handoff_assert_error_shape "$stderr_file" "$reason" "$fix"; then
    test_pass "$label"
    return 0
  fi

  test_fail "$label"
  return 1
}

smoke_slice_handoff_expect_success() {
  local label="$1"
  local expected_stdout="$2"
  local expected_stderr="$3"
  local stdout_file="$smoke_test_base/slice-handoff-${label}.out"
  local stderr_file="$smoke_test_base/slice-handoff-${label}.err"

  shift 3
  if smoke_slice_handoff_run "$stdout_file" "$stderr_file" "$@"; then
    if [ "$(cat "$stdout_file" 2>/dev/null || true)" = "$expected_stdout" ] && [ "$(cat "$stderr_file" 2>/dev/null || true)" = "$expected_stderr" ]; then
      test_pass "$label"
      return 0
    fi
  fi

  test_fail "$label"
  return 1
}

# repo-automation/tests/lib/contracts/slice-handoff.sh EOF
