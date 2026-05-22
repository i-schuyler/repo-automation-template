#!/usr/bin/env bash
# repo-automation/tests/contracts/check-tooling.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck disable=SC2154
# smoke_test_base, smoke_repo_root, TEST_OUTPUT_MODE, and TEST_TEMP_ROOT are
# shared harness globals initialized by repo-automation/tests/lib/smoke-common.sh.

smoke_check_tooling_make_fixture() {
  local fixture_dir="$1"
  shift
  local tool

  mkdir -p "$fixture_dir"
  for tool in "$@"; do
    printf '#!/usr/bin/env sh\nexit 0\n' > "$fixture_dir/$tool"
    chmod +x "$fixture_dir/$tool"
  done
}

smoke_check_tooling_show_capture() {
  local stdout_file="$1"
  local stderr_file="$2"

  if [ "$TEST_OUTPUT_MODE" = "explain" ]; then
    cat "$stdout_file"
    if [ -s "$stderr_file" ]; then
      cat "$stderr_file" >&2
    fi
  fi
}

smoke_check_tooling_run() {
  local stdout_file="$1"
  local stderr_file="$2"
  local fixture_dir="$3"
  local platform="$4"
  shift 4

  (
    # shellcheck disable=SC2154
    cd "$smoke_repo_root" || return 1
    REPO_AUTOMATION_TOOLING_PATH="$fixture_dir" \
      REPO_AUTOMATION_TOOLING_PLATFORM="$platform" \
      repo-automation/bin/check-tooling "$@"
  ) >"$stdout_file" 2>"$stderr_file"
}

smoke_check_tooling_help() {
  # shellcheck disable=SC2154
  local out="$smoke_test_base/check-tooling-help-$$.txt"
  local err="$smoke_test_base/check-tooling-help-$$.err"

  if (
    cd "$smoke_repo_root" || return 1
    repo-automation/bin/check-tooling --help >"$out" 2>"$err"
  ) && grep -Fqx 'Usage: repo-automation/bin/check-tooling [--help] [--quiet] [--explain] [--json]' "$out" &&
    grep -Fq -- '--quiet' "$out" &&
    grep -Fq -- '--explain' "$out" &&
    grep -Fq -- '--json' "$out" &&
    ! grep -Fq -- '--quiet=' "$out" &&
    ! grep -Fq -- '--json=' "$out" &&
    [ ! -s "$err" ]; then
    smoke_check_tooling_show_capture "$out" "$err"
    test_pass "check-tooling help shows strict flags"
  else
    smoke_check_tooling_show_capture "$out" "$err"
    test_fail "check-tooling help shows strict flags"
    return 1
  fi
}

smoke_check_tooling_all_present() {
  local fixture_dir="$smoke_test_base/check-tooling-all-$$"
  local out="$smoke_test_base/check-tooling-all-out-$$.txt"
  local err="$smoke_test_base/check-tooling-all-err-$$.txt"

  test_register_temp_dir "$fixture_dir" || return 1
  smoke_check_tooling_make_fixture "$fixture_dir" \
    bash git python3 sed awk find sort xargs df \
    gh shellcheck timeout du ssh

  if smoke_check_tooling_run "$out" "$err" "$fixture_dir" ubuntu-debian; then
    if [ "$(cat "$out")" = "pass" ] && [ ! -s "$err" ]; then
      smoke_check_tooling_show_capture "$out" "$err"
      return 0
    fi
  else
    return 1
  fi

  smoke_check_tooling_show_capture "$out" "$err"
  return 1
}

smoke_check_tooling_required_missing() {
  local fixture_dir="$smoke_test_base/check-tooling-required-$$"
  local out="$smoke_test_base/check-tooling-required-out-$$.txt"
  local err="$smoke_test_base/check-tooling-required-err-$$.txt"

  test_register_temp_dir "$fixture_dir" || return 1
  smoke_check_tooling_make_fixture "$fixture_dir" \
    bash git python3 sed find sort xargs df \
    gh shellcheck timeout du ssh

  if smoke_check_tooling_run "$out" "$err" "$fixture_dir" ubuntu-debian --quiet; then
    return 1
  fi

  if grep -Fqx 'fail: missing required tools' "$out" &&
    grep -Fqx 'missing: awk' "$out" &&
    grep -Fqx 'fix: sudo apt-get update && sudo apt-get install -y bash git python3 sed gawk findutils coreutils shellcheck gh openssh-client' "$out" &&
    [ ! -s "$err" ]; then
    smoke_check_tooling_show_capture "$out" "$err"
    return 0
  fi

  smoke_check_tooling_show_capture "$out" "$err"
  return 1
}

