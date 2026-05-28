#!/usr/bin/env bash
# repo-automation/tests/lib/smoke-common.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-common.sh"

smoke_common_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
smoke_tests_dir="$(cd "$smoke_common_dir/.." && pwd)"
smoke_repo_root="$(cd "$smoke_tests_dir/../.." && pwd)"

smoke_timeout_seconds="${smoke_timeout_seconds:-120}"
# shellcheck disable=SC2034 # Shared smoke fixture globals consumed by smoke-fixtures.sh and wrappers.
smoke_test_base=""
# shellcheck disable=SC2034 # Shared smoke fixture globals consumed by smoke-fixtures.sh and wrappers.
smoke_test_dir=""
# shellcheck disable=SC2034 # Shared smoke fixture globals consumed by smoke-fixtures.sh and wrappers.
smoke_remote_dir=""
# shellcheck disable=SC2034 # Shared smoke fixture globals consumed by smoke-fixtures.sh and wrappers.
smoke_expected_origin_url="git@github.com:i-schuyler/repo-automation-template.git"
smoke_output_mode="${smoke_output_mode:-summary}"
smoke_help_requested=0

# shellcheck source=/dev/null
source "$smoke_common_dir/smoke-fixtures.sh"

# shellcheck source=/dev/null
source "$smoke_common_dir/smoke-gh-stub.sh"

# shellcheck source=/dev/null
source "$smoke_common_dir/smoke-capture.sh"

smoke_usage() {
  printf 'Usage: %s [--quiet] [--explain] [--json] [--help]\n' "${TEST_OUTPUT_SCRIPT_PATH:-repo-automation/tests/smoke.sh}"
}

smoke_parse_output_mode() {
  local arg=""

  while [ "$#" -gt 0 ]; do
    arg="$1"
    case "$arg" in
      --quiet)
        smoke_output_mode="quiet"
        ;;
      --explain)
        smoke_output_mode="explain"
        ;;
      --json)
        smoke_output_mode="json"
        ;;
      --help)
        smoke_usage
        # shellcheck disable=SC2034 # Read by smoke wrapper scripts after parsing.
        smoke_help_requested=1
        return 0
        ;;
      *)
        if [ "${arg#--}" != "$arg" ]; then
          printf 'fail: unknown flag: %s\n' "$arg" >&2
        else
          printf 'fail: unknown argument: %s\n' "$arg" >&2
        fi
        return 1
        ;;
    esac
    shift
  done

  TEST_OUTPUT_MODE="$smoke_output_mode"
  export TEST_OUTPUT_MODE
  return 0
}

smoke_run_focused_contract_wrapper() {
  local body_function="${1:-}"
  local status=0
  local smoke_wrapper_path="${0#./}"
  local smoke_wrapper_script="${smoke_wrapper_path##*/}"
  local failure_line=""

  if [ -z "$body_function" ]; then
    printf 'fail: missing focused wrapper body function\n' >&2
    return 1
  fi
  shift

  smoke_wrapper_script="${smoke_wrapper_script%.sh}"
  TEST_OUTPUT_SCRIPT="$smoke_wrapper_script"
  export TEST_OUTPUT_SCRIPT
  TEST_OUTPUT_SCRIPT_PATH="$smoke_wrapper_path"
  smoke_help_requested=0

  smoke_parse_output_mode "$@" || return 1
  if [ "$smoke_help_requested" -eq 1 ]; then
    return 0
  fi

  trap 'test_cleanup' EXIT INT TERM

  if [ "$TEST_OUTPUT_MODE" = "explain" ]; then
    "$body_function" || status=1
  else
    smoke_capture_begin "$smoke_wrapper_script" || return 1
    "$body_function" || status=1
    if [ "$status" -ne 0 ] && [ "$TEST_FIRST_FAILURE_INDEX" -lt 0 ]; then
      # shellcheck disable=SC2154 # Set by repo-automation/tests/lib/smoke-capture.sh.
      failure_line="$(test_extract_first_actionable_failure "$smoke_capture_file" || true)"
      if [ -n "$failure_line" ]; then
        test_fail "$failure_line"
      else
        test_fail "$smoke_wrapper_script"
      fi
    fi
    smoke_capture_cleanup || return 1
  fi

  if [ "$status" -ne 0 ] && [ "$TEST_FIRST_FAILURE_INDEX" -lt 0 ]; then
    test_fail "$smoke_wrapper_script"
  fi

  smoke_finish_output "$status"
  return "$status"
}

