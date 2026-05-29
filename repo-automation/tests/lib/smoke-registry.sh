#!/usr/bin/env bash
# repo-automation/tests/lib/smoke-registry.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.

smoke_contract_names=(
  "smoke:add-doc-pr-contract"
  "smoke:pr-body-check-contract"
  "smoke:pr-create-contract"
  "smoke:report-upstream-contract"
  "smoke:failure-log-contract"
  "smoke:run-tests-contract"
  "smoke:run-tests-failure-contract"
  "smoke:run-tests-results-contract"
  "smoke:run-tests-json-contract"
  "smoke:run-tests-routing-contract"
  "smoke:test-timeout-contract"
  "smoke:touched-files-contract"
  "smoke:ci-status-watch-contract"
  "smoke:ci-log-dump-contract"
  "smoke:ci-failure-artifacts-contract"
  "smoke:contract-debt-report-contract"
  "smoke:repo-doctor-contract"
  "smoke:check-portability"
  "smoke:status-packet-contract"
  "smoke:post-codex-review-contract"
  "smoke:post-codex-packet-contract"
  "smoke:review-pack-contract"
  "smoke:pr-finish-watch-exit"
  "smoke:slice-handoff-contract"
  "smoke:repo-zip-contract"
  "smoke:evidence-bundle-contract"
  "smoke:repair-prompt-contract"
  "smoke:github-settings-check"
  "smoke:managed-file-tools"
  "smoke:shellcheck-ci-parity"
  "smoke:installer-contract"
  "smoke:starter-template-contract"
  "smoke:branch-cleanup-preflight"
  "smoke:check-tooling"
  "smoke:codex-slice-preflight"
  "smoke:prepare-release-contract"
  "smoke:automation-freshness-contract"
)

smoke_contract_scripts=(
  "repo-automation/tests/contracts/add-doc-pr.sh"
  "repo-automation/tests/contracts/pr-body-check.sh"
  "repo-automation/tests/contracts/pr-create.sh"
  "repo-automation/tests/contracts/report-upstream.sh"
  "repo-automation/tests/contracts/failure-log.sh"
  "repo-automation/tests/contracts/run-tests.sh"
  "repo-automation/tests/contracts/run-tests-failure.sh"
  "repo-automation/tests/contracts/run-tests-results.sh"
  "repo-automation/tests/contracts/run-tests-json.sh"
  "repo-automation/tests/contracts/run-tests-routing.sh"
  "repo-automation/tests/contracts/test-timeout.sh"
  "repo-automation/tests/contracts/touched-files.sh"
  "repo-automation/tests/contracts/ci-status-watch.sh"
  "repo-automation/tests/contracts/ci-log-dump.sh"
  "repo-automation/tests/contracts/ci-failure-artifacts.sh"
  "repo-automation/tests/contracts/contract-debt-report.sh"
  "repo-automation/tests/contracts/repo-doctor.sh"
  "repo-automation/tests/contracts/check-portability.sh"
  "repo-automation/tests/contracts/status-packet.sh"
  "repo-automation/tests/contracts/post-codex-review.sh"
  "repo-automation/tests/contracts/post-codex-packet.sh"
  "repo-automation/tests/contracts/review-pack.sh"
  "repo-automation/tests/contracts/pr-finish-watch.sh"
  "repo-automation/tests/contracts/slice-handoff.sh"
  "repo-automation/tests/contracts/repo-zip.sh"
  "repo-automation/tests/contracts/evidence-bundle.sh"
  "repo-automation/tests/contracts/repair-prompt.sh"
  "repo-automation/tests/contracts/github-settings-check.sh"
  "repo-automation/tests/contracts/managed-file-tools.sh"
  "repo-automation/tests/contracts/shellcheck-ci-parity.sh"
  "repo-automation/tests/contracts/installer.sh"
  "repo-automation/tests/contracts/starter-template.sh"
  "repo-automation/tests/contracts/branch-cleanup-preflight.sh"
  "repo-automation/tests/contracts/check-tooling.sh"
  "repo-automation/tests/contracts/codex-slice-preflight.sh"
  "repo-automation/tests/contracts/prepare-release.sh"
  "repo-automation/tests/contracts/automation-freshness.sh"
)

smoke_metadata_contract_paths=(
  "${smoke_contract_scripts[@]}"
  # repo-flow has a focused contract, but remains out of full smoke because it
  # exceeds the smoke named-check timeout in the full registry.
  "repo-automation/tests/contracts/repo-flow.sh"
)

smoke_validate_metadata_contract_registry() {
  local metadata_path="$smoke_repo_root/repo-automation/helper-metadata.json"
  local missing_paths=""

  missing_paths="$(python3 - "$metadata_path" "${smoke_metadata_contract_paths[@]}" <<'PY'
import json
import pathlib
import sys

metadata_path = pathlib.Path(sys.argv[1])
registered = set(sys.argv[2:])
data = json.loads(metadata_path.read_text(encoding='utf-8'))
missing = []
for helper in data.get('helpers', []):
    if not isinstance(helper, dict):
        continue
    path = helper.get('contract_test_path')
    if isinstance(path, str) and path and path not in registered:
        missing.append(path)
for path in sorted(set(missing)):
    print(path)
PY
)" || return 1

  if [ -n "$missing_paths" ]; then
    while IFS= read -r missing_path; do
      [ -n "$missing_path" ] || continue
      printf 'fail: helper metadata contract_test_path missing from smoke registry: %s\n' "$missing_path" >&2
    done <<EOF
$missing_paths
EOF
    return 1
  fi

  return 0
}

smoke_run_all_contracts() {
  local status=0
  local i=0

  smoke_validate_metadata_contract_registry || return 1

  for i in "${!smoke_contract_scripts[@]}"; do
    smoke_run_named_check "${smoke_contract_names[$i]}" "${smoke_contract_scripts[$i]}" || status=1
  done

  return "$status"
}

# repo-automation/tests/lib/smoke-registry.sh EOF
