# repo-automation/lib/run-tests-failure.sh

# shellcheck shell=bash

run_tests_extract_log_excerpt() {
  local log_file="$1"
  local fail_line=""
  local start_line=""
  local end_line=""

  [ -f "$log_file" ] || return 1

  fail_line="$(
    grep -n -m 1 -E '^(fail|FAIL): ' "$log_file" | cut -d: -f1
  )"
  if [ -z "$fail_line" ]; then
    fail_line="$(
      grep -n -m 1 -E '^COMMAND: ' "$log_file" | cut -d: -f1
    )"
  fi
  [ -n "$fail_line" ] || return 1

  start_line=$((fail_line - 2))
  [ "$start_line" -lt 1 ] && start_line=1
  end_line=$((fail_line + 1))

  sed -n "${start_line},${end_line}p" "$log_file"
}
run_tests_extract_smoke_failure() {
  local output_file="$1"
  local fail_line=""
  local running_line=""

  if [ ! -f "$output_file" ]; then
    printf 'failed\n'
    return 0
  fi

  fail_line="$(
    awk '
      match($0, /^(fail|FAIL): /) {
        print substr($0, RLENGTH + 1)
        exit
      }
    ' "$output_file"
  )"
  if [ -n "$fail_line" ]; then
    printf '%s\n' "$fail_line"
    return 0
  fi

  running_line="$(sed -n 's/^RUNNING: //p' "$output_file" | tail -n 1)"
  if [ -n "$running_line" ]; then
    printf 'timed out during %s\n' "$running_line"
    return 0
  fi

  printf 'failed\n'
}
run_tests_print_smoke_failure_excerpt() {
  local output_file="$1"
  local fail_line=""
  local start_line=""
  local end_line=""

  if [ ! -f "$output_file" ]; then
    return 0
  fi

  fail_line="$(grep -n -m 1 -E '^(fail|FAIL): ' "$output_file" | cut -d: -f1)"
  if [ -z "$fail_line" ]; then
    return 0
  fi

  start_line="$fail_line"
  end_line=$((fail_line + 8))

  printf 'SMOKE EXCERPT:\n'
  sed -n "${start_line},${end_line}p" "$output_file"
}
run_tests_extract_log_first_failure() {
  local log_file="$1"
  local first_failure=""

  if [ -z "$log_file" ] || [ ! -f "$log_file" ]; then
    return 1
  fi

  first_failure="$(sed -n -E 's/^(fail|FAIL): //p' "$log_file" | head -n 1)"
  [ -n "$first_failure" ] || return 1

  printf '%s\n' "$first_failure"
}
run_tests_extract_log_command() {
  local log_file="$1"
  local command_line=""

  if [ -z "$log_file" ] || [ ! -f "$log_file" ]; then
    return 1
  fi

  command_line="$(sed -n 's/^COMMAND: //p' "$log_file" | head -n 1)"
  [ -n "$command_line" ] || return 1

  printf '%s\n' "$command_line"
}
run_tests_focus_command_from_log() {
  local first_failure="$1"
  local command_line="$2"

  case "$first_failure" in
    smoke:installer-contract*)
      printf 'repo-automation/tests/contracts/installer.sh --quiet\n'
      return 0
      ;;
    smoke:run-tests-contract*)
      printf 'repo-automation/tests/contracts/run-tests.sh --quiet\n'
      return 0
      ;;
    shellcheck\ path\ discovery*)
      printf 'repo-automation/bin/shellcheck-ci-parity --print-paths\n'
      return 0
      ;;
    shellcheck\ repo-automation\ scripts\ and\ tests*)
      printf 'repo-automation/bin/shellcheck-ci-parity\n'
      return 0
      ;;
  esac

  case "$command_line" in
    *repo-automation/tests/docs-check.sh*)
      printf 'repo-automation/tests/docs-check.sh --quiet\n'
      return 0
      ;;
    *repo-automation/tests/version-consistency.sh*)
      printf 'repo-automation/tests/version-consistency.sh --quiet\n'
      return 0
      ;;
    *repo-automation/tests/smoke.sh*)
      printf 'repo-automation/tests/smoke.sh --quiet\n'
      return 0
      ;;
  esac

  [ -n "$command_line" ] || return 1
  printf '%s\n' "$command_line"
}
run_tests_print_log_reference() {
  local log_file="$1"

  if [ -n "$log_file" ]; then
    printf 'log: %s\n' "$log_file"
  fi
}
run_tests_print_failure_fix_from_log() {
  local log_file="$1"
  local log_cleaned="${2:-0}"
  local first_failure=""
  local command_line=""
  local focused_command=""
  local excerpt=""

  if [ "$log_cleaned" -eq 1 ]; then
    excerpt="$(run_tests_extract_log_excerpt "$log_file" 2>/dev/null || true)"
    repo_auto_print_failure_footer \
      log cleaned \
      excerpt "$excerpt" \
      fix "use --log-file=<path> or --no-clean-temp for durable logs"
    return 0
  fi

  repo_auto_print_failure_footer log "$log_file"
  first_failure="$(run_tests_extract_log_first_failure "$log_file" 2>/dev/null || true)"
  command_line="$(run_tests_extract_log_command "$log_file" 2>/dev/null || true)"
  focused_command="$(run_tests_focus_command_from_log "$first_failure" "$command_line" 2>/dev/null || true)"

  if [ -n "$first_failure" ]; then
    printf 'first failure: %s\n' "$first_failure"
  fi

  if [ -n "$focused_command" ]; then
    repo_auto_print_failure_footer fix "inspect log and run focused check: $focused_command"
  else
    repo_auto_print_failure_footer fix "inspect log: $log_file"
  fi
}

# repo-automation/lib/run-tests-failure.sh EOF
