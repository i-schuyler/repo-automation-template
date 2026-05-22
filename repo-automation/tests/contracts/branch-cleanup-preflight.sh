#!/usr/bin/env bash
# repo-automation/tests/contracts/branch-cleanup-preflight.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/contracts/pr-workflow.sh"

smoke_main_impl() {
  local status=0

  # shellcheck disable=SC2034 # Used by shared harness helpers.
  TEST_OUTPUT_SCRIPT="branch-cleanup-preflight"
  smoke_parse_output_mode "$@" || return 1
  # shellcheck disable=SC2154 # Set by smoke_parse_output_mode.
  if [ "$smoke_help_requested" -eq 1 ]; then
    return 0
  fi

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1

  if [ "$TEST_OUTPUT_MODE" = "json" ]; then
    smoke_run_named_check "smoke:branch-cleanup-json" smoke_check_branch_cleanup_json >/dev/null 2>&1 || status=1
  else
    smoke_run_named_check "smoke:branch-cleanup-json" smoke_check_branch_cleanup_json || status=1
  fi

  return "$status"
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_main_impl "$@"
}

smoke_main "$@"
# repo-automation/tests/contracts/branch-cleanup-preflight.sh EOF
