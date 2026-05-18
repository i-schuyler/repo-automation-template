#!/usr/bin/env bash
# repo-automation/tests/contracts/repo-doctor.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/contracts/repo-health.sh"

smoke_main() {
  local status=0

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1

  smoke_run_named_check "smoke:repo-doctor-contract" smoke_check_repo_doctor_contract || status=1
  smoke_run_named_check "smoke:repo-config-local-override-contract" smoke_check_repo_config_local_override_contract || status=1
  smoke_run_named_check "smoke:repo-doctor-artifact-guard" smoke_check_repo_doctor_artifact_guard || status=1
  smoke_run_named_check "smoke:repo-doctor-missing-config" smoke_check_repo_doctor_missing_config || status=1

  return "$status"
}

smoke_main "$@"
# repo-automation/tests/contracts/repo-doctor.sh EOF
