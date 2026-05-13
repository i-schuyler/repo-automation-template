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


def fail(message: str) -> None:
    print(f'FAIL: {message}', file=sys.stderr)
    raise SystemExit(1)


if not manifest_path.is_file():
    fail(f'manifest-vs-installer coverage check needs {manifest_path}')

if not installer_path.is_file():
    fail(f'manifest-vs-installer coverage check needs {installer_path}')

try:
    manifest_data = json.loads(manifest_path.read_text(encoding='utf-8'))
except json.JSONDecodeError as exc:
    fail(f'cannot parse {manifest_path}: {exc}')

manifest_paths = []
for entry in manifest_data.get('managed_files', []):
    path = entry.get('path')
    if path:
        manifest_paths.append(path)

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

print('PASS: manifest-vs-installer managed-file coverage matches')
PY
}

version_main "$@"
# repo-automation/tests/version-consistency.sh EOF
