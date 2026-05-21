#!/usr/bin/env bash
# repo-automation/tests/version-consistency.sh

set -u
set -o pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
. "$script_dir/../lib/common.sh"

version_consistency_quiet=0
version_consistency_explain=0

version_consistency_usage() {
  printf 'Usage: repo-automation/tests/version-consistency.sh [--quiet] [--explain] [--help]\n'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --quiet)
      version_consistency_quiet=1
      ;;
    --explain)
      version_consistency_explain=1
      ;;
    --help)
      version_consistency_usage
      exit 0
      ;;
    --*)
      repo_auto_flag_error "unknown flag" "$1" "run repo-automation/tests/version-consistency.sh --help" >&2
      exit 1
      ;;
    *)
      repo_auto_stop "unknown argument: $1"
      exit 1
      ;;
  esac
  shift
done

version_main() {
  local repo_root
  local expected_version
  local prepare_release_output=""
  local prepare_release_status=0

  repo_root="$(cd "$script_dir/../.." && pwd)"
  cd "$repo_root" || return 1

  if [ -x repo-automation/bin/prepare-release ]; then
    if [ "$version_consistency_explain" -eq 1 ]; then
      repo-automation/bin/prepare-release --check --explain || return $?
    elif [ "$version_consistency_quiet" -eq 1 ]; then
      prepare_release_output="$(repo-automation/bin/prepare-release --check 2>&1)"
      prepare_release_status=$?
      if [ "$prepare_release_status" -ne 0 ]; then
        printf 'FAIL: version-consistency: prepare-release --check failed\n' >&2
        if [ -n "$prepare_release_output" ]; then
          printf '%s\n' "$prepare_release_output" >&2
        fi
        return "$prepare_release_status"
      fi
    else
      repo-automation/bin/prepare-release --check >/dev/null || return $?
    fi
  else
    if [ ! -f VERSION ]; then
      printf 'FAIL: version-consistency: VERSION file is missing\n' >&2
      return 1
    fi

    expected_version="$(tr -d '[:space:]' < VERSION)"
    if [ -z "$expected_version" ]; then
      printf 'FAIL: version-consistency: VERSION file is empty\n' >&2
      return 1
    fi

    if grep -q '^REPO_AUTOMATION_VERSION="'"$expected_version"'"$' .repo-automation.conf; then
      if [ "$version_consistency_explain" -eq 1 ]; then
        printf 'PASS: installed automation config REPO_AUTOMATION_VERSION matches VERSION\n'
      fi
    else
      printf 'FAIL: version-consistency: installed automation config REPO_AUTOMATION_VERSION matches VERSION\n' >&2
      return 1
    fi

    if grep -q "Current version: $expected_version" README.md; then
      if [ "$version_consistency_explain" -eq 1 ]; then
        printf 'PASS: automation README current version matches VERSION\n'
      fi
    else
      printf 'FAIL: version-consistency: automation README current version matches VERSION\n' >&2
      return 1
    fi

    if grep -q "^## \\[$expected_version\\] - Unreleased$" CHANGELOG.md; then
      if [ "$version_consistency_explain" -eq 1 ]; then
        printf 'PASS: automation CHANGELOG has unreleased heading for VERSION\n'
      fi
    else
      printf 'FAIL: version-consistency: automation CHANGELOG has unreleased heading for VERSION\n' >&2
      return 1
    fi

    if grep -q "| Current version line | starts at $expected_version |" docs/DECISIONS.md; then
      if [ "$version_consistency_explain" -eq 1 ]; then
        printf 'PASS: automation DECISIONS current version line matches VERSION\n'
      fi
    else
      printf 'FAIL: version-consistency: automation DECISIONS current version line matches VERSION\n' >&2
      return 1
    fi

    if grep -q '^Current version: '"$expected_version"'$' docs/VERSIONING.md &&      grep -q 'Version Modes' docs/VERSIONING.md &&      grep -q 'prepare-release' docs/VERSIONING.md &&      grep -q 'REPO_AUTOMATION_CONF_VERSION' docs/VERSIONING.md; then
      if [ "$version_consistency_explain" -eq 1 ]; then
        printf 'PASS: VERSIONING documents automation version modes and guard\n'
      fi
    else
      printf 'FAIL: version-consistency: VERSIONING documents automation version modes and guard\n' >&2
      return 1
    fi

    if grep -q '^REPO_AUTOMATION_VERSION="'"$expected_version"'"$' examples/downstream/.repo-automation.conf.example ||      grep -q '^INSTALLED_VERSION_OR_REF="'"${expected_version}-EXAMPLE"'"$' examples/downstream/.repo-automation.conf.example; then
      if [ "$version_consistency_explain" -eq 1 ]; then
        printf 'PASS: downstream example installed automation ref is aligned or explicit EXAMPLE suffix\n'
      fi
    else
      printf 'FAIL: version-consistency: downstream example installed automation ref is aligned or explicit EXAMPLE suffix\n' >&2
      return 1
    fi
  fi

  VERSION_CONSISTENCY_QUIET="$version_consistency_quiet" VERSION_CONSISTENCY_EXPLAIN="$version_consistency_explain" python3 - "$repo_root" <<'PY' || return 1
from pathlib import Path
import json
import re
import os
import sys

repo_root = Path(sys.argv[1]).resolve()
quiet = os.environ.get('VERSION_CONSISTENCY_QUIET') == '1'
explain = os.environ.get('VERSION_CONSISTENCY_EXPLAIN') == '1'
manifest_path = repo_root / 'repo-automation' / 'manifest.json'
installer_path = repo_root / 'repo-automation' / 'bin' / 'repo-automation-install'
helper_metadata_path = repo_root / 'repo-automation' / 'helper-metadata.json'


def fail(message: str) -> None:
    print(f'FAIL: version-consistency: {message}', file=sys.stderr)
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
    print('FAIL: version-consistency: manifest-vs-installer drift detected', file=sys.stderr)
    print('Managed paths are present in repo-automation/manifest.json but missing from repo-automation/bin/repo-automation-install managed-file coverage:', file=sys.stderr)
    for path in missing:
        print(f'- {path}', file=sys.stderr)
    print('Smallest fix: add the missing path(s) to the appropriate repo-automation/bin/repo-automation-install coverage list, or remove them from repo-automation/manifest.json if they are no longer installed.', file=sys.stderr)
    raise SystemExit(1)

missing_helpers = sorted(set(helper_paths) - set(manifest_paths))
if missing_helpers:
    print('FAIL: version-consistency: helper-inventory drift detected', file=sys.stderr)
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

all_config_keys = sorted({
    key
    for entry in helper_metadata.get('helpers', [])
    for key in (entry.get('config_keys', []) if isinstance(entry.get('config_keys', []), list) else [])
    if isinstance(key, str) and key
})

config_key_drift = []
for entry in helper_metadata.get('helpers', []):
    path = entry.get('path')
    keys = entry.get('config_keys', [])
    if not isinstance(path, str) or not path or not isinstance(keys, list):
        continue
    source_path = repo_root / path
    try:
        source_text = source_path.read_text(encoding='utf-8', errors='ignore')
    except OSError:
        continue
    used_keys = [
        key for key in all_config_keys
        if re.search(r'(?<![A-Z0-9_])' + re.escape(key) + r'(?![A-Z0-9_])', source_text)
    ]
    missing_keys = [key for key in used_keys if key not in keys]
    if missing_keys:
        config_key_drift.append((path, missing_keys))

if config_key_drift:
    print('FAIL: helper-metadata config-key drift detected', file=sys.stderr)
    print("Helper source references config keys missing from that helper's config_keys in repo-automation/helper-metadata.json:", file=sys.stderr)
    for path, keys in config_key_drift:
        print(f'- {path}: {", ".join(keys)}', file=sys.stderr)
    print('Smallest fix: add the missing keys to the matching helper entry, or stop referencing them in the helper source if they are no longer used.', file=sys.stderr)
    raise SystemExit(1)

if explain:
    print('PASS: manifest-vs-installer managed-file coverage matches')
    print('PASS: helper-metadata config-key coverage matches helper sources')
PY

  if [ "$version_consistency_quiet" -eq 0 ] && [ "$version_consistency_explain" -eq 0 ]; then
    printf 'pass\n'
  fi
}

version_main "$@"
# repo-automation/tests/version-consistency.sh EOF
