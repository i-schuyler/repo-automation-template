#!/usr/bin/env bash
# repo-automation/tests/contracts/pr-body-check.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/contracts/pr-workflow.sh"

smoke_main_impl() {
  local status=0
  local smoke_test_base=""
  local smoke_test_dir=""
  local smoke_remote_dir=""
  local helper_dir=""
  local lib_dir=""
  local tests_dir=""
  local tests_lib_dir=""
  local tests_contracts_dir=""

  trap 'test_cleanup' EXIT INT TERM

  mkdir -p "$TEST_TEMP_ROOT" || return 1
  smoke_test_base="$(mktemp -d "${TEST_TEMP_ROOT}/smoke.XXXXXX")" || return 1
  test_register_temp_dir "$smoke_test_base" || return 1
  smoke_test_dir="$smoke_test_base/smoke"
  smoke_remote_dir="$smoke_test_base/smoke-remote.git"
  helper_dir="$smoke_test_dir/repo-automation/bin"
  lib_dir="$smoke_test_dir/repo-automation/lib"
  tests_dir="$smoke_test_dir/repo-automation/tests"
  tests_lib_dir="$tests_dir/lib"
  tests_contracts_dir="$tests_dir/contracts"
  mkdir -p "$helper_dir" "$lib_dir" "$tests_lib_dir/contracts" "$tests_contracts_dir" "$smoke_test_dir/.github" || return 1
  cp "$smoke_repo_root/repo-automation/bin/pr-body-check" "$helper_dir/pr-body-check" || return 1
  chmod +x "$helper_dir/pr-body-check" || return 1
  cp "$smoke_repo_root/repo-automation/lib/common.sh" "$lib_dir/common.sh" || return 1
  cp "$smoke_repo_root/.github/pull_request_template.md" "$smoke_test_dir/.github/pull_request_template.md" || return 1
  cp "$smoke_repo_root/repo-automation/tests/lib/test-common.sh" "$tests_lib_dir/test-common.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/lib/smoke-common.sh" "$tests_lib_dir/smoke-common.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/lib/smoke-fixtures.sh" "$tests_lib_dir/smoke-fixtures.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/lib/smoke-gh-stub.sh" "$tests_lib_dir/smoke-gh-stub.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/lib/smoke-capture.sh" "$tests_lib_dir/smoke-capture.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/lib/contracts/pr-workflow.sh" "$tests_lib_dir/contracts/pr-workflow.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/contracts/pr-body-check.sh" "$tests_contracts_dir/pr-body-check.sh" || return 1
  chmod +x "$tests_contracts_dir/pr-body-check.sh" || return 1
  export smoke_test_base smoke_test_dir smoke_remote_dir smoke_repo_root smoke_timeout_seconds

  smoke_run_named_check "smoke:pr-body-check-contract" smoke_check_pr_body_check_contract || status=1

  return "$status"
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_main_impl "$@"
}

smoke_main "$@"
# repo-automation/tests/contracts/pr-body-check.sh EOF
