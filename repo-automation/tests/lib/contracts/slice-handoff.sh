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

smoke_slice_handoff_owned_temp_dir() {
  local pattern="$1"
  local parent="$smoke_test_base/slice-handoff"

  mkdir -p "$parent" || return 1
  mktemp -d "$parent/$pattern.XXXXXX" || return 1
}

smoke_slice_handoff_owned_env_root() {
  local pattern="$1"
  local parent="$smoke_test_base/slice-handoff-env"

  mkdir -p "$parent" || return 1
  mktemp -d "$parent/$pattern.XXXXXX" || return 1
}

smoke_slice_handoff_run_with_isolated_temp_env() {
  local tmpdir="$1"
  local home="$2"
  local var=""

  shift 2
  for var in $(compgen -A variable FAKE_ 2>/dev/null); do
    # shellcheck disable=SC2163
    export "$var"
  done
  PATH="$PATH" TMPDIR="$tmpdir" HOME="$home" "$@"
}

smoke_slice_handoff_seed_execution_repo() {
  local source_repo="$1"
  local repo_dir="$2"

  rm -rf -- "$repo_dir" || return 1
  git clone --local --no-hardlinks "$source_repo" "$repo_dir" >/dev/null 2>&1 || return 1
  git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  [ "$(git -C "$repo_dir" rev-parse --show-toplevel 2>/dev/null)" = "$repo_dir" ] || return 1
  (
    cd "$repo_dir" || return 1
    git config user.name "repo-automation-test" || return 1
    git config user.email "repo-automation-test@example.com" || return 1
  )
}

smoke_slice_handoff_prepare_execution_repo() {
  local config_path="$smoke_test_dir/.repo-automation.conf"
  local execution_remote_dir=""

  smoke_slice_handoff_install_fake_repo_flow || return 1
  smoke_slice_handoff_install_fake_pr_body_check || return 1
  if [ "${FAKE_CODEX_RUN_HELPER:-0}" = 1 ]; then
    smoke_slice_handoff_install_fake_codex_run || return 1
  fi
  execution_remote_dir="$(smoke_slice_handoff_owned_temp_dir "remote")" || return 1
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
  rm -rf -- "$smoke_test_dir/.prompts" || return 1
  cp -R "$smoke_repo_root/.prompts" "$smoke_test_dir/.prompts" || return 1
  cp -- "$smoke_repo_root/repo-automation/bin/slice-handoff" "$smoke_test_dir/repo-automation/bin/slice-handoff" || return 1
  chmod +x "$smoke_test_dir/repo-automation/bin/slice-handoff" || return 1
  git -C "$smoke_test_dir" update-index --skip-worktree repo-automation/bin/slice-handoff || return 1
  smoke_slice_handoff_install_runtime_helper "slice-validator" || return 1
}

smoke_slice_handoff_install_prompt_presets() {
  local handoff_path="$1"
  local prompt_dir=""

  prompt_dir="$(dirname "$handoff_path")/.prompts" || return 1
  rm -rf -- "$prompt_dir" || return 1
  cp -R "$smoke_repo_root/.prompts" "$prompt_dir" || return 1
}

smoke_slice_handoff_install_runtime_helper() {
  local helper_name="$1"
  local source_path="$smoke_repo_root/repo-automation/bin/$helper_name"
  local target_path="$smoke_test_dir/repo-automation/bin/$helper_name"

  cp -- "$source_path" "$target_path" || return 1
  chmod +x "$target_path" || return 1
  git -C "$smoke_test_dir" update-index --skip-worktree "repo-automation/bin/$helper_name" || return 1
}

smoke_slice_handoff_assert_runtime_helper() {
  local helper_name="$1"
  local helper_path="$smoke_test_dir/repo-automation/bin/$helper_name"

  if [ -x "$helper_path" ]; then
    return 0
  fi

  printf 'fail: missing runtime helper in smoke repo: %s\n' "$helper_path" >&2
  printf 'fix: install or copy the child helper into the smoke temp repo before running slice-handoff\n' >&2
  return 1
}

smoke_slice_handoff_install_fake_slice_validator() {
  local validator_path="$smoke_test_dir/repo-automation/bin/slice-validator"

  cat > "$validator_path" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

args_file="${FAKE_SLICE_VALIDATOR_ARGS_FILE:-}"
stdout_text="${FAKE_SLICE_VALIDATOR_STDOUT_TEXT:-}"
stderr_text="${FAKE_SLICE_VALIDATOR_STDERR_TEXT:-}"
exit_code="${FAKE_SLICE_VALIDATOR_EXIT_CODE:-0}"
artifact_dir=""
manifest_out=""
submit_requested=0
json_requested=0
file_path=""

if [ -n "$args_file" ]; then
  printf '%s\n' "$@" > "$args_file"
fi

for arg in "$@"; do
  case "$arg" in
    --submit)
      submit_requested=1
      ;;
    --json)
      json_requested=1
      ;;
    --file=*)
      file_path="${arg#--file=}"
      ;;
    --artifact-dir=*)
      artifact_dir="${arg#--artifact-dir=}"
      ;;
    --manifest-out=*)
      manifest_out="${arg#--manifest-out=}"
      ;;
  esac
done

if [ -n "$artifact_dir" ]; then
  mkdir -p "$artifact_dir" || exit 1
  printf 'fake validator prompt\n' > "$artifact_dir/codex-prompt.md" || exit 1
  printf 'fake validator review request\n' > "$artifact_dir/review-request.txt" || exit 1
  if [ "$submit_requested" -eq 1 ]; then
    printf 'fake validator pr body\n' > "$artifact_dir/pr-body.md" || exit 1
  fi
fi

if [ -n "$manifest_out" ]; then
  mkdir -p "$(dirname "$manifest_out")" || exit 1
  cat > "$manifest_out" <<EOF2
{
  "schema": "repo-automation-slice-validator/v1",
  "result": "pass",
  "branch": "feature/slice-handoff-smoke",
  "title": "Slice handoff smoke",
  "codex_profile": "default",
  "submit_mode": "none",
  "commit_message": "",
  "prompt_path": "${artifact_dir}/codex-prompt.md",
  "review_request_path": "${artifact_dir}/review-request.txt",
  "pr_body_path": ""
}
EOF2
fi

if [ "$json_requested" -eq 1 ]; then
  printf '{"schema":"repo-automation-helper-output/v1","script":"slice-validator","mode":"json","result":"pass","manifest_path":"%s","artifact_dir":"%s","branch":"feature/slice-handoff-smoke","title":"Slice handoff smoke","submit_mode":"none","codex_profile":"default","validated_capabilities":{"preflight":true,"codex_run":true,"codex_status":true,"pr_body_check":false,"repo_flow_submit":false,"review_request_render":true},"forbidden_steps":["pr-body-check","repo-flow submit"],"next":"codex-slice-preflight"}\n' "$manifest_out" "$artifact_dir"
fi

if [ -n "$stdout_text" ]; then
  printf '%s\n' "$stdout_text"
fi
if [ -n "$stderr_text" ]; then
  printf '%s\n' "$stderr_text" >&2
fi

exit "$exit_code"
EOF
  chmod +x "$validator_path" || return 1
}

smoke_slice_handoff_install_fake_repo_flow() {
  local repo_flow_path="$smoke_test_dir/repo-automation/bin/repo-flow"

  cat > "$repo_flow_path" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

args_file="${FAKE_REPO_FLOW_ARGS_FILE:-}"
stdout_text="${FAKE_REPO_FLOW_STDOUT_TEXT:-}"
stderr_text="${FAKE_REPO_FLOW_STDERR_TEXT:-}"
exit_code="${FAKE_REPO_FLOW_EXIT_CODE:-0}"
pr_number="${FAKE_REPO_FLOW_PR_NUMBER:-123}"
commit_sha="${FAKE_REPO_FLOW_COMMIT_SHA:-0123abcd}"
watched="${FAKE_REPO_FLOW_WATCHED:-true}"
ci_state="${FAKE_REPO_FLOW_CI_STATE:-pass}"
url_or_stop="${FAKE_REPO_FLOW_URL_OR_STOP:-https://github.com/i-schuyler/repo-automation-template/pull/123}"
stop_reason="${FAKE_REPO_FLOW_STOP_REASON:-repo-flow submit failed}"
mode="${1:-}"
review_request_file=""
review_request_path=""
review_request_block_path=""

shift || true

if [ -n "$args_file" ]; then
  {
    printf '%s\n' "$mode"
    printf '%s\n' "$@"
  } > "$args_file"
fi

while [ "$#" -gt 0 ]; do
  case "$1" in
    --review-request-file=*)
      review_request_file="${1#--review-request-file=}"
      ;;
  esac
  shift
done

if [ -n "$review_request_file" ]; then
  review_request_path="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-flow-submit-review.XXXXXX")" || exit 1
  review_request_block_path="$(mktemp "${TMPDIR:-$HOME/.cache}/repo-flow-submit-review-block.XXXXXX")" || exit 1
  python3 - "$review_request_file" "$review_request_path" "$url_or_stop" <<'PY' || exit 1
from pathlib import Path
import sys

source = Path(sys.argv[1])
output = Path(sys.argv[2])
pr_url = sys.argv[3]

text = source.read_text(encoding='utf-8')
text = text.replace('<PR_URL>', pr_url)
output.write_text(text, encoding='utf-8')
PY
  {
    printf '===== PR REVIEW REQUEST =====\n'
    cat "$review_request_path"
    if [ "$(tail -c 1 "$review_request_path" 2>/dev/null | od -An -t x1 | tr -d '[:space:]')" != "0a" ]; then
      printf '\n'
    fi
    printf '===== END PR REVIEW REQUEST =====\n'
  } > "$review_request_block_path" || exit 1
fi

if [ -n "$stdout_text" ]; then
  printf '%s\n' "$stdout_text"
fi

if [ -n "$stderr_text" ]; then
  printf '%s\n' "$stderr_text" >&2
fi

if [ "$mode" = "submit" ]; then
  {
    printf '===== FINAL SUMMARY =====\n'
    printf 'script=repo-flow\n'
    printf 'mode=submit\n'
    printf 'rc=%s\n' "$exit_code"
    printf 'pr=%s\n' "$pr_number"
    printf 'commit=%s\n' "$commit_sha"
    printf 'watched=%s\n' "$watched"
    printf 'ci=%s\n' "$ci_state"
    if [ "$exit_code" -eq 0 ]; then
      printf 'url_or_stop=%s\n' "$url_or_stop"
    else
      printf 'url_or_stop=%s\n' "$stop_reason"
    fi
    if [ -n "$review_request_path" ]; then
      printf 'review_request_path=%s\n' "$review_request_path"
    fi
    if [ -n "$review_request_block_path" ]; then
      printf 'review_request_block_path=%s\n' "$review_request_block_path"
    fi
    printf '===== END =====\n'
  } >&2
else
  printf 'fail: unsupported repo-flow mode: %s\n' "$mode" >&2
fi

