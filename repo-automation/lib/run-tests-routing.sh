#!/usr/bin/env bash
# repo-automation/lib/run-tests-routing.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.

run_tests_collect_changed_files() {
  local changed_ref_name="$1"
  local -n changed_ref="$changed_ref_name"
  local path

  while IFS= read -r path; do
    [ -n "$path" ] && changed_ref+=("$path")
  done <<EOF
$(
  {
    git diff --name-only --cached --diff-filter=ACDMR
    git diff --name-only --diff-filter=ACDMR
    git ls-files --others --exclude-standard
  } | sed '/^$/d' | sort -u
)
EOF
}

run_tests_changed_needs_docs() {
  case "$1" in
    README.md|CHANGELOG.md|CONTRIBUTING.md|SUPPORT.md|docs/*|repo-automation/docs/*|.github/pull_request_template.md|.github/ISSUE_TEMPLATE/*)
      return 0
      ;;
  esac

  return 1
}

run_tests_changed_needs_version() {
  case "$1" in
    VERSION|README.md|CHANGELOG.md|docs/DECISIONS.md|docs/VERSIONING.md|examples/downstream/.repo-automation.conf.example|repo-automation/manifest.json|repo-automation/bin/repo-automation-install|repo-automation/tests/version-consistency.sh|repo-automation/bin/prepare-release)
      return 0
      ;;
  esac

  return 1
}

run_tests_changed_needs_smoke() {
  case "$1" in
    repo-automation/bin/*|repo-automation/lib/*|repo-automation/tests/*|repo-automation/manifest.json|.github/workflows/*)
      return 0
      ;;
  esac

  return 1
}

# repo-automation/lib/run-tests-routing.sh EOF
