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
cwd_file="${FAKE_CODEX_CWD_FILE:-}"
exit_code="${FAKE_CODEX_EXIT_CODE:-0}"
final_text="${FAKE_CODEX_FINAL_TEXT:-fake final output}"
stdout_text="${FAKE_CODEX_STDOUT_TEXT:-}"
stderr_text="${FAKE_CODEX_STDERR_TEXT:-}"
write_final="${FAKE_CODEX_WRITE_FINAL:-1}"
write_empty_final="${FAKE_CODEX_WRITE_EMPTY_FINAL:-0}"
final_chmod="${FAKE_CODEX_FINAL_CHMOD:-}"
capture_stdin="${FAKE_CODEX_CAPTURE_STDIN:-1}"
output_last_message=""
prev=""
mode=""
is_resume=0

if [ -n "$args_file" ]; then
  printf '%s\n' "$@" > "$args_file"
fi

for arg in "$@"; do
  if [ -n "$prev" ]; then
    case "$prev" in
      --output-last-message)
        if [ "$is_resume" -eq 1 ] 2>/dev/null; then
          printf "error: unexpected argument '%s' found\n" "$prev" >&2
          exit 2
        fi
        output_last_message="$arg"
        ;;
    esac
    prev=""
    continue
  fi
  case "$arg" in
    exec)
      mode="exec"
      ;;
    resume)
      if [ "$mode" = "exec" ]; then
        is_resume=1
      fi
      ;;
    --output-last-message)
      prev="$arg"
      ;;
    --cd|--sandbox|--profile|--model|-c|-C|--output-last-message)
      if [ "$is_resume" -eq 1 ] 2>/dev/null; then
        printf "error: unexpected argument '%s' found\n" "$arg" >&2
        exit 2
      fi
      ;;
  esac
done

if [ -n "$cwd_file" ]; then
  pwd > "$cwd_file"
fi

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
  if [ -n "$final_chmod" ]; then
    chmod "$final_chmod" "$output_last_message"
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

