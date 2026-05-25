# repo-automation/tests/lib/contracts/status-diff.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.

smoke_check_touched_files_contract() {
  local status=0
  local touched_worktree_json="$smoke_test_base/touched-files-worktree-$$.json"
  local touched_range_json="$smoke_test_base/touched-files-range-$$.json"
  local touched_help="$smoke_test_base/touched-files-help-$$.txt"
  local gh_stub_dir="$smoke_test_base/gh-stub"
  local touched_range_repo=""
  local touched_base_format_stderr="$smoke_test_base/touched-files-base-format-$$.txt"
  local touched_base_missing_stderr="$smoke_test_base/touched-files-base-missing-$$.txt"
  local touched_base_empty_stderr="$smoke_test_base/touched-files-base-empty-$$.txt"
  local touched_head_format_stderr="$smoke_test_base/touched-files-head-format-$$.txt"
  local touched_head_missing_stderr="$smoke_test_base/touched-files-head-missing-$$.txt"
  local touched_head_empty_stderr="$smoke_test_base/touched-files-head-empty-$$.txt"
  local touched_base_unknown_stderr="$smoke_test_base/touched-files-base-unknown-$$.txt"
  local touched_positional_stderr="$smoke_test_base/touched-files-positional-$$.txt"

  smoke_write_gh_stub "$gh_stub_dir" || return 1

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/touched-files --help > "$touched_help"
  ) && \
    grep -Fq -- '--base=<ref>' "$touched_help" && \
    grep -Fq -- '--head=<ref>' "$touched_help" && \
    ! grep -Fq -- '--base REF' "$touched_help" && \
    ! grep -Fq -- '--head REF' "$touched_help"; then
    test_pass "touched-files help shows strict value syntax"
  else
    test_fail "touched-files help shows strict value syntax"
    status=1
  fi


  if (
    cd "$smoke_test_dir" || return 1
    printf '\nsmoke touched-files\n' >> README.md || return 1
    : > scratch.txt || return 1
    PATH="$gh_stub_dir:$PATH" repo-automation/bin/touched-files --machine-json > "$touched_worktree_json"
  ) && python3 -m json.tool "$touched_worktree_json" >/dev/null && \
    smoke_json_assert "$touched_worktree_json" 'data.get("mode") == "working-tree" and "README.md" in data.get("working_tree_tracked_files", []) and "scratch.txt" in data.get("untracked_files", [])'; then
    test_pass "touched-files working-tree fallback is parseable"
  else
    test_fail "touched-files working-tree fallback is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    rm -f scratch.txt >/dev/null 2>&1 || true
    git checkout -- README.md >/dev/null 2>&1 || true
  ); then
    :
  fi

  touched_range_repo="$(smoke_setup_subset_repo)" || {
    test_fail "touched-files commit-range fixture creates a repo"
    status=1
  }

  if [ -n "$touched_range_repo" ] && (
    cd "$touched_range_repo" || return 1
    git checkout -b feature/touched-files-range >/dev/null 2>&1 || return 1
    printf '
range touch
' >> repo-automation/docs/testing.md || return 1
    git add repo-automation/docs/testing.md || return 1
    git commit -m "range touch" >/dev/null || return 1
    repo-automation/bin/touched-files --machine-json > "$touched_range_json"
  ) && python3 -m json.tool "$touched_range_json" >/dev/null &&     smoke_json_assert "$touched_range_json" 'data.get("mode") == "commit-range" and "repo-automation/docs/testing.md" in data.get("commit_range_files", [])'; then
    test_pass "touched-files commit-range output is parseable"
  else
    test_fail "touched-files commit-range output is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/touched-files --base main >/dev/null 2> "$touched_base_format_stderr"
  ); then
    test_fail "touched-files rejects --base <ref>"
    status=1
  elif smoke_assert_flag_error_shape "$touched_base_format_stderr" "flag format not accepted" "--base" "use --base=<ref>"; then
    test_pass "touched-files rejects --base <ref>"
  else
    test_fail "touched-files rejects --base <ref>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/touched-files --head main >/dev/null 2> "$touched_head_format_stderr"
  ); then
    test_fail "touched-files rejects --head <ref>"
    status=1
  elif smoke_assert_flag_error_shape "$touched_head_format_stderr" "flag format not accepted" "--head" "use --head=<ref>"; then
    test_pass "touched-files rejects --head <ref>"
  else
    test_fail "touched-files rejects --head <ref>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/touched-files --base >/dev/null 2> "$touched_base_missing_stderr"
  ); then
    test_fail "touched-files rejects missing --base value"
    status=1
  elif smoke_assert_flag_error_shape "$touched_base_missing_stderr" "missing flag value" "--base" "use --base=<ref>"; then
    test_pass "touched-files rejects missing --base value"
  else
    test_fail "touched-files rejects missing --base value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/touched-files --head >/dev/null 2> "$touched_head_missing_stderr"
  ); then
    test_fail "touched-files rejects missing --head value"
    status=1
  elif smoke_assert_flag_error_shape "$touched_head_missing_stderr" "missing flag value" "--head" "use --head=<ref>"; then
    test_pass "touched-files rejects missing --head value"
  else
    test_fail "touched-files rejects missing --head value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/touched-files --base= >/dev/null 2> "$touched_base_empty_stderr"
  ); then
    test_fail "touched-files rejects empty --base value"
    status=1
  elif smoke_assert_flag_error_shape "$touched_base_empty_stderr" "empty flag value" "--base" "use --base=<ref>"; then
    test_pass "touched-files rejects empty --base value"
  else
    test_fail "touched-files rejects empty --base value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/touched-files --head= >/dev/null 2> "$touched_head_empty_stderr"
  ); then
    test_fail "touched-files rejects empty --head value"
    status=1
  elif smoke_assert_flag_error_shape "$touched_head_empty_stderr" "empty flag value" "--head" "use --head=<ref>"; then
    test_pass "touched-files rejects empty --head value"
  else
    test_fail "touched-files rejects empty --head value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/touched-files --whatever >/dev/null 2> "$touched_base_unknown_stderr"
  ); then
    test_fail "touched-files rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$touched_base_unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/touched-files --help"; then
    test_pass "touched-files rejects unknown flags"
  else
    test_fail "touched-files rejects unknown flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/touched-files positional >/dev/null 2> "$touched_positional_stderr"
  ); then
    test_fail "touched-files rejects positional arguments"
    status=1
  elif grep -Fxq 'STOP: unknown argument: positional' "$touched_positional_stderr"; then
    test_pass "touched-files rejects positional arguments"
  else
    test_fail "touched-files rejects positional arguments"
    status=1
  fi

  rm -f "$touched_worktree_json" "$touched_range_json" "$touched_help" "$touched_base_format_stderr" "$touched_base_missing_stderr" "$touched_base_empty_stderr" "$touched_head_format_stderr" "$touched_head_missing_stderr" "$touched_head_empty_stderr" "$touched_base_unknown_stderr" "$touched_positional_stderr" >/dev/null 2>&1 || true
  return "$status"
}

# repo-automation/tests/lib/contracts/status-diff.sh EOF
