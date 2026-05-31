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

smoke_slice_handoff_write_fake_codex() {
  local fake_bin_dir="$1"

  mkdir -p "$fake_bin_dir" || return 1
  cat > "$fake_bin_dir/codex" <<'EOF'
#!/usr/bin/env bash
set -u

log_file="${FAKE_CODEX_LOG_FILE:-}"
args_file="${FAKE_CODEX_ARGS_FILE:-}"
stdout_text="${FAKE_CODEX_STDOUT_TEXT:-pass}"
stderr_text="${FAKE_CODEX_STDERR_TEXT:-}"
final_text="${FAKE_CODEX_FINAL_TEXT:-fake final output}"
exit_code="${FAKE_CODEX_EXIT_CODE:-0}"
output_last_message=""
prev=""

if [ -n "$args_file" ]; then
  printf '%s\n' "$@" > "$args_file"
fi

for arg in "$@"; do
  if [ -n "$prev" ]; then
    case "$prev" in
      --output-last-message)
        output_last_message="$arg"
        ;;
    esac
    prev=""
    continue
  fi
  case "$arg" in
    --output-last-message)
      prev="$arg"
      ;;
  esac
done

if [ -n "$output_last_message" ]; then
  printf '%s\n' "$final_text" > "$output_last_message"
fi

if [ -n "$log_file" ]; then
  {
    printf 'argv:\n'
    printf '%s\n' "$@"
    printf 'output_last_message=%s\n' "$output_last_message"
  } > "$log_file"
fi

if [ -n "$stdout_text" ]; then
  printf '%s\n' "$stdout_text"
fi

if [ -n "$stderr_text" ]; then
  printf '%s\n' "$stderr_text" >&2
fi

exit "$exit_code"
EOF
  chmod +x "$fake_bin_dir/codex" || return 1
}

smoke_slice_handoff_assert_clean_worktree() {
  local dirty_status=""
  local dirty_excerpt=""

  dirty_status="$(git -C "$smoke_test_dir" status --short --untracked-files=normal 2>/dev/null || true)"
  if [ -n "$dirty_status" ]; then
    dirty_excerpt="$(printf '%s\n' "$dirty_status" | awk 'NR <= 5 { if (NR > 1) printf "; "; printf "%s", $0 } END { print "" }')"
    printf 'fail: slice-handoff execution repo dirty before preflight: %s' "$dirty_excerpt" >&2
    printf 'fix: move generated files outside the execution repo before invoking preflight\n' >&2
    return 1
  fi
}

smoke_slice_handoff_assert_dirty_preflight_failure() {
  local stderr_file="$1"
  local args_file="$2"
  local expected_excerpt="$3"

  grep -Fxq 'step=preflight' "$stderr_file" || return 1
  grep -Fxq "excerpt=$expected_excerpt" "$stderr_file" || return 1
  [ ! -s "$args_file" ] || return 1
}