exit "$exit_code"
EOF
  chmod +x "$repo_flow_path" || return 1
  git -C "$smoke_test_dir" add repo-automation/bin/repo-flow >/dev/null 2>&1 || return 1
  git -C "$smoke_test_dir" commit -m "fake repo-flow for slice-handoff submit" --no-verify >/dev/null 2>&1 || return 1
}

smoke_slice_handoff_install_fake_pr_body_check() {
  local pr_body_check_path="$smoke_test_dir/repo-automation/bin/pr-body-check"

  cat > "$pr_body_check_path" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

args_file="${FAKE_PR_BODY_CHECK_ARGS_FILE:-}"
stdout_text="${FAKE_PR_BODY_CHECK_STDOUT_TEXT:-pass}"
stderr_text="${FAKE_PR_BODY_CHECK_STDERR_TEXT:-}"
exit_code="${FAKE_PR_BODY_CHECK_EXIT_CODE:-0}"
body_file=""
json_mode=0

if [ -n "$args_file" ]; then
  printf '%s\n' "$@" > "$args_file"
fi

for arg in "$@"; do
  case "$arg" in
    --body-file=*)
      body_file="${arg#--body-file=}"
      ;;
    --json)
      json_mode=1
      ;;
  esac
done

if [ "$json_mode" -eq 1 ]; then
  if [ "$exit_code" -eq 0 ]; then
    printf '{"schema":"repo-automation-helper-output/v1","script":"pr-body-check","mode":"json","result":"pass","body_file":"%s"}\n' "$body_file"
  else
    printf '{"schema":"repo-automation-helper-output/v1","script":"pr-body-check","mode":"json","result":"fail","code":"pr-body-check-failed","step":"pr-body-check","reason":"%s","fix":"replace branch/base/ahead/behind scaffolding with real PR body content","body_file":"%s"}\n' "${stderr_text:-body validation failed}" "$body_file"
  fi
  exit "$exit_code"
fi

if [ -n "$stdout_text" ]; then
  printf '%s\n' "$stdout_text"
fi

if [ -n "$stderr_text" ]; then
  printf '%s\n' "$stderr_text" >&2
fi

exit "$exit_code"
EOF
  chmod +x "$pr_body_check_path" || return 1
  git -C "$smoke_test_dir" add repo-automation/bin/pr-body-check >/dev/null 2>&1 || return 1
  git -C "$smoke_test_dir" commit -m "fake pr-body-check for slice-handoff submit" --no-verify >/dev/null 2>&1 || return 1
}

smoke_slice_handoff_install_fake_codex_run() {
  local codex_run_path="$smoke_test_dir/repo-automation/bin/codex-run"

  cat > "$codex_run_path" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail

stdout_text="${FAKE_CODEX_RUN_STDOUT_TEXT:-pass}"
stderr_text="${FAKE_CODEX_RUN_STDERR_TEXT:-}"
exit_code="${FAKE_CODEX_RUN_EXIT_CODE:-0}"
skip_final_output="${FAKE_CODEX_RUN_SKIP_FINAL_OUTPUT:-0}"
final_text=""
out_dir=""
prev=""

for arg in "$@"; do
  if [ -n "$prev" ]; then
    case "$prev" in
      --out-dir)
        out_dir="$arg"
        ;;
    esac
    prev=""
    continue
  fi
  case "$arg" in
    --out-dir=*)
      out_dir="${arg#--out-dir=}"
      ;;
    --out-dir)
      prev="$arg"
      ;;
  esac
done

if [ -z "$out_dir" ]; then
  out_dir="${FAKE_CODEX_RUN_OUT_DIR:-}"
fi

if [ -n "${FAKE_CODEX_RUN_FINAL_TEXT_FILE:-}" ] && [ -r "$FAKE_CODEX_RUN_FINAL_TEXT_FILE" ]; then
  final_text="$(cat "$FAKE_CODEX_RUN_FINAL_TEXT_FILE")"
else
  final_text="${FAKE_CODEX_RUN_FINAL_TEXT:-fake final output}"
fi

if [ -n "$out_dir" ]; then
  mkdir -p "$out_dir" || exit 1
  final_output_path="$out_dir/codex-final.txt"
  summary_path="$out_dir/codex-run-summary.txt"
  if [ -n "$stdout_text" ]; then
    stdout_text="$(printf '%s\nfinal_output_path=%s\nsummary_path=%s' "$stdout_text" "$final_output_path" "$summary_path")"
  fi
  {
    printf 'script=codex-run\n'
    printf 'result=pass\n'
    printf 'exit_code=0\n'
    printf 'final_output_path=%s\n' "$final_output_path"
    if [ "$skip_final_output" -eq 0 ]; then
      printf 'final_output_status=present\n'
    else
      printf 'final_output_status=missing\n'
    fi
  } > "$summary_path"
  if [ "$skip_final_output" -eq 0 ] && [ -n "$final_text" ]; then
    printf '%s\n' "$final_text" > "$final_output_path"
  fi
fi

if [ -n "$stdout_text" ]; then
  printf '%s\n' "$stdout_text"
fi

if [ -n "$stderr_text" ]; then
  printf '%s\n' "$stderr_text" >&2
fi

exit "$exit_code"
EOF
  chmod +x "$codex_run_path" || return 1
  git -C "$smoke_test_dir" update-index --skip-worktree repo-automation/bin/codex-run >/dev/null 2>&1 || return 1
}

smoke_slice_handoff_restore_codex_run() {
  local codex_run_path="$smoke_test_dir/repo-automation/bin/codex-run"

  cp -- "$smoke_repo_root/repo-automation/bin/codex-run" "$codex_run_path" || return 1
  chmod +x "$codex_run_path" || return 1
  git -C "$smoke_test_dir" update-index --no-skip-worktree repo-automation/bin/codex-run >/dev/null 2>&1 || return 1
}

smoke_slice_handoff_set_execution_codex_run_final_text() {
  local final_text="$1"

  printf '%s' "$final_text" > "$smoke_slice_handoff_execution_fake_codex_run_final_text_file" || return 1
}

smoke_slice_handoff_clear_execution_codex_run_final_text() {
  rm -f -- "$smoke_slice_handoff_execution_fake_codex_run_final_text_file" || return 1
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
  local pr_review_prompt_id="${10:-}"

  mkdir -p "$(dirname "$path")" || return 1
  smoke_slice_handoff_install_prompt_presets "$path" || return 1
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
    if [ -n "$pr_review_prompt_id" ]; then
      printf 'pr_review_prompt_id: %s\n' "$pr_review_prompt_id"
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
skip_final_output="${FAKE_CODEX_SKIP_FINAL_OUTPUT:-0}"
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
  if [ "$skip_final_output" -eq 0 ]; then
    printf '%s\n' "$final_text" > "$output_last_message"
  fi
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

smoke_slice_handoff_assert_execution_repo_ready() {
  local repo_root=""
  local dirty_status=""
  local dirty_excerpt=""

  repo_root="$(git -C "$smoke_test_dir" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$repo_root" ] && [ -n "${smoke_slice_handoff_execution_seed_dir:-}" ] && [ -d "$smoke_slice_handoff_execution_seed_dir" ]; then
    smoke_slice_handoff_seed_execution_repo "$smoke_slice_handoff_execution_seed_dir" "$smoke_test_dir" || return 1
    smoke_slice_handoff_prepare_execution_repo || return 1
    repo_root="$(git -C "$smoke_test_dir" rev-parse --show-toplevel 2>/dev/null || true)"
  fi
  if [ -z "$repo_root" ]; then
    printf 'fail: slice-handoff execution repo is not a git repository: %s\n' "$smoke_test_dir" >&2
    printf 'fix: re-seed the smoke execution repo before invoking execution-mode slice-handoff\n' >&2
    return 1
  fi
  if [ "$repo_root" != "$smoke_test_dir" ]; then
    printf 'fail: slice-handoff execution repo root mismatch: %s\n' "$repo_root" >&2
    printf 'fix: re-seed the smoke execution repo before invoking execution-mode slice-handoff\n' >&2
    return 1
  fi
  if [ "${FAKE_CODEX_RUN_HELPER:-0}" = 1 ] && [ -x "$smoke_test_dir/repo-automation/bin/codex-run" ]; then
    smoke_slice_handoff_install_fake_codex_run || return 1
  fi

  dirty_status="$(git -C "$smoke_test_dir" status --short --untracked-files=normal 2>/dev/null || true)"
  if [ -n "$dirty_status" ]; then
    dirty_excerpt="$(printf '%s\n' "$dirty_status" | awk 'NR <= 5 { if (NR > 1) printf "; "; printf "%s", $0 } END { print "" }')"
    printf 'fail: slice-handoff execution repo dirty before preflight: %s' "$dirty_excerpt" >&2
    printf 'fix: move generated files outside the execution repo before invoking preflight\n' >&2
    return 1
  fi
}

smoke_slice_handoff_assert_execution_preflight_isolated() {
  local run_dir="$1"
  local sentinel_path="$2"
  local execution_fixture_root="$3"
  local smoke_fixture_root="$4"
  local deleted_paths_file="$run_dir/preflight-deleted-paths.txt"

  [ -e "$sentinel_path" ] || return 1

  python3 - "$run_dir/preflight.json" "$deleted_paths_file" "$execution_fixture_root" "$smoke_fixture_root" "$TEST_TEMP_ROOT" <<'PY' || return 1
from pathlib import Path
import json
import sys

preflight_path = Path(sys.argv[1])
deleted_paths_file = Path(sys.argv[2])
execution_fixture_root = sys.argv[3]
smoke_fixture_root = sys.argv[4]
test_temp_root = sys.argv[5]
data = json.loads(preflight_path.read_text(encoding='utf-8'))
deleted = data.get('cleanup_deleted_paths', '')
paths = []
if isinstance(deleted, list):
    raw_paths = [str(item) for item in deleted if item is not None]
else:
    raw_paths = str(deleted).split(',')
for item in raw_paths:
    path = item.strip()
    if path:
        paths.append(path)
deleted_paths_file.write_text('\n'.join(paths) + ('\n' if paths else ''), encoding='utf-8')
for path in paths:
    if path == test_temp_root:
        raise SystemExit(1)
    if path == smoke_fixture_root:
        raise SystemExit(1)
    if path == execution_fixture_root or path.startswith(execution_fixture_root + '/'):
        raise SystemExit(1)
PY
}

smoke_slice_handoff_assert_dirty_preflight_failure() {
  local stderr_file="$1"
  local args_file="$2"
  local run_dir="$3"
  local expected_excerpt="$4"

  smoke_slice_handoff_assert_child_failure_shape "$stderr_file" "preflight" "repo-automation/bin/codex-slice-preflight" "1" "$run_dir/preflight.stdout" "$run_dir/preflight.stderr" "$expected_excerpt" "$expected_excerpt" "fix preflight and rerun slice-handoff" || return 1
  [ ! -s "$args_file" ] || return 1
}

