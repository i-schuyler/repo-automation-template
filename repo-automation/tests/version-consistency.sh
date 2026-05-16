#!/usr/bin/env bash
# repo-automation/tests/version-consistency.sh

set -u
set -o pipefail

version_main() {
  local repo_root
  local expected_version

  repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
  cd "$repo_root" || return 1

  if [ -x repo-automation/bin/prepare-release ]; then
    repo-automation/bin/prepare-release --check "$@" || return $?
  else
    if [ ! -f VERSION ]; then
      printf 'FAIL: VERSION exists\n' >&2
      return 1
    fi

    expected_version="$(tr -d '[:space:]' < VERSION)"
    if [ -z "$expected_version" ]; then
      printf 'FAIL: VERSION is non-empty\n' >&2
      return 1
    fi

    if grep -q '^REPO_AUTOMATION_VERSION="'"$expected_version"'"$' .repo-automation.conf; then
      printf 'PASS: installed automation config REPO_AUTOMATION_VERSION matches VERSION\n'
    else
      printf 'FAIL: installed automation config REPO_AUTOMATION_VERSION matches VERSION\n' >&2
      return 1
    fi

    if grep -q "Current version: $expected_version" README.md; then
      printf 'PASS: automation README current version matches VERSION\n'
    else
      printf 'FAIL: automation README current version matches VERSION\n' >&2
      return 1
    fi

    if grep -q "^## \\[$expected_version\\] - Unreleased$" CHANGELOG.md; then
      printf 'PASS: automation CHANGELOG has unreleased heading for VERSION\n'
    else
      printf 'FAIL: automation CHANGELOG has unreleased heading for VERSION\n' >&2
      return 1
    fi

    if grep -q "| Current version line | starts at $expected_version |" docs/DECISIONS.md; then
      printf 'PASS: automation DECISIONS current version line matches VERSION\n'
    else
      printf 'FAIL: automation DECISIONS current version line matches VERSION\n' >&2
      return 1
    fi

    if grep -q '^Current version: '"$expected_version"'$' docs/VERSIONING.md &&      grep -q 'Version Modes' docs/VERSIONING.md &&      grep -q 'prepare-release' docs/VERSIONING.md &&      grep -q 'REPO_AUTOMATION_CONF_VERSION' docs/VERSIONING.md; then
      printf 'PASS: VERSIONING documents automation version modes and guard\n'
    else
      printf 'FAIL: VERSIONING documents automation version modes and guard\n' >&2
      return 1
    fi

    if grep -q '^REPO_AUTOMATION_VERSION="'"$expected_version"'"$' examples/downstream/.repo-automation.conf.example ||      grep -q '^INSTALLED_VERSION_OR_REF="'"${expected_version}-EXAMPLE"'"$' examples/downstream/.repo-automation.conf.example; then
      printf 'PASS: downstream example installed automation ref is aligned or explicit EXAMPLE suffix\n'
    else
      printf 'FAIL: downstream example installed automation ref is aligned or explicit EXAMPLE suffix\n' >&2
      return 1
    fi
  fi

  python3 - "$repo_root" <<'PY' || return 1
from pathlib import Path
import json
import re
import sys

repo_root = Path(sys.argv[1]).resolve()
manifest_path = repo_root / 'repo-automation' / 'manifest.json'
installer_path = repo_root / 'repo-automation' / 'bin' / 'repo-automation-install'
helper_metadata_path = repo_root / 'repo-automation' / 'helper-metadata.json'


def fail(message: str) -> None:
    print(f'FAIL: {message}', file=sys.stderr)
    raise SystemExit(1)


if not manifest_path.is_file():
    fail(f'manifest-vs-installer coverage check needs {manifest_path}')

if not installer_path.is_file():
    fail(f'manifest-vs-installer coverage check needs {installer_path}')

if not helper_metadata_path.is_file():
    fail(f'helper inventory check needs {helper_metadata_path}')

try:
    manifest_data = json.loads(manifest_path.read_text(encoding='utf-8'))
except json.JSONDecodeError as exc:
    fail(f'cannot parse {manifest_path}: {exc}')

try:
    helper_metadata = json.loads(helper_metadata_path.read_text(encoding='utf-8'))
except json.JSONDecodeError as exc:
    fail(f'cannot parse {helper_metadata_path}: {exc}')

if helper_metadata.get('schema') != 'repo-automation-helper-metadata/v1':
    fail('unexpected helper metadata schema value')
if helper_metadata.get('repository') != 'repo-automation-template':
    fail('unexpected helper metadata repository value')
if not isinstance(helper_metadata.get('helpers', []), list):
    fail('helper metadata helpers must be a list')
if not isinstance(helper_metadata.get('planned_routes', []), list):
    fail('helper metadata planned_routes must be a list')

manifest_paths = []
for entry in manifest_data.get('managed_files', []):
    path = entry.get('path')
    if path:
        manifest_paths.append(path)

helper_paths = []
required_fields = {
    'name',
    'path',
    'doc_path',
    'contract_test_path',
    'kind',
    'public',
    'phone_safe',
    'check_cost_tier',
    'writes_files',
    'writes_git',
    'uses_github',
    'runs_run_tests',
    'can_run_broad_checks',
    'supports_quiet',
    'supports_json',
    'artifact_helper',
    'umbrella_helper',
    'workflow_role',
    'config_keys',
}
for entry in helper_metadata.get('helpers', []):
    if not isinstance(entry, dict):
        fail('helper metadata entries must be objects')
    missing_fields = sorted(required_fields - set(entry))
    if missing_fields:
        fail(f'helper metadata entry missing fields for {entry.get("name", "<unknown>")}: {", ".join(missing_fields)}')
    if entry.get('public') is True:
        helper_paths.append(entry.get('path'))
    doc_path = entry.get('doc_path')
    contract_path = entry.get('contract_test_path')
    if not isinstance(doc_path, str) or not doc_path:
        fail(f'helper metadata entry missing doc_path for {entry.get("name", "<unknown>")}')
    if not isinstance(contract_path, str) or not contract_path:
        fail(f'helper metadata entry missing contract_test_path for {entry.get("name", "<unknown>")}')
    if not (repo_root / doc_path).is_file():
        fail(f'helper metadata doc_path missing on disk: {doc_path}')
    if not (repo_root / contract_path).is_file():
        fail(f'helper metadata contract_test_path missing on disk: {contract_path}')

planned_routes = helper_metadata.get('planned_routes', [])
planned_names = {entry.get('name') for entry in planned_routes if isinstance(entry, dict)}
for planned_name in {'submit', 'autopilot plan-only'}:
    if planned_name not in planned_names:
        fail(f'helper metadata missing planned route row: {planned_name}')

installer_paths = set()
coverage_sections = {
    'managed_files',
    'starter_template_files',
    'optional_test_files',
    'optional_ci_files',
}
current_section = None
for raw_line in installer_path.read_text(encoding='utf-8', errors='ignore').splitlines():
    line = raw_line.strip()
    if current_section is None:
        for section in coverage_sections:
            if raw_line.startswith(f'  local -a {section}=('):
                current_section = section
                break
        continue
    if line == ')':
        current_section = None
        continue
    match = re.match(r'^"([^"]+)"$', line)
    if match:
        installer_paths.add(match.group(1))

missing = sorted(set(manifest_paths) - installer_paths)
if missing:
    print('FAIL: manifest-vs-installer drift detected', file=sys.stderr)
    print('Managed paths are present in repo-automation/manifest.json but missing from repo-automation/bin/repo-automation-install managed-file coverage:', file=sys.stderr)
    for path in missing:
        print(f'- {path}', file=sys.stderr)
    print('Smallest fix: add the missing path(s) to the appropriate repo-automation/bin/repo-automation-install coverage list, or remove them from repo-automation/manifest.json if they are no longer installed.', file=sys.stderr)
    raise SystemExit(1)

missing_helpers = sorted(set(helper_paths) - set(manifest_paths))
if missing_helpers:
    print('FAIL: helper-inventory drift detected', file=sys.stderr)
    print('Public helper paths are present in repo-automation/helper-metadata.json but missing from repo-automation/manifest.json:', file=sys.stderr)
    for path in missing_helpers:
        print(f'- {path}', file=sys.stderr)
    print('Smallest fix: add the missing helper paths to repo-automation/manifest.json and repo-automation/bin/repo-automation-install, or remove them from repo-automation/helper-metadata.json if they are no longer public.', file=sys.stderr)
    raise SystemExit(1)

missing_helper_installer = sorted(set(helper_paths) - installer_paths)
if missing_helper_installer:
    print('FAIL: helper-inventory installer drift detected', file=sys.stderr)
    print('Public helper paths are present in repo-automation/helper-metadata.json but missing from repo-automation/bin/repo-automation-install coverage:', file=sys.stderr)
    for path in missing_helper_installer:
        print(f'- {path}', file=sys.stderr)
    print('Smallest fix: add the missing helper paths to repo-automation/bin/repo-automation-install managed-file coverage, or remove them from repo-automation/helper-metadata.json if they are no longer public.', file=sys.stderr)
    raise SystemExit(1)

print('PASS: manifest-vs-installer managed-file coverage matches')
PY
}

version_main "$@"
# repo-automation/tests/version-consistency.sh EOF
