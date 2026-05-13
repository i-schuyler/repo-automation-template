#!/usr/bin/env bash
# repo-automation/tests/contracts/pr-create.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"

smoke_main() {
  local status=0

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1

  smoke_run_named_check "smoke:pr-create-body-file" smoke_check_pr_create_body_file || status=1
  smoke_run_named_check "smoke:pr-create-body-text" smoke_check_pr_create_body_text || status=1

  return "$status"
}

smoke_main "$@"
# repo-automation/tests/contracts/pr-create.sh EOF
