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

smoke_render_output_mode_error() {
  local render_mode="$1"
  local code="$2"
  local reason="$3"
  local fix="$4"

  case "$render_mode" in
    json)
      printf '{'
      printf '"schema":"repo-automation-helper-output/v1",'
      printf '"script":"%s",' "$(test_escape_json "${TEST_OUTPUT_SCRIPT:-smoke}")"
      printf '"mode":"json",'
      printf '"result":"fail",'
      printf '"status":"fail",'
      printf '"code":"%s",' "$(test_escape_json "$code")"
      printf '"step":"output-mode-parse",'
      printf '"reason":"%s",' "$(test_escape_json "$reason")"
      printf '"fix":"%s",' "$(test_escape_json "$fix")"
      printf '"pass_count":0,"warn_count":0,"fail_count":0,"checks":[]'
      printf '}\n'
      ;;
    quiet)
      printf 'result=fail\n' >&2
      printf 'code=%s\n' "$code" >&2
      printf 'step=output-mode-parse\n' >&2
      printf 'reason=%s\n' "$reason" >&2
      printf 'fix=%s\n' "$fix" >&2
      ;;
    *)
      repo_auto_print_failure_footer fail "$reason" fix "$fix" >&2
      ;;
  esac
}

smoke_parse_output_mode() {
  local arg=""
  local saw_quiet=0
  local saw_explain=0
  local saw_json=0
  local mode_count=0
  local render_mode="default"
  local conflict_flags=()
  local error_code=""
  local error_reason=""
  local error_fix=""

  while [ "$#" -gt 0 ]; do
    arg="$1"
    case "$arg" in
      --quiet)
        saw_quiet=1
        conflict_flags+=("--quiet")
        ;;
      --explain)
        saw_explain=1
        conflict_flags+=("--explain")
        ;;
      --json)
        saw_json=1
        conflict_flags+=("--json")
        ;;
      --help)
        smoke_usage
        # shellcheck disable=SC2034 # Read by smoke wrapper scripts after parsing.
        smoke_help_requested=1
        return 0
        ;;
      *)
        if [ -z "$error_code" ]; then
          if [ "${arg#--}" != "$arg" ]; then
            error_code="unknown-flag"
            error_reason="unknown flag: $arg"
          else
            error_code="unknown-argument"
            error_reason="unknown argument: $arg"
          fi
          error_fix="run ${TEST_OUTPUT_SCRIPT_PATH:-repo-automation/tests/smoke.sh} --help"
        fi
        ;;
    esac
    shift
  done

  mode_count=$((saw_quiet + saw_explain + saw_json))
  if [ "$mode_count" -gt 1 ] && [ -z "$error_code" ]; then
    error_code="output-mode-conflict"
    error_reason="incompatible output mode flags: ${conflict_flags[*]}"
    error_fix="use exactly one of --quiet, --explain, or --json"
  fi

  if [ -n "$error_code" ]; then
    if [ "$saw_json" -eq 1 ]; then
      render_mode="json"
    elif [ "$saw_quiet" -eq 1 ]; then
      render_mode="quiet"
    fi
    smoke_render_output_mode_error "$render_mode" "$error_code" "$error_reason" "$error_fix"
    return 1
  fi

  if [ "$saw_json" -eq 1 ]; then
    smoke_output_mode="json"
  elif [ "$saw_quiet" -eq 1 ]; then
    smoke_output_mode="quiet"
  elif [ "$saw_explain" -eq 1 ]; then
    smoke_output_mode="explain"
  fi

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
        # shellcheck disable=SC2034 # Shared by test-common.sh failure renderers.
        TEST_FIRST_FAILURE_LOG="$smoke_capture_file"
        test_fail "$body_function"
      fi
    fi
    smoke_capture_cleanup "$status" || return 1
  fi

  if [ "$status" -ne 0 ] && [ "$TEST_FIRST_FAILURE_INDEX" -lt 0 ]; then
    test_fail "$body_function"
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
    smoke_capture_cleanup "$status" || return 1
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