smoke_check_tooling_recommended_missing() {
  local fixture_dir="$smoke_test_base/check-tooling-recommended-$$"
  local out="$smoke_test_base/check-tooling-recommended-out-$$.txt"
  local err="$smoke_test_base/check-tooling-recommended-err-$$.txt"

  test_register_temp_dir "$fixture_dir" || return 1
  smoke_check_tooling_make_fixture "$fixture_dir" \
    bash git python3 sed awk find sort xargs df \
    timeout du ssh

  if smoke_check_tooling_run "$out" "$err" "$fixture_dir" ubuntu-debian; then
    if grep -Fqx 'warn: missing recommended tools' "$out" &&
      grep -Fqx 'recommended_missing: gh, shellcheck' "$out" &&
      grep -Fqx 'fix: sudo apt-get update && sudo apt-get install -y bash git python3 sed gawk findutils coreutils shellcheck gh openssh-client' "$out" &&
      [ ! -s "$err" ]; then
      smoke_check_tooling_show_capture "$out" "$err"
      return 0
    fi
  else
    return 1
  fi

  smoke_check_tooling_show_capture "$out" "$err"
  return 1
}

smoke_check_tooling_json() {
  local fixture_dir="$smoke_test_base/check-tooling-json-$$"
  local out="$smoke_test_base/check-tooling-json-out-$$.json"
  local err="$smoke_test_base/check-tooling-json-err-$$.txt"

  test_register_temp_dir "$fixture_dir" || return 1
  smoke_check_tooling_make_fixture "$fixture_dir" \
    bash git python3 sed awk find sort xargs df \
    timeout du ssh

  if smoke_check_tooling_run "$out" "$err" "$fixture_dir" ubuntu-debian --json; then
    if python3 -m json.tool "$out" >/dev/null &&
      smoke_json_assert "$out" 'data.get("script") == "check-tooling" and data.get("platform") == "ubuntu-debian" and data.get("status") == "warn" and data.get("required_missing") == [] and data.get("recommended_missing") == ["gh", "shellcheck"] and data.get("required_present") == ["bash", "git", "python3", "sed", "awk", "find", "sort", "xargs", "df"] and data.get("recommended_present") == ["timeout", "du", "ssh"] and data.get("fix") == "sudo apt-get update && sudo apt-get install -y bash git python3 sed gawk findutils coreutils shellcheck gh openssh-client"' &&
      [ ! -s "$err" ]; then
      smoke_check_tooling_show_capture "$out" "$err"
      return 0
    fi
  else
    return 1
  fi

  smoke_check_tooling_show_capture "$out" "$err"
  return 1
}

smoke_check_tooling_quiet_success() {
  local fixture_dir="$smoke_test_base/check-tooling-quiet-$$"
  local out="$smoke_test_base/check-tooling-quiet-out-$$.txt"
  local err="$smoke_test_base/check-tooling-quiet-err-$$.txt"

  test_register_temp_dir "$fixture_dir" || return 1
  smoke_check_tooling_make_fixture "$fixture_dir" \
    bash git python3 sed awk find sort xargs df \
    gh shellcheck timeout du ssh

  if smoke_check_tooling_run "$out" "$err" "$fixture_dir" ubuntu-debian --quiet; then
    [ ! -s "$out" ] && [ ! -s "$err" ]
  else
    return 1
  fi
}

