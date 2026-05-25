# repo-automation/tests/lib/contracts/managed-files.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.



smoke_check_managed_file_tools_contract() {
  local status=0
  local managed_file_help="$smoke_test_base/managed-file-check-help-$$.txt"
  local managed_file_add_help="$smoke_test_base/managed-file-add-help-$$.txt"
  local managed_file_clean_out="$smoke_test_base/managed-file-check-clean.out"
  local managed_file_clean_err="$smoke_test_base/managed-file-check-clean.err"
  local managed_file_fail_stderr="$smoke_test_base/managed-file-check-fail.stderr"
  local managed_file_add_stderr="$smoke_test_base/managed-file-add.stderr"
  local managed_file_new_path="repo-automation/docs/managed-file-tools-smoke.md"
  local managed_file_manifest_path="$smoke_test_dir/repo-automation/manifest.json"
  local managed_file_installer_path="$smoke_test_dir/repo-automation/bin/repo-automation-install"
  local managed_file_manifest_backup="$smoke_test_base/managed-file-manifest-backup-$$.json"
  local managed_file_installer_backup="$smoke_test_base/managed-file-installer-backup-$$.sh"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/managed-file-check --help > "$managed_file_help"
  ) && grep -Fq -- '--changed' "$managed_file_help" && grep -Fq -- '--quiet' "$managed_file_help" && ! grep -Fq -- '--changed CHANGED' "$managed_file_help"; then
    test_pass "managed-file-check help shows strict flag syntax"
  else
    test_fail "managed-file-check help shows strict flag syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/managed-file-add --help > "$managed_file_add_help"
  ) && grep -Fq -- '--path=<path>' "$managed_file_add_help" && grep -Fq -- '--kind=<kind>' "$managed_file_add_help" && ! grep -Fq -- '--path PATH' "$managed_file_add_help" && ! grep -Fq -- '--kind KIND' "$managed_file_add_help"; then
    test_pass "managed-file-add help shows strict value syntax"
  else
    test_fail "managed-file-add help shows strict value syntax"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/managed-file-add --whatever >/dev/null 2> "$managed_file_add_stderr"
  ); then
    test_fail "managed-file-add rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$managed_file_add_stderr" "unknown flag" "--whatever" "run repo-automation/bin/managed-file-add --help"; then
    test_pass "managed-file-add rejects unknown flags"
  else
    test_fail "managed-file-add rejects unknown flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/managed-file-check --changed > "$managed_file_clean_out" 2> "$managed_file_clean_err"
  ) && [ "$(cat "$managed_file_clean_out")" = "pass" ] && [ ! -s "$managed_file_clean_err" ]; then
    test_pass "managed-file-check prints pass on clean success"
  else
    test_fail "managed-file-check prints pass on clean success"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/managed-file-check --changed --quiet > "$managed_file_clean_out" 2> "$managed_file_clean_err"
  ) && [ ! -s "$managed_file_clean_out" ] && [ ! -s "$managed_file_clean_err" ]; then
    test_pass "managed-file-check quiet output is silent on clean success"
  else
    test_fail "managed-file-check quiet output is silent on clean success"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    printf '# helper smoke\n' > "$managed_file_new_path" || return 1
    repo-automation/bin/managed-file-check --changed >/dev/null 2> "$managed_file_fail_stderr"
  ); then
    test_fail "managed-file-check flags new repo-automation paths for review"
    status=1
  elif grep -Fq 'coverage review required' "$managed_file_fail_stderr"; then
    test_pass "managed-file-check flags new repo-automation paths for review"
  else
    test_fail "managed-file-check flags new repo-automation paths for review"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    cp "$managed_file_manifest_path" "$managed_file_manifest_backup" || return 1
    cp "$managed_file_installer_path" "$managed_file_installer_backup" || return 1
    repo-automation/bin/managed-file-add --path="$managed_file_new_path" --kind=doc >/dev/null
  ) && python3 -m json.tool "$managed_file_manifest_path" >/dev/null && \
    grep -Fq -- "\"path\": \"$managed_file_new_path\"" "$managed_file_manifest_path" && \
    grep -Fq -- "\"$managed_file_new_path\"" "$managed_file_installer_path"; then
    test_pass "managed-file-add updates manifest and installer coverage"
  else
    test_fail "managed-file-add updates manifest and installer coverage"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/managed-file-check --changed >/dev/null
  ); then
    test_pass "managed-file-check passes after managed-file-add"
  else
    test_fail "managed-file-check passes after managed-file-add"
    status=1
  fi

  cp "$managed_file_manifest_backup" "$managed_file_manifest_path" >/dev/null 2>&1 || true
  cp "$managed_file_installer_backup" "$managed_file_installer_path" >/dev/null 2>&1 || true

  rm -f "$managed_file_help" "$managed_file_add_help" "$managed_file_clean_out" "$managed_file_clean_err" "$managed_file_fail_stderr" "$managed_file_add_stderr" >/dev/null 2>&1 || true
  rm -f "$managed_file_manifest_backup" "$managed_file_installer_backup" >/dev/null 2>&1 || true
  return "$status"
}

# repo-automation/tests/lib/contracts/managed-files.sh EOF
