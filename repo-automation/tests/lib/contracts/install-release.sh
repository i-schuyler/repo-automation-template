# repo-automation/tests/lib/contracts/install-release.sh

# shellcheck shell=bash



smoke_check_prepare_release_contract() {
  local status=0
  local prepare_release_help_out="$smoke_test_base/prepare-release-help-$$.txt"
  local prepare_release_check_json="$smoke_test_base/prepare-release-check-$$.json"
  local prepare_release_dry_run_json="$smoke_test_base/prepare-release-dry-run-$$.json"
  local prepare_release_apply_json="$smoke_test_base/prepare-release-apply-$$.json"
  local pre_dry_run_status="$smoke_test_base/prepare-release-pre-dry-run-status-$$.txt"
  local post_dry_run_status="$smoke_test_base/prepare-release-post-dry-run-status-$$.txt"
  local prepare_release_version_format_stderr="$smoke_test_base/prepare-release-version-format-$$.stderr"
  local prepare_release_version_missing_stderr="$smoke_test_base/prepare-release-version-missing-$$.stderr"
  local prepare_release_version_empty_stderr="$smoke_test_base/prepare-release-version-empty-$$.stderr"
  local prepare_release_unknown_stderr="$smoke_test_base/prepare-release-unknown-$$.stderr"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/prepare-release --help > "$prepare_release_help_out"
  ) && grep -q '^Usage: repo-automation/bin/prepare-release ' "$prepare_release_help_out" && \
    grep -Fq -- '--version=<semver>' "$prepare_release_help_out" && \
    ! grep -Fq -- '--version SEMVER' "$prepare_release_help_out"; then
    test_pass "prepare-release help succeeds"
  else
    test_fail "prepare-release help succeeds"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/prepare-release --version 0.2.0 >/dev/null 2> "$prepare_release_version_format_stderr"
  ); then
    test_fail "prepare-release rejects --version <value>"
    status=1
  elif smoke_assert_flag_error_shape "$prepare_release_version_format_stderr" "flag format not accepted" "--version" "use --version=<semver>"; then
    test_pass "prepare-release rejects --version <value>"
  else
    test_fail "prepare-release rejects --version <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/prepare-release --version >/dev/null 2> "$prepare_release_version_missing_stderr"
  ); then
    test_fail "prepare-release rejects missing --version value"
    status=1
  elif smoke_assert_flag_error_shape "$prepare_release_version_missing_stderr" "missing flag value" "--version" "use --version=<semver>"; then
    test_pass "prepare-release rejects missing --version value"
  else
    test_fail "prepare-release rejects missing --version value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/prepare-release --version= >/dev/null 2> "$prepare_release_version_empty_stderr"
  ); then
    test_fail "prepare-release rejects empty --version value"
    status=1
  elif smoke_assert_flag_error_shape "$prepare_release_version_empty_stderr" "empty flag value" "--version" "use --version=<semver>"; then
    test_pass "prepare-release rejects empty --version value"
  else
    test_fail "prepare-release rejects empty --version value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/prepare-release --whatever >/dev/null 2> "$prepare_release_unknown_stderr"
  ); then
    test_fail "prepare-release rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$prepare_release_unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/prepare-release --help"; then
    test_pass "prepare-release rejects unknown flags"
  else
    test_fail "prepare-release rejects unknown flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/prepare-release --check --machine-json > "$prepare_release_check_json"
  ) && python -m json.tool "$prepare_release_check_json" >/dev/null && \
    smoke_json_assert "$prepare_release_check_json" 'data.get("mode") == "check" and data.get("overall_status") == "pass" and data.get("source_version") == "0.1.0" and data.get("target_version") == "0.1.0"'; then
    test_pass "prepare-release check passes"
  else
    test_fail "prepare-release check passes"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    git status --short > "$pre_dry_run_status" &&
      repo-automation/bin/prepare-release --version=0.2.0 --dry-run --machine-json > "$prepare_release_dry_run_json" &&
      git status --short > "$post_dry_run_status"
  ) && cmp -s "$pre_dry_run_status" "$post_dry_run_status" && python -m json.tool "$prepare_release_dry_run_json" >/dev/null && \
    smoke_json_assert "$prepare_release_dry_run_json" 'data.get("mode") == "dry-run" and data.get("overall_status") == "pass" and data.get("target_version") == "0.2.0" and data.get("planned_count", 0) > 0 and data.get("updated_count", 0) == 0'; then
    test_pass "prepare-release dry-run reports planned changes"
  else
    test_fail "prepare-release dry-run reports planned changes"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/prepare-release --version=0.2.0 --apply --machine-json > "$prepare_release_apply_json"
  ) && python -m json.tool "$prepare_release_apply_json" >/dev/null && \
    smoke_json_assert "$prepare_release_apply_json" 'data.get("mode") == "apply" and data.get("overall_status") == "pass" and data.get("target_version") == "0.2.0" and data.get("updated_count", 0) > 0'; then
    test_pass "prepare-release apply updates files"
  else
    test_fail "prepare-release apply updates files"
    status=1
  fi

  if python -m json.tool "$prepare_release_apply_json" >/dev/null &&     smoke_json_assert "$prepare_release_apply_json" 'data.get("mode") == "apply" and data.get("overall_status") == "pass" and data.get("updated_count", 0) == 11 and any(entry.get("path", "").endswith("docs/VERSIONING.md") and entry.get("status") == "updated" for entry in data.get("results", [])) and any(entry.get("path", "").endswith("docs/DECISIONS.md") and entry.get("status") == "updated" for entry in data.get("results", [])) and any(entry.get("path", "").endswith("examples/downstream/.repo-automation.conf.example") and entry.get("status") == "updated" for entry in data.get("results", [])) and any(entry.get("path", "").endswith("docs/DOWNSTREAM_FEEDBACK.md") and entry.get("status") == "updated" for entry in data.get("results", []))'; then
    test_pass "prepare-release updates managed version placements"
  else
    test_fail "prepare-release updates managed version placements"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/prepare-release --check >/dev/null
  ); then
    test_pass "prepare-release check passes after apply"
  else
    test_fail "prepare-release check passes after apply"
    status=1
  fi

  rm -f "$prepare_release_help_out" "$prepare_release_check_json" "$prepare_release_dry_run_json" "$prepare_release_apply_json" "$pre_dry_run_status" "$post_dry_run_status" "$prepare_release_version_format_stderr" "$prepare_release_version_missing_stderr" "$prepare_release_version_empty_stderr" "$prepare_release_unknown_stderr" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_automation_freshness_contract() {
  local status=0
  local freshness_default_out="$smoke_test_base/automation-freshness-default-$$.txt"
  local freshness_json="$smoke_test_base/automation-freshness-$$.json"
  local source_format_stderr="$smoke_test_base/automation-freshness-source-format.stderr"
  local source_missing_stderr="$smoke_test_base/automation-freshness-source-missing.stderr"
  local source_empty_stderr="$smoke_test_base/automation-freshness-source-empty.stderr"
  local unknown_flag_stderr="$smoke_test_base/automation-freshness-unknown.stderr"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/automation-freshness > "$freshness_default_out"
  ) && grep -Eq '^RESULT: pass=' "$freshness_default_out" && ! grep -Eq '^FAIL:$' "$freshness_default_out"; then
    test_pass "automation-freshness human default output is compact"
  else
    test_fail "automation-freshness human default output is compact"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    repo-automation/bin/automation-freshness --machine-json --source-root="$smoke_test_dir" > "$freshness_json"
  ) && python -m json.tool "$freshness_json" >/dev/null && \
    smoke_json_assert "$freshness_json" 'data.get("overall_status") == "pass" and data.get("source_root") == "'"$smoke_test_dir"'" and data.get("manifest_path", "").endswith("repo-automation/manifest.json") and any(item.get("path") == "repo-automation/bin/automation-freshness" and item.get("present") for item in data.get("managed_files", []))'; then
    test_pass "automation-freshness machine-json is parseable"
  else
    test_fail "automation-freshness machine-json is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/automation-freshness --source-root "$smoke_test_dir" >/dev/null 2> "$source_format_stderr"
  ); then
    test_fail "automation-freshness rejects --source-root <value>"
    status=1
  elif smoke_assert_flag_error_shape "$source_format_stderr" "flag format not accepted" "--source-root" "use --source-root=<path>"; then
    test_pass "automation-freshness rejects --source-root <value>"
  else
    test_fail "automation-freshness rejects --source-root <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/automation-freshness --source-root >/dev/null 2> "$source_missing_stderr"
  ); then
    test_fail "automation-freshness rejects missing --source-root value"
    status=1
  elif smoke_assert_flag_error_shape "$source_missing_stderr" "missing flag value" "--source-root" "use --source-root=<path>"; then
    test_pass "automation-freshness rejects missing --source-root value"
  else
    test_fail "automation-freshness rejects missing --source-root value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/automation-freshness --source-root= >/dev/null 2> "$source_empty_stderr"
  ); then
    test_fail "automation-freshness rejects empty --source-root value"
    status=1
  elif smoke_assert_flag_error_shape "$source_empty_stderr" "empty flag value" "--source-root" "use --source-root=<path>"; then
    test_pass "automation-freshness rejects empty --source-root value"
  else
    test_fail "automation-freshness rejects empty --source-root value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/automation-freshness --whatever >/dev/null 2> "$unknown_flag_stderr"
  ); then
    test_fail "automation-freshness rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$unknown_flag_stderr" "unknown flag" "--whatever" "run repo-automation/bin/automation-freshness --help"; then
    test_pass "automation-freshness rejects unknown flags"
  else
    test_fail "automation-freshness rejects unknown flags"
    status=1
  fi

  rm -f "$freshness_default_out" "$freshness_json" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_installer_starter_template_profile() {
  local status=0
  local starter_plan_json="$smoke_test_base/repo-install-starter-plan-$$.json"
  local starter_target="$smoke_test_base/install-starter-target-$$"
  local starter_remote="$smoke_test_base/install-starter-target-$$-remote.git"
  local starter_ready_json="$smoke_test_base/starter-template-ready-install-$$.json"
  local starter_doctor_json="$smoke_test_base/repo-doctor-starter-install-$$.json"
  local starter_artifact_json="$smoke_test_base/repo-doctor-starter-source-artifact-$$.json"

  mkdir -p "$starter_target" || return 1
  (
    cd "$starter_target" || return 1
    git init -b main >/dev/null || return 1
    git config user.name "repo-automation-install-test" || return 1
    git config user.email "repo-automation-install-test@example.com" || return 1
    cp "$smoke_repo_root/README.md" README.md || return 1
    cp "$smoke_repo_root/VERSION" VERSION || return 1
    cp "$smoke_repo_root/CHANGELOG.md" CHANGELOG.md || return 1
    cp -R "$smoke_repo_root/docs" . || return 1
    cp -R "$smoke_repo_root/examples" . || return 1
    git add -A || return 1
    git commit -m "init starter target" >/dev/null || return 1
    git init --bare --initial-branch=main "$starter_remote" >/dev/null || return 1
    git remote add origin "$starter_remote" || return 1
    git push -u origin main >/dev/null || return 1
  ) || status=1

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-install --target="$starter_target" --starter-template --json > "$starter_plan_json"
  ) && python -m json.tool "$starter_plan_json" >/dev/null && \
    smoke_json_assert "$starter_plan_json" 'data.get("mode") == "install" and data.get("profile") == "starter-template" and ".github/pull_request_template.md" in data.get("files_to_add", []) and ".github/ISSUE_TEMPLATE/automation-bug.yml" in data.get("files_to_add", []) and ".github/ISSUE_TEMPLATE/automation-feature.yml" in data.get("files_to_add", []) and ".github/workflows/ci.yml" not in data.get("files_to_add", []) and data.get("target_remote_status") in ("missing", "unsupported", "present")'; then
    test_pass "repo-automation-install starter-template plan/json includes template files"
  else
    test_fail "repo-automation-install starter-template plan/json includes template files"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-install --target="$starter_target" --starter-template --apply >/dev/null
  ) && [ -f "$starter_target/.repo-automation.conf" ] && [ -f "$starter_target/.github/pull_request_template.md" ] && [ -f "$starter_target/.github/ISSUE_TEMPLATE/automation-bug.yml" ] && [ -f "$starter_target/.github/ISSUE_TEMPLATE/automation-feature.yml" ] && [ ! -f "$starter_target/.github/workflows/ci.yml" ] && grep -qx 'CHECK_PROFILE_DEFAULT="starter-template"' "$starter_target/.repo-automation.conf"; then
    test_pass "repo-automation-install starter-template apply creates templates without CI"
  else
    test_fail "repo-automation-install starter-template apply creates templates without CI"
    status=1
  fi

  if (
    cd "$starter_target" || return 1
    repo-automation/bin/starter-template-ready --check-current --machine-json > "$starter_ready_json"
  ) && python -m json.tool "$starter_ready_json" >/dev/null && \
    smoke_json_assert "$starter_ready_json" 'data.get("overall_status") == "pass" and data.get("source_root") == "'"$starter_target"'"'; then
    test_pass "starter-template-ready passes for installed starter target"
  else
    test_fail "starter-template-ready passes for installed starter target"
    status=1
  fi

  if (
    cd "$starter_target" || return 1
    repo-automation/bin/repo-doctor --quick --no-run-tests --json --json-level=warn > "$starter_doctor_json"
  ) && python -m json.tool "$starter_doctor_json" >/dev/null && \
    smoke_json_assert "$starter_doctor_json" 'data.get("mode") == "quick" and data.get("overall_status") in ("pass", "warn") and not any(check.get("status") == "fail" for check in data.get("checks", []))'; then
    test_pass "repo-doctor quick/no-run-tests passes for installed starter target"
  else
    test_fail "repo-doctor quick/no-run-tests passes for installed starter target"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    repo-automation/bin/repo-doctor --check=artifact-guard --json --json-level=all > "$starter_artifact_json"
  ) && python -m json.tool "$starter_artifact_json" >/dev/null && \
    smoke_json_assert "$starter_artifact_json" 'data.get("overall_status") == "pass" and any(check.get("name") == "artifact-guard" and check.get("status") == "pass" for check in data.get("checks", []))'; then
    test_pass "source repo artifact guard remains clean after starter-template smoke"
  else
    test_fail "source repo artifact guard remains clean after starter-template smoke"
    status=1
  fi

  return "$status"
}

