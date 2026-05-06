#!/usr/bin/env bash
# tests/version-consistency.sh

set -u
set -o pipefail

version_info() {
  printf 'PASS: %s\n' "$1"
}

version_fail() {
  printf 'FAIL: %s\n' "$1" >&2
}

version_main() {
  local repo_root
  local expected_version
  local status=0

  repo_root="$(cd "$(dirname "$0")/.." && pwd)"
  cd "$repo_root" || return 1

  if [ ! -f VERSION ]; then
    version_fail "VERSION exists"
    return 1
  fi
  version_info "VERSION exists"

  expected_version="$(tr -d '[:space:]' < VERSION)"
  if [ -z "$expected_version" ]; then
    version_fail "VERSION is non-empty"
    return 1
  fi
  version_info "VERSION is non-empty"

  if grep -q "^REPO_AUTOMATION_VERSION=\"$expected_version\"$" .repo-automation.conf; then
    version_info ".repo-automation.conf REPO_AUTOMATION_VERSION matches VERSION"
  else
    version_fail ".repo-automation.conf REPO_AUTOMATION_VERSION matches VERSION"
    status=1
  fi

  if grep -q "Current version: $expected_version" README.md; then
    version_info "README current version matches VERSION"
  else
    version_fail "README current version matches VERSION"
    status=1
  fi

  if grep -q "^## \[$expected_version\] - Unreleased$" CHANGELOG.md; then
    version_info "CHANGELOG has unreleased heading for VERSION"
  else
    version_fail "CHANGELOG has unreleased heading for VERSION"
    status=1
  fi

  if grep -q "| Current version line | starts at $expected_version |" docs/DECISIONS.md; then
    version_info "DECISIONS current version line matches VERSION"
  else
    version_fail "DECISIONS current version line matches VERSION"
    status=1
  fi

  if grep -q "Version numbers must stay aligned in these places:" docs/VERSIONING.md && \
     grep -q "tests/version-consistency.sh" docs/VERSIONING.md; then
    version_info "VERSIONING documents version placements and test guard"
  else
    version_fail "VERSIONING documents version placements and test guard"
    status=1
  fi

  if grep -q "^REPO_AUTOMATION_VERSION=\"$expected_version\"$" examples/downstream/.repo-automation.conf.example || \
     grep -q "^INSTALLED_VERSION_OR_REF=\"${expected_version}-EXAMPLE\"$" examples/downstream/.repo-automation.conf.example; then
    version_info "downstream example version is aligned or explicit EXAMPLE suffix"
  else
    version_fail "downstream example version is aligned or explicit EXAMPLE suffix"
    status=1
  fi

  return "$status"
}

version_main "$@"
# tests/version-consistency.sh EOF
