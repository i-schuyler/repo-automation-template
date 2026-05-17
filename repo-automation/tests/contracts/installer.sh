#!/usr/bin/env bash
# repo-automation/tests/contracts/installer.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/contracts/install-release.sh"

smoke_main() {
  local status=0

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1

  smoke_run_named_check "smoke:installer-apply-contract" smoke_check_installer_apply_contract || status=1

  return "$status"
}

smoke_main "$@"
# repo-automation/tests/contracts/installer.sh EOF