smoke_slice_handoff_run_dirty_preflight_regression() {
  local smoke_check_root="$smoke_test_base/slice-handoff-dirty"
  local valid_none_file="$smoke_check_root/valid-none.md"
  local execution_tmp_root="$smoke_test_base/slice-handoff-tmp"
  local execution_artifact_root="$execution_tmp_root/slice-handoff-execution"
  local execution_dirty_out_dir="$execution_artifact_root/out-execution-dirty"
  local dirty_execution_smoke_test_dir=""
  local dirty_execution_sentinel=""
  local dirty_execution_isolation_root=""
  local dirty_execution_isolated_tmpdir=""
  local dirty_execution_isolated_home=""
  local fake_codex_bin_dir=""
  local args_file="$execution_artifact_root/fake-codex-dirty.args"
  local stdout_file="$execution_artifact_root/slice-handoff-execution-dirty.out"
  local stderr_file="$execution_artifact_root/slice-handoff-execution-dirty.err"
  local saved_smoke_test_base="$smoke_test_base"
  local saved_smoke_test_dir="$smoke_test_dir"
  local saved_smoke_remote_dir="$smoke_remote_dir"
  local status=0

  smoke_setup_temp_repo || return 1
  mkdir -p "$smoke_check_root" || return 1
  mkdir -p "$execution_tmp_root" || return 1
  smoke_slice_handoff_write_file "$valid_none_file" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "Implement the slice exactly as specified." || return 1
  dirty_execution_smoke_test_dir="$(smoke_slice_handoff_owned_temp_dir "execution-dirty")" || return 1
  test_register_temp_dir "$dirty_execution_smoke_test_dir" || return 1
  smoke_slice_handoff_seed_execution_repo "$smoke_test_dir" "$dirty_execution_smoke_test_dir" || return 1
  git -C "$dirty_execution_smoke_test_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  [ "$(git -C "$dirty_execution_smoke_test_dir" rev-parse --show-toplevel 2>/dev/null)" = "$dirty_execution_smoke_test_dir" ] || return 1
  # shellcheck disable=SC2034
  smoke_slice_handoff_execution_seed_dir="$saved_smoke_test_dir"
  smoke_test_dir="$dirty_execution_smoke_test_dir"
  dirty_execution_sentinel="$smoke_test_base/slice-handoff/.slice-handoff-execution-sentinel"
  printf 'keep\n' > "$dirty_execution_sentinel" || return 1
  dirty_execution_isolation_root="$(smoke_slice_handoff_owned_env_root "execution-dirty")" || return 1
  dirty_execution_isolated_tmpdir="$dirty_execution_isolation_root/tmpdir"
  dirty_execution_isolated_home="$dirty_execution_isolation_root/home"
  mkdir -p "$dirty_execution_isolated_tmpdir" "$dirty_execution_isolated_home" || return 1
  smoke_slice_handoff_prepare_execution_repo || return 1
  fake_codex_bin_dir="$execution_artifact_root/fake-codex-bin"
  smoke_slice_handoff_write_fake_codex "$fake_codex_bin_dir" || return 1
  printf 'dirty execution repo\n' > "$smoke_test_dir/dirty-before-preflight.txt" || return 1
  rm -rf -- "$execution_dirty_out_dir" || return 1
  rm -f -- "$stdout_file" "$stderr_file" "$args_file" || return 1
  if ! (
    PATH="$fake_codex_bin_dir:$PATH" FAKE_CODEX_ARGS_FILE="$args_file" FAKE_CODEX_STDOUT_TEXT='fake codex stdout' FAKE_CODEX_STDERR_TEXT='fake codex stderr' FAKE_CODEX_FINAL_TEXT='fake final output' smoke_slice_handoff_run_with_isolated_temp_env "$dirty_execution_isolated_tmpdir" "$dirty_execution_isolated_home" smoke_slice_handoff_run "$stdout_file" "$stderr_file" --file="$valid_none_file" --out-dir="$execution_dirty_out_dir"
  ); then
    if [ ! -d "$dirty_execution_isolated_tmpdir/repo-automation/slice-handoff-runs" ]; then
      printf 'fail: slice-handoff dirty-preflight run dir root missing: %s\n' "$dirty_execution_isolated_tmpdir/repo-automation/slice-handoff-runs" >&2
      printf 'fix: ensure slice-handoff creates the run-dir root before preflight failure handling\n' >&2
      test_fail "dirty-preflight-run-dir"
      status=1
    else
      run_dir="$(smoke_slice_handoff_latest_run_dir "$dirty_execution_isolated_tmpdir/repo-automation/slice-handoff-runs" "dirty-preflight")" || return 1
      if ! smoke_slice_handoff_assert_dirty_preflight_failure "$stderr_file" "$args_file" "$run_dir" "stop_reason=working tree must be clean before preflight"; then
        status=1
      elif ! grep -Fxq 'fix=paste this blocker into ChatGPT' "$stderr_file"; then
        status=1
      elif [ ! -e "$dirty_execution_sentinel" ]; then
        status=1
      else
        if ! python3 - "$run_dir" "$dirty_execution_sentinel" "$dirty_execution_smoke_test_dir" "$saved_smoke_test_base" "$TEST_TEMP_ROOT" <<'PY'
from pathlib import Path
import json
import sys

run_dir = Path(sys.argv[1])
sentinel_path = Path(sys.argv[2])
execution_fixture_root = sys.argv[3]
smoke_fixture_root = sys.argv[4]
test_temp_root = sys.argv[5]
preflight = json.loads((run_dir / 'preflight.json').read_text(encoding='utf-8'))
deleted = preflight.get('cleanup_deleted_paths', '')
if isinstance(deleted, list):
    paths = [str(item) for item in deleted if item]
else:
    paths = [line for line in str(deleted).splitlines() if line]
for path in paths:
    if path == test_temp_root:
        raise SystemExit(1)
    if path == smoke_fixture_root:
        raise SystemExit(1)
    if path == execution_fixture_root or path.startswith(execution_fixture_root + '/'):
        raise SystemExit(1)
if not sentinel_path.exists():
    raise SystemExit(1)
PY
        then
          status=1
        fi
      fi
    fi
  else
    printf 'fail: dirty preflight run unexpectedly succeeded\n' >&2
    status=1
  fi

  smoke_test_base="$saved_smoke_test_base"
  smoke_test_dir="$saved_smoke_test_dir"
  smoke_remote_dir="$saved_smoke_remote_dir"
  return "$status"
}

smoke_slice_handoff_assert_error_shape() {
  local stderr_file="$1"
  local reason="$2"
  local fix="$3"
  local filtered_stderr_file=""

  filtered_stderr_file="$(mktemp "${TMPDIR:-$HOME/.cache}/slice-handoff-expected-error.XXXXXX")" || return 1
  grep -v '^[+]' "$stderr_file" > "$filtered_stderr_file" 2>/dev/null || true
  if [ "$(wc -l < "$filtered_stderr_file" | tr -d '[:space:]')" = "2" ] &&
    grep -Fxq "fail: $reason" "$filtered_stderr_file" &&
    grep -Fxq "fix: $fix" "$filtered_stderr_file"; then
    rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true
    return 0
  fi
  rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true
  return 1
}

smoke_slice_handoff_assert_child_failure_shape() {
  local stderr_file="$1"
  local expected_step="$2"
  local expected_command_class="$3"
  local expected_exit_code="$4"
  local expected_stdout_path="$5"
  local expected_stderr_path="$6"
  local expected_reason="$7"
  local expected_excerpt="${8:-$7}"
  local expected_next="$9"
  local filtered_stderr_file=""

  filtered_stderr_file="$(mktemp "${TMPDIR:-$HOME/.cache}/slice-handoff-execution-error.XXXXXX")" || return 1
  grep -v '^[+]' "$stderr_file" > "$filtered_stderr_file" 2>/dev/null || true
  if grep -Fxq 'fail: slice-handoff child boundary failed' "$filtered_stderr_file" &&
    grep -Fxq "step=$expected_step" "$filtered_stderr_file" &&
    grep -Fxq "command_class=$expected_command_class" "$filtered_stderr_file" &&
    grep -Fxq "exit_code=$expected_exit_code" "$filtered_stderr_file" &&
    grep -Fxq "stdout_path=$expected_stdout_path" "$filtered_stderr_file" &&
    grep -Fxq "stderr_path=$expected_stderr_path" "$filtered_stderr_file" &&
    grep -Fxq "reason=$expected_reason" "$filtered_stderr_file" &&
    grep -Fxq "excerpt=$expected_excerpt" "$filtered_stderr_file" &&
    grep -Fxq 'fix=paste this blocker into ChatGPT' "$filtered_stderr_file" &&
    grep -Fxq "next=$expected_next" "$filtered_stderr_file"; then
    rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true
    return 0
  fi
  rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true
  return 1
}

smoke_slice_handoff_assert_validator_failure_shape() {
  local stderr_file="$1"
  local expected_reason="$2"
  local _expected_fix="${3:-}"
  local expected_next="${4:-fix the reported validator failure and rerun slice-handoff}"
  local filtered_stderr_file=""

  filtered_stderr_file="$(mktemp "${TMPDIR:-$HOME/.cache}/slice-handoff-validator-error.XXXXXX")" || return 1
  grep -v '^[+]' "$stderr_file" > "$filtered_stderr_file" 2>/dev/null || true
  if grep -Fxq 'fail: slice-handoff child boundary failed' "$filtered_stderr_file" &&
    grep -Fxq 'step=slice-validator' "$filtered_stderr_file" &&
    grep -Fq 'command_class=repo-automation/bin/slice-validator' "$filtered_stderr_file" &&
    grep -Fq 'command=repo-automation/bin/slice-validator' "$filtered_stderr_file" &&
    grep -Fxq 'exit_code=1' "$filtered_stderr_file" &&
    grep -Fq "reason=$expected_reason" "$filtered_stderr_file" &&
    grep -Fq "excerpt=reason=$expected_reason" "$filtered_stderr_file" &&
    grep -Fxq 'fix=paste this blocker into ChatGPT' "$filtered_stderr_file" &&
    grep -Fxq "next=$expected_next" "$filtered_stderr_file"; then
    rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true
    return 0
  fi
  rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true
  return 1
}

smoke_slice_handoff_assert_text_file() {
  local path="$1"
  local expected="$2"

  [ "$(cat "$path" 2>/dev/null || true)" = "$expected" ]
}

smoke_slice_handoff_expected_review_request_default() {
  cat <<'EOF'
Please review this PR before merge:

<PR_URL>

Slice handoff smoke
Branch: feature/slice-handoff-smoke

Review the changed files and any related docs, tests, metadata, command contracts, output contracts, and examples for drift.

Return CLEAN, NEEDS REPAIR, BLOCKING, or UNCERTAIN. If repair is needed, describe one same-branch repair direction.
EOF
}

smoke_slice_handoff_expected_review_request_submit() {
  cat <<'EOF'
Please review this PR before merge:

<PR_URL>

Slice handoff submit smoke
Branch: feature/slice-handoff-submit

Review the changed files and any related docs, tests, metadata, command contracts, output contracts, and examples for drift.

Return CLEAN, NEEDS REPAIR, BLOCKING, or UNCERTAIN. If repair is needed, describe one same-branch repair direction.
EOF
}

