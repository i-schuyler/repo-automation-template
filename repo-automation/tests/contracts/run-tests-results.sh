#!/usr/bin/env bash
# repo-automation/tests/contracts/run-tests-results.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/contracts/run-tests-results.sh"

smoke_main_impl() {
  local status=0

  trap 'test_cleanup' EXIT INT TERM

  smoke_run_named_check "smoke:run-tests-results-contract" smoke_check_run_tests_results_contract || status=1

  return "$status"
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_main_impl "$@"
}

smoke_main "$@"
# repo-automation/tests/contracts/run-tests-results.sh EOF