codex_run_contract_assert_not_exists() {
  local path="$1"
  [ ! -e "$path" ]
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
  local resume_out_dir=""
  local invalid_resume_out_dir=""
  local expected_resume_summary=""

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
  cwd_log="$contract_root/codex.cwd"
  codex_log="$contract_root/codex.log"
  default_out_dir="$smoke_test_base/codex-run-default"
  explain_out_dir="$smoke_test_base/codex-run-explain"
  quiet_out_dir="$smoke_test_base/codex-run-quiet"
  resume_out_dir="$smoke_test_base/codex-run-resume"
  resume_custom_out_dir="$smoke_test_base/codex-run-resume-custom"
  resume_custom_cd_dir="$contract_root/resume-cd"
  model_out_dir="$smoke_test_base/codex-run-model"
  reasoning_out_dir="$smoke_test_base/codex-run-reasoning"
  model_reasoning_out_dir="$smoke_test_base/codex-run-model-reasoning"
  invalid_resume_out_dir="$smoke_test_base/codex-run-invalid-resume"
  invalid_model_out_dir="$smoke_test_base/codex-run-invalid-model"
  invalid_reasoning_out_dir="$smoke_test_base/codex-run-invalid-reasoning"
  child_fail_out_dir="$smoke_test_base/codex-run-child-fail"
  missing_final_out_dir="$smoke_test_base/codex-run-missing-final"
  empty_final_out_dir="$smoke_test_base/codex-run-empty-final"
  conflict_out_dir="$smoke_test_base/codex-run-conflict"
  json_out_dir="$smoke_test_base/codex-run-json"
  block_fail_out_dir="$smoke_test_base/codex-run-block-fail"
  stdout_file="$contract_root/stdout"
  stderr_file="$contract_root/stderr"

  mkdir -p "$contract_root" || return 1

  codex_run_contract_write_fake_codex "$fake_bin_dir" || return 1
  hash -r || return 1

  printf 'run codex-run smoke prompt\n' > "$prompt_file"
  : > "$empty_prompt_file"
  printf 'prompt for invalid profile\n' > "$invalid_profile_prompt"

  expected_default_stdout="$(printf 'pass\nfinal_output_path=%s/codex-run-default/codex-final.txt\nsummary_path=%s/codex-run-default/codex-run-summary.txt' "$smoke_test_base" "$smoke_test_base")"
  expected_default_summary="$(printf 'script=codex-run\nresult=pass\nexit_code=0\nprompt_file=%s\nresume_mode=fresh\nresume_session_id=\nout_dir=%s/codex-run-default\ncd=%s\nprofile=default\nsandbox=workspace-write\ntimeout=0\ntimeout_enforced=not_enforced\ncodex_path=%s/codex\nstdout_path=%s/codex.stdout\nstderr_path=%s/codex.stderr\nfinal_output_path=%s/codex-run-default/codex-final.txt\nfinal_output_status=present\ncodex_final_output_block_path=%s/codex-run-default/codex-final-output-block.txt' "$prompt_file" "$smoke_test_base" "$repo_root" "$fake_bin_dir" "$smoke_test_base/codex-run-default" "$smoke_test_base/codex-run-default" "$smoke_test_base" "$smoke_test_base")"
  expected_resume_summary="$(printf 'script=codex-run\nresult=pass\nexit_code=0\nprompt_file=%s\nresume_mode=resume\nresume_session_id=session-123\nout_dir=%s/codex-run-resume\nresume_workdir=%s\nrequested_profile=default\nrequested_sandbox=workspace-write\ntimeout=0\ntimeout_enforced=not_enforced\ncodex_path=%s/codex\nstdout_path=%s/codex.stdout\nstderr_path=%s/codex.stderr\nfinal_output_path=%s/codex-run-resume/codex-final.txt\nfinal_output_status=present\ncodex_final_output_block_path=%s/codex-run-resume/codex-final-output-block.txt' "$prompt_file" "$smoke_test_base" "$repo_root" "$fake_bin_dir" "$smoke_test_base/codex-run-resume" "$smoke_test_base/codex-run-resume" "$smoke_test_base" "$smoke_test_base")"
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
      codex_run_contract_assert_text "$default_out_dir/codex-final-output-block.txt" "$(cat <<'EOF'
===== CODEX FINAL OUTPUT =====
fake final output
===== END CODEX FINAL OUTPUT =====
EOF
)" &&
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
    rm -rf -- "$resume_out_dir" &&
      mkdir -p "$resume_out_dir" &&
      FAKE_CODEX_STDOUT_TEXT='resume final output from fake codex' \
      FAKE_CODEX_STDERR_TEXT='resume stderr from fake codex' \
      FAKE_CODEX_LOG_FILE="$codex_log" \
      FAKE_CODEX_ARGS_FILE="$args_log" \
      FAKE_CODEX_CWD_FILE="$cwd_log" \
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$resume_out_dir" --resume-session-id=session-123 >"$stdout_file" 2>"$stderr_file" &&
      codex_run_contract_assert_text "$stdout_file" "$(printf 'pass
final_output_path=%s/codex-run-resume/codex-final.txt
summary_path=%s/codex-run-resume/codex-run-summary.txt' "$smoke_test_base" "$smoke_test_base")" &&
      codex_run_contract_assert_empty "$stderr_file" &&
      codex_run_contract_assert_text "$resume_out_dir/codex-final.txt" 'resume final output from fake codex' &&
      codex_run_contract_assert_text "$resume_out_dir/codex-final-output-block.txt" "$(cat <<'EOF'
===== CODEX FINAL OUTPUT =====
resume final output from fake codex
===== END CODEX FINAL OUTPUT =====
EOF
)" &&
      codex_run_contract_assert_text "$resume_out_dir/codex.stdout" 'resume final output from fake codex' &&
      codex_run_contract_assert_text "$resume_out_dir/codex.stderr" 'resume stderr from fake codex' &&
      codex_run_contract_assert_text "$resume_out_dir/codex-run-summary.txt" "$expected_resume_summary" &&
      codex_run_contract_assert_text "$cwd_log" "$repo_root" &&
      codex_run_contract_assert_text "$args_log" "$(cat <<EOF