smoke_slice_handoff_expected_review_request_head() {
  cat <<'EOF'
Please review this PR before merge.
EOF
}

smoke_slice_handoff_expected_execution_stdout() {
  local out_dir="$1"
  local review_request_path="$2"
  local include_pr_body="${3:-0}"

  if [ "$include_pr_body" -eq 1 ]; then
    printf 'pass\nout_dir=%s\ncodex_prompt_path=%s/codex-prompt.md\npreview_path=%s/dry-run-preview.txt\npr_body_path=%s/pr-body.md\nreview_request_path=%s/review-request.txt\nsummary_path=%s/slice-handoff-summary.txt\nvalidation_manifest_path=%s/validation-manifest.json' \
      "$out_dir" "$out_dir" "$out_dir" "$out_dir" "$review_request_path" "$out_dir" "$out_dir"
  else
    printf 'pass\nout_dir=%s\ncodex_prompt_path=%s/codex-prompt.md\npreview_path=%s/dry-run-preview.txt\nreview_request_path=%s/review-request.txt\nsummary_path=%s/slice-handoff-summary.txt\nvalidation_manifest_path=%s/validation-manifest.json' \
      "$out_dir" "$out_dir" "$out_dir" "$review_request_path" "$out_dir" "$out_dir"
  fi
}

smoke_slice_handoff_expected_execution_summary() {
  local out_dir="$1"
  local branch="$2"
  local title="$3"
  local codex_profile="$4"
  local submit_mode="$5"
  local commit_message="$6"
  local pr_body_path="$7"

  printf 'schema=repo-automation-slice-handoff/v1\nbranch=%s\ntitle=%s\ncodex_profile=%s\nsubmit_mode=%s\ncommit_message=%s\ncodex_prompt_path=%s/codex-prompt.md\npr_body_path=%s\nreview_request_path=%s/review-request.txt\nvalidation_manifest_path=%s/validation-manifest.json' \
    "$branch" "$title" "$codex_profile" "$submit_mode" "$commit_message" "$out_dir" "$pr_body_path" "$out_dir" "$out_dir"
}

smoke_slice_handoff_expected_dry_run_preview() {
  local out_dir="$1"
  local branch="$2"
  local title="$3"
  local codex_profile="$4"
  local submit_mode="$5"
  local commit_message="$6"
  local pr_body_path="$7"
  local submit_authorized="${8:-0}"

  cat <<EOF
dry_run_mode=enabled
branch=$branch
title=$title
codex_profile=$codex_profile
submit_mode=$submit_mode
commit_message=$commit_message
codex_prompt_path=$out_dir/codex-prompt.md
pr_body_path=$pr_body_path
review_request_path=$out_dir/review-request.txt
summary_path=$out_dir/slice-handoff-summary.txt
preview_path=$out_dir/dry-run-preview.txt
planned_run_dir_root=$smoke_slice_handoff_expected_planned_run_dir_root
planned_active_run_dir=<active-run-dir>
planned_marker_file_name=.repo-automation-slice-run

Planned execution shapes
planned_run_dir_cleanup_argv:
- repo-automation/bin/slice-run-dir
- --cleanup-stale
- --root=$smoke_slice_handoff_expected_planned_run_dir_root
- --max-age-days=7
- --keep=10
- --preserve-path=<active-run-dir>
- --json
planned_preflight_argv:
- repo-automation/bin/codex-slice-preflight
- --branch=$branch
- --clean-test-cache
- --preserve-path=<active-run-dir>
- --json
planned_codex_run_argv:
- repo-automation/bin/codex-run
- --prompt-file=<active-run-dir>/codex-prompt.md
- --out-dir=<active-run-dir>/codex-run
- --profile=$codex_profile
- --cd=$smoke_slice_handoff_expected_dry_run_repo_root
EOF
  if [ "$submit_authorized" -eq 1 ] && [ "$pr_body_path" != "not_applicable" ]; then
    cat <<EOF2
planned_pr_body_validation_argv:
- repo-automation/bin/pr-body-check
- --body-file=$pr_body_path
planned_repo_flow_submit_argv:
- repo-automation/bin/repo-flow
- submit
- --all
- --message=$commit_message
- --body-file=$pr_body_path
- --review-request-file=<active-run-dir>/review-request-source.txt
- --watch
- --timeout=900
- --diagnose-on-fail
- --explain
EOF2
  else
    printf 'planned_pr_body_validation_argv=not_applicable\nplanned_repo_flow_submit_argv=not_applicable\n'
  fi
  cat <<EOF

Planned artifact/log/metadata paths
preflight_log_path=not_created_by_dry_run
codex_run_stdout_path=not_created_by_dry_run
codex_run_stderr_path=not_created_by_dry_run
codex_run_summary_path=not_created_by_dry_run
codex_final_output_path=not_written_by_dry_run
submit_log_path=not_created_by_dry_run

Expected future final outcomes
expected_future_final_outcomes=$(
  if [ "$submit_authorized" -eq 1 ] && [ "$submit_mode" = "repo-flow-submit-all" ] && [ "$pr_body_path" != "not_applicable" ]; then
    printf '%s' 'blocker or PR URL / FINAL SUMMARY / review request'
  else
    printf '%s' 'blocker or review request'
  fi
)
EOF
}

smoke_slice_handoff_expected_dry_run_stdout() {
  local out_dir="$1"

  printf 'pass\nout_dir=%s\ncodex_prompt_path=%s/codex-prompt.md\npreview_path=%s/dry-run-preview.txt\nreview_request_path=%s/review-request.txt\nsummary_path=%s/slice-handoff-summary.txt\nvalidation_manifest_path=%s/validation-manifest.json' \
    "$out_dir" "$out_dir" "$out_dir" "$out_dir" "$out_dir" "$out_dir"
}

smoke_slice_handoff_expected_submit_stdout() {
  local out_dir="$1"

  printf 'pass\nout_dir=%s\ncodex_prompt_path=%s/codex-prompt.md\npreview_path=%s/dry-run-preview.txt\npr_body_path=%s/pr-body.md\nreview_request_path=%s/review-request.txt\nsummary_path=%s/slice-handoff-summary.txt\nvalidation_manifest_path=%s/validation-manifest.json' \
    "$out_dir" "$out_dir" "$out_dir" "$out_dir" "$out_dir" "$out_dir" "$out_dir"
}

smoke_slice_handoff_expected_handoff_summary() {
  local out_dir="$1"
  local branch="$2"
  local title="$3"
  local codex_profile="$4"
  local submit_mode="$5"
  local commit_message="$6"
  local pr_body_path="$7"

  printf 'schema=repo-automation-slice-handoff/v1\nbranch=%s\ntitle=%s\ncodex_profile=%s\nsubmit_mode=%s\ncommit_message=%s\ncodex_prompt_path=%s/codex-prompt.md\npr_body_path=%s\nreview_request_path=%s/review-request.txt\nvalidation_manifest_path=%s/validation-manifest.json' \
    "$branch" "$title" "$codex_profile" "$submit_mode" "$commit_message" "$out_dir" "$pr_body_path" "$out_dir" "$out_dir"
}

smoke_slice_handoff_prepare_contract_context() {
  smoke_slice_handoff_check_root="$smoke_test_base/slice-handoff"
  smoke_slice_handoff_valid_none_file="$smoke_slice_handoff_check_root/valid-none.md"
  smoke_slice_handoff_valid_submit_file="$smoke_slice_handoff_check_root/valid-submit.md"
  smoke_slice_handoff_valid_none_out_dir="$smoke_test_base/out-valid-none"
  smoke_slice_handoff_valid_submit_out_dir="$smoke_test_base/out-valid-submit"
  smoke_slice_handoff_valid_preset_out_dir="$smoke_test_base/out-valid-preset"
  smoke_slice_handoff_valid_quiet_out_dir="$smoke_test_base/out-quiet"
  smoke_slice_handoff_execution_tmp_root="$smoke_test_base/slice-handoff-tmp"
  smoke_slice_handoff_execution_artifact_root="$smoke_slice_handoff_execution_tmp_root/slice-handoff-execution"
  smoke_slice_handoff_execution_none_out_dir="$smoke_slice_handoff_execution_artifact_root/out-execution-none"
  smoke_slice_handoff_execution_submit_out_dir="$smoke_slice_handoff_execution_artifact_root/out-execution-submit"
  smoke_slice_handoff_execution_quiet_out_dir="$smoke_slice_handoff_execution_artifact_root/out-execution-quiet"
  smoke_slice_handoff_execution_explain_out_dir="$smoke_slice_handoff_execution_artifact_root/out-execution-explain"
  smoke_slice_handoff_invalid_out_dir="$smoke_test_base/out-invalid-validation"
  smoke_slice_handoff_invalid_submit_file="$smoke_slice_handoff_check_root/invalid-submit-pr-body.md"
  smoke_slice_handoff_valid_preset_file="$smoke_slice_handoff_check_root/valid-preset.md"
  smoke_slice_handoff_invalid_prompt_conflict_file="$smoke_slice_handoff_check_root/invalid-pr-review-conflict.md"
  smoke_slice_handoff_invalid_prompt_id_file="$smoke_slice_handoff_check_root/invalid-pr-review-id.md"
  smoke_slice_handoff_missing_prompt_file="$smoke_slice_handoff_check_root/missing-pr-review-preset.md"
  smoke_slice_handoff_lifecycle_file="$smoke_slice_handoff_check_root/lifecycle.md"
  smoke_slice_handoff_self_modifying_helper_file="$smoke_slice_handoff_check_root/self-modifying-helper.md"
  smoke_slice_handoff_helper_command_mention_file="$smoke_slice_handoff_check_root/helper-command-mention.md"
  smoke_slice_handoff_top_level_fixture_baseline_file="$smoke_slice_handoff_check_root/top-level-fixture-baseline.txt"
  smoke_slice_handoff_top_level_fixture_after_file="$smoke_slice_handoff_check_root/top-level-fixture-after.txt"
  smoke_slice_handoff_valid_prompt="Implement the slice exactly as specified."
  smoke_slice_handoff_submit_prompt="Implement the slice and prepare the PR body."
  smoke_slice_handoff_invalid_submit_body="This PR body is intentionally invalid for pr-body-check."
  smoke_slice_handoff_submit_body="$(cat <<'EOF'
## Scope

Slice handoff smoke.

## What changed

Nothing.

## What did not change

Nothing.

## Verification status

Validated with slice-handoff and pr-body-check.

## User-visible behavior changes

None.

## Stop conditions encountered

None.

## Re-entry hint

Review the PR and continue the slice.
EOF
)"
  smoke_slice_handoff_explicit_review_request_text='Please review this PR before merge.'
  smoke_slice_handoff_expected_dry_run_repo_root="$smoke_test_dir"
  smoke_slice_handoff_expected_planned_run_dir_root="${TMPDIR:-$HOME/.cache}/repo-automation/slice-handoff-runs"
  smoke_slice_handoff_expected_submit_repo_flow_url_or_stop="https://github.com/i-schuyler/repo-automation-template/pull/123"
  smoke_slice_handoff_expected_submit_repo_flow_pr="123"
  smoke_slice_handoff_expected_submit_commit_sha="0123abcd"
  smoke_slice_handoff_expected_submit_watched="true"
  smoke_slice_handoff_expected_submit_ci_state="pass"
  smoke_slice_handoff_expected_default_review_request="$(smoke_slice_handoff_expected_review_request_default)"
  smoke_slice_handoff_expected_submit_default_review_request="$(smoke_slice_handoff_expected_review_request_submit)"
  smoke_slice_handoff_expected_none_prompt="$smoke_slice_handoff_valid_prompt"
  smoke_slice_handoff_expected_submit_prompt="$smoke_slice_handoff_submit_prompt"
  smoke_slice_handoff_expected_none_preview="$(smoke_slice_handoff_expected_dry_run_preview "$smoke_slice_handoff_valid_none_out_dir" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "not_applicable")"
  smoke_slice_handoff_expected_submit_noauth_preview="$(smoke_slice_handoff_expected_dry_run_preview "$smoke_slice_handoff_valid_submit_out_dir" "feature/slice-handoff-submit" "Slice handoff submit smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "not_applicable")"
  smoke_slice_handoff_expected_submit_preview="$(smoke_slice_handoff_expected_dry_run_preview "$smoke_slice_handoff_valid_submit_out_dir" "feature/slice-handoff-submit" "Slice handoff submit smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$smoke_slice_handoff_valid_submit_out_dir/pr-body.md" 1)"
  smoke_slice_handoff_expected_quiet_preview="$(smoke_slice_handoff_expected_dry_run_preview "$smoke_slice_handoff_valid_quiet_out_dir" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "not_applicable")"
  smoke_slice_handoff_expected_preset_preview="$(smoke_slice_handoff_expected_dry_run_preview "$smoke_slice_handoff_valid_preset_out_dir" "feature/slice-handoff-pr-review" "Slice handoff preset review smoke" "default" "none" "" "not_applicable")"
  smoke_slice_handoff_expected_none_review_stdout="$(smoke_slice_handoff_expected_dry_run_stdout "$smoke_slice_handoff_valid_quiet_out_dir")"
  smoke_slice_handoff_expected_explicit_review_stdout="$(smoke_slice_handoff_expected_submit_stdout "$smoke_slice_handoff_valid_submit_out_dir")"
  smoke_slice_handoff_expected_submit_review_request_rendered="$(cat <<'EOF'
