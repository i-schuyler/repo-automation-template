#!/usr/bin/env bash
# repo-automation/tests/smoke.sh

set -u
set -o pipefail

# shellcheck source=/dev/null
source "$(cd "$(dirname "$0")" && pwd)/lib/smoke-common.sh"

smoke_main() {
  smoke_run "$@"
}

smoke_main "$@"
# repo-automation/tests/smoke.sh EOF
