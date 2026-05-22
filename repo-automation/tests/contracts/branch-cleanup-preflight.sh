#!/usr/bin/env bash
# repo-automation/tests/contracts/branch-cleanup-preflight.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/contracts/pr-workflow.sh"

smoke_main_impl() {
  smoke_setup_temp_repo || return 1
  smoke_run_named_check "smoke:branch-cleanup-json" smoke_check_branch_cleanup_json
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_main_impl "$@"
}

smoke_main "$@"
# repo-automation/tests/contracts/branch-cleanup-preflight.sh EOF
