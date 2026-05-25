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
  local smoke_output_capture=""
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
    mkdir -p "$TEST_TEMP_ROOT" || return 1
    smoke_output_capture="$(mktemp "$TEST_TEMP_ROOT/${smoke_wrapper_script}.XXXXXX")" || return 1
    exec 3>&1 4>&2
    exec >"$smoke_output_capture" 2>&1
    "$body_function" || status=1
    if [ "$status" -ne 0 ] && [ "$TEST_FIRST_FAILURE_INDEX" -lt 0 ]; then
      failure_line="$(test_extract_first_actionable_failure "$smoke_output_capture" || true)"
      if [ -n "$failure_line" ]; then
        test_fail "$failure_line"
      else
        test_fail "$smoke_wrapper_script"
      fi
    fi
    exec 1>&3 2>&4
    rm -f -- "$smoke_output_capture" >/dev/null 2>&1 || true
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
  local smoke_output_capture=""
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
    mkdir -p "$TEST_TEMP_ROOT" || return 1
    smoke_output_capture="$(mktemp "$TEST_TEMP_ROOT/smoke.XXXXXX")" || return 1
    exec 3>&1 4>&2
    exec >"$smoke_output_capture" 2>&1
    smoke_run_all_contracts || status=1
    exec 1>&3 2>&4
    rm -f -- "$smoke_output_capture" >/dev/null 2>&1 || true
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

smoke_write_gh_stub() {
  local gh_stub_dir="$1"

  mkdir -p "$gh_stub_dir" || return 1
  cat > "$gh_stub_dir/gh" <<'EOF'
#!/usr/bin/env bash
set -u
cmd="${1:-}"
sub="${2:-}"
shift 2 >/dev/null 2>&1 || true
  case "$cmd $sub" in
  'auth status')
    exit 0
    ;;
  'pr checks')
    if [ -n "${GH_STUB_PR_CHECKS_SEQUENCE_FILE:-}" ] && [ -f "$GH_STUB_PR_CHECKS_SEQUENCE_FILE" ]; then
      first_line="$(sed -n '1p' "$GH_STUB_PR_CHECKS_SEQUENCE_FILE" 2>/dev/null || true)"
      rest_lines="$(sed -n '2,$p' "$GH_STUB_PR_CHECKS_SEQUENCE_FILE" 2>/dev/null || true)"
      if [ -n "$first_line" ]; then
        printf '%s\n' "$first_line"
        printf '%s\n' "$rest_lines" > "$GH_STUB_PR_CHECKS_SEQUENCE_FILE"
      else
        printf '%s\n' "${GH_STUB_PR_CHECKS_JSON:-[]}"
      fi
    else
      printf '%s\n' "${GH_STUB_PR_CHECKS_JSON:-[]}"
    fi
    ;;
  'pr view')
    if [ -n "${GH_STUB_PR_VIEW_LOG_FILE:-}" ]; then
      printf '%s\n' "gh pr view $*" >> "$GH_STUB_PR_VIEW_LOG_FILE"
    fi
    if [ -n "${GH_STUB_PR_VIEW_FAIL_ONCE_FILE:-}" ] && [ ! -e "${GH_STUB_PR_VIEW_FAIL_ONCE_FILE}" ]; then
      : > "$GH_STUB_PR_VIEW_FAIL_ONCE_FILE"
      printf '%s\n' "${GH_STUB_PR_VIEW_FAIL_ONCE_STDERR:-net/http: TLS handshake timeout}" >&2
      exit 1
    fi
    case " $* " in
      *' --json '*)
        if [[ " $* " != *' --jq '* ]]; then
          GH_STUB_PR_VIEW_NUMBER_VALUE="${GH_STUB_PR_VIEW_NUMBER:-123}" \
          GH_STUB_PR_VIEW_TITLE_VALUE="${GH_STUB_PR_VIEW_TITLE:-demo title}" \
          GH_STUB_PR_VIEW_URL_VALUE="${GH_STUB_PR_VIEW_URL:-https://github.com/i-schuyler/repo-automation-template/pull/123}" \
          GH_STUB_PR_VIEW_STATE_VALUE="${GH_STUB_PR_VIEW_STATE:-OPEN}" \
          GH_STUB_PR_VIEW_IS_DRAFT_VALUE="${GH_STUB_PR_VIEW_IS_DRAFT:-false}" \
          GH_STUB_PR_VIEW_MERGEABLE_VALUE="${GH_STUB_PR_VIEW_MERGEABLE:-MERGEABLE}" \
          GH_STUB_PR_VIEW_HEAD_SHA_VALUE="${GH_STUB_PR_VIEW_HEAD_SHA:-}" \
          GH_STUB_PR_VIEW_HEAD_REF_VALUE="${GH_STUB_PR_VIEW_HEAD_REF:-feature/demo}" \
          python3 - <<'PY'
