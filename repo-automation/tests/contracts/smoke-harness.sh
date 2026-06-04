#!/usr/bin/env bash
# repo-automation/tests/contracts/smoke-harness.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"

smoke_harness_actionable_check() {
  printf 'FAIL: focused inner failure\n' >&2
  return 1
}

smoke_harness_silent_check() {
  return 1
}

smoke_harness_main_impl() {
  local status=0
  local base_dir=""
  base_dir="$(mktemp -d "${TEST_TEMP_ROOT}/smoke-harness.XXXXXX")" || return 1
  test_register_temp_dir "$base_dir" || return 1
  local actionable_wrapper="$base_dir/actionable.sh"
  local silent_wrapper="$base_dir/silent.sh"
  local body_wrapper="$base_dir/body.sh"
  local stdout_file="$base_dir/stdout.txt"
  local stderr_file="$base_dir/stderr.txt"
  local json_file="$base_dir/out.json"

  cat > "$actionable_wrapper" <<EOF
#!/usr/bin/env bash
set -u
set -o pipefail

# shellcheck source=/dev/null
source "__SMOKE_COMMON__"

smoke_harness_main_impl() {
  smoke_run_named_check "smoke:harness-actionable-check" smoke_harness_actionable_check
}

smoke_harness_actionable_check() {
  printf 'FAIL: focused inner failure\n' >&2
  return 1
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_harness_main_impl "\$@"
}

smoke_main "\$@"
EOF
  sed -i "s#__SMOKE_COMMON__#$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh#g" "$actionable_wrapper"
  chmod +x "$actionable_wrapper" || return 1

  cat > "$silent_wrapper" <<EOF
#!/usr/bin/env bash
set -u
set -o pipefail

# shellcheck source=/dev/null
source "__SMOKE_COMMON__"

smoke_harness_main_impl() {
  smoke_run_named_check "smoke:harness-silent-check" smoke_harness_silent_check
}

smoke_harness_silent_check() {
  return 1
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_harness_main_impl "\$@"
}

smoke_main "\$@"
EOF
  sed -i "s#__SMOKE_COMMON__#$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh#g" "$silent_wrapper"
  chmod +x "$silent_wrapper" || return 1

  cat > "$body_wrapper" <<EOF
#!/usr/bin/env bash
set -u
set -o pipefail

# shellcheck source=/dev/null
source "__SMOKE_COMMON__"

smoke_harness_main_impl() {
  return 1
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_harness_main_impl "\$@"
}

smoke_main "\$@"
EOF
  sed -i "s#__SMOKE_COMMON__#$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh#g" "$body_wrapper"
  chmod +x "$body_wrapper" || return 1

  if "$actionable_wrapper" --quiet > "$stdout_file" 2> "$stderr_file"; then
    test_fail "smoke harness actionable quiet should fail"
    status=1
  elif grep -Fxq 'result=fail' "$stderr_file" && grep -Fxq 'code=named-check-failed' "$stderr_file" && grep -Fxq 'step=smoke:harness-actionable-check' "$stderr_file" && grep -Fxq 'reason=focused inner failure' "$stderr_file" && grep -Fxq 'fix=inspect the failing check' "$stderr_file" && [ ! -s "$stdout_file" ]; then
    test_pass "smoke harness actionable quiet failure is actionable"
  else
    test_fail "smoke harness actionable quiet failure is actionable"
    status=1
  fi

  if "$actionable_wrapper" > "$stdout_file" 2> "$stderr_file"; then
    test_fail "smoke harness actionable default should fail"
    status=1
  elif grep -Fxq 'fail: smoke:harness-actionable-check: focused inner failure' "$stderr_file"; then
    if grep -Fxq 'fix: inspect the failing check' "$stderr_file"; then
      test_pass "smoke harness actionable default failure is compact"
    else
      test_fail "smoke harness actionable default failure is compact"
      status=1
    fi
  else
    test_fail "smoke harness actionable default failure is compact"
    status=1
  fi

  if "$silent_wrapper" --quiet > "$stdout_file" 2> "$stderr_file"; then
    test_fail "smoke harness silent quiet should fail"
    status=1
  elif grep -Fxq 'result=fail' "$stderr_file" && grep -Fxq 'code=named-check-failed' "$stderr_file" && grep -Fxq 'step=smoke:harness-silent-check' "$stderr_file" && grep -Fxq 'reason=smoke:harness-silent-check: check failed without actionable captured output' "$stderr_file" && grep -Fxq 'fix=patch the failing check to emit fail/FAIL/STOP/ERROR before returning nonzero' "$stderr_file" && grep -Eq '^log=.+$' "$stderr_file" && [ ! -s "$stdout_file" ]; then
    test_pass "smoke harness silent quiet failure is actionable"
  else
    test_fail "smoke harness silent quiet failure is actionable"
    status=1
  fi

  if "$body_wrapper" --quiet > "$stdout_file" 2> "$stderr_file"; then
    test_fail "smoke harness body quiet should fail"
    status=1
  elif grep -Fxq 'result=fail' "$stderr_file" && grep -Fxq 'code=test-wrapper-body-failed' "$stderr_file" && grep -Fxq 'step=smoke_harness_main_impl' "$stderr_file" && grep -Fxq 'reason=smoke_harness_main_impl: wrapper body failed before reporting an actionable check' "$stderr_file" && grep -Fxq 'fix=patch the wrapper body to emit fail/FAIL/STOP/ERROR or a named check failure before returning nonzero' "$stderr_file" && grep -Eq '^log=.+$' "$stderr_file" && [ ! -s "$stdout_file" ]; then
    test_pass "smoke harness body quiet failure is actionable"
  else
    test_fail "smoke harness body quiet failure is actionable"
    status=1
  fi

  if "$body_wrapper" > "$stdout_file" 2> "$stderr_file"; then
    test_fail "smoke harness body default should fail"
    status=1
  elif grep -Fxq 'fail: smoke_harness_main_impl: wrapper body failed before reporting an actionable check' "$stderr_file" && grep -Eq '^log: .+$' "$stderr_file" && grep -Fxq 'fix: patch the wrapper body to emit fail/FAIL/STOP/ERROR or a named check failure before returning nonzero' "$stderr_file"; then
    test_pass "smoke harness body default failure is compact"
  else
    test_fail "smoke harness body default failure is compact"
    status=1
  fi

  if "$actionable_wrapper" --json > "$json_file" 2> "$stderr_file"; then
    test_fail "smoke harness json preserves first failure"
    status=1
  elif python3 -m json.tool "$json_file" >/dev/null && smoke_json_assert "$json_file" 'data.get("first_failure", {}).get("check") == "smoke:harness-actionable-check" and data.get("first_failure", {}).get("message") == "focused inner failure"'; then
    test_pass "smoke harness json preserves first failure"
  else
    test_fail "smoke harness json preserves first failure"
    status=1
  fi

  rm -rf "$base_dir" >/dev/null 2>&1 || true
  return "$status"
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_harness_main_impl "$@"
}

smoke_main "$@"
# repo-automation/tests/contracts/smoke-harness.sh EOF
