#!/usr/bin/env bash
# repo-automation/tests/lib/smoke-fixtures.sh

# shellcheck shell=bash
# shellcheck disable=SC2154
# smoke_test_base, smoke_test_dir, and smoke_repo_root are shared harness
# globals initialized by repo-automation/tests/lib/smoke-common.sh before
# contract checks run.

smoke_collect_lib_paths() {
  local path=""
  for path in "$smoke_repo_root"/repo-automation/lib/*.sh; do
    [ -e "$path" ] || continue
    printf '%s\n' "${path#"$smoke_repo_root/"}"
  done
}

smoke_assert_fixture_integrity() {
  local rel_path=""
  local source_path=""
  local target_path=""

  while IFS= read -r rel_path; do
    [ -n "$rel_path" ] || continue
    source_path="$smoke_repo_root/$rel_path"
    target_path="$smoke_test_dir/$rel_path"
    [ -f "$target_path" ] || return 1
    if [ -x "$source_path" ] && [ ! -x "$target_path" ]; then
      return 1
    fi
  done <<EOF
$(smoke_collect_lib_paths)
EOF

  return 0
}

smoke_write_artifact_safety_fixture() {
  local root="$1"

  mkdir -p "$root/docs" "$root/build" "$root/node_modules/pkg" "$root/vendor/cache" "$root/.cache" "$root/repo-automation-output/review-pack" || return 1

  cat > "$root/.editorconfig" <<'EOF'
root = true

[*.md]
charset = utf-8
EOF
  printf '%s\n' '.cache/ignored.cache' >> "$root/.gitignore"
  cat > "$root/.env" <<'EOF'
SECRET_TOKEN=fixture-secret
EOF
  printf 'ignored cache fixture\n' > "$root/.cache/ignored.cache"
  printf 'safe untracked doc fixture\n' > "$root/docs/safe-untracked.md"
  printf 'generated packet artifact fixture\n' > "$root/repo-automation-output/review-pack/output.txt"
  printf 'build output fixture\n' > "$root/build/output.bin"
  printf 'nested dependency cache fixture\n' > "$root/node_modules/pkg/cache.txt"
  printf 'nested vendor cache fixture\n' > "$root/vendor/cache/tool.bin"
}

smoke_setup_temp_repo() {
  mkdir -p "$TEST_TEMP_ROOT" || return 1
  smoke_test_base="$(mktemp -d "${TEST_TEMP_ROOT}/smoke.XXXXXX")" || return 1
  test_register_temp_dir "$smoke_test_base" || return 1
  smoke_test_dir="$smoke_test_base/smoke"
  smoke_remote_dir="$smoke_test_base/smoke-remote.git"
  mkdir -p "$smoke_test_dir" || return 1

  export smoke_repo_root smoke_test_base smoke_test_dir smoke_remote_dir smoke_expected_origin_url smoke_timeout_seconds

  mkdir -p "$smoke_test_dir/repo-automation/bin" "$smoke_test_dir/repo-automation/lib" "$smoke_test_dir/repo-automation/tests/lib" "$smoke_test_dir/repo-automation/tests/lib/contracts" "$smoke_test_dir/repo-automation/tests/contracts" "$smoke_test_dir/repo-automation/tests" || return 1
  cp "$smoke_repo_root/AGENTS.md" "$smoke_test_dir/AGENTS.md" || return 1
  cp "$smoke_repo_root"/repo-automation/lib/*.sh "$smoke_test_dir/repo-automation/lib/" || return 1
  cp "$smoke_repo_root/repo-automation/bin/branch-cleanup" "$smoke_test_dir/repo-automation/bin/branch-cleanup" || return 1
  cp "$smoke_repo_root/repo-automation/bin/codex-slice-preflight" "$smoke_test_dir/repo-automation/bin/codex-slice-preflight" || return 1
  cp "$smoke_repo_root/repo-automation/bin/pr-finish" "$smoke_test_dir/repo-automation/bin/pr-finish" || return 1
  cp "$smoke_repo_root/repo-automation/bin/add-doc-pr" "$smoke_test_dir/repo-automation/bin/add-doc-pr" || return 1
  cp "$smoke_repo_root/repo-automation/bin/pr-body-check" "$smoke_test_dir/repo-automation/bin/pr-body-check" || return 1
  cp "$smoke_repo_root/repo-automation/bin/pr-create" "$smoke_test_dir/repo-automation/bin/pr-create" || return 1
  cp "$smoke_repo_root/repo-automation/bin/repo-flow" "$smoke_test_dir/repo-automation/bin/repo-flow" || return 1
  cp "$smoke_repo_root/repo-automation/bin/automation-freshness" "$smoke_test_dir/repo-automation/bin/automation-freshness" || return 1
  cp "$smoke_repo_root/repo-automation/bin/repo-automation-report-upstream" "$smoke_test_dir/repo-automation/bin/repo-automation-report-upstream" || return 1
  cp "$smoke_repo_root/repo-automation/bin/repo-doctor" "$smoke_test_dir/repo-automation/bin/repo-doctor" || return 1
  cp "$smoke_repo_root/repo-automation/bin/github-settings-check" "$smoke_test_dir/repo-automation/bin/github-settings-check" || return 1
  cp "$smoke_repo_root/repo-automation/bin/managed-file-check" "$smoke_test_dir/repo-automation/bin/managed-file-check" || return 1
  cp "$smoke_repo_root/repo-automation/bin/managed-file-add" "$smoke_test_dir/repo-automation/bin/managed-file-add" || return 1
  cp "$smoke_repo_root/repo-automation/bin/failure-log" "$smoke_test_dir/repo-automation/bin/failure-log" || return 1
  cp "$smoke_repo_root/repo-automation/bin/touched-files" "$smoke_test_dir/repo-automation/bin/touched-files" || return 1
  cp "$smoke_repo_root/repo-automation/bin/ci-status" "$smoke_test_dir/repo-automation/bin/ci-status" || return 1
  cp "$smoke_repo_root/repo-automation/bin/ci-watch" "$smoke_test_dir/repo-automation/bin/ci-watch" || return 1
  cp "$smoke_repo_root/repo-automation/bin/ci-log-dump" "$smoke_test_dir/repo-automation/bin/ci-log-dump" || return 1
  cp "$smoke_repo_root/repo-automation/bin/ci-failure-artifacts" "$smoke_test_dir/repo-automation/bin/ci-failure-artifacts" || return 1
  cp "$smoke_repo_root/repo-automation/bin/contract-debt-report" "$smoke_test_dir/repo-automation/bin/contract-debt-report" || return 1
  cp "$smoke_repo_root/repo-automation/bin/shellcheck-ci-parity" "$smoke_test_dir/repo-automation/bin/shellcheck-ci-parity" || return 1
  cp "$smoke_repo_root/repo-automation/bin/check-portability" "$smoke_test_dir/repo-automation/bin/check-portability" || return 1
  cp "$smoke_repo_root/repo-automation/bin/status-packet" "$smoke_test_dir/repo-automation/bin/status-packet" || return 1
  cp "$smoke_repo_root/repo-automation/bin/post-codex-review" "$smoke_test_dir/repo-automation/bin/post-codex-review" || return 1
  cp "$smoke_repo_root/repo-automation/bin/post-codex-packet" "$smoke_test_dir/repo-automation/bin/post-codex-packet" || return 1
  cp "$smoke_repo_root/repo-automation/bin/review-pack" "$smoke_test_dir/repo-automation/bin/review-pack" || return 1
  cp "$smoke_repo_root/repo-automation/bin/repair-prompt" "$smoke_test_dir/repo-automation/bin/repair-prompt" || return 1
  cp "$smoke_repo_root/repo-automation/bin/repo-zip" "$smoke_test_dir/repo-automation/bin/repo-zip" || return 1
  cp "$smoke_repo_root/repo-automation/bin/evidence-bundle" "$smoke_test_dir/repo-automation/bin/evidence-bundle" || return 1
  cp "$smoke_repo_root/repo-automation/bin/starter-template-ready" "$smoke_test_dir/repo-automation/bin/starter-template-ready" || return 1
  cp "$smoke_repo_root/repo-automation/bin/prepare-release" "$smoke_test_dir/repo-automation/bin/prepare-release" || return 1
  cp "$smoke_repo_root/repo-automation/bin/repo-automation-install" "$smoke_test_dir/repo-automation/bin/repo-automation-install" || return 1
  cp "$smoke_repo_root/repo-automation/bin/check-tooling" "$smoke_test_dir/repo-automation/bin/check-tooling" || return 1
  cp "$smoke_repo_root/repo-automation/bin/run-tests" "$smoke_test_dir/repo-automation/bin/run-tests" || return 1
  cp "$smoke_repo_root/repo-automation/helper-metadata.json" "$smoke_test_dir/repo-automation/helper-metadata.json" || return 1
  cp "$smoke_repo_root/repo-automation/manifest.json" "$smoke_test_dir/repo-automation/manifest.json" || return 1
  cp "$smoke_repo_root/repo-automation/tests/lib/test-common.sh" "$smoke_test_dir/repo-automation/tests/lib/test-common.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/lib/smoke-common.sh" "$smoke_test_dir/repo-automation/tests/lib/smoke-common.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/lib/smoke-gh-stub.sh" "$smoke_test_dir/repo-automation/tests/lib/smoke-gh-stub.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/lib/smoke-capture.sh" "$smoke_test_dir/repo-automation/tests/lib/smoke-capture.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/lib/smoke-fixtures.sh" "$smoke_test_dir/repo-automation/tests/lib/smoke-fixtures.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/lib/smoke-registry.sh" "$smoke_test_dir/repo-automation/tests/lib/smoke-registry.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/lib/contracts"/*.sh "$smoke_test_dir/repo-automation/tests/lib/contracts/" || return 1
  cp "$smoke_repo_root/repo-automation/tests/docs-check.sh" "$smoke_test_dir/repo-automation/tests/docs-check.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/smoke.sh" "$smoke_test_dir/repo-automation/tests/smoke.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/version-consistency.sh" "$smoke_test_dir/repo-automation/tests/version-consistency.sh" || return 1
  cp "$smoke_repo_root/repo-automation/tests/contracts"/*.sh "$smoke_test_dir/repo-automation/tests/contracts/" || return 1
  chmod +x "$smoke_test_dir/repo-automation/bin/branch-cleanup" "$smoke_test_dir/repo-automation/bin/codex-slice-preflight" "$smoke_test_dir/repo-automation/bin/pr-finish" "$smoke_test_dir/repo-automation/bin/add-doc-pr" "$smoke_test_dir/repo-automation/bin/pr-body-check" "$smoke_test_dir/repo-automation/bin/pr-create" "$smoke_test_dir/repo-automation/bin/repo-flow" "$smoke_test_dir/repo-automation/bin/automation-freshness" "$smoke_test_dir/repo-automation/bin/github-settings-check" "$smoke_test_dir/repo-automation/bin/managed-file-check" "$smoke_test_dir/repo-automation/bin/managed-file-add" "$smoke_test_dir/repo-automation/bin/starter-template-ready" "$smoke_test_dir/repo-automation/bin/prepare-release" "$smoke_test_dir/repo-automation/bin/repo-automation-report-upstream" "$smoke_test_dir/repo-automation/bin/repo-doctor" "$smoke_test_dir/repo-automation/bin/check-tooling" "$smoke_test_dir/repo-automation/bin/check-portability" "$smoke_test_dir/repo-automation/bin/failure-log" "$smoke_test_dir/repo-automation/bin/touched-files" "$smoke_test_dir/repo-automation/bin/ci-status" "$smoke_test_dir/repo-automation/bin/ci-watch" "$smoke_test_dir/repo-automation/bin/shellcheck-ci-parity" "$smoke_test_dir/repo-automation/bin/contract-debt-report" "$smoke_test_dir/repo-automation/bin/status-packet" "$smoke_test_dir/repo-automation/bin/post-codex-review" "$smoke_test_dir/repo-automation/bin/post-codex-packet" "$smoke_test_dir/repo-automation/bin/review-pack" "$smoke_test_dir/repo-automation/bin/repair-prompt" "$smoke_test_dir/repo-automation/bin/repo-zip" "$smoke_test_dir/repo-automation/bin/evidence-bundle" "$smoke_test_dir/repo-automation/bin/ci-failure-artifacts" "$smoke_test_dir/repo-automation/bin/repo-automation-install" "$smoke_test_dir/repo-automation/bin/run-tests" "$smoke_test_dir/repo-automation/tests/docs-check.sh" "$smoke_test_dir/repo-automation/tests/smoke.sh" "$smoke_test_dir/repo-automation/tests/version-consistency.sh" "$smoke_test_dir/repo-automation/tests/contracts"/*.sh || return 1

  (
    cd "$smoke_test_dir" || return 1
    git init -b main >/dev/null || return 1
    git config user.name "repo-automation-test" || return 1
    git config user.email "repo-automation-test@example.com" || return 1
    cat > README.md <<EOF
# smoke

Current version: 0.1.0
EOF
    cat > CONTRIBUTING.md <<'EOF'
# Contributing

Smoke fixture contribution notes.
EOF
    cat > SUPPORT.md <<'EOF'
# Support

Smoke fixture support notes.
EOF
    cat > VERSION <<EOF
0.1.0
EOF
    cat > CHANGELOG.md <<EOF
# Changelog

## [0.1.0] - Unreleased

EOF
    mkdir -p docs .github/workflows .github/ISSUE_TEMPLATE || return 1
    cp -R "$smoke_repo_root/repo-automation/docs" repo-automation/ || return 1
    cp "$smoke_repo_root/.github/pull_request_template.md" .github/pull_request_template.md || return 1
    cp "$smoke_repo_root/.github/ISSUE_TEMPLATE/automation-bug.yml" .github/ISSUE_TEMPLATE/automation-bug.yml || return 1
    cp "$smoke_repo_root/.github/ISSUE_TEMPLATE/automation-feature.yml" .github/ISSUE_TEMPLATE/automation-feature.yml || return 1
    mkdir -p examples/downstream/docs/repo-automation || return 1
    cat > docs/DECISIONS.md <<EOF
# Decisions

| Current version line | starts at 0.1.0 |
EOF
    cat > docs/KNOWN_LIMITATIONS.md <<'EOF'
# Known Limitations

Smoke fixture limitations.
EOF
    cat > docs/VERSIONING.md <<EOF
# Versioning

Current version: 0.1.0

## Version Modes

The automation release version is checked by prepare-release.

Version numbers must stay aligned in these places:
- VERSION
- .repo-automation.conf
- REPO_AUTOMATION_VERSION
- REPO_AUTOMATION_CONF_VERSION
- repo-automation/tests/version-consistency.sh
- examples/downstream/.repo-automation.conf.example
EOF
    cat > docs/DOWNSTREAM_FEEDBACK.md <<'EOF'
# Downstream Feedback

Installed config should include:

```sh
INSTALLED_VERSION_OR_REF="0.1.0"
```
EOF
    cat > docs/WORKFLOW_AUDIT_CHECKLIST.md <<'EOF'
# Workflow Audit Checklist

Smoke fixture checklist notes.
EOF
    cat > docs/INDEX.md <<EOF
# Docs Index

- [README](../README.md)
- [Changelog](../CHANGELOG.md)
- [Contributing](../CONTRIBUTING.md)
- [Support](../SUPPORT.md)
- [Decisions](../docs/DECISIONS.md)
- [Known Limitations](../docs/KNOWN_LIMITATIONS.md)
- [Downstream Feedback](../docs/DOWNSTREAM_FEEDBACK.md)
- [Versioning](../docs/VERSIONING.md)
- [Workflow Audit Checklist](../docs/WORKFLOW_AUDIT_CHECKLIST.md)
- [Pull Request Template](../.github/pull_request_template.md)
- [Automation Bug Issue Form](../.github/ISSUE_TEMPLATE/automation-bug.yml)
- [Automation Feature Issue Form](../.github/ISSUE_TEMPLATE/automation-feature.yml)
- [Example Downstream Config](../examples/downstream/.repo-automation.conf.example)
- [Example Downstream Repo Automation README](../examples/downstream/docs/repo-automation/README.md)
- [Branch Cleanup](../repo-automation/docs/branch-cleanup.md)
- [Codex Slice Preflight](../repo-automation/docs/codex-slice-preflight.md)
- [PR Finish](../repo-automation/docs/pr-finish.md)
- [Add Doc PR](../repo-automation/docs/add-doc-pr.md)
- [PR Create](../repo-automation/docs/pr-create.md)
- [Report Upstream](../repo-automation/docs/repo-automation-report-upstream.md)
- [Repo Doctor](../repo-automation/docs/repo-doctor.md)
- [GitHub Settings Check](../repo-automation/docs/github-settings-check.md)
- [Failure Log](../repo-automation/docs/failure-log.md)
- [Touched Files](../repo-automation/docs/touched-files.md)
- [CI Status](../repo-automation/docs/ci-status.md)
- [CI Watch](../repo-automation/docs/ci-watch.md)
- [Status Packet](../repo-automation/docs/status-packet.md)
- [Repo Zip](../repo-automation/docs/repo-zip.md)
- [Evidence Bundle](../repo-automation/docs/evidence-bundle.md)
- [Starter Template Readiness](../repo-automation/docs/starter-template-readiness.md)
- [Managed Files](../repo-automation/docs/managed-files.md)
- [Repo Automation Install](../repo-automation/docs/repo-automation-install.md)
- [Output Modes](../repo-automation/docs/output-modes.md)
- [Testing](../repo-automation/docs/testing.md)
EOF
    mkdir -p examples/downstream || return 1
    cat > examples/downstream/.repo-automation.conf.example <<EOF
REPO_AUTOMATION_VERSION="0.1.0"
INSTALLED_VERSION_OR_REF="0.1.0-EXAMPLE"
EOF
    cat > examples/downstream/docs/repo-automation/README.md <<'EOF'
# Downstream Repo Automation

```text
Repo automation installed context:
- Installed version/ref: 0.1.0-EXAMPLE
```
EOF
    cat > .github/workflows/ci.yml <<EOF
name: CI
permissions:
  contents: read
EOF
    touch .github/ISSUE_TEMPLATE/automation-bug.yml .github/ISSUE_TEMPLATE/automation-feature.yml || return 1
    git add README.md || return 1
    git add VERSION CHANGELOG.md README.md docs .github examples || return 1
    git commit -m "init" >/dev/null || return 1
    git init --bare --initial-branch=main "$smoke_remote_dir" >/dev/null || return 1
    git remote add origin "$smoke_remote_dir" || return 1
    git push -u origin main >/dev/null 2>&1 || return 1
    git remote set-url origin "$smoke_expected_origin_url" || return 1
    git update-ref refs/remotes/origin/main "$(git rev-parse main)" || return 1
    cat > .repo-automation.conf <<EOF
# .repo-automation.conf
REPO_AUTOMATION_CONF_VERSION="0.1"
REPO_AUTOMATION_VERSION="0.1.0"
UPSTREAM_REPO_FULL_NAME="i-schuyler/repo-automation-template"
UPSTREAM_ISSUE_URL="https://github.com/i-schuyler/repo-automation-template/issues/new/choose"
INSTALLED_FROM="i-schuyler/repo-automation-template"
INSTALLED_VERSION_OR_REF="0.1.0"
INSTALLED_AT="2026-05-06"
LOCAL_OVERRIDES_DOC="repo-automation/docs/local-overrides.md"
DEFAULT_BRANCH="main"
DOCS_DIR="docs"
DOCS_INDEX="docs/INDEX.md"
STATE_DIR_NAME="repo-automation-template-tests"
REMOTE_NAME="origin"
EXPECTED_REMOTE_URL="$smoke_expected_origin_url"
PREFLIGHT_REQUIRE_CLEAN_WORKTREE="true"
CI_PROVIDER="github"
PR_PROVIDER="github"
MERGE_MODE="squash"
DOC_PR_TIMEOUT_SECONDS=60
DOC_PR_POLL_SECONDS=10
IMPLEMENTATION_PR_TIMEOUT_SECONDS=300
IMPLEMENTATION_PR_POLL_SECONDS=15
DOC_BRANCH_PREFIX="docs"
FEATURE_BRANCH_PREFIX="feature"
FIX_BRANCH_PREFIX="fix"
CHECK_PROFILE_DEFAULT="docs"
CHECK_PROFILE_DOCS_COMMANDS=("git diff --check")
CHECK_PROFILE_NONE_COMMANDS=()
# .repo-automation.conf EOF
EOF
    # Commit the full automation baseline before docs-only boundary tests.
    git add -A >/dev/null || return 1
    git commit -m "add test automation files" >/dev/null || return 1
    git update-ref refs/remotes/origin/main "$(git rev-parse main)" || return 1
    return 0
  ) || return 1

  smoke_assert_fixture_integrity || return 1
}

smoke_setup_subset_repo() {
  local subset_base
  local subset_dir

  subset_base="$(mktemp -d "${TEST_TEMP_ROOT}/subset.XXXXXX")" || return 1
  test_register_temp_dir "$subset_base" || return 1
  subset_dir="$subset_base/repo"

  cp -R "$smoke_test_dir" "$subset_dir" || return 1
  cat > "$subset_dir/repo-automation/tests/smoke.sh" <<'EOF'
#!/usr/bin/env bash
set -u
set -o pipefail
printf 'PASS: subset smoke stub
'
EOF
  chmod +x "$subset_dir/repo-automation/tests/smoke.sh" || return 1
  (
    cd "$subset_dir" || return 1
    git config user.name "repo-automation-test" || return 1
    git config user.email "repo-automation-test@example.com" || return 1
    git add repo-automation/tests/smoke.sh >/dev/null 2>&1 || return 1
    git commit -m "Stub smoke check" >/dev/null 2>&1 || return 1
  ) || return 1

  printf '%s
' "$subset_dir"
}

smoke_restore_fixture_after_timeout() {
  if [ "${TEST_LAST_TIMEOUT:-0}" -eq 1 ] || [ ! -d "$smoke_test_dir" ]; then
    smoke_setup_temp_repo || return 1
  fi
}

# repo-automation/tests/lib/smoke-fixtures.sh EOF