Please review this PR before merge:

https://github.com/i-schuyler/repo-automation-template/pull/123

Slice handoff submit smoke
Branch: feature/slice-handoff-pr-review

Review the changed files and any related docs, tests, metadata, command contracts, output contracts, and examples for drift.

Return CLEAN, NEEDS REPAIR, BLOCKING, or UNCERTAIN. If repair is needed, describe one same-branch repair direction.
EOF
)"
  smoke_slice_handoff_expected_preset_review_request="$(cat "$smoke_test_dir/.prompts/repo-automation-template-pr-review.md")"
  smoke_slice_handoff_expected_none_stdout="$(smoke_slice_handoff_expected_dry_run_stdout "$smoke_slice_handoff_valid_none_out_dir")"
  smoke_slice_handoff_expected_submit_stdout_value="$(smoke_slice_handoff_expected_dry_run_stdout "$smoke_slice_handoff_valid_submit_out_dir")"
  smoke_slice_handoff_expected_preset_stdout="$(smoke_slice_handoff_expected_dry_run_stdout "$smoke_slice_handoff_valid_preset_out_dir")"
  smoke_slice_handoff_expected_none_summary="$(smoke_slice_handoff_expected_handoff_summary "$smoke_slice_handoff_valid_none_out_dir" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "")"
  smoke_slice_handoff_expected_quiet_summary="$(smoke_slice_handoff_expected_handoff_summary "$smoke_slice_handoff_valid_quiet_out_dir" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "")"
  smoke_slice_handoff_expected_submit_summary="$(smoke_slice_handoff_expected_handoff_summary "$smoke_slice_handoff_valid_submit_out_dir" "feature/slice-handoff-submit" "Slice handoff submit smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$smoke_slice_handoff_valid_submit_out_dir/pr-body.md")"
  smoke_slice_handoff_expected_submit_noauth_summary="$(smoke_slice_handoff_expected_handoff_summary "$smoke_slice_handoff_valid_submit_out_dir" "feature/slice-handoff-submit" "Slice handoff submit smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "")"
  smoke_slice_handoff_expected_execution_none_summary="$(smoke_slice_handoff_expected_handoff_summary "$smoke_slice_handoff_execution_none_out_dir" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "")"
  smoke_slice_handoff_expected_execution_quiet_summary="$(smoke_slice_handoff_expected_handoff_summary "$smoke_slice_handoff_execution_quiet_out_dir" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "")"
  smoke_slice_handoff_expected_execution_review_request_head="$(smoke_slice_handoff_expected_review_request_head)"
  smoke_slice_handoff_execution_valid_none_file="$smoke_slice_handoff_execution_artifact_root/valid-none.md"
  smoke_slice_handoff_execution_valid_submit_file="$smoke_slice_handoff_execution_artifact_root/valid-submit.md"
  smoke_slice_handoff_execution_valid_preset_file="$smoke_slice_handoff_execution_artifact_root/valid-preset.md"
  smoke_slice_handoff_execution_invalid_submit_file="$smoke_slice_handoff_execution_artifact_root/invalid-submit-pr-body.md"
  smoke_slice_handoff_execution_fake_codex_bin_dir=""
  smoke_slice_handoff_execution_fake_codex_args_none_file=""
  smoke_slice_handoff_execution_fake_codex_args_submit_file=""
  smoke_slice_handoff_execution_fake_codex_args_submit_blocker_file=""
  smoke_slice_handoff_execution_fake_codex_args_submit_blocker_crlf_file=""
  smoke_slice_handoff_execution_fake_codex_args_submit_missing_final_file=""
  smoke_slice_handoff_execution_fake_codex_run_final_text_file="$smoke_slice_handoff_execution_artifact_root/fake-codex-run-final.txt"
  FAKE_CODEX_RUN_FINAL_TEXT_FILE="$smoke_slice_handoff_execution_fake_codex_run_final_text_file"
  smoke_slice_handoff_execution_fake_repo_flow_args_submit_file=""
  smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file=""

  mkdir -p "$smoke_slice_handoff_check_root" "$smoke_slice_handoff_execution_tmp_root" "$smoke_slice_handoff_execution_artifact_root" || return 1
  rm -rf -- "$smoke_slice_handoff_check_root/.prompts" "$smoke_slice_handoff_execution_artifact_root/.prompts" || return 1
  cp -R "$smoke_repo_root/.prompts" "$smoke_slice_handoff_check_root/.prompts" || return 1
  cp -R "$smoke_repo_root/.prompts" "$smoke_slice_handoff_execution_artifact_root/.prompts" || return 1

  smoke_slice_handoff_write_file "$smoke_slice_handoff_valid_none_file" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "$smoke_slice_handoff_valid_prompt" || return 1
  smoke_slice_handoff_write_file "$smoke_slice_handoff_valid_submit_file" "feature/slice-handoff-submit" "Slice handoff submit smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$smoke_slice_handoff_submit_prompt" "$smoke_slice_handoff_submit_body" || return 1
  smoke_slice_handoff_write_file "$smoke_slice_handoff_invalid_submit_file" "feature/slice-handoff-submit" "Slice handoff submit smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$smoke_slice_handoff_submit_prompt" "$smoke_slice_handoff_invalid_submit_body" || return 1
  smoke_slice_handoff_write_file "$smoke_slice_handoff_valid_preset_file" "feature/slice-handoff-pr-review" "Slice handoff preset review smoke" "default" "none" "" "$smoke_slice_handoff_valid_prompt" "" "" "repo-automation-template-pr-review" || return 1
  smoke_slice_handoff_write_file "$smoke_slice_handoff_invalid_prompt_conflict_file" "feature/slice-handoff-pr-review" "Slice handoff preset review smoke" "default" "none" "" "$smoke_slice_handoff_valid_prompt" "" "$smoke_slice_handoff_explicit_review_request_text" "repo-automation-template-pr-review" || return 1
  smoke_slice_handoff_write_file "$smoke_slice_handoff_invalid_prompt_id_file" "feature/slice-handoff-pr-review" "Slice handoff preset review smoke" "default" "none" "" "$smoke_slice_handoff_valid_prompt" "" "" "-bad" || return 1
  smoke_slice_handoff_write_file "$smoke_slice_handoff_missing_prompt_file" "feature/slice-handoff-pr-review" "Slice handoff preset review smoke" "default" "none" "" "$smoke_slice_handoff_valid_prompt" "" "" "missing-preset" || return 1
  smoke_slice_handoff_write_file "$smoke_slice_handoff_lifecycle_file" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "Please create a PR." || return 1
  smoke_slice_handoff_write_file "$smoke_slice_handoff_self_modifying_helper_file" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "Update repo-automation/bin/slice-handoff to add the new guard." || return 1
  smoke_slice_handoff_write_file "$smoke_slice_handoff_helper_command_mention_file" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "Please run repo-automation/bin/slice-handoff --help as a command reference, then continue with the slice." || return 1
}

