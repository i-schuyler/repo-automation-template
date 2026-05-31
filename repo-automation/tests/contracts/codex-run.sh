#!/usr/bin/env bash
# repo-automation/tests/contracts/codex-run.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are initialized by
# smoke-common before the focused contract body runs.

codex_run_contract_write_fake_codex() {
  local fake_bin_dir="$1"

  mkdir -p "$fake_bin_dir" || return 1
  cat > "$fake_bin_dir/codex" <<'EOF'
#!/usr/bin/env bash
set -u

log_file="${FAKE_CODEX_LOG_FILE:-}"
stdin_file="${FAKE_CODEX_STDIN_FILE:-}"
args_file="${FAKE_CODEX_ARGS_FILE:-}"
exit_code="${FAKE_CODEX_EXIT_CODE:-0}"
final_text="${FAKE_CODEX_FINAL_TEXT:-fake final output}"
stdout_text="${FAKE_CODEX_STDOUT_TEXT:-}"
stderr_text="${FAKE_CODEX_STDERR_TEXT:-}"
write_final="${FAKE_CODEX_WRITE_FINAL:-1}"
write_empty_final="${FAKE_CODEX_WRITE_EMPTY_FINAL:-0}"
capture_stdin="${FAKE_CODEX_CAPTURE_STDIN:-1}"
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

if [ "$capture_stdin" -eq 1 ] 2>/dev/null && [ -n "$stdin_file" ]; then
  cat > "$stdin_file"
else
  cat >/dev/null
fi

if [ -n "$output_last_message" ] && [ "$write_final" -eq 1 ] 2>/dev/null; then
  if [ "$write_empty_final" -eq 1 ] 2>/dev/null; then
    : > "$output_last_message"
  else
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

codex_run_contract_assert_text() {
  local path="$1"
  local expected="$2"

  [ "$(cat "$path" 2>/dev/null || true)" = "$expected" ]
}

codex_run_contract_assert_file_exists() {
  local path="$1"
  [ -f "$path" ]
}

codex_run_contract_assert_empty() {
  local path="$1"
  [ ! -s "$path" ]
}

codex_run_contract_assert_grep() {
  local needle="$1"
  local path="$2"

  grep -Fq -- "$needle" "$path"
}

codex_run_contract_main_impl() {
  # shellcheck disable=SC2154
  local status=0
  local repo_root=""
  local expected_default_stdout=""
  local expected_default_summary=""
  local expected_explain_summary=""

  smoke_setup_temp_repo || return 1
  # shellcheck disable=SC2154
  cd "$smoke_test_dir" || return 1
  repo_root="$smoke_test_dir"
  # shellcheck disable=SC2154
  contract_root="$smoke_test_base/codex-run-contract"
  fake_bin_dir="$contract_root/fake-bin"
  prompt_file="$contract_root/prompt.txt"
  empty_prompt_file="$contract_root/empty-prompt.txt"
  missing_prompt_file="$contract_root/missing-prompt.txt"
  invalid_profile_prompt="$contract_root/invalid-profile-prompt.txt"
  stdin_log="$contract_root/codex.stdin"
  args_log="$contract_root/codex.args"
  codex_log="$contract_root/codex.log"
  default_out_dir="$smoke_test_base/codex-run-default"
  explain_out_dir="$smoke_test_base/codex-run-explain"
  quiet_out_dir="$smoke_test_base/codex-run-quiet"
  child_fail_out_dir="$smoke_test_base/codex-run-child-fail"
  missing_final_out_dir="$smoke_test_base/codex-run-missing-final"
  empty_final_out_dir="$smoke_test_base/codex-run-empty-final"
  stdout_file="$contract_root/stdout"
  stderr_file="$contract_root/stderr"

  mkdir -p "$contract_root" || return 1

  codex_run_contract_write_fake_codex "$fake_bin_dir" || return 1
  hash -r || return 1

  printf 'run codex-run smoke prompt\n' > "$prompt_file"
  : > "$empty_prompt_file"
  printf 'prompt for invalid profile\n' > "$invalid_profile_prompt"

  expected_default_stdout="$(printf 'pass\nfinal_output_path=%s/codex-run-default/codex-final.txt\nsummary_path=%s/codex-run-default/codex-run-summary.txt' "$smoke_test_base" "$smoke_test_base")"
  expected_default_summary="$(printf 'script=codex-run\nresult=pass\nexit_code=0\nprompt_file=%s\nout_dir=%s/codex-run-default\ncd=%s\nprofile=default\nsandbox=workspace-write\ntimeout=0\ntimeout_enforced=not_enforced\ncodex_path=%s/codex\nstdout_path=%s/codex.stdout\nstderr_path=%s/codex.stderr\nfinal_output_path=%s/codex-run-default/codex-final.txt\nfinal_output_status=present' "$prompt_file" "$smoke_test_base" "$repo_root" "$fake_bin_dir" "$smoke_test_base/codex-run-default" "$smoke_test_base/codex-run-default" "$smoke_test_base")"
  expected_explain_summary="$(cat <<EOF
script=codex-run
mode=run
rc=0
profile=default
sandbox=workspace-write
final_output=$smoke_test_base/codex-run-explain/codex-final.txt
summary=$smoke_test_base/codex-run-explain/codex-run-summary.txt
status=pass
EOF
)"

  if (
    rm -rf -- "$default_out_dir" &&
      mkdir -p "$default_out_dir" &&
      FAKE_CODEX_STDOUT_TEXT='stdout from fake codex' \
      FAKE_CODEX_STDERR_TEXT='stderr from fake codex' \
      FAKE_CODEX_FINAL_TEXT='fake final output' \
      FAKE_CODEX_LOG_FILE="$codex_log" \
      FAKE_CODEX_STDIN_FILE="$stdin_log" \
      FAKE_CODEX_ARGS_FILE="$args_log" \
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$default_out_dir" >"$stdout_file" 2>"$stderr_file" &&
      codex_run_contract_assert_text "$stdout_file" "$expected_default_stdout" &&
      codex_run_contract_assert_empty "$stderr_file" &&
      codex_run_contract_assert_text "$default_out_dir/codex-final.txt" 'fake final output' &&
      codex_run_contract_assert_text "$default_out_dir/codex.stdout" 'stdout from fake codex' &&
      codex_run_contract_assert_text "$default_out_dir/codex.stderr" 'stderr from fake codex' &&
      codex_run_contract_assert_text "$default_out_dir/codex-run-summary.txt" "$expected_default_summary" &&
      codex_run_contract_assert_text "$stdin_log" 'run codex-run smoke prompt' &&
      codex_run_contract_assert_text "$args_log" "$(cat <<EOF
exec
--cd
$repo_root
--sandbox
workspace-write
--output-last-message
$default_out_dir/codex-final.txt
-
EOF
)"
  ); then
    :
  else
    test_fail "default-success"
    status=1
  fi

  if (
    rm -rf -- "$quiet_out_dir" &&
      mkdir -p "$quiet_out_dir" &&
      # --quiet quiet success
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$quiet_out_dir" --quiet >"$stdout_file" 2>"$stderr_file" &&
      codex_run_contract_assert_empty "$stdout_file" &&
      codex_run_contract_assert_empty "$stderr_file"
  ); then
    :
  else
    test_fail "quiet-success"
    status=1
  fi

  if (
    rm -rf -- "$explain_out_dir" &&
      mkdir -p "$explain_out_dir" &&
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$explain_out_dir" --explain >"$stdout_file" 2>"$stderr_file" &&
      codex_run_contract_assert_grep 'INFO: codex-run profile=default sandbox=workspace-write timeout=0' "$stdout_file" &&
      codex_run_contract_assert_grep '===== FINAL SUMMARY =====' "$stdout_file" &&
      codex_run_contract_assert_grep 'status=pass' "$stdout_file" &&
      codex_run_contract_assert_text <(smoke_extract_final_summary_block "$stdout_file") "$expected_explain_summary"
  ); then
    :
  else
    test_fail "explain-summary"
    status=1
  fi

  if (
    rm -rf -- "$contract_root/missing" &&
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$missing_prompt_file" --out-dir="$default_out_dir" >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "missing-prompt"
    status=1
  else
    codex_run_contract_assert_grep 'prompt file does not exist:' "$stderr_file" || { test_fail "missing-prompt"; status=1; }
  fi

  if (
    PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$empty_prompt_file" --out-dir="$default_out_dir" >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "empty-prompt"
    status=1
  else
    codex_run_contract_assert_grep 'prompt file is empty:' "$stderr_file" || { test_fail "empty-prompt"; status=1; }
  fi

  if (
    PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$default_out_dir" --profile='bad profile' >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "invalid-profile"
    status=1
  else
    codex_run_contract_assert_grep 'invalid profile: bad profile' "$stderr_file" || { test_fail "invalid-profile"; status=1; }
  fi

  if (
    FAKE_CODEX_EXIT_CODE=17 \
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$child_fail_out_dir" >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "child-failure"
    status=1
  else
    if codex_run_contract_assert_grep 'fail: codex-run failed' "$stderr_file" &&
      codex_run_contract_assert_grep 'step: codex' "$stderr_file" &&
      codex_run_contract_assert_grep 'exit_code: 17' "$stderr_file" &&
      codex_run_contract_assert_grep 'fix: paste this blocker into ChatGPT' "$stderr_file"; then
      :
    else
      test_fail "child-failure"
      status=1
    fi
  fi

  if (
    FAKE_CODEX_WRITE_FINAL=0 \
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$missing_final_out_dir" >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "missing-final-output"
    status=1
  else
    if codex_run_contract_assert_grep 'step: final-output-contract' "$stderr_file" &&
      codex_run_contract_assert_grep 'codex exec exited 0 but final output file is missing or empty' "$stderr_file"; then
      :
    else
      test_fail "missing-final-output"
      status=1
    fi
  fi

  if (
    FAKE_CODEX_WRITE_EMPTY_FINAL=1 \
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$empty_final_out_dir" >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "empty-final-output"
    status=1
  else
    if codex_run_contract_assert_grep 'step: final-output-contract' "$stderr_file" &&
      codex_run_contract_assert_grep 'codex exec exited 0 but final output file is missing or empty' "$stderr_file"; then
      :
    else
      test_fail "empty-final-output"
      status=1
    fi
  fi

  return "$status"
}

codex_run_contract_main() {
  smoke_run_focused_contract_wrapper codex_run_contract_main_impl "$@"
}

codex_run_contract_main "$@"
# repo-automation/tests/contracts/codex-run.sh EOF