import json
import os

number_value = os.environ.get('GH_STUB_PR_VIEW_NUMBER_VALUE', '123')
try:
    number_value = int(number_value)
except Exception:
    pass

data = {
    'number': number_value,
    'title': os.environ.get('GH_STUB_PR_VIEW_TITLE_VALUE', 'demo title'),
    'url': os.environ.get('GH_STUB_PR_VIEW_URL_VALUE', 'https://github.com/i-schuyler/repo-automation-template/pull/123'),
    'state': os.environ.get('GH_STUB_PR_VIEW_STATE_VALUE', 'OPEN'),
    'isDraft': os.environ.get('GH_STUB_PR_VIEW_IS_DRAFT_VALUE', 'false').lower() == 'true',
    'mergeable': os.environ.get('GH_STUB_PR_VIEW_MERGEABLE_VALUE', 'MERGEABLE'),
    'headRefOid': os.environ.get('GH_STUB_PR_VIEW_HEAD_SHA_VALUE', ''),
    'headRefName': os.environ.get('GH_STUB_PR_VIEW_HEAD_REF_VALUE', 'feature/demo'),
}
print(json.dumps(data))
PY
          exit 0
        fi
        ;;
    esac
    case " $* " in
      *' --json number '*|*' --jq .number '*)
        printf '%s\n' "${GH_STUB_PR_VIEW_NUMBER:-123}"
        ;;
      *' --json title '*|*' --jq .title '*)
        printf '%s\n' "${GH_STUB_PR_VIEW_TITLE:-demo title}"
        ;;
      *' --json url '*|*' --jq .url '*)
        printf '%s\n' "${GH_STUB_PR_VIEW_URL:-https://github.com/i-schuyler/repo-automation-template/pull/123}"
        ;;
      *' --json state '*|*' --jq .state '*)
        printf '%s\n' "${GH_STUB_PR_VIEW_STATE:-OPEN}"
        ;;
      *' --json isDraft '*|*' --jq .isDraft '*)
        printf '%s\n' "${GH_STUB_PR_VIEW_IS_DRAFT:-false}"
        ;;
      *' --json mergeable '*|*' --jq .mergeable '*)
        printf '%s\n' "${GH_STUB_PR_VIEW_MERGEABLE:-MERGEABLE}"
        ;;
      *' --json headRefName '*|*' --jq .headRefName '*)
        printf '%s\n' "${GH_STUB_PR_VIEW_HEAD_REF:-feature/demo}"
        ;;
      *' --json headRefOid '*|*' --jq .headRefOid '*)
        printf '%s\n' "${GH_STUB_PR_VIEW_HEAD_SHA:-}"
        ;;
      *)
        printf '%s\n' "${GH_STUB_PR_VIEW_HEAD_REF:-feature/demo}"
        ;;
    esac
    ;;
  'pr merge')
    if [ -n "${GH_STUB_PR_MERGE_LOG_FILE:-}" ]; then
      printf '%s\n' "gh pr merge $*" >> "$GH_STUB_PR_MERGE_LOG_FILE"
    fi
    if [ -n "${GH_STUB_PR_MERGE_STDERR_FILE:-}" ]; then
      printf '%s\n' "gh pr merge $*" >> "$GH_STUB_PR_MERGE_STDERR_FILE"
    fi
    if [ "${GH_STUB_PR_MERGE_EXIT:-0}" -ne 0 ] 2>/dev/null; then
      printf '%s\n' "${GH_STUB_PR_MERGE_ERROR:-merge failed}" >&2
      exit "${GH_STUB_PR_MERGE_EXIT}"
    fi
    if [ "${GH_STUB_PR_MERGE_UPDATE_MAIN:-0}" -eq 1 ] 2>/dev/null; then
      git branch -f main HEAD >/dev/null 2>&1 || true
    fi
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
    if [ -n "$body_file" ] && [ -f "$body_file" ] && [ -n "${GH_STUB_PR_CREATE_BODY_COPY_FILE:-}" ]; then
      cat "$body_file" > "$GH_STUB_PR_CREATE_BODY_COPY_FILE"
    fi
    if [ -n "$body_file" ] && [ -f "$body_file" ] && [ -n "${GH_STUB_PR_CREATE_BODY_CONTENT_FILE:-}" ]; then
      cat "$body_file" > "$GH_STUB_PR_CREATE_BODY_CONTENT_FILE"
    fi
    printf '%s\n' "${GH_STUB_PR_CREATE_URL:-https://github.com/i-schuyler/repo-automation-template/pull/123}"
    ;;
  'pr edit')
    body_file=""
    number="${1:-}"
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
    if [ -n "$body_file" ] && [ -f "$body_file" ] && [ -n "${GH_STUB_PR_EDIT_BODY_COPY_FILE:-}" ]; then
      cat "$body_file" > "$GH_STUB_PR_EDIT_BODY_COPY_FILE"
    fi
    if [ -n "$body_file" ] && [ -f "$body_file" ] && [ -n "${GH_STUB_PR_EDIT_BODY_CONTENT_FILE:-}" ]; then
      cat "$body_file" > "$GH_STUB_PR_EDIT_BODY_CONTENT_FILE"
    fi
    ;;
  'pr list')
    case " $* " in
      *' --jq '*)
        printf '%s\n' "${GH_STUB_PR_LIST_NUMBER:-}"
        ;;
      *)
        printf '%s\n' "${GH_STUB_PR_LIST_JSON:-[]}"
        ;;
    esac
    ;;
  'run list')
    if [ -n "${GH_STUB_RUN_LIST_LOG_FILE:-}" ]; then
      printf '%s\n' "gh run list $*" >> "$GH_STUB_RUN_LIST_LOG_FILE"
    fi
    if [ -n "${GH_STUB_RUN_LIST_SEQUENCE_FILE:-}" ] && [ -f "$GH_STUB_RUN_LIST_SEQUENCE_FILE" ]; then
      first_line="$(sed -n '1p' "$GH_STUB_RUN_LIST_SEQUENCE_FILE" 2>/dev/null || true)"
      rest_lines="$(sed -n '2,$p' "$GH_STUB_RUN_LIST_SEQUENCE_FILE" 2>/dev/null || true)"
      if [ -n "$first_line" ]; then
        printf '%s\n' "$first_line"
        printf '%s\n' "$rest_lines" > "$GH_STUB_RUN_LIST_SEQUENCE_FILE"
      else
        printf '%s\n' "${GH_STUB_RUN_LIST_JSON:-[]}"
      fi
    elif [ -n "${GH_STUB_RUN_LIST_FAIL_ONCE_FILE:-}" ] && [ ! -e "${GH_STUB_RUN_LIST_FAIL_ONCE_FILE}" ]; then
      : > "$GH_STUB_RUN_LIST_FAIL_ONCE_FILE"
      printf '%s\n' "${GH_STUB_RUN_LIST_FAIL_ONCE_STDERR:-net/http: TLS handshake timeout}" >&2
      exit 1
    else
      printf '%s\n' "${GH_STUB_RUN_LIST_JSON:-[]}"
    fi
    ;;
  'run view')
    if [ -n "${GH_STUB_RUN_VIEW_ALWAYS_FAIL_STDERR:-}" ]; then
      printf '%s\n' "${GH_STUB_RUN_VIEW_ALWAYS_FAIL_STDERR}" >&2
      exit 1
    fi
    if [ -n "${GH_STUB_RUN_VIEW_FAIL_ONCE_FILE:-}" ] && [ ! -e "${GH_STUB_RUN_VIEW_FAIL_ONCE_FILE}" ]; then
      : > "$GH_STUB_RUN_VIEW_FAIL_ONCE_FILE"
      printf '%s\n' "${GH_STUB_RUN_VIEW_FAIL_ONCE_STDERR:-net/http: TLS handshake timeout}" >&2
      exit 1
    fi
    if [ -n "${GH_STUB_RUN_VIEW_CALLED_FILE:-}" ]; then
      : > "$GH_STUB_RUN_VIEW_CALLED_FILE"
    fi
    if [ "${GH_STUB_RUN_VIEW_EMPTY:-0}" -eq 1 ] 2>/dev/null; then
      exit 0
    fi
    case " $* " in
      *' --log-failed '*)
        printf '%s\n' "${GH_STUB_RUN_VIEW_FAILED_LOG:-}"
        ;;
      *)
        printf '%s\n' "${GH_STUB_RUN_VIEW_LOG:-}"
        ;;
    esac
    ;;
  'api repos/'*)
    endpoint="$sub"
    case "$endpoint" in
      */actions/permissions)
        printf '%s\n' "${GH_STUB_ACTIONS_PERMISSIONS_JSON:-{\"enabled\":true,\"allowed_actions\":\"all\"}}"
        ;;
      */branches/*/protection)
        printf '%s\n' "${GH_STUB_BRANCH_PROTECTION_JSON:-{\"required_status_checks\":{}}}"
        ;;
      */rulesets)
        printf '%s\n' "${GH_STUB_RULESETS_JSON:-[]}"
        ;;
      *)
        printf '%s\n' "${GH_STUB_REPO_JSON:-{\"default_branch\":\"main\",\"delete_branch_on_merge\":true,\"allow_merge_commit\":true,\"allow_squash_merge\":true,\"allow_rebase_merge\":true}}"
        ;;
    esac
    ;;
  *)
    printf 'gh stub unexpected command: %s %s\n' "$cmd" "$sub" >&2
    exit 1
    ;;
esac
EOF
  chmod +x "$gh_stub_dir/gh" || return 1
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