smoke_slice_handoff_prepare_execution_context() {
  find "$TEST_TEMP_ROOT" -maxdepth 1 -mindepth 1 -type d \( \
      -name 'repo-automation-slice-handoff-remote.*' -o \
      -name 'repo-automation-slice-handoff-exec.*' -o \
      -name 'repo-automation-slice-handoff-exec-dirty.*' \
    \) -printf '%f\n' | sort > "$smoke_slice_handoff_top_level_fixture_baseline_file" || return 1
  smoke_slice_handoff_execution_smoke_test_dir="$(smoke_slice_handoff_owned_temp_dir "execution")" || return 1
  test_register_temp_dir "$smoke_slice_handoff_execution_smoke_test_dir" || return 1
  smoke_slice_handoff_seed_execution_repo "$smoke_test_dir" "$smoke_slice_handoff_execution_smoke_test_dir" || return 1
  git -C "$smoke_slice_handoff_execution_smoke_test_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  [ "$(git -C "$smoke_slice_handoff_execution_smoke_test_dir" rev-parse --show-toplevel 2>/dev/null)" = "$smoke_slice_handoff_execution_smoke_test_dir" ] || return 1
  # shellcheck disable=SC2034
  smoke_slice_handoff_execution_seed_dir="$smoke_test_dir"
  smoke_test_dir="$smoke_slice_handoff_execution_smoke_test_dir"
  smoke_slice_handoff_prepare_execution_repo || return 1
  smoke_slice_handoff_execution_fixture_sentinel="$smoke_test_base/slice-handoff/.slice-handoff-execution-sentinel"
  printf 'keep\n' > "$smoke_slice_handoff_execution_fixture_sentinel" || return 1
  smoke_slice_handoff_execution_isolation_root="$(smoke_slice_handoff_owned_env_root "execution")" || return 1
  smoke_slice_handoff_execution_isolated_tmpdir="$smoke_slice_handoff_execution_isolation_root/tmpdir"
  smoke_slice_handoff_execution_isolated_home="$smoke_slice_handoff_execution_isolation_root/home"
  mkdir -p "$smoke_slice_handoff_execution_isolated_tmpdir" "$smoke_slice_handoff_execution_isolated_home" || return 1
  smoke_slice_handoff_expected_execution_repo_root="$smoke_test_dir"
  smoke_slice_handoff_expected_execution_planned_run_dir_root="$smoke_slice_handoff_execution_isolated_tmpdir/repo-automation/slice-handoff-runs"
  smoke_slice_handoff_expected_execution_none_preview="${smoke_slice_handoff_expected_none_preview//$smoke_slice_handoff_valid_none_out_dir/$smoke_slice_handoff_execution_none_out_dir}"
  smoke_slice_handoff_expected_execution_none_preview="${smoke_slice_handoff_expected_execution_none_preview//$smoke_slice_handoff_expected_dry_run_repo_root/$smoke_slice_handoff_expected_execution_repo_root}"
  smoke_slice_handoff_expected_execution_none_preview="${smoke_slice_handoff_expected_execution_none_preview//$smoke_slice_handoff_expected_planned_run_dir_root/$smoke_slice_handoff_expected_execution_planned_run_dir_root}"
  smoke_slice_handoff_expected_execution_submit_preview="${smoke_slice_handoff_expected_submit_preview//$smoke_slice_handoff_valid_submit_out_dir/$smoke_slice_handoff_execution_submit_out_dir}"
  smoke_slice_handoff_expected_execution_submit_preview="${smoke_slice_handoff_expected_execution_submit_preview//feature\/slice-handoff-submit/feature\/slice-handoff-pr-review}"
  smoke_slice_handoff_expected_execution_submit_preview="${smoke_slice_handoff_expected_execution_submit_preview//Slice handoff submit smoke/Slice handoff preset review smoke}"
  smoke_slice_handoff_expected_execution_submit_preview="${smoke_slice_handoff_expected_execution_submit_preview//$smoke_slice_handoff_expected_dry_run_repo_root/$smoke_slice_handoff_expected_execution_repo_root}"
  smoke_slice_handoff_expected_execution_submit_preview="${smoke_slice_handoff_expected_execution_submit_preview//$smoke_slice_handoff_expected_planned_run_dir_root/$smoke_slice_handoff_expected_execution_planned_run_dir_root}"
  smoke_slice_handoff_expected_execution_submit_summary="$(printf 'schema=repo-automation-slice-handoff/v1\nbranch=feature/slice-handoff-pr-review\ntitle=Slice handoff preset review smoke\ncodex_profile=review\nsubmit_mode=repo-flow-submit-all\ncommit_message=chore: slice-handoff smoke\ncodex_prompt_path=%s/codex-prompt.md\npr_body_path=%s/pr-body.md\nreview_request_path=%s/review-request.txt\nvalidation_manifest_path=%s/validation-manifest.json' "$smoke_slice_handoff_execution_submit_out_dir" "$smoke_slice_handoff_execution_submit_out_dir" "$smoke_slice_handoff_execution_submit_out_dir" "$smoke_slice_handoff_execution_submit_out_dir")"
  smoke_slice_handoff_expected_execution_quiet_preview="${smoke_slice_handoff_expected_quiet_preview//$smoke_slice_handoff_valid_quiet_out_dir/$smoke_slice_handoff_execution_quiet_out_dir}"
  smoke_slice_handoff_expected_execution_quiet_preview="${smoke_slice_handoff_expected_execution_quiet_preview//$smoke_slice_handoff_expected_dry_run_repo_root/$smoke_slice_handoff_expected_execution_repo_root}"
  smoke_slice_handoff_expected_execution_quiet_preview="${smoke_slice_handoff_expected_execution_quiet_preview//$smoke_slice_handoff_expected_planned_run_dir_root/$smoke_slice_handoff_expected_execution_planned_run_dir_root}"
  smoke_slice_handoff_expected_execution_explain_preview="${smoke_slice_handoff_expected_execution_submit_preview//$smoke_slice_handoff_execution_submit_out_dir/$smoke_slice_handoff_execution_explain_out_dir}"
  smoke_slice_handoff_expected_execution_explain_summary="$(printf 'schema=repo-automation-slice-handoff/v1\nbranch=feature/slice-handoff-pr-review\ntitle=Slice handoff preset review smoke\ncodex_profile=review\nsubmit_mode=repo-flow-submit-all\ncommit_message=chore: slice-handoff smoke\ncodex_prompt_path=%s/codex-prompt.md\npr_body_path=%s/pr-body.md\nreview_request_path=%s/review-request.txt\nvalidation_manifest_path=%s/validation-manifest.json' "$smoke_slice_handoff_execution_explain_out_dir" "$smoke_slice_handoff_execution_explain_out_dir" "$smoke_slice_handoff_execution_explain_out_dir" "$smoke_slice_handoff_execution_explain_out_dir")"
  smoke_slice_handoff_write_file "$smoke_slice_handoff_execution_valid_none_file" "feature/slice-handoff-smoke" "Slice handoff smoke" "default" "none" "" "$smoke_slice_handoff_valid_prompt" || return 1
  smoke_slice_handoff_write_file "$smoke_slice_handoff_execution_valid_submit_file" "feature/slice-handoff-submit" "Slice handoff submit smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$smoke_slice_handoff_submit_prompt" "$smoke_slice_handoff_submit_body" || return 1
  smoke_slice_handoff_write_file "$smoke_slice_handoff_execution_valid_preset_file" "feature/slice-handoff-pr-review" "Slice handoff preset review smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$smoke_slice_handoff_submit_prompt" "$smoke_slice_handoff_submit_body" "" "repo-automation-template-pr-review" || return 1
  smoke_slice_handoff_write_file "$smoke_slice_handoff_execution_invalid_submit_file" "feature/slice-handoff-submit" "Slice handoff submit smoke" "review" "repo-flow-submit-all" "chore: slice-handoff smoke" "$smoke_slice_handoff_submit_prompt" "$smoke_slice_handoff_submit_body" || return 1
  smoke_slice_handoff_execution_fake_codex_bin_dir="$smoke_slice_handoff_execution_artifact_root/fake-codex"
  smoke_slice_handoff_write_fake_codex "$smoke_slice_handoff_execution_fake_codex_bin_dir" || return 1
  smoke_slice_handoff_set_execution_codex_run_final_text 'fake final output' || return 1
  smoke_slice_handoff_execution_fake_codex_args_none_file="$smoke_slice_handoff_execution_artifact_root/fake-codex-none.args"
  smoke_slice_handoff_execution_fake_codex_args_submit_file="$smoke_slice_handoff_execution_artifact_root/fake-codex-submit.args"
  smoke_slice_handoff_execution_fake_codex_args_submit_blocker_file="$smoke_slice_handoff_execution_artifact_root/fake-codex-submit-blocker.args"
  smoke_slice_handoff_execution_fake_codex_args_submit_blocker_crlf_file="$smoke_slice_handoff_execution_artifact_root/fake-codex-submit-blocker-crlf.args"
  smoke_slice_handoff_execution_fake_codex_args_submit_missing_final_file="$smoke_slice_handoff_execution_artifact_root/fake-codex-submit-missing-final.args"
  smoke_slice_handoff_execution_fake_repo_flow_args_submit_file="$smoke_slice_handoff_execution_artifact_root/fake-repo-flow-submit.args"
  smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file="$smoke_slice_handoff_execution_artifact_root/fake-pr-body-check-submit.args"
  smoke_slice_handoff_install_fake_codex_run || return 1
  : \
    "$smoke_slice_handoff_check_root" \
    "$smoke_slice_handoff_valid_none_file" \
    "$smoke_slice_handoff_valid_submit_file" \
    "$smoke_slice_handoff_valid_none_out_dir" \
    "$smoke_slice_handoff_valid_submit_out_dir" \
    "$smoke_slice_handoff_valid_preset_out_dir" \
    "$smoke_slice_handoff_valid_quiet_out_dir" \
    "$smoke_slice_handoff_invalid_out_dir" \
    "$smoke_slice_handoff_execution_tmp_root" \
    "$smoke_slice_handoff_execution_artifact_root" \
    "$smoke_slice_handoff_execution_none_out_dir" \
    "$smoke_slice_handoff_execution_submit_out_dir" \
    "$smoke_slice_handoff_execution_quiet_out_dir" \
    "$smoke_slice_handoff_execution_explain_out_dir" \
    "$smoke_slice_handoff_valid_preset_file" \
    "$smoke_slice_handoff_invalid_prompt_conflict_file" \
    "$smoke_slice_handoff_invalid_prompt_id_file" \
    "$smoke_slice_handoff_missing_prompt_file" \
    "$smoke_slice_handoff_lifecycle_file" \
    "$smoke_slice_handoff_self_modifying_helper_file" \
    "$smoke_slice_handoff_helper_command_mention_file" \
    "$smoke_slice_handoff_top_level_fixture_baseline_file" \
    "$smoke_slice_handoff_top_level_fixture_after_file" \
    "$smoke_slice_handoff_valid_prompt" \
    "$smoke_slice_handoff_submit_prompt" \
    "$smoke_slice_handoff_invalid_submit_body" \
    "$smoke_slice_handoff_submit_body" \
    "$smoke_slice_handoff_explicit_review_request_text" \
    "$smoke_slice_handoff_expected_dry_run_repo_root" \
    "$smoke_slice_handoff_expected_planned_run_dir_root" \
    "$smoke_slice_handoff_expected_submit_repo_flow_url_or_stop" \
    "$smoke_slice_handoff_expected_submit_repo_flow_pr" \
    "$smoke_slice_handoff_expected_submit_commit_sha" \
    "$smoke_slice_handoff_expected_submit_watched" \
    "$smoke_slice_handoff_expected_submit_ci_state" \
    "$smoke_slice_handoff_expected_default_review_request" \
    "$smoke_slice_handoff_expected_submit_default_review_request" \
    "$smoke_slice_handoff_expected_none_prompt" \
    "$smoke_slice_handoff_expected_submit_prompt" \
    "$smoke_slice_handoff_expected_none_preview" \
    "$smoke_slice_handoff_expected_submit_noauth_preview" \
    "$smoke_slice_handoff_expected_submit_preview" \
    "$smoke_slice_handoff_expected_quiet_preview" \
    "$smoke_slice_handoff_expected_preset_preview" \
    "$smoke_slice_handoff_expected_none_review_stdout" \
    "$smoke_slice_handoff_expected_explicit_review_stdout" \
    "$smoke_slice_handoff_expected_submit_review_request_rendered" \
    "$smoke_slice_handoff_expected_preset_review_request" \
    "$smoke_slice_handoff_expected_none_stdout" \
    "$smoke_slice_handoff_expected_submit_stdout_value" \
    "$smoke_slice_handoff_expected_preset_stdout" \
    "$smoke_slice_handoff_expected_none_summary" \
    "$smoke_slice_handoff_expected_quiet_summary" \
    "$smoke_slice_handoff_expected_submit_summary" \
    "$smoke_slice_handoff_expected_submit_noauth_summary" \
    "$smoke_slice_handoff_expected_execution_none_summary" \
    "$smoke_slice_handoff_expected_execution_quiet_summary" \
    "$smoke_slice_handoff_expected_execution_review_request_head" \
    "$smoke_slice_handoff_expected_execution_submit_summary" \
    "$smoke_slice_handoff_expected_execution_explain_preview" \
    "$smoke_slice_handoff_expected_execution_explain_summary" \
    "$smoke_slice_handoff_execution_fake_codex_bin_dir" \
    "$smoke_slice_handoff_execution_fake_codex_run_final_text_file" \
    "$FAKE_CODEX_RUN_FINAL_TEXT_FILE" \
    "$smoke_slice_handoff_execution_fake_codex_args_none_file" \
    "$smoke_slice_handoff_execution_fake_codex_args_submit_file" \
    "$smoke_slice_handoff_execution_fake_codex_args_submit_blocker_file" \
    "$smoke_slice_handoff_execution_fake_codex_args_submit_blocker_crlf_file" \
    "$smoke_slice_handoff_execution_fake_codex_args_submit_missing_final_file" \
    "$smoke_slice_handoff_execution_fake_repo_flow_args_submit_file" \
    "$smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file"
}