smoke_finish_output() {
  local status="${1:-0}"

  test_finish_output "$status"
  return "$status"
}

smoke_run() {
  local status=0
  local smoke_registry_lib="$smoke_repo_root/repo-automation/tests/lib/smoke-registry.sh"

  trap 'test_cleanup' EXIT INT TERM

  cd "$smoke_repo_root" || return 1

  if [ ! -f "$smoke_registry_lib" ]; then
    repo_auto_stop "missing required library: repo-automation/tests/lib/smoke-registry.sh"
    return 1
  fi
  # shellcheck source=/dev/null
  source "$smoke_registry_lib" || return 1

  if [ "$smoke_timeout_seconds" -gt 0 ] && ! test_have_timeout; then
    test_warn_timeout_once
  fi

  if [ "$TEST_OUTPUT_MODE" = "explain" ]; then
    smoke_run_all_contracts || status=1
  else
    smoke_capture_begin smoke || return 1
    smoke_run_all_contracts || status=1
    smoke_capture_cleanup || return 1
  fi

  return "$status"
}

smoke_json_assert() {
  local json_file="$1"
  local check_code="$2"
  if python3 - "$json_file" "$check_code" <<'PY'
import json
import pathlib
import sys

json_path = pathlib.Path(sys.argv[1])
check_code = sys.argv[2]
data = json.loads(json_path.read_text(encoding="utf-8"))
globals_dict = {"data": data}
ok = eval(check_code, {}, globals_dict)  # controlled local test expression
sys.exit(0 if ok else 1)
PY
  then
    return 0
  fi

  return 1
}

smoke_extract_final_summary_block() {
  local summary_file="$1"

  awk '
    /^===== FINAL SUMMARY =====$/ {
      if (seen_summary) {
        exit 1
      }
      seen_summary=1
      in_summary=1
      next
    }
    /^===== END =====$/ {
      if (in_summary) {
        seen_end=1
        in_summary=0
      }
      next
    }
    in_summary { print }
    END {
      if (seen_summary == 1 && seen_end == 1 && in_summary == 0) {
        exit 0
      }
      exit 1
    }
  ' "$summary_file"
}

smoke_assert_single_final_summary_block() {
  local summary_file="$1"

  smoke_extract_final_summary_block "$summary_file" >/dev/null
}

smoke_assert_final_summary_field() {
  local summary_file="$1"
  local field="$2"
  local expected_value="$3"
  local summary_block=""

  summary_block="$(smoke_extract_final_summary_block "$summary_file")" || return 1
  printf '%s\n' "$summary_block" | grep -Fxq -- "$field=$expected_value"
}

smoke_assert_final_summary_field_regex() {
  local summary_file="$1"
  local field="$2"
  local value_regex="$3"
  local summary_block=""

  summary_block="$(smoke_extract_final_summary_block "$summary_file")" || return 1
  printf '%s\n' "$summary_block" | grep -Eq "^${field}=${value_regex}$"
}

smoke_assert_final_summary_field_absent() {
  local summary_file="$1"
  local field="$2"

  if grep -Fq -- "$field=" "$summary_file"; then
    return 1
  fi
  return 0
}

smoke_assert_final_summary_block_lacks_regex() {
  local summary_file="$1"
  local forbidden_regex="$2"
  local summary_block=""

  summary_block="$(smoke_extract_final_summary_block "$summary_file")" || return 1
  if printf '%s\n' "$summary_block" | grep -Eq "$forbidden_regex"; then
    return 1
  fi
  return 0
}

smoke_assert_flag_error_shape() {
  local stderr_file="$1"
  local reason="$2"
  local flag="$3"
  local fix="$4"

  grep -Fxq "fail: $reason" "$stderr_file" &&
    grep -Fxq "flag: $flag" "$stderr_file" &&
    grep -Fxq "fix: $fix" "$stderr_file"
}

smoke_assert_single_path_output() {
  local output_file="$1"

  [ "$(wc -l < "$output_file" | tr -d '[:space:]')" = "1" ] &&
    ! grep -Eq '^(INFO|PASS):|^(packet dir|packet zip|bundle dir|bundle zip|zip path|file count):' "$output_file"
}

smoke_run_named_check() {
  local check_name="$1"
  local check_function="$2"

  if test_run_named_check "$check_name" "$check_function"; then
    return 0
  fi

  smoke_restore_fixture_after_timeout || return 1
  return 1
}

# repo-automation/tests/lib/smoke-common.sh EOF
