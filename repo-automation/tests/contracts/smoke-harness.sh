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
  local qde_fixture="$base_dir/qde-fixture.txt"
  local body_wrapper_help_fix=""

  cat > "$qde_fixture" <<'EOF'
result=fail
code=example-code
step=example-step
reason=example reason
fix=example fix
path=/tmp/example-path
artifact=/tmp/example-artifact
log=/tmp/example-log
excerpt=example excerpt
EOF

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
  body_wrapper_help_fix="run $body_wrapper --help"

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
  elif [ ! -s "$stderr_file" ] && python3 -m json.tool "$json_file" >/dev/null && smoke_json_assert "$json_file" 'data.get("schema") == "repo-automation-helper-output/v1" and data.get("script") == "actionable" and data.get("mode") == "json" and data.get("result") == "fail" and data.get("code") == "named-check-failed" and data.get("step") == "smoke:harness-actionable-check" and data.get("reason") == "focused inner failure" and data.get("fix") == "inspect the failing check" and data.get("first_failure", {}).get("check") == "smoke:harness-actionable-check" and data.get("first_failure", {}).get("message") == "focused inner failure"'; then
    test_pass "smoke harness json preserves first failure"
  else
    test_fail "smoke harness json preserves first failure"
    status=1
  fi

  if "$silent_wrapper" --json > "$json_file" 2> "$stderr_file"; then
    test_fail "smoke harness json silent failure includes actionable fields"
    status=1
  elif [ ! -s "$stderr_file" ] && python3 -m json.tool "$json_file" >/dev/null && smoke_json_assert "$json_file" 'data.get("schema") == "repo-automation-helper-output/v1" and data.get("script") == "silent" and data.get("mode") == "json" and data.get("result") == "fail" and data.get("code") == "named-check-failed" and data.get("step") == "smoke:harness-silent-check" and data.get("reason") == "smoke:harness-silent-check: check failed without actionable captured output" and data.get("fix") == "patch the failing check to emit fail/FAIL/STOP/ERROR before returning nonzero" and data.get("log")'; then
    test_pass "smoke harness json silent failure includes actionable fields"
  else
    test_fail "smoke harness json silent failure includes actionable fields"
    status=1
  fi

  if "$body_wrapper" --json > "$json_file" 2> "$stderr_file"; then
    test_fail "smoke harness json body failure includes actionable fields"
    status=1
  elif [ ! -s "$stderr_file" ] && python3 -m json.tool "$json_file" >/dev/null && smoke_json_assert "$json_file" 'data.get("schema") == "repo-automation-helper-output/v1" and data.get("script") == "body" and data.get("mode") == "json" and data.get("result") == "fail" and data.get("code") == "test-wrapper-body-failed" and data.get("step") == "smoke_harness_main_impl" and data.get("reason") == "smoke_harness_main_impl: wrapper body failed before reporting an actionable check" and data.get("fix") == "patch the wrapper body to emit fail/FAIL/STOP/ERROR or a named check failure before returning nonzero" and data.get("log")'; then
    test_pass "smoke harness json body failure includes actionable fields"
  else
    test_fail "smoke harness json body failure includes actionable fields"
    status=1
  fi

  if smoke_assert_quiet_failure_envelope "$qde_fixture" "example-code" "example-step" "example reason" "example fix" "/tmp/example-path" "/tmp/example-artifact" "/tmp/example-log" "example excerpt"; then
    test_pass "smoke harness quiet envelope helper supports optional fields"
  else
    test_fail "smoke harness quiet envelope helper supports optional fields"
    status=1
  fi

  if "$body_wrapper" --quiet --explain > "$stdout_file" 2> "$stderr_file"; then
    test_fail "smoke harness rejects quiet explain conflict"
    status=1
  elif smoke_assert_quiet_failure_envelope "$stderr_file" "output-mode-conflict" "output-mode-parse" "incompatible output mode flags: --quiet --explain" "use exactly one of --quiet, --explain, or --json" && [ ! -s "$stdout_file" ]; then
    test_pass "smoke harness rejects quiet explain conflict"
  else
    test_fail "smoke harness rejects quiet explain conflict"
    status=1
  fi

  if "$body_wrapper" --json --explain > "$json_file" 2> "$stderr_file"; then
    test_fail "smoke harness rejects json explain conflict"
    status=1
  elif [ ! -s "$stderr_file" ] && python3 -m json.tool "$json_file" >/dev/null && smoke_json_assert "$json_file" 'data.get("schema") == "repo-automation-helper-output/v1" and data.get("script") == "body" and data.get("mode") == "json" and data.get("result") == "fail" and data.get("status") == "fail" and data.get("code") == "output-mode-conflict" and data.get("step") == "output-mode-parse" and data.get("reason") == "incompatible output mode flags: --json --explain" and data.get("fix") == "use exactly one of --quiet, --explain, or --json" and data.get("pass_count") == 0 and data.get("fail_count") == 0 and data.get("warn_count") == 0'; then
    test_pass "smoke harness rejects json explain conflict"
  else
    test_fail "smoke harness rejects json explain conflict"
    status=1
  fi

  if "$body_wrapper" --quiet --bogus > "$stdout_file" 2> "$stderr_file"; then
    test_fail "smoke harness rejects quiet unknown flag"
    status=1
  elif smoke_assert_quiet_failure_envelope "$stderr_file" "unknown-flag" "output-mode-parse" "unknown flag: --bogus" "$body_wrapper_help_fix" && [ ! -s "$stdout_file" ]; then
    test_pass "smoke harness rejects quiet unknown flag"
  else
    test_fail "smoke harness rejects quiet unknown flag"
    status=1
  fi

  if "$body_wrapper" --bogus > "$stdout_file" 2> "$stderr_file"; then
    test_fail "smoke harness rejects default unknown flag"
    status=1
  elif grep -Fxq 'fail: unknown flag: --bogus' "$stderr_file" && grep -Fxq "fix: $body_wrapper_help_fix" "$stderr_file" && [ ! -s "$stdout_file" ]; then
    test_pass "smoke harness rejects default unknown flag"
  else
    test_fail "smoke harness rejects default unknown flag"
    status=1
  fi

  if "$body_wrapper" --json --bogus > "$json_file" 2> "$stderr_file"; then
    test_fail "smoke harness rejects json unknown flag"
    status=1
  elif [ ! -s "$stderr_file" ] && python3 -m json.tool "$json_file" >/dev/null && smoke_json_assert "$json_file" "data.get(\"schema\") == \"repo-automation-helper-output/v1\" and data.get(\"script\") == \"body\" and data.get(\"mode\") == \"json\" and data.get(\"result\") == \"fail\" and data.get(\"status\") == \"fail\" and data.get(\"code\") == \"unknown-flag\" and data.get(\"step\") == \"output-mode-parse\" and data.get(\"reason\") == \"unknown flag: --bogus\" and data.get(\"fix\") == \"$body_wrapper_help_fix\""; then
    test_pass "smoke harness rejects json unknown flag"
  else
    test_fail "smoke harness rejects json unknown flag"
    status=1
  fi

  if "$body_wrapper" --quiet bogus > "$stdout_file" 2> "$stderr_file"; then
    test_fail "smoke harness rejects quiet unknown argument"
    status=1
  elif smoke_assert_quiet_failure_envelope "$stderr_file" "unknown-argument" "output-mode-parse" "unknown argument: bogus" "$body_wrapper_help_fix" && [ ! -s "$stdout_file" ]; then
    test_pass "smoke harness rejects quiet unknown argument"
  else
    test_fail "smoke harness rejects quiet unknown argument"
    status=1
  fi

  if "$body_wrapper" bogus > "$stdout_file" 2> "$stderr_file"; then
    test_fail "smoke harness rejects default unknown argument"
    status=1
  elif grep -Fxq 'fail: unknown argument: bogus' "$stderr_file" && grep -Fxq "fix: $body_wrapper_help_fix" "$stderr_file" && [ ! -s "$stdout_file" ]; then
    test_pass "smoke harness rejects default unknown argument"
  else
    test_fail "smoke harness rejects default unknown argument"
    status=1
  fi

  if "$body_wrapper" --json bogus > "$json_file" 2> "$stderr_file"; then
    test_fail "smoke harness rejects json unknown argument"
    status=1
  elif [ ! -s "$stderr_file" ] && python3 -m json.tool "$json_file" >/dev/null && smoke_json_assert "$json_file" "data.get(\"schema\") == \"repo-automation-helper-output/v1\" and data.get(\"script\") == \"body\" and data.get(\"mode\") == \"json\" and data.get(\"result\") == \"fail\" and data.get(\"status\") == \"fail\" and data.get(\"code\") == \"unknown-argument\" and data.get(\"step\") == \"output-mode-parse\" and data.get(\"reason\") == \"unknown argument: bogus\" and data.get(\"fix\") == \"$body_wrapper_help_fix\""; then
    test_pass "smoke harness rejects json unknown argument"
  else
    test_fail "smoke harness rejects json unknown argument"
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
