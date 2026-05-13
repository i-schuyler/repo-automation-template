#!/usr/bin/env bash
# repo-automation/tests/contracts/report-upstream.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"

smoke_main() {
  local status=0

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1

  smoke_run_named_check "smoke:report-upstream-preview" smoke_check_report_upstream_preview || status=1
  smoke_run_named_check "smoke:report-upstream-secret-scan" smoke_check_report_upstream_secret_scan || status=1

  return "$status"
}

smoke_main "$@"
# repo-automation/tests/contracts/report-upstream.sh EOF
