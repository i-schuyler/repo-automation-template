# repo-automation/tests/lib/contracts/run-tests-json.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# shellcheck disable=SC2034
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.

smoke_check_run_tests_json_contract() {
  local status=0
  local json_out="$smoke_test_base/run-tests-json-$$.json"

  # shellcheck source=/dev/null
  source "$smoke_repo_root/repo-automation/lib/run-tests-json.sh" || return 1

  run_tests_log_status_value() { printf '%s\n' "${RUN_TESTS_LOG_STATUS_VALUE:-none}"; }
  run_tests_log_file_value() { printf '%s\n' "${RUN_TESTS_LOG_FILE_VALUE:-}"; }
  run_tests_log_fix_value() { printf '%s\n' "${RUN_TESTS_LOG_FIX_VALUE:-}"; }
  run_tests_log_policy_value() { printf '%s\n' "${RUN_TESTS_LOG_POLICY_VALUE:-run-temp-cleaned-by-default}"; }

  if [ "$(run_tests_json_escape "$(printf 'a\\\"b\nc\rd\t')")" = 'a\\\"b\nc\rd\t' ]; then
    test_pass "run-tests json escape handles special characters"
  else
    test_fail "run-tests json escape handles special characters"
    status=1
  fi

  run_tests_mode="summary"
  run_tests_run_mode="full"
  run_tests_json_level="all"
  run_tests_checks=(
    "pass one|pass|0|p"
    "warn one|warn|0|w"
    "fail one|fail|1|f"
    "skip one|skipped|0|s"
  )
  RUN_TESTS_LOG_STATUS_VALUE="path" RUN_TESTS_LOG_FILE_VALUE="/tmp/run-tests.log" RUN_TESTS_LOG_FIX_VALUE="inspect log" RUN_TESTS_LOG_POLICY_VALUE="run-temp-cleaned-by-default" \
    run_tests_print_json "warn" 1 1 1 1 >"$json_out"
  if python3 - "$json_out" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding='utf-8'))
assert data["script"] == "run-tests"
assert data["mode"] == "summary"
assert data["overall_status"] == "warn"
assert data["pass_count"] == 1
assert data["warn_count"] == 1
assert data["fail_count"] == 1
assert data["skipped_count"] == 1
assert data["json_level"] == "all"
assert [check["status"] for check in data["checks"]] == ["pass", "warn", "fail", "skipped"]
assert all(isinstance(check["timed_out"], bool) for check in data["checks"])
assert data["log_status"] == "path"
assert data["log_policy"] == "run-temp-cleaned-by-default"
assert data["log_file"] == "/tmp/run-tests.log"
assert data["log_fix"] == "inspect log"
PY
  then
    test_pass "run-tests json render emits base fields and counts"
  else
    test_fail "run-tests json render emits base fields and counts"
    status=1
  fi

  run_tests_run_mode="full"
  run_tests_json_level="fail"
  run_tests_checks=(
    "pass one|pass|0|p"
    "warn one|warn|0|w"
    "fail one|fail|1|f"
    "skip one|skipped|0|s"
  )
  RUN_TESTS_LOG_STATUS_VALUE="none" RUN_TESTS_LOG_FILE_VALUE="" RUN_TESTS_LOG_FIX_VALUE="" RUN_TESTS_LOG_POLICY_VALUE="run-temp-cleaned-by-default" \
    run_tests_print_json "fail" 0 0 1 0 >"$json_out"
  if python3 - "$json_out" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding='utf-8'))
assert [check["status"] for check in data["checks"]] == ["fail"]
assert data["log_status"] == "none"
assert data["log_policy"] == "run-temp-cleaned-by-default"
assert data["log_file"] == ""
assert "log_fix" not in data
assert data["checks"][0]["timed_out"] is True
PY
  then
    test_pass "run-tests json level fail includes only failed checks"
  else
    test_fail "run-tests json level fail includes only failed checks"
    status=1
  fi

  run_tests_run_mode="full"
  run_tests_json_level="warn"
  run_tests_checks=(
    "pass one|pass|0|p"
    "warn one|warn|0|w"
    "fail one|fail|1|f"
    "skip one|skipped|0|s"
  )
  RUN_TESTS_LOG_STATUS_VALUE="path" RUN_TESTS_LOG_FILE_VALUE="/tmp/log.txt" RUN_TESTS_LOG_FIX_VALUE="fix me" RUN_TESTS_LOG_POLICY_VALUE="kept" \
    run_tests_print_json "warn" 1 1 1 1 >"$json_out"
  if python3 - "$json_out" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding='utf-8'))
assert [check["status"] for check in data["checks"]] == ["warn", "fail"]
assert data["log_status"] == "path"
assert data["log_policy"] == "kept"
assert data["log_file"] == "/tmp/log.txt"
assert data["log_fix"] == "fix me"
PY
  then
    test_pass "run-tests json level warn includes fail and warn checks"
  else
    test_fail "run-tests json level warn includes fail and warn checks"
    status=1
  fi

  run_tests_run_mode="changed"
  run_tests_changed_selected_subsets=("docs" "version" "smoke")
  run_tests_json_level="all"
  run_tests_checks=(
    "pass one|pass|0|p"
    "warn one|warn|0|w"
    "fail one|fail|1|f"
    "skip one|skipped|0|s"
  )
  RUN_TESTS_LOG_STATUS_VALUE="path" RUN_TESTS_LOG_FILE_VALUE="/tmp/changed.log" RUN_TESTS_LOG_FIX_VALUE="" RUN_TESTS_LOG_POLICY_VALUE="changed-policy" \
    run_tests_print_json "warn" 1 1 1 1 >"$json_out"
  if python3 - "$json_out" <<'PY'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding='utf-8'))
assert [check["status"] for check in data["checks"]] == ["pass", "warn", "fail", "skipped"]
assert data["selected_subsets"] == ["docs", "version", "smoke"]
assert data["log_status"] == "path"
assert data["log_policy"] == "changed-policy"
assert data["log_file"] == "/tmp/changed.log"
assert "log_fix" not in data
assert all(isinstance(check["timed_out"], bool) for check in data["checks"])
PY
  then
    test_pass "run-tests json level all includes all checks and subset order"
  else
    test_fail "run-tests json level all includes all checks and subset order"
    status=1
  fi

  rm -f "$json_out" >/dev/null 2>&1 || true
  return "$status"
}

# repo-automation/tests/lib/contracts/run-tests-json.sh EOF