exec
resume
session-123
run codex-run smoke prompt
EOF
)"
  ); then
    :
  else
    test_fail "resume-success"
    status=1
  fi

  if (
    rm -rf -- "$invalid_resume_out_dir" &&
      mkdir -p "$invalid_resume_out_dir" &&
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$invalid_resume_out_dir" --resume-session-id='../bad id' >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "invalid-resume-session-id"
    status=1
  else
    if codex_run_contract_assert_grep 'invalid resume session id:' "$stderr_file" &&
      codex_run_contract_assert_not_exists "$invalid_resume_out_dir/codex.args"; then
      :
    else
      test_fail "invalid-resume-session-id"
      status=1
    fi
  fi

  if (
    rm -rf -- "$resume_custom_out_dir" &&
      mkdir -p "$resume_custom_out_dir" &&
      mkdir -p "$resume_custom_cd_dir" &&
      FAKE_CODEX_STDOUT_TEXT='resume final output with custom options' \
      FAKE_CODEX_STDERR_TEXT='resume stderr with custom options' \
      FAKE_CODEX_LOG_FILE="$codex_log" \
      FAKE_CODEX_ARGS_FILE="$args_log" \
      FAKE_CODEX_CWD_FILE="$cwd_log" \
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$resume_custom_out_dir" --resume-session-id=session-123 --profile=resume-profile --cd="$resume_custom_cd_dir" --sandbox=read-only --model=gpt-5.4-mini --reasoning=high --explain >"$stdout_file" 2>"$stderr_file" &&
      codex_run_contract_assert_empty "$stdout_file" &&
      codex_run_contract_assert_grep 'INFO: codex-run requested_profile=resume-profile requested_sandbox=read-only timeout=0' "$stderr_file" &&
      codex_run_contract_assert_grep 'INFO: codex-run requested_model=gpt-5.4-mini' "$stderr_file" &&
      codex_run_contract_assert_grep 'INFO: codex-run requested_reasoning=high' "$stderr_file" &&
      codex_run_contract_assert_grep 'requested_profile=resume-profile' "$stderr_file" &&
      codex_run_contract_assert_grep 'requested_sandbox=read-only' "$stderr_file" &&
      codex_run_contract_assert_grep 'resume_workdir='"$resume_custom_cd_dir" "$stderr_file" &&
      codex_run_contract_assert_text "$resume_custom_out_dir/codex-final.txt" 'resume final output with custom options' &&
      codex_run_contract_assert_text "$resume_custom_out_dir/codex-final-output-block.txt" "$(cat <<'EOF'
===== CODEX FINAL OUTPUT =====
resume final output with custom options
===== END CODEX FINAL OUTPUT =====
EOF
)" &&
      codex_run_contract_assert_text "$resume_custom_out_dir/codex.stdout" 'resume final output with custom options' &&
      codex_run_contract_assert_text "$resume_custom_out_dir/codex.stderr" 'resume stderr with custom options' &&
      codex_run_contract_assert_text "$resume_custom_out_dir/codex-run-summary.txt" "$(printf 'script=codex-run
result=pass
exit_code=0
prompt_file=%s
resume_mode=resume
resume_session_id=session-123
out_dir=%s/codex-run-resume-custom
resume_workdir=%s
requested_profile=resume-profile
requested_sandbox=read-only
requested_model=gpt-5.4-mini
requested_reasoning=high
timeout=0
timeout_enforced=not_enforced
codex_path=%s/codex
stdout_path=%s/codex.stdout
stderr_path=%s/codex.stderr
final_output_path=%s/codex-run-resume-custom/codex-final.txt
final_output_status=present
codex_final_output_block_path=%s/codex-run-resume-custom/codex-final-output-block.txt' "$prompt_file" "$smoke_test_base" "$resume_custom_cd_dir" "$fake_bin_dir" "$smoke_test_base/codex-run-resume-custom" "$smoke_test_base/codex-run-resume-custom" "$smoke_test_base" "$smoke_test_base")" &&
      codex_run_contract_assert_text "$cwd_log" "$resume_custom_cd_dir" &&
      codex_run_contract_assert_text "$args_log" "$(cat <<EOF
exec
resume
session-123
run codex-run smoke prompt
EOF
)"
  ); then
    :
  else
    test_fail "resume-custom-options"
    status=1
  fi

  if (
    rm -rf -- "$model_out_dir" &&
      mkdir -p "$model_out_dir" &&
      FAKE_CODEX_LOG_FILE="$codex_log" \
      FAKE_CODEX_ARGS_FILE="$args_log" \
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$model_out_dir" --model=gpt-5.4-mini >"$stdout_file" 2>"$stderr_file" &&
      codex_run_contract_assert_text "$stdout_file" "$(printf 'pass
final_output_path=%s/codex-run-model/codex-final.txt
summary_path=%s/codex-run-model/codex-run-summary.txt' "$smoke_test_base" "$smoke_test_base")" &&
      codex_run_contract_assert_empty "$stderr_file" &&
      codex_run_contract_assert_grep '--model' "$args_log" &&
      codex_run_contract_assert_grep 'gpt-5.4-mini' "$args_log" &&
      codex_run_contract_assert_grep 'requested_model=gpt-5.4-mini' "$model_out_dir/codex-run-summary.txt"
  ); then
    :
  else
    test_fail "model-forwarding"
    status=1
  fi

  if (
    rm -rf -- "$reasoning_out_dir" &&
      mkdir -p "$reasoning_out_dir" &&
      FAKE_CODEX_LOG_FILE="$codex_log" \
      FAKE_CODEX_ARGS_FILE="$args_log" \
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$reasoning_out_dir" --reasoning=medium >"$stdout_file" 2>"$stderr_file" &&
      codex_run_contract_assert_text "$stdout_file" "$(printf 'pass
final_output_path=%s/codex-run-reasoning/codex-final.txt
summary_path=%s/codex-run-reasoning/codex-run-summary.txt' "$smoke_test_base" "$smoke_test_base")" &&
      codex_run_contract_assert_empty "$stderr_file" &&
      codex_run_contract_assert_grep '-c' "$args_log" &&
      codex_run_contract_assert_grep 'model_reasoning_effort=medium' "$args_log" &&
      codex_run_contract_assert_grep 'requested_reasoning=medium' "$reasoning_out_dir/codex-run-summary.txt"
  ); then
    :
  else
    test_fail "reasoning-forwarding"
    status=1
  fi

  if (
    rm -rf -- "$model_reasoning_out_dir" &&
      mkdir -p "$model_reasoning_out_dir" &&
      FAKE_CODEX_LOG_FILE="$codex_log" \
      FAKE_CODEX_ARGS_FILE="$args_log" \
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$model_reasoning_out_dir" --model=gpt-5.4-mini --reasoning=high --explain >"$stdout_file" 2>"$stderr_file" &&
      codex_run_contract_assert_empty "$stdout_file" &&
      codex_run_contract_assert_grep 'INFO: codex-run requested_model=gpt-5.4-mini' "$stderr_file" &&
      codex_run_contract_assert_grep 'INFO: codex-run requested_reasoning=high' "$stderr_file" &&
      codex_run_contract_assert_grep 'requested_model=gpt-5.4-mini' "$model_reasoning_out_dir/codex-run-summary.txt" &&
      codex_run_contract_assert_grep 'requested_reasoning=high' "$model_reasoning_out_dir/codex-run-summary.txt" &&
      codex_run_contract_assert_grep '--model' "$args_log" &&
      codex_run_contract_assert_grep 'gpt-5.4-mini' "$args_log" &&
      codex_run_contract_assert_grep '-c' "$args_log" &&
      codex_run_contract_assert_grep 'model_reasoning_effort=high' "$args_log" &&
      codex_run_contract_assert_grep '===== FINAL SUMMARY =====' "$stderr_file"
  ); then
    :
  else
    test_fail "model-reasoning-explain-forwarding"
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
    rm -rf -- "$conflict_out_dir" &&
      mkdir -p "$conflict_out_dir" &&
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$conflict_out_dir" --quiet --explain >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "quiet-explain-conflict"
    status=1
  else
    if codex_run_contract_assert_empty "$stdout_file" &&
      codex_run_contract_assert_grep 'result=fail' "$stderr_file" &&
      codex_run_contract_assert_grep 'code=output-mode-conflict' "$stderr_file" &&
      codex_run_contract_assert_grep 'step=output-modes' "$stderr_file" &&
      codex_run_contract_assert_grep 'reason=quiet and explain cannot be combined' "$stderr_file" &&
      codex_run_contract_assert_grep 'fix=use only one output mode' "$stderr_file" &&
      codex_run_contract_assert_not_exists "$conflict_out_dir/codex.args"; then
      :
    else
      test_fail "quiet-explain-conflict"
      status=1
    fi
  fi

  if (
    rm -rf -- "$json_out_dir" &&
      mkdir -p "$json_out_dir" &&
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$json_out_dir" --json --explain >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "json-unsupported"
    status=1
  else
    if codex_run_contract_assert_empty "$stdout_file" &&
      codex_run_contract_assert_grep 'fail: unsupported flag' "$stderr_file" &&
      codex_run_contract_assert_grep 'flag: --json' "$stderr_file" &&
      codex_run_contract_assert_grep 'fix: use --quiet or --explain; JSON output is not implemented yet' "$stderr_file" &&
      codex_run_contract_assert_not_exists "$json_out_dir/codex.args"; then
      :
    else
      test_fail "json-unsupported"
      status=1
    fi
  fi

  if (
    rm -rf -- "$json_out_dir" &&
      mkdir -p "$json_out_dir" &&
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$json_out_dir" --quiet --json >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "quiet-json-unsupported"
    status=1
  else
    if codex_run_contract_assert_empty "$stdout_file" &&
      codex_run_contract_assert_grep 'result=fail' "$stderr_file" &&
      codex_run_contract_assert_grep 'code=unsupported-json' "$stderr_file" &&
      codex_run_contract_assert_grep 'step=output-modes' "$stderr_file" &&
      codex_run_contract_assert_grep 'reason=JSON output is not implemented yet' "$stderr_file" &&
      codex_run_contract_assert_grep 'fix=use --quiet or --explain without --json' "$stderr_file" &&
      codex_run_contract_assert_not_exists "$json_out_dir/codex.args"; then
      :
    else
      test_fail "quiet-json-unsupported"
      status=1
    fi
  fi

  if (
    rm -rf -- "$explain_out_dir" &&
      mkdir -p "$explain_out_dir" &&
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$explain_out_dir" --explain >"$stdout_file" 2>"$stderr_file" &&
      codex_run_contract_assert_empty "$stdout_file" &&
      codex_run_contract_assert_grep 'INFO: codex-run profile=default sandbox=workspace-write timeout=0' "$stderr_file" &&
      codex_run_contract_assert_grep '===== FINAL SUMMARY =====' "$stderr_file" &&
      codex_run_contract_assert_grep 'status=pass' "$stderr_file" &&
      codex_run_contract_assert_text <(smoke_extract_final_summary_block "$stderr_file") "$expected_explain_summary" &&
      python3 - "$stderr_file" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
summary = "===== FINAL SUMMARY =====\n"
summary_end = "===== END =====\n"
block = "\n===== CODEX FINAL OUTPUT =====\nfake final output\n===== END CODEX FINAL OUTPUT =====\n"
if text.count(summary) != 1 or text.count("===== CODEX FINAL OUTPUT =====") != 1:
    raise SystemExit(1)
summary_index = text.index(summary)
summary_end_index = text.index(summary_end, summary_index) + len(summary_end)
block_index = text.index(block)
if not summary_index < summary_end_index <= block_index:
    raise SystemExit(1)
PY
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
    PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$invalid_model_out_dir" --model='bad model' >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "invalid-model"
    status=1
  else
    codex_run_contract_assert_grep 'invalid flag value' "$stderr_file" || { test_fail "invalid-model"; status=1; }
    codex_run_contract_assert_grep '--model' "$stderr_file" || { test_fail "invalid-model"; status=1; }
  fi

  if (
    PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$invalid_reasoning_out_dir" --reasoning=extreme >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "invalid-reasoning"
    status=1
  else
    codex_run_contract_assert_grep 'invalid flag value' "$stderr_file" || { test_fail "invalid-reasoning"; status=1; }
    codex_run_contract_assert_grep '--reasoning' "$stderr_file" || { test_fail "invalid-reasoning"; status=1; }
  fi

  if (
    FAKE_CODEX_EXIT_CODE=17 \
      FAKE_CODEX_STDERR_TEXT='child failure line one
child failure line two' \
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$child_fail_out_dir" >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "child-failure"
    status=1
  else
    if codex_run_contract_assert_grep 'fail: codex-run failed' "$stderr_file" &&
      codex_run_contract_assert_grep 'step: codex' "$stderr_file" &&
      codex_run_contract_assert_grep 'exit_code: 17' "$stderr_file" &&
      codex_run_contract_assert_grep 'reason: codex exec exited with status 17' "$stderr_file" &&
      codex_run_contract_assert_grep 'log: '"$child_fail_out_dir"'/codex.stderr' "$stderr_file" &&
      codex_run_contract_assert_grep 'child failure line one' "$stderr_file" &&
      codex_run_contract_assert_grep 'fix: inspect the child failure log and rerun codex-run' "$stderr_file"; then
      :
    else
      test_fail "child-failure"
      status=1
    fi
  fi

  if (
    FAKE_CODEX_EXIT_CODE=17 \
      FAKE_CODEX_STDERR_TEXT='child failure line one
child failure line two' \
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$child_fail_out_dir" --quiet >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "quiet-child-failure"
    status=1
  else
    if codex_run_contract_assert_empty "$stdout_file" &&
      codex_run_contract_assert_grep 'result=fail' "$stderr_file" &&
      codex_run_contract_assert_grep 'code=codex-child-failed' "$stderr_file" &&
      codex_run_contract_assert_grep 'step=codex' "$stderr_file" &&
      codex_run_contract_assert_grep 'reason=codex exec exited with status 17' "$stderr_file" &&
      codex_run_contract_assert_grep 'log='"$child_fail_out_dir"'/codex.stderr' "$stderr_file" &&
      codex_run_contract_assert_grep 'excerpt=child failure line one' "$stderr_file" &&
      codex_run_contract_assert_grep 'fix=inspect the child failure log and rerun codex-run' "$stderr_file"; then
      :
    else
      test_fail "quiet-child-failure"
      status=1
    fi
  fi

  if (
    FAKE_CODEX_WRITE_FINAL=0 \
      FAKE_CODEX_STDOUT_TEXT='' \
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$missing_final_out_dir" --resume-session-id=session-123 >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "resume-missing-final-output"
    status=1
  else
    if codex_run_contract_assert_grep 'fail: codex-run failed' "$stderr_file" &&
      codex_run_contract_assert_grep 'step: resume-final-output-contract' "$stderr_file" &&
      codex_run_contract_assert_grep 'reason: resume mode cannot produce a reliable final-output artifact' "$stderr_file" &&
      codex_run_contract_assert_grep 'artifact: '"$missing_final_out_dir"'/codex-final.txt' "$stderr_file" &&
      codex_run_contract_assert_grep 'fix: use codex exec for non-resume execution or implement a verified resume final-output capture path' "$stderr_file" &&
      codex_run_contract_assert_grep 'failure_code=resume-final-output-contract-failed' "$missing_final_out_dir/codex-run-summary.txt" &&
      codex_run_contract_assert_grep 'failure_step=resume-final-output-contract' "$missing_final_out_dir/codex-run-summary.txt" &&
      codex_run_contract_assert_empty "$missing_final_out_dir/codex-final.txt"; then
      :
    else
      test_fail "resume-missing-final-output"
      status=1
    fi
  fi

  if (
    rm -rf -- "$missing_final_out_dir" &&
      FAKE_CODEX_WRITE_FINAL=0 \
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$missing_final_out_dir" --quiet >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "quiet-missing-final-output"
    status=1
  else
    if codex_run_contract_assert_empty "$stdout_file" &&
      codex_run_contract_assert_grep 'result=fail' "$stderr_file" &&
      codex_run_contract_assert_grep 'code=final-output-contract-failed' "$stderr_file" &&
      codex_run_contract_assert_grep 'step=final-output-contract' "$stderr_file" &&
      codex_run_contract_assert_grep 'reason=final output file is missing' "$stderr_file" &&
      codex_run_contract_assert_grep 'artifact='"$missing_final_out_dir"'/codex-final.txt' "$stderr_file" &&
      codex_run_contract_assert_grep 'fix=ensure codex exec writes a non-empty final output file' "$stderr_file"; then
      :
    else
      test_fail "quiet-missing-final-output"
      status=1
    fi
  fi

  if (
    FAKE_CODEX_WRITE_EMPTY_FINAL=1 \
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$empty_final_out_dir" --quiet >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "empty-final-output"
    status=1
  else
    if codex_run_contract_assert_empty "$stdout_file" &&
      codex_run_contract_assert_grep 'result=fail' "$stderr_file" &&
      codex_run_contract_assert_grep 'code=final-output-contract-failed' "$stderr_file" &&
      codex_run_contract_assert_grep 'step=final-output-contract' "$stderr_file" &&
      codex_run_contract_assert_grep 'reason=final output file is empty' "$stderr_file" &&
      codex_run_contract_assert_grep 'artifact='"$empty_final_out_dir"'/codex-final.txt' "$stderr_file" &&
      codex_run_contract_assert_grep 'fix=ensure codex exec writes a non-empty final output file' "$stderr_file" &&
      codex_run_contract_assert_not_exists "$empty_final_out_dir/codex-final-output-block.txt"; then
      :
    else
      test_fail "empty-final-output"
      status=1
    fi
  fi

  if (
    FAKE_CODEX_WRITE_FINAL=1 \
      FAKE_CODEX_FINAL_CHMOD=000 \
      PATH="$fake_bin_dir:$PATH" \
      repo-automation/bin/codex-run --prompt-file="$prompt_file" --out-dir="$block_fail_out_dir" --quiet >"$stdout_file" 2>"$stderr_file"
  ); then
    test_fail "final-output-block-failure"
    status=1
  else
    if codex_run_contract_assert_empty "$stdout_file" &&
      codex_run_contract_assert_grep 'result=fail' "$stderr_file" &&
      codex_run_contract_assert_grep 'code=codex-final-output-block-write-failed' "$stderr_file" &&
      codex_run_contract_assert_grep 'step=final-output-block' "$stderr_file" &&
      codex_run_contract_assert_grep 'reason=failed to write final output block artifact' "$stderr_file" &&
      codex_run_contract_assert_grep 'artifact='"$block_fail_out_dir"'/codex-final-output-block.txt' "$stderr_file" &&
      codex_run_contract_assert_grep 'fix=ensure the final output file stays readable while codex-run writes the block artifact' "$stderr_file" &&
      codex_run_contract_assert_not_exists "$block_fail_out_dir/codex-final-output-block.txt"; then
      :
    else
      test_fail "final-output-block-failure"
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
