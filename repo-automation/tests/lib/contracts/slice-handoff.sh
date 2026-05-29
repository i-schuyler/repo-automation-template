# repo-automation/tests/lib/contracts/slice-handoff.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.

smoke_slice_handoff_script() {
  printf '%s/repo-automation/bin/slice-handoff' "$smoke_repo_root"
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

smoke_slice_handoff_run() {
  local stdout_file="$1"
  local stderr_file="$2"

  shift 2
  "$(smoke_slice_handoff_script)" "$@" >"$stdout_file" 2>"$stderr_file"
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