smoke_check_tooling_explain() {
  local fixture_dir="$smoke_test_base/check-tooling-explain-$$"
  local out="$smoke_test_base/check-tooling-explain-out-$$.txt"
  local err="$smoke_test_base/check-tooling-explain-err-$$.txt"

  test_register_temp_dir "$fixture_dir" || return 1
  smoke_check_tooling_make_fixture "$fixture_dir" \
    bash git python3 sed awk find sort xargs df \
    gh shellcheck timeout du ssh

  if smoke_check_tooling_run "$out" "$err" "$fixture_dir" ubuntu-debian --explain; then
    if grep -Fqx 'status: pass' "$out" &&
      grep -Fqx 'platform: ubuntu-debian' "$out" &&
      grep -Fqx 'required_checked: bash, git, python3, sed, awk, find, sort, xargs, df' "$out" &&
      grep -Fqx 'required_present: bash, git, python3, sed, awk, find, sort, xargs, df' "$out" &&
      grep -Fqx 'recommended_checked: gh, shellcheck, timeout, du, ssh' "$out" &&
      grep -Fqx 'recommended_present: gh, shellcheck, timeout, du, ssh' "$out" &&
      [ ! -s "$err" ]; then
      smoke_check_tooling_show_capture "$out" "$err"
      return 0
    fi
  else
    return 1
  fi

  smoke_check_tooling_show_capture "$out" "$err"
  return 1
}

smoke_check_tooling_platform_fixes() {
  local platform=""
  local expected_fix=""
  local fixture_dir=""
  local out=""
  local err=""
  local status=0

  for platform in termux-android ubuntu-debian macos unknown; do
    case "$platform" in
      termux-android)
        expected_fix='pkg install bash git python sed gawk findutils coreutils xargs shellcheck gh openssh'
        ;;
      ubuntu-debian)
        expected_fix='sudo apt-get update && sudo apt-get install -y bash git python3 sed gawk findutils coreutils shellcheck gh openssh-client'
        ;;
      macos)
        expected_fix='brew install bash git python gnu-sed gawk findutils coreutils shellcheck gh openssh'
        ;;
      unknown)
        expected_fix='install missing tools with your platform package manager'
        ;;
    esac

    fixture_dir="$smoke_test_base/check-tooling-platform-$platform-$$"
    out="$smoke_test_base/check-tooling-platform-$platform-out-$$.txt"
    err="$smoke_test_base/check-tooling-platform-$platform-err-$$.txt"
    test_register_temp_dir "$fixture_dir" || return 1

    if smoke_check_tooling_run "$out" "$err" "$fixture_dir" "$platform"; then
      test_fail "check-tooling platform fix suggestion for $platform"
      status=1
      smoke_check_tooling_show_capture "$out" "$err"
      continue
    fi

    if ! grep -Fqx "fix: $expected_fix" "$out"; then
      test_fail "check-tooling platform fix suggestion for $platform"
      status=1
      smoke_check_tooling_show_capture "$out" "$err"
      continue
    fi

    smoke_check_tooling_show_capture "$out" "$err"
  done

  return "$status"
}

smoke_check_tooling_unknown_flag() {
  local fixture_dir="$smoke_test_base/check-tooling-unknown-$$"
  local out="$smoke_test_base/check-tooling-unknown-out-$$.txt"
  local err="$smoke_test_base/check-tooling-unknown-err-$$.txt"

  test_register_temp_dir "$fixture_dir" || return 1
  smoke_check_tooling_make_fixture "$fixture_dir" bash

  if smoke_check_tooling_run "$out" "$err" "$fixture_dir" ubuntu-debian --bogus; then
    return 1
  fi

  [ ! -s "$out" ] && smoke_assert_flag_error_shape "$err" "unknown flag" "--bogus" "run repo-automation/bin/check-tooling --help"
}

smoke_main_impl() {
  local status=0

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1

  smoke_run_named_check "smoke:check-tooling-help" smoke_check_tooling_help || status=1
  smoke_run_named_check "smoke:check-tooling-all-present" smoke_check_tooling_all_present || status=1
  smoke_run_named_check "smoke:check-tooling-required-missing" smoke_check_tooling_required_missing || status=1
  smoke_run_named_check "smoke:check-tooling-recommended-missing" smoke_check_tooling_recommended_missing || status=1
  smoke_run_named_check "smoke:check-tooling-json" smoke_check_tooling_json || status=1
  smoke_run_named_check "smoke:check-tooling-quiet-success" smoke_check_tooling_quiet_success || status=1
  smoke_run_named_check "smoke:check-tooling-explain" smoke_check_tooling_explain || status=1
  smoke_run_named_check "smoke:check-tooling-platform-fixes" smoke_check_tooling_platform_fixes || status=1
  smoke_run_named_check "smoke:check-tooling-unknown-flag" smoke_check_tooling_unknown_flag || status=1

  return "$status"
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_main_impl "$@"
}

smoke_main "$@"
# repo-automation/tests/contracts/check-tooling.sh EOF