smoke_assert_quiet_success_empty() {
  local stdout_file="$1"
  local stderr_file="$2"

  [ ! -s "$stdout_file" ] && [ ! -s "$stderr_file" ]
}

smoke_assert_quiet_failure_envelope() {
  local stderr_file="$1"
  local expected_code="$2"
  local expected_step="$3"
  local expected_reason="$4"
  local expected_fix="$5"
  local expected_path="${6:-}"
  local expected_artifact="${7:-}"
  local expected_log="${8:-}"
  local expected_excerpt="${9:-}"
  local filtered_stderr_file=""
  local line=""
  local seen_result=0
  local seen_code=0
  local seen_step=0
  local seen_reason=0
  local seen_fix=0
  local seen_path=0
  local seen_artifact=0
  local seen_log=0
  local seen_excerpt=0

  filtered_stderr_file="$(mktemp "${TMPDIR:-$HOME/.cache}/smoke-quiet-envelope.XXXXXX")" || return 1
  grep -v '^[+]' "$stderr_file" > "$filtered_stderr_file" 2>/dev/null || true
  # shellcheck disable=SC2094 # The temp file is only consumed after filtering completes.
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      '')
        rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true
        return 1
        ;;
      'result=fail')
        seen_result=1
        ;;
      code=*)
        [ "$line" = "code=$expected_code" ] || { rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true; return 1; }
        seen_code=$((seen_code + 1))
        ;;
      step=*)
        [ "$line" = "step=$expected_step" ] || { rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true; return 1; }
        seen_step=$((seen_step + 1))
        ;;
      reason=*)
        [ "$line" = "reason=$expected_reason" ] || { rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true; return 1; }
        seen_reason=$((seen_reason + 1))
        ;;
      fix=*)
        [ "$line" = "fix=$expected_fix" ] || { rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true; return 1; }
        seen_fix=$((seen_fix + 1))
        ;;
      path=*)
        if [ -n "$expected_path" ]; then
          [ "$line" = "path=$expected_path" ] || { rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true; return 1; }
        fi
        seen_path=$((seen_path + 1))
        ;;
      artifact=*)
        if [ -n "$expected_artifact" ]; then
          [ "$line" = "artifact=$expected_artifact" ] || { rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true; return 1; }
        fi
        seen_artifact=$((seen_artifact + 1))
        ;;
      log=*)
        if [ -n "$expected_log" ]; then
          [ "$line" = "log=$expected_log" ] || { rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true; return 1; }
        fi
        seen_log=$((seen_log + 1))
        ;;
      excerpt=*)
        if [ -n "$expected_excerpt" ]; then
          [ "$line" = "excerpt=$expected_excerpt" ] || { rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true; return 1; }
        fi
        seen_excerpt=$((seen_excerpt + 1))
        ;;
      *)
        rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true
        return 1
        ;;
    esac
  done < "$filtered_stderr_file"
  if [ "$seen_result" -eq 1 ] && [ "$seen_code" -eq 1 ] && [ "$seen_step" -eq 1 ] && [ "$seen_reason" -eq 1 ] && [ "$seen_fix" -eq 1 ] &&
    [ "$seen_path" -le 1 ] && [ "$seen_artifact" -le 1 ] && [ "$seen_log" -le 1 ] && [ "$seen_excerpt" -le 1 ] &&
    { [ -z "$expected_path" ] || [ "$seen_path" -eq 1 ]; } &&
    { [ -z "$expected_artifact" ] || [ "$seen_artifact" -eq 1 ]; } &&
    { [ -z "$expected_log" ] || [ "$seen_log" -eq 1 ]; } &&
    { [ -z "$expected_excerpt" ] || [ "$seen_excerpt" -eq 1 ]; }; then
    rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true
    return 0
  fi
  rm -f -- "$filtered_stderr_file" >/dev/null 2>&1 || true
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

  ! grep -Fq -- "$field=" "$summary_file"
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
