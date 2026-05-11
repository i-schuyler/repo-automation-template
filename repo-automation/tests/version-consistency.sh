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
    repo-automation/bin/prepare-release --check "$@"
    return $?
  fi

  if [ ! -f VERSION ]; then
    printf 'FAIL: VERSION exists
' >&2
    return 1
  fi

  expected_version="$(tr -d '[:space:]' < VERSION)"
  if [ -z "$expected_version" ]; then
    printf 'FAIL: VERSION is non-empty
' >&2
    return 1
  fi

  if grep -q '^REPO_AUTOMATION_VERSION="'"$expected_version"'"$' .repo-automation.conf; then
    printf 'PASS: .repo-automation.conf REPO_AUTOMATION_VERSION matches VERSION
'
  else
    printf 'FAIL: .repo-automation.conf REPO_AUTOMATION_VERSION matches VERSION
' >&2
    return 1
  fi

  if grep -q "Current version: $expected_version" README.md; then
    printf 'PASS: README current version matches VERSION
'
  else
    printf 'FAIL: README current version matches VERSION
' >&2
    return 1
  fi

  if grep -q "^## \[$expected_version\] - Unreleased$" CHANGELOG.md; then
    printf 'PASS: CHANGELOG has unreleased heading for VERSION
'
  else
    printf 'FAIL: CHANGELOG has unreleased heading for VERSION
' >&2
    return 1
  fi

  if grep -q "| Current version line | starts at $expected_version |" docs/DECISIONS.md; then
    printf 'PASS: DECISIONS current version line matches VERSION
'
  else
    printf 'FAIL: DECISIONS current version line matches VERSION
' >&2
    return 1
  fi

  if grep -q "Version numbers must stay aligned in these places:" docs/VERSIONING.md &&      grep -q "repo-automation/tests/version-consistency.sh" docs/VERSIONING.md; then
    printf 'PASS: VERSIONING documents version placements and test guard
'
  else
    printf 'FAIL: VERSIONING documents version placements and test guard
' >&2
    return 1
  fi

  if grep -q '^REPO_AUTOMATION_VERSION="'"$expected_version"'"$' examples/downstream/.repo-automation.conf.example ||      grep -q '^INSTALLED_VERSION_OR_REF="'"${expected_version}-EXAMPLE"'"$' examples/downstream/.repo-automation.conf.example; then
    printf 'PASS: downstream example version is aligned or explicit EXAMPLE suffix
'
  else
    printf 'FAIL: downstream example version is aligned or explicit EXAMPLE suffix
' >&2
    return 1
  fi
}

version_main "$@"
# repo-automation/tests/version-consistency.sh EOF