smoke_slice_handoff_prepare_execution_submit_context() {
  local scenario_slug="$1"

  smoke_slice_handoff_execution_submit_out_dir="$smoke_slice_handoff_execution_artifact_root/out-execution-$scenario_slug"
  smoke_slice_handoff_execution_fake_codex_args_submit_file="$smoke_slice_handoff_execution_artifact_root/fake-codex-submit-$scenario_slug.args"
  smoke_slice_handoff_execution_fake_codex_args_submit_blocker_file="$smoke_slice_handoff_execution_artifact_root/fake-codex-submit-blocker-$scenario_slug.args"
  smoke_slice_handoff_execution_fake_codex_args_submit_blocker_crlf_file="$smoke_slice_handoff_execution_artifact_root/fake-codex-submit-blocker-crlf-$scenario_slug.args"
  smoke_slice_handoff_execution_fake_codex_args_submit_missing_final_file="$smoke_slice_handoff_execution_artifact_root/fake-codex-submit-missing-final-$scenario_slug.args"
  smoke_slice_handoff_execution_fake_repo_flow_args_submit_file="$smoke_slice_handoff_execution_artifact_root/fake-repo-flow-submit-$scenario_slug.args"
  smoke_slice_handoff_execution_fake_pr_body_check_args_submit_file="$smoke_slice_handoff_execution_artifact_root/fake-pr-body-check-submit-$scenario_slug.args"
  smoke_slice_handoff_execution_fake_codex_run_final_text_file="$smoke_slice_handoff_execution_artifact_root/fake-codex-run-final-$scenario_slug.txt"
  FAKE_CODEX_RUN_FINAL_TEXT_FILE="$smoke_slice_handoff_execution_fake_codex_run_final_text_file"

  smoke_slice_handoff_expected_execution_submit_preview="${smoke_slice_handoff_expected_submit_preview//$smoke_slice_handoff_valid_submit_out_dir/$smoke_slice_handoff_execution_submit_out_dir}"
  smoke_slice_handoff_expected_execution_submit_preview="${smoke_slice_handoff_expected_execution_submit_preview//feature\/slice-handoff-submit/feature\/slice-handoff-pr-review}"
  smoke_slice_handoff_expected_execution_submit_preview="${smoke_slice_handoff_expected_execution_submit_preview//Slice handoff submit smoke/Slice handoff preset review smoke}"
  smoke_slice_handoff_expected_execution_submit_preview="${smoke_slice_handoff_expected_execution_submit_preview//$smoke_slice_handoff_expected_dry_run_repo_root/$smoke_slice_handoff_expected_execution_repo_root}"
  smoke_slice_handoff_expected_execution_submit_preview="${smoke_slice_handoff_expected_execution_submit_preview//$smoke_slice_handoff_expected_planned_run_dir_root/$smoke_slice_handoff_expected_execution_planned_run_dir_root}"
  smoke_slice_handoff_expected_execution_submit_summary="$(printf 'schema=repo-automation-slice-handoff/v1\nbranch=feature/slice-handoff-pr-review\ntitle=Slice handoff preset review smoke\ncodex_profile=review\nsubmit_mode=repo-flow-submit-all\ncommit_message=chore: slice-handoff smoke\ncodex_prompt_path=%s/codex-prompt.md\npr_body_path=%s/pr-body.md\nreview_request_path=%s/review-request.txt\nvalidation_manifest_path=%s/validation-manifest.json' "$smoke_slice_handoff_execution_submit_out_dir" "$smoke_slice_handoff_execution_submit_out_dir" "$smoke_slice_handoff_execution_submit_out_dir" "$smoke_slice_handoff_execution_submit_out_dir")"
  smoke_slice_handoff_expected_execution_explain_preview="${smoke_slice_handoff_expected_execution_submit_preview//$smoke_slice_handoff_execution_submit_out_dir/$smoke_slice_handoff_execution_explain_out_dir}"
  smoke_slice_handoff_expected_execution_explain_summary="$(printf 'schema=repo-automation-slice-handoff/v1\nbranch=feature/slice-handoff-pr-review\ntitle=Slice handoff preset review smoke\ncodex_profile=review\nsubmit_mode=repo-flow-submit-all\ncommit_message=chore: slice-handoff smoke\ncodex_prompt_path=%s/codex-prompt.md\npr_body_path=%s/pr-body.md\nreview_request_path=%s/review-request.txt\nvalidation_manifest_path=%s/validation-manifest.json' "$smoke_slice_handoff_execution_explain_out_dir" "$smoke_slice_handoff_execution_explain_out_dir" "$smoke_slice_handoff_execution_explain_out_dir" "$smoke_slice_handoff_execution_explain_out_dir")"
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
  local expected_mode="${4:-execution-codex-run}"
  local expected_next="${5:-repo-flow submit not implemented in this slice}"
  local expected_repo_flow_url_or_stop="${6:-}"
  local run_dir=""
  local filtered_stderr_file=""

  filtered_stderr_file="$(mktemp "${TMPDIR:-$HOME/.cache}/slice-handoff-execution-stderr.XXXXXX")" || return 1
  grep -v '^[+]' "$stderr_file" > "$filtered_stderr_file" 2>/dev/null || true
  if [ -s "$filtered_stderr_file" ]; then
    rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true
    return 1
  fi
  rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true

  if [ "$expected_mode" = "execution-submit" ]; then
    :
  fi
  grep -Fxq 'pass' "$stdout_file" || return 1
  grep -Fxq "mode=$expected_mode" "$stdout_file" || return 1
  grep -Fxq "branch=$expected_branch" "$stdout_file" || return 1
  grep -Eq '^run_dir=.+' "$stdout_file" || return 1
  grep -Fxq 'preflight_status=pass' "$stdout_file" || return 1
  grep -Fxq 'codex_status=pass' "$stdout_file" || return 1
  grep -Eq '^codex_final_output_path=.+' "$stdout_file" || return 1
  if [ "$expected_mode" = "execution-submit" ]; then
    grep -Fxq 'submit_status=pass' "$stdout_file" || return 1
    if [ -n "$expected_repo_flow_url_or_stop" ]; then
      grep -Fxq "repo_flow_url_or_stop=$expected_repo_flow_url_or_stop" "$stdout_file" || return 1
    fi
  fi
  grep -Fxq "next=$expected_next" "$stdout_file" || return 1

  run_dir="$(smoke_slice_handoff_extract_field "$stdout_file" run_dir)"
  [ -n "$run_dir" ] || return 1
  if [ "$expected_mode" = "execution-submit" ]; then
    grep -Fxq "review_request_path=$run_dir/review-request.txt" "$stdout_file" || return 1
  fi
  printf '%s\n' "$run_dir"
}

smoke_slice_handoff_assert_execution_submit_success_boundary() {
  local stdout_file="$1"
  local stderr_file="$2"
  local expected_branch="$3"
  local expected_repo_flow_url_or_stop="${4:-}"
  local run_dir=""

  run_dir="$(smoke_slice_handoff_assert_execution_stdout "$stdout_file" "$stderr_file" "$expected_branch" "execution-submit" "review PR before merge" "$expected_repo_flow_url_or_stop")" || return 1
  printf '%s\n' "$run_dir"
}

smoke_slice_handoff_assert_execution_blocker_summary() {
  local stderr_file="$1"
  local expected_mode="$2"
  local expected_branch="$3"
  local expected_run_dir="$4"
  local expected_codex_final_output_path="$5"

  grep -Fxq '===== FINAL SUMMARY =====' "$stderr_file" || return 1
  grep -Fxq 'script=slice-handoff' "$stderr_file" || return 1
  grep -Fxq "mode=$expected_mode" "$stderr_file" || return 1
  grep -Fxq 'rc=1' "$stderr_file" || return 1
  grep -Fxq 'step=codex-final-contract' "$stderr_file" || return 1
  grep -Fxq "branch=$expected_branch" "$stderr_file" || return 1
  grep -Fxq "run_dir=$expected_run_dir" "$stderr_file" || return 1
  grep -Fxq "codex_final_output_path=$expected_codex_final_output_path" "$stderr_file" || return 1
  grep -Fxq '===== CODEX FINAL OUTPUT =====' "$stderr_file" || return 1
  grep -Fxq '===== END CODEX FINAL OUTPUT =====' "$stderr_file" || return 1
  grep -Fxq 'pr_body_check=not_run' "$stderr_file" || return 1
  grep -Fxq 'repo_flow_submit=not_run' "$stderr_file" || return 1
  grep -Fxq 'review_request_printed=false' "$stderr_file" || return 1
  grep -Fxq 'next=paste blocker into ChatGPT' "$stderr_file" || return 1
  grep -Fxq '===== END =====' "$stderr_file" || return 1
  ! grep -Fq '===== PR REVIEW REQUEST =====' "$stderr_file" || return 1
}

smoke_slice_handoff_assert_execution_submit_blocker_boundary() {
  local stderr_file="$1"
  local expected_branch="$2"
  local expected_run_dir="$3"
  local expected_codex_final_output_path="$4"

  smoke_slice_handoff_assert_execution_blocker_summary "$stderr_file" "execution-submit" "$expected_branch" "$expected_run_dir" "$expected_codex_final_output_path" || return 1
  ! grep -Fq 'INFO: slice-handoff PR-body validation' "$stderr_file" || return 1
  ! grep -Fq 'INFO: slice-handoff repo-flow submit' "$stderr_file" || return 1
  [ ! -e "$expected_run_dir/pr-body-check.stdout" ] || return 1
  [ ! -e "$expected_run_dir/pr-body-check.stderr" ] || return 1
  [ ! -e "$expected_run_dir/repo-flow-submit.stdout" ] || return 1
  [ ! -e "$expected_run_dir/repo-flow-submit.stderr" ] || return 1
}

