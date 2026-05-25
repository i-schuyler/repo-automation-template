#!/usr/bin/env bash
# repo-automation/tests/lib/contracts/run-tests-routing.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.

smoke_check_run_tests_routing_contract() {
  local status=0
  local changed_files=()
  local changed_files_json="$smoke_test_base/run-tests-routing-changed-$$.txt"
  local docs_path="README.md"
  local version_path="VERSION"
  local unknown_path="notes/unknown.txt"

  if (
    cd "$smoke_test_dir" || return 1
    # shellcheck source=/dev/null
    . "$smoke_repo_root/repo-automation/lib/common.sh" || return 1
    # shellcheck source=/dev/null
    . "$smoke_repo_root/repo-automation/lib/run-tests-routing.sh" || return 1
    printf 'staged\n' >> "$docs_path" || return 1
    git add "$docs_path" || return 1
    printf 'unstaged\n' >> "$version_path" || return 1
    mkdir -p "$(dirname "$unknown_path")" || return 1
    printf 'untracked\n' > "$unknown_path" || return 1
    run_tests_collect_changed_files changed_files &&
      [ "${#changed_files[@]}" -ge 3 ] &&
      printf '%s\n' "${changed_files[@]}" > "$changed_files_json" &&
      grep -Fxq 'README.md' "$changed_files_json" &&
      grep -Fxq 'VERSION' "$changed_files_json" &&
      grep -Fxq 'notes/unknown.txt' "$changed_files_json"
  ); then
    test_pass "run-tests routing collects staged, unstaged, and untracked files"
  else
    test_fail "run-tests routing collects staged, unstaged, and untracked files"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    # shellcheck source=/dev/null
    . "$smoke_repo_root/repo-automation/lib/common.sh" || return 1
    # shellcheck source=/dev/null
    . "$smoke_repo_root/repo-automation/lib/run-tests-routing.sh" || return 1
    run_tests_changed_needs_docs 'README.md' &&
    ! run_tests_changed_needs_docs 'repo-automation/bin/run-tests' &&
    run_tests_changed_needs_version 'VERSION' &&
    ! run_tests_changed_needs_version 'notes/unknown.txt' &&
    run_tests_changed_needs_smoke 'repo-automation/bin/run-tests' &&
    run_tests_changed_needs_smoke 'repo-automation/tests/contracts/run-tests.sh' &&
    ! run_tests_changed_needs_smoke 'notes/unknown.txt'
  ); then
    test_pass "run-tests routing path classification matches contract"
  else
    test_fail "run-tests routing path classification matches contract"
    status=1
  fi

  rm -f "$changed_files_json" >/dev/null 2>&1 || true
  return "$status"
}

# repo-automation/tests/lib/contracts/run-tests-routing.sh EOF
