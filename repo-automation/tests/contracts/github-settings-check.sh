#!/usr/bin/env bash
# repo-automation/tests/contracts/github-settings-check.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/contracts/github-settings.sh"

smoke_main_impl() {
  local status=0

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1

  smoke_run_named_check "smoke:github-settings-check" smoke_check_github_settings_contract || status=1

  return "$status"
}

smoke_main() {
  smoke_run_focused_contract_wrapper smoke_main_impl "$@"
}

smoke_main "$@"
# repo-automation/tests/contracts/github-settings-check.sh EOF