smoke_check_starter_template_readiness() {
  local status=0
  local readiness_json="$smoke_test_base/starter-template-ready-$$.json"
  local readiness_missing_json="$smoke_test_base/starter-template-ready-missing-$$.json"
  local readiness_doctor_out="$smoke_test_base/repo-doctor-starter-template-readiness-$$.txt"
  local readiness_missing_template="$smoke_test_dir/.github/pull_request_template.md"
  local readiness_missing_backup="$smoke_test_base/pull_request_template.md.bak"
  local readiness_human="$smoke_test_base/starter-template-ready-human-$$.txt"
  local source_format_stderr="$smoke_test_base/starter-template-ready-source-format.stderr"
  local source_missing_stderr="$smoke_test_base/starter-template-ready-source-missing.stderr"
  local source_empty_stderr="$smoke_test_base/starter-template-ready-source-empty.stderr"
  local unknown_flag_stderr="$smoke_test_base/starter-template-ready-unknown.stderr"

  if (
    cd "$smoke_repo_root" || return 1
    repo-automation/bin/starter-template-ready --machine-json --source-root="$smoke_test_dir" > "$readiness_json"
  ) && python -m json.tool "$readiness_json" >/dev/null &&     smoke_json_assert "$readiness_json" 'data.get("overall_status") == "pass" and data.get("source_root") == "'"$smoke_test_dir"'"'; then
    test_pass "starter-template-ready source-root machine-json passes"
  else
    test_fail "starter-template-ready source-root machine-json passes"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/starter-template-ready --source-root "$smoke_test_dir" >/dev/null 2> "$source_format_stderr"
  ); then
    test_fail "starter-template-ready rejects --source-root <value>"
    status=1
  elif smoke_assert_flag_error_shape "$source_format_stderr" "flag format not accepted" "--source-root" "use --source-root=<path>"; then
    test_pass "starter-template-ready rejects --source-root <value>"
  else
    test_fail "starter-template-ready rejects --source-root <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/starter-template-ready --source-root >/dev/null 2> "$source_missing_stderr"
  ); then
    test_fail "starter-template-ready rejects missing --source-root value"
    status=1
  elif smoke_assert_flag_error_shape "$source_missing_stderr" "missing flag value" "--source-root" "use --source-root=<path>"; then
    test_pass "starter-template-ready rejects missing --source-root value"
  else
    test_fail "starter-template-ready rejects missing --source-root value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/starter-template-ready --source-root= >/dev/null 2> "$source_empty_stderr"
  ); then
    test_fail "starter-template-ready rejects empty --source-root value"
    status=1
  elif smoke_assert_flag_error_shape "$source_empty_stderr" "empty flag value" "--source-root" "use --source-root=<path>"; then
    test_pass "starter-template-ready rejects empty --source-root value"
  else
    test_fail "starter-template-ready rejects empty --source-root value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/starter-template-ready --whatever >/dev/null 2> "$unknown_flag_stderr"
  ); then
    test_fail "starter-template-ready rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$unknown_flag_stderr" "unknown flag" "--whatever" "run repo-automation/bin/starter-template-ready --help"; then
    test_pass "starter-template-ready rejects unknown flags"
  else
    test_fail "starter-template-ready rejects unknown flags"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/starter-template-ready --check-current > "$readiness_human"
  ) && grep -Eq '^RUNNING starter-template readiness\.\.\.$' "$readiness_human" && grep -Eq '^RESULT: pass=[0-9]+ warn=0 fail=0 skipped=0$' "$readiness_human"; then
    test_pass "starter-template-ready default human output passes"
  else
    test_fail "starter-template-ready default human output passes"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-doctor --check=starter-template-readiness --no-run-tests > "$readiness_doctor_out"
  ) && [ "$(cat "$readiness_doctor_out")" = "pass" ]; then
    test_pass "repo-doctor starter-template-readiness check passes"
  else
    test_fail "repo-doctor starter-template-readiness check passes"
    status=1
  fi

  if (
    cd "$smoke_repo_root" || return 1
    mv "$readiness_missing_template" "$readiness_missing_backup" || return 1
    repo-automation/bin/starter-template-ready --machine-json --source-root="$smoke_test_dir" > "$readiness_missing_json"
    result=$?
    mv "$readiness_missing_backup" "$readiness_missing_template" || return 1
    [ "$result" -ne 0 ]
  ) && python -m json.tool "$readiness_missing_json" >/dev/null &&     smoke_json_assert "$readiness_missing_json" 'data.get("overall_status") == "fail" and ".github/pull_request_template.md" in (data.get("stop_reason") or "")'; then
    test_pass "starter-template-ready reports missing starter-template files"
  else
    test_fail "starter-template-ready reports missing starter-template files"
    status=1
    (
      cd "$smoke_repo_root" || true
      [ -f "$readiness_missing_template" ] || mv "$readiness_missing_backup" "$readiness_missing_template" >/dev/null 2>&1 || true
    )
  fi

  rm -f "$readiness_json" "$readiness_missing_json" "$readiness_human" "$readiness_doctor_out" >/dev/null 2>&1 || true
  return "$status"
}

