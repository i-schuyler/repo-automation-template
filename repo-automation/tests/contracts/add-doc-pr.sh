#!/usr/bin/env bash
# repo-automation/tests/contracts/add-doc-pr.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/smoke-common.sh"
# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/../lib/contracts/pr-workflow.sh"

smoke_main() {
  local status=0

  trap 'test_cleanup' EXIT INT TERM

  smoke_setup_temp_repo || return 1

  smoke_run_named_check "smoke:add-doc-pr-docs-only" smoke_check_add_doc_pr_docs_only || status=1
  smoke_run_named_check "smoke:add-doc-pr-blocked-file" smoke_check_add_doc_pr_blocked_file || status=1

  return "$status"
}

smoke_main "$@"
# repo-automation/tests/contracts/add-doc-pr.sh EOF