smoke_slice_handoff_assert_no_repo_root_out_dir() {
  local out_dir="$smoke_repo_root/slice-handoff-out-inside-repo"

  if [ -e "$out_dir" ]; then
    printf 'fail: unexpected slice-handoff out-dir leaked into repo root: %s\n' "$out_dir" >&2
    printf 'fix: keep slice-handoff out-dir fixtures under smoke temp paths\n' >&2
    return 1
  fi
}

smoke_slice_handoff_assert_codex_final_output_is_blocker() {
  local path="$1"

  python3 - "$path" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
try:
    text = path.read_text(encoding='utf-8')
except OSError:
    raise SystemExit(1)

if not text.strip():
    raise SystemExit(1)

for line in text.splitlines():
    candidate = line.strip(' \t\r')
    if not candidate:
        continue
    raise SystemExit(0 if candidate == 'blocker' else 1)

raise SystemExit(1)
PY
}

smoke_slice_handoff_assert_stderr_effectively_empty() {
  local stderr_file="$1"
  local filtered_stderr_file=""

  filtered_stderr_file="$(mktemp "${TMPDIR:-$HOME/.cache}/slice-handoff-empty-stderr.XXXXXX")" || return 1
  grep -v '^[+]' "$stderr_file" > "$filtered_stderr_file" 2>/dev/null || true
  if [ ! -s "$filtered_stderr_file" ]; then
    rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true
    return 0
  fi
  rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true
  return 1
}

smoke_slice_handoff_assert_execution_success_summary() {
  local stderr_file="$1"
  local expected_mode="$2"
  local expected_branch="$3"
  local expected_run_dir="$4"
  local expected_review_request_path="$5"
  local expected_pr="$6"
  local expected_commit="$7"
  local expected_watched="$8"
  local expected_ci="$9"
  local expected_url_or_stop="${10}"
  local expected_review_request_printed="${11}"
  local expected_next="${12}"

  grep -Fxq '===== FINAL SUMMARY =====' "$stderr_file" || return 1
  grep -Fxq 'script=slice-handoff' "$stderr_file" || return 1
  grep -Fxq "mode=$expected_mode" "$stderr_file" || return 1
  grep -Fxq 'rc=0' "$stderr_file" || return 1
  grep -Fxq "branch=$expected_branch" "$stderr_file" || return 1
  grep -Fxq "run_dir=$expected_run_dir" "$stderr_file" || return 1
  grep -Fxq "review_request_path=$expected_review_request_path" "$stderr_file" || return 1
  grep -Fxq "pr=$expected_pr" "$stderr_file" || return 1
  grep -Fxq "commit=$expected_commit" "$stderr_file" || return 1
  grep -Fxq "watched=$expected_watched" "$stderr_file" || return 1
  grep -Fxq "ci=$expected_ci" "$stderr_file" || return 1
  grep -Fxq "url_or_stop=$expected_url_or_stop" "$stderr_file" || return 1
  grep -Fxq 'review_request_valid=true' "$stderr_file" || return 1
  grep -Fxq "review_request_printed=$expected_review_request_printed" "$stderr_file" || return 1
  grep -Fxq "next=$expected_next" "$stderr_file" || return 1
  grep -Fxq '===== END =====' "$stderr_file" || return 1
}

smoke_slice_handoff_assert_review_request_block() {
  local stderr_file="$1"
  local expected_review_request_file="$2"
  local filtered_stderr_file=""

  filtered_stderr_file="$(mktemp "${TMPDIR:-$HOME/.cache}/slice-handoff-review-request.XXXXXX")" || return 1
  grep -v '^[+]' "$stderr_file" > "$filtered_stderr_file" 2>/dev/null || true

  if ! python3 - "$filtered_stderr_file" "$expected_review_request_file" <<'PY'
from pathlib import Path
import sys

stderr_lines = Path(sys.argv[1]).read_text(encoding='utf-8').splitlines()
expected_lines = Path(sys.argv[2]).read_text(encoding='utf-8').splitlines()

try:
    end_index = stderr_lines.index('===== END =====')
    start_index = stderr_lines.index('===== PR REVIEW REQUEST =====')
except ValueError:
    raise SystemExit(1)

if start_index != end_index + 2:
    raise SystemExit(1)
if stderr_lines[-1] != '===== END PR REVIEW REQUEST =====':
    raise SystemExit(1)
if stderr_lines[start_index + 1:-1] != expected_lines:
    raise SystemExit(1)
PY
  then
    rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true
    return 1
  fi
  rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true
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
  local expected_execution_mode="${9:-execution-codex-run}"
  local expected_next="${10:-repo-flow submit not implemented in this slice}"
  local expected_repo_flow_url_or_stop="${11:-}"

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
    validation-manifest.json \
    codex-prompt.md \
    review-request.txt \
    codex-run/codex-final.txt \
    codex-run/codex-run-summary.txt
  do
    [ -f "$run_dir/$path" ] || return 1
  done
  if [ "$expected_execution_mode" = "execution-submit" ]; then
    for path in \
      pr-body-check.stdout \
      pr-body-check.stderr \
      review-request-source.txt \
      repo-flow-submit.stdout \
      repo-flow-submit.stderr
    do
      [ -f "$run_dir/$path" ] || return 1
    done
  fi
  [ ! -s "$run_dir/codex-run.stderr" ] || return 1
  grep -Fxq 'pass' "$run_dir/codex-run.stdout" || return 1
  grep -Eq '^final_output_path=.+' "$run_dir/codex-run.stdout" || return 1
  grep -Eq '^summary_path=.+' "$run_dir/codex-run.stdout" || return 1
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
  if [ "$expected_execution_mode" = "execution-submit" ]; then
    grep -Fxq 'pass' "$run_dir/pr-body-check.stdout" || return 1
    [ ! -s "$run_dir/pr-body-check.stderr" ] || return 1
    grep -Fxq '===== FINAL SUMMARY =====' "$run_dir/repo-flow-submit.stderr" || return 1
    grep -Eq '^url_or_stop=https://github.com/i-schuyler/repo-automation-template/pull/[0-9]+$' "$run_dir/repo-flow-submit.stderr" || return 1
  fi

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
  grep -Fxq "validation_manifest_path=$run_dir/validation-manifest.json" "$run_dir/slice-handoff-summary.txt" || return 1
  if [ "$submit_mode" = "repo-flow-submit-all" ]; then
    grep -Fxq "pr_body_path=$run_dir/pr-body.md" "$run_dir/slice-handoff-summary.txt" || return 1
  else
    grep -Fxq "pr_body_path=" "$run_dir/slice-handoff-summary.txt" || return 1
  fi
  grep -Fxq "schema=repo-automation-slice-handoff-execution/v1" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  grep -Fxq "mode=$expected_execution_mode" "$run_dir/slice-handoff-execution-summary.txt" || return 1
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
  grep -Fxq "validation_manifest_path=$run_dir/validation-manifest.json" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  grep -Fxq "result=pass" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  if [ "$expected_execution_mode" = "execution-submit" ]; then
    grep -Fxq "pr_body_check_stdout_path=$run_dir/pr-body-check.stdout" "$run_dir/slice-handoff-execution-summary.txt" || return 1
    grep -Fxq "pr_body_check_stderr_path=$run_dir/pr-body-check.stderr" "$run_dir/slice-handoff-execution-summary.txt" || return 1
    grep -Fxq "repo_flow_submit_stdout_path=$run_dir/repo-flow-submit.stdout" "$run_dir/slice-handoff-execution-summary.txt" || return 1
    grep -Fxq "repo_flow_submit_stderr_path=$run_dir/repo-flow-submit.stderr" "$run_dir/slice-handoff-execution-summary.txt" || return 1
    grep -Fxq "next=$expected_next" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  else
    grep -Fxq "next=$expected_next" "$run_dir/slice-handoff-execution-summary.txt" || return 1
  fi
  return 0
}

smoke_slice_handoff_latest_run_dir() {
  python3 - "$@" <<'PY'
from pathlib import Path
import os
import sys

args = sys.argv[1:]
if args:
    root = Path(args[0])
    context = args[1] if len(args) > 1 else 'slice-handoff'
else:
    root = Path(os.environ.get('TMPDIR', str(Path.home() / '.cache'))) / 'repo-automation' / 'slice-handoff-runs'
    context = 'slice-handoff'
if not root.is_dir():
    print(f'fail: {context} run dir root missing: {root}', file=sys.stderr)
    print(f'fix: ensure slice-handoff creates the run-dir root before returning from {context}', file=sys.stderr)
    raise SystemExit(1)
dirs = [path for path in root.iterdir() if path.is_dir()]
if not dirs:
    print(f'fail: {context} run dir missing: {root}', file=sys.stderr)
    print(f'fix: ensure slice-handoff creates a run directory before returning from {context}', file=sys.stderr)
    raise SystemExit(1)
dirs.sort(key=lambda path: path.stat().st_mtime, reverse=True)
print(dirs[0])
PY
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
    # shellcheck disable=SC2031
    capture_stdout_tmp="$(mktemp "${TMPDIR:-$HOME/.cache}/slice-handoff-stdout.XXXXXX")" || return 1
    # shellcheck disable=SC2031
    capture_stderr_tmp="$(mktemp "${TMPDIR:-$HOME/.cache}/slice-handoff-stderr.XXXXXX")" || {
      rm -f -- "$capture_stdout_tmp" >/dev/null 2>&1 || true
      return 1
    }
    capture_stdout="$capture_stdout_tmp"
    capture_stderr="$capture_stderr_tmp"
    (
      cd "$smoke_test_dir" || return 1
      if [ "${FAKE_CODEX_RUN_HELPER:-0}" = 1 ]; then
        smoke_slice_handoff_install_fake_codex_run || return 1
      fi
      PATH="$PATH" TMPDIR="${TMPDIR:-}" HOME="${HOME:-}" "$script_path" "$@"
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

smoke_slice_handoff_expect_validator_failure() {
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

  if smoke_slice_handoff_assert_validator_failure_shape "$stderr_file" "$reason" "$fix"; then
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
  local filtered_stderr_file=""

  shift 3
  if smoke_slice_handoff_run "$stdout_file" "$stderr_file" "$@"; then
    filtered_stderr_file="$(mktemp "${TMPDIR:-$HOME/.cache}/slice-handoff-expected-success.XXXXXX")" || return 1
    grep -v '^[+]' "$stderr_file" > "$filtered_stderr_file" 2>/dev/null || true
    if [ "$(cat "$stdout_file" 2>/dev/null || true)" = "$expected_stdout" ] && [ "$(cat "$filtered_stderr_file" 2>/dev/null || true)" = "$expected_stderr" ]; then
      rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true
      test_pass "$label"
      return 0
    fi
    rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true
  fi

  test_fail "$label"
  return 1
}

# repo-automation/tests/lib/contracts/slice-handoff.sh EOF
