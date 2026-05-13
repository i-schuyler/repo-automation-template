#!/usr/bin/env bash
# repo-automation/tests/smoke.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/lib/smoke-common.sh"

smoke_main() {
  local status=0
  local i=0

  trap 'test_cleanup' EXIT INT TERM

  cd "$smoke_repo_root" || return 1

  if [ "$smoke_timeout_seconds" -gt 0 ] && ! test_have_timeout; then
    test_warn_timeout_once
  fi

  for i in "${!smoke_contract_scripts[@]}"; do
    test_run_named_check "${smoke_contract_names[$i]}" "${smoke_contract_scripts[$i]}" || status=1
  done

  return "$status"
}

smoke_main "$@"
# repo-automation/tests/smoke.sh EOF