smoke_check_installer_apply_contract() {
  local status=0
  local install_plan_json="$smoke_test_base/repo-install-plan-$$.json"
  local install_target="$smoke_test_base/install-target-$$"
  local install_target_remote="$smoke_test_base/install-target-$$-remote.git"
  local install_status_before
  local install_status_after
  local install_commit_count_before
  local install_commit_count_after
  local install_remote_head_before
  local install_remote_head_after
  local install_doctor_json="$smoke_test_base/repo-doctor-install-$$.json"
  local install_target_format_stderr="$smoke_test_base/repo-install-target-format-$$.stderr"
  local install_target_missing_stderr="$smoke_test_base/repo-install-target-missing-$$.stderr"
  local install_target_empty_stderr="$smoke_test_base/repo-install-target-empty-$$.stderr"
  local install_unknown_stderr="$smoke_test_base/repo-install-unknown-$$.stderr"

  mkdir -p "$install_target" || return 1
  (
    cd "$install_target" || return 1
    git init -b main >/dev/null || return 1
    git config user.name "repo-automation-install-test" || return 1
    git config user.email "repo-automation-install-test@example.com" || return 1
    cp "$smoke_repo_root/README.md" README.md || return 1
    cp "$smoke_repo_root/VERSION" VERSION || return 1
    cp "$smoke_repo_root/CHANGELOG.md" CHANGELOG.md || return 1
    cp -R "$smoke_repo_root/docs" . || return 1
    cp -R "$smoke_repo_root/.github" . || return 1
    cp -R "$smoke_repo_root/examples" . || return 1
    git add -A || return 1
    git commit -m "init target" >/dev/null || return 1
    git init --bare --initial-branch=main "$install_target_remote" >/dev/null || return 1
    git remote add origin "$install_target_remote" || return 1
    git push -u origin main >/dev/null || return 1
  ) || status=1
  install_commit_count_before="$(git -C "$install_target" rev-list --count HEAD)"
  install_remote_head_before="$(git -C "$install_target_remote" rev-parse refs/heads/main)"

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-install --target="$install_target" --json --include-tests > "$install_plan_json"
  ) && python -m json.tool "$install_plan_json" >/dev/null; then
    if smoke_json_assert "$install_plan_json" 'data.get("profile") == "default" and "repo-automation/bin/branch-cleanup" in data.get("files_to_add", []) and "repo-automation/bin/post-codex-packet" in data.get("files_to_add", []) and "repo-automation/bin/repair-prompt" in data.get("files_to_add", []) and "repo-automation/bin/review-pack" in data.get("files_to_add", []) and "repo-automation/bin/repo-zip" in data.get("files_to_add", []) and "repo-automation/bin/evidence-bundle" in data.get("files_to_add", []) and "repo-automation/docs/post-codex-packet.md" in data.get("files_to_add", []) and "repo-automation/docs/repair-prompt.md" in data.get("files_to_add", []) and "repo-automation/docs/review-pack.md" in data.get("files_to_add", []) and "repo-automation/docs/repo-zip.md" in data.get("files_to_add", []) and "repo-automation/docs/evidence-bundle.md" in data.get("files_to_add", []) and "repo-automation/tests/lib/test-common.sh" in data.get("files_to_add", []) and "repo-automation/tests/lib/smoke-common.sh" in data.get("files_to_add", []) and "repo-automation/tests/smoke.sh" in data.get("files_to_add", []) and len([path for path in data.get("files_to_add", []) if path.startswith("repo-automation/tests/contracts/")]) == 25 and ".github/pull_request_template.md" not in data.get("files_to_add", []) and data.get("target_remote_status") == "unsupported"'; then
      test_pass "repo-automation-install plan/json is parseable"
    else
      test_fail "repo-automation-install plan/json is parseable"
      status=1
    fi
  else
    test_fail "repo-automation-install plan/json is parseable"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-install --target "$install_target" >/dev/null 2> "$install_target_format_stderr"
  ); then
    test_fail "repo-automation-install rejects --target <value>"
    status=1
  elif smoke_assert_flag_error_shape "$install_target_format_stderr" "flag format not accepted" "--target" "use --target=<path>"; then
    test_pass "repo-automation-install rejects --target <value>"
  else
    test_fail "repo-automation-install rejects --target <value>"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-install --target >/dev/null 2> "$install_target_missing_stderr"
  ); then
    test_fail "repo-automation-install rejects missing --target value"
    status=1
  elif smoke_assert_flag_error_shape "$install_target_missing_stderr" "missing flag value" "--target" "use --target=<path>"; then
    test_pass "repo-automation-install rejects missing --target value"
  else
    test_fail "repo-automation-install rejects missing --target value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-install --target= >/dev/null 2> "$install_target_empty_stderr"
  ); then
    test_fail "repo-automation-install rejects empty --target value"
    status=1
  elif smoke_assert_flag_error_shape "$install_target_empty_stderr" "empty flag value" "--target" "use --target=<path>"; then
    test_pass "repo-automation-install rejects empty --target value"
  else
    test_fail "repo-automation-install rejects empty --target value"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-install --whatever >/dev/null 2> "$install_unknown_stderr"
  ); then
    test_fail "repo-automation-install rejects unknown flags"
    status=1
  elif smoke_assert_flag_error_shape "$install_unknown_stderr" "unknown flag" "--whatever" "run repo-automation/bin/repo-automation-install --help"; then
    test_pass "repo-automation-install rejects unknown flags"
  else
    test_fail "repo-automation-install rejects unknown flags"
    status=1
  fi

  if grep -Fq "$install_target_remote" "$install_plan_json"; then
    test_fail "repo-automation-install JSON does not leak raw target origin"
    status=1
  else
    test_pass "repo-automation-install JSON does not leak raw target origin"
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-install --target="$install_target" --apply --dry-run >/dev/null
  ) && [ ! -f "$install_target/.repo-automation.conf" ]; then
    test_pass "repo-automation-install dry-run does not write files"
  else
    test_fail "repo-automation-install dry-run does not write files"
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-install --target="$install_target" --apply --include-tests >/dev/null
  ) && [ -f "$install_target/AGENTS.md" ] && [ -f "$install_target/.repo-automation.conf" ] && [ -f "$install_target/repo-automation/docs/README.md" ] && [ -f "$install_target/repo-automation/docs/local-overrides.md" ] && [ -f "$install_target/repo-automation/docs/post-codex-packet.md" ] && [ -f "$install_target/repo-automation/docs/repair-prompt.md" ] && [ -f "$install_target/repo-automation/docs/review-pack.md" ] && [ -f "$install_target/repo-automation/docs/repo-zip.md" ] && [ -f "$install_target/repo-automation/docs/evidence-bundle.md" ] && [ -f "$install_target/repo-automation/bin/repo-doctor" ] && [ -f "$install_target/repo-automation/bin/failure-log" ] && [ -f "$install_target/repo-automation/bin/status-packet" ] && [ -f "$install_target/repo-automation/bin/post-codex-packet" ] && [ -f "$install_target/repo-automation/bin/repair-prompt" ] && [ -f "$install_target/repo-automation/bin/review-pack" ] && [ -f "$install_target/repo-automation/bin/repo-zip" ] && [ -f "$install_target/repo-automation/bin/evidence-bundle" ] && [ -f "$install_target/repo-automation/bin/run-tests" ] && [ -f "$install_target/repo-automation/tests/lib/test-common.sh" ] && [ -f "$install_target/repo-automation/tests/smoke.sh" ] && [ -x "$install_target/repo-automation/bin/repo-doctor" ] && [ -x "$install_target/repo-automation/bin/failure-log" ] && [ -x "$install_target/repo-automation/bin/status-packet" ] && [ -x "$install_target/repo-automation/bin/post-codex-packet" ] && [ -x "$install_target/repo-automation/bin/repair-prompt" ] && [ -x "$install_target/repo-automation/bin/review-pack" ] && [ -x "$install_target/repo-automation/bin/repo-zip" ] && [ -x "$install_target/repo-automation/bin/evidence-bundle" ] && [ -x "$install_target/repo-automation/bin/run-tests" ] && [ -x "$install_target/repo-automation/tests/smoke.sh" ] && cmp -s "$smoke_repo_root/AGENTS.md" "$install_target/AGENTS.md"; then
    test_pass "repo-automation-install apply creates managed files"
  else
    test_fail "repo-automation-install apply creates managed files"
    status=1
  fi

  if (
    cd "$install_target" || return 1
    [ -f repo-automation/tests/lib/smoke-common.sh ] || return 1
    [ -f repo-automation/tests/contracts/add-doc-pr.sh ] || return 1
    [ -f repo-automation/tests/contracts/report-upstream.sh ] || return 1
    [ -f repo-automation/tests/contracts/failure-log.sh ] || return 1
    [ -f repo-automation/tests/contracts/run-tests.sh ] || return 1
    [ -f repo-automation/tests/contracts/touched-files.sh ] || return 1
    [ -f repo-automation/tests/contracts/ci-log-dump.sh ] || return 1
    [ -f repo-automation/tests/contracts/repo-doctor.sh ] || return 1
    [ -f repo-automation/tests/contracts/status-packet.sh ] || return 1
    [ -f repo-automation/tests/contracts/post-codex-packet.sh ] || return 1
    [ -f repo-automation/tests/contracts/repair-prompt.sh ] || return 1
    [ -f repo-automation/tests/contracts/review-pack.sh ] || return 1
    [ -f repo-automation/tests/contracts/repo-zip.sh ] || return 1
    [ -f repo-automation/tests/contracts/evidence-bundle.sh ] || return 1
    [ -f repo-automation/tests/contracts/github-settings-check.sh ] || return 1
    [ -f repo-automation/tests/contracts/managed-file-tools.sh ] || return 1
    [ -f repo-automation/tests/contracts/shellcheck-ci-parity.sh ] || return 1
    [ -f repo-automation/tests/contracts/installer.sh ] || return 1
    [ -f repo-automation/tests/contracts/starter-template.sh ] || return 1
    [ -f repo-automation/tests/contracts/branch-cleanup-preflight.sh ] || return 1
    [ -f repo-automation/tests/contracts/prepare-release.sh ] || return 1
    [ -f repo-automation/tests/contracts/automation-freshness.sh ] || return 1
    [ -x repo-automation/tests/contracts/add-doc-pr.sh ] || return 1
    [ -x repo-automation/tests/contracts/report-upstream.sh ] || return 1
    [ -x repo-automation/tests/contracts/failure-log.sh ] || return 1
    [ -x repo-automation/tests/contracts/run-tests.sh ] || return 1
    [ -x repo-automation/tests/contracts/touched-files.sh ] || return 1
    [ -x repo-automation/tests/contracts/ci-log-dump.sh ] || return 1
    [ -x repo-automation/tests/contracts/repo-doctor.sh ] || return 1
    [ -x repo-automation/tests/contracts/status-packet.sh ] || return 1
    [ -x repo-automation/tests/contracts/post-codex-packet.sh ] || return 1
    [ -x repo-automation/tests/contracts/repair-prompt.sh ] || return 1
    [ -x repo-automation/tests/contracts/review-pack.sh ] || return 1
    [ -x repo-automation/tests/contracts/repo-zip.sh ] || return 1
    [ -x repo-automation/tests/contracts/evidence-bundle.sh ] || return 1
    [ -x repo-automation/tests/contracts/github-settings-check.sh ] || return 1
    [ -x repo-automation/tests/contracts/managed-file-tools.sh ] || return 1
    [ -x repo-automation/tests/contracts/shellcheck-ci-parity.sh ] || return 1
    [ -x repo-automation/tests/contracts/installer.sh ] || return 1
    [ -x repo-automation/tests/contracts/starter-template.sh ] || return 1
    [ -x repo-automation/tests/contracts/branch-cleanup-preflight.sh ] || return 1
    [ -x repo-automation/tests/contracts/prepare-release.sh ] || return 1
    [ -x repo-automation/tests/contracts/automation-freshness.sh ] || return 1
  ); then
    test_pass "repo-automation-install include-tests bundle installs smoke contracts"
  else
    test_fail "repo-automation-install include-tests bundle installs smoke contracts"
    status=1
  fi

  if (
    cd "$install_target" || return 1
    # shellcheck disable=SC1091
    source repo-automation/lib/common.sh && repo_auto_load_config >/dev/null && repo_auto_validate_required_config >/dev/null
  ); then
    test_pass "repo-automation-install installed config loads and validates"
  else
    test_fail "repo-automation-install installed config loads and validates"
    status=1
  fi

  if (
    cd "$install_target" || return 1
    repo-automation/bin/repo-doctor --quick --no-run-tests >/dev/null
  ); then
    test_pass "repo-automation-install target repo-doctor quick/no-run-tests succeeds"
  else
    test_fail "repo-automation-install target repo-doctor quick/no-run-tests succeeds"
    status=1
  fi

  if (
    cd "$install_target" || return 1
    repo-automation/bin/repo-doctor --json --quick --no-run-tests > "$install_doctor_json"
  ) && python -m json.tool "$install_doctor_json" >/dev/null && \
    smoke_json_assert "$install_doctor_json" 'data.get("overall_status") in ("pass", "warn") and any(check.get("status") == "warn" for check in data.get("checks", [])) and not any(check.get("status") == "fail" for check in data.get("checks", []))'; then
    test_pass "repo-automation-install target repo-doctor json audit succeeds"
  else
    test_fail "repo-automation-install target repo-doctor json audit succeeds"
    status=1
  fi

  if grep -qx 'EXPECTED_REMOTE_URL=""' "$install_target/.repo-automation.conf"; then
    test_pass "repo-automation-install uses empty EXPECTED_REMOTE_URL fallback for unsupported target origin"
  else
    test_fail "repo-automation-install uses empty EXPECTED_REMOTE_URL fallback for unsupported target origin"
    status=1
  fi

  install_status_before="$(git -C "$install_target" status --porcelain)"
  if [ -n "$install_status_before" ]; then
    test_pass "repo-automation-install does not commit or push in target repo"
  else
    test_fail "repo-automation-install does not commit or push in target repo"
    status=1
  fi
  install_commit_count_after="$(git -C "$install_target" rev-list --count HEAD)"
  install_remote_head_after="$(git -C "$install_target_remote" rev-parse refs/heads/main)"
  if [ "$install_commit_count_before" = "$install_commit_count_after" ] && [ "$install_remote_head_before" = "$install_remote_head_after" ]; then
    test_pass "repo-automation-install leaves target history and remote untouched"
  else
    test_fail "repo-automation-install leaves target history and remote untouched"
    status=1
  fi

  if (
    cd "$install_target" || return 1
    printf '# local override\n' > repo-automation/docs/local-overrides.md
  ); then
    :
  else
    status=1
  fi

  if (
    cd "$smoke_test_dir" || return 1
    repo-automation/bin/repo-automation-install --target="$install_target" --json > "$install_plan_json"
  ) && python -m json.tool "$install_plan_json" >/dev/null && \
    smoke_json_assert "$install_plan_json" 'data.get("mode") == "update"'; then
    test_pass "repo-automation-install second plan infers update mode"
  else
    test_fail "repo-automation-install second plan infers update mode"
    status=1
  fi

  if grep -q '^# local override$' "$install_target/repo-automation/docs/local-overrides.md"; then
    test_pass "repo-automation-install preserves existing local overrides"
  else
    test_fail "repo-automation-install preserves existing local overrides"
    status=1
  fi

  install_status_after="$(git -C "$install_target" status --porcelain)"
  if [ -n "$install_status_after" ]; then
    :
  else
    test_fail "repo-automation-install target repo remains unchanged in git history"
    status=1
  fi

  rm -f "$install_plan_json" >/dev/null 2>&1 || true
  rm -f "$install_doctor_json" >/dev/null 2>&1 || true
  rm -f "$install_target_format_stderr" "$install_target_missing_stderr" "$install_target_empty_stderr" "$install_unknown_stderr" >/dev/null 2>&1 || true
  return "$status"
}

# repo-automation/tests/lib/contracts/install-release.sh EOF