smoke_slice_handoff_run_dirty_preflight_regression() {
  local smoke_check_root="$smoke_test_base/slice-handoff-dirty"
  local valid_none_file="$smoke_check_root/valid-none.md"
  local execution_artifact_root="${TMPDIR:-$HOME/.cache}/slice-handoff-execution"
  local execution_dirty_out_dir="$execution_artifact_root/out-execution-dirty"
  local dirty_execution_smoke_test_dir=""
  local fake_codex_bin_dir=""
  local args_file="$execution_artifact_root/fake-codex-dirty.args"
  local stdout_file="$execution_artifact_root/slice-handoff-execution-dirty.out"
  local stderr_file="$execution_artifact_root/slice-handoff-execution-dirty.err"

  smoke_setup_temp_repo || return 1
  mkdir -p "$smoke_check_root" || return 1
  smoke_slice_handoff_write_file "$valid_none_file" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "Implement the slice exactly as specified." || return 1
  dirty_execution_smoke_test_dir="$(mktemp -d "${TMPDIR:-$HOME/.cache}/repo-automation-slice-handoff-dirty.XXXXXX")" || return 1
  cp -R "$smoke_test_dir"/. "$dirty_execution_smoke_test_dir" || return 1
  smoke_test_dir="$dirty_execution_smoke_test_dir"
  smoke_slice_handoff_prepare_execution_repo || return 1
  fake_codex_bin_dir="$execution_artifact_root/fake-codex-bin"
  smoke_slice_handoff_write_fake_codex "$fake_codex_bin_dir" || return 1
  printf 'dirty execution repo\n' > "$smoke_test_dir/dirty-before-preflight.txt" || return 1
  rm -rf -- "$execution_dirty_out_dir" || return 1
  rm -f -- "$stdout_file" "$stderr_file" "$args_file" || return 1
  if ! PATH="$fake_codex_bin_dir:$PATH" FAKE_CODEX_ARGS_FILE="$args_file" FAKE_CODEX_STDOUT_TEXT='fake codex stdout' FAKE_CODEX_STDERR_TEXT='fake codex stderr' FAKE_CODEX_FINAL_TEXT='fake final output' smoke_slice_handoff_run "$stdout_file" "$stderr_file" --file="$valid_none_file" --out-dir="$execution_dirty_out_dir"; then
    smoke_slice_handoff_assert_dirty_preflight_failure "$stderr_file" "$args_file" "stop_reason=working tree must be clean before preflight" || return 1
    grep -Fxq 'fix=paste this blocker into ChatGPT' "$stderr_file" || return 1
    return 0
  fi

  printf 'fail: dirty preflight run unexpectedly succeeded\n' >&2
  return 1
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
  [ "$(wc -l < "$stdout_file" | tr -d '[:space:]')" = "8" ] || return 1
  grep -Fxq 'pass' "$stdout_file" || return 1
  grep -Fxq 'mode=execution-codex-run' "$stdout_file" || return 1
  grep -Fxq "branch=$expected_branch" "$stdout_file" || return 1
  grep -Eq '^run_dir=.+' "$stdout_file" || return 1
  grep -Fxq 'preflight_status=pass' "$stdout_file" || return 1
  grep -Fxq 'codex_status=pass' "$stdout_file" || return 1
  grep -Eq '^codex_final_output_path=.+' "$stdout_file" || return 1
  grep -Fxq 'next=repo-flow submit not implemented in this slice' "$stdout_file" || return 1

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
    codex-run.stdout \
    codex-run.stderr \
    slice-handoff-summary.txt \
    slice-handoff-execution-summary.txt \
    codex-prompt.md \
    review-request.txt \
    codex-run/codex.stdout \
    codex-run/codex.stderr \
    codex-run/codex-final.txt \
    codex-run/codex-run-summary.txt
  do
    [ -f "$run_dir/$path" ] || return 1
  done
  [ ! -s "$run_dir/codex-run.stderr" ] || return 1
  grep -Fxq 'pass' "$run_dir/codex-run.stdout" || return 1
  grep -Eq '^final_output_path=.+' "$run_dir/codex-run.stdout" || return 1
  grep -Eq '^summary_path=.+' "$run_dir/codex-run.stdout" || return 1
  [ -s "$run_dir/codex-run/codex.stdout" ] || return 1
  [ -s "$run_dir/codex-run/codex.stderr" ] || return 1
  [ -s "$run_dir/codex-run/codex-final.txt" ] || return 1
  grep -Fxq 'script=codex-run' "$run_dir/codex-run/codex-run-summary.txt" || return 1
  grep -Fxq 'result=pass' "$run_dir/codex-run/codex-run-summary.txt" || return 1
  grep -Fxq 'exit_code=0' "$run_dir/codex-run/codex-run-summary.txt" || return 1
  grep -Fxq "final_output_path=$run_dir/codex-run/codex-final.txt" "$run_dir/codex-run/codex-run-summary.txt" || return 1
  grep -Fxq 'final_output_status=present' "$run_dir/codex-run/codex-run-summary.txt" || return 1

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
  grep -Fxq "mode=execution-codex-run" "$run_dir/slice-handoff-execution-summary.txt" || return 1
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
  grep -Fxq "codex_run_stdout_path=$run_dir/codex-run.stdout" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  grep -Fxq "codex_run_stderr_path=$run_dir/codex-run.stderr" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  grep -Fxq "codex_run_summary_path=$run_dir/codex-run/codex-run-summary.txt" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  grep -Fxq "codex_final_output_path=$run_dir/codex-run/codex-final.txt" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  grep -Fxq "result=pass" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  grep -Fxq "next=repo-flow submit not implemented in this slice" "$run_dir/slice-handoff-execution-summary.txt" || return 1
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
      env PATH="$PATH" "$script_path" "$@"
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
