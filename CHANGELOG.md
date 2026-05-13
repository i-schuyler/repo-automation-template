# Changelog

This project uses Keep-a-Changelog-style sections without requiring an external dependency.

## [0.1.0] - Unreleased

### Added

- Added read-only `repo-automation/bin/ci-log-dump` helper for failed GitHub Actions log capture, durable output, and tail excerpts.
- Implemented compact output modes for `repo-automation/bin/run-tests` and `repo-automation/bin/repo-doctor`.
- Hardened audit/test portability with per-check timeout guards, compact audit mode, and named smoke subcheck reporting.
- Moved smoke scenario execution into the shared harness and removed global timeout shadowing.
- Added bounded smoke harness cleanup, named subchecks, and timeout-safe child cleanup.
- Added lightweight docs CI for markdown links, docs index coverage, stale phrasing, and public-entry navigation.
- Added a manifest-vs-installer drift check to keep `repo-automation/manifest.json` aligned with `repo-automation/bin/repo-automation-install` coverage.
- Added downstream `AGENTS.md` install guidance and a compact patch-editing note for repo-local edits.

- Added docs-only bootstrap canon.
- Added issue-form plan and downstream feedback canon.
- Added versioning canon.
- Added monetization funnel docs.
- Added repo-local config scaffold.
- Added shared Bash library scaffold.
- Added config/common-library docs.
- Added safe branch cleanup helper with plan-only default.
- Added Codex slice preflight helper.
- Added docs for branch cleanup and preflight.
- Hardened config failure handling for branch cleanup and preflight.
- Made JSON output machine-parseable on stdout.
- Added all-local-branch classification with skipped reasons.
- Added Git ref-format validation for branch names.
- Added GitHub Actions CI scaffold.
- Added local test runner.
- Added smoke tests for branch cleanup and preflight.
- Added version consistency guard.
- Added PR finish helper for status/watch/explicit merge flows.
- Added PR finish docs and smoke coverage.
- Added docs-only PR helper.
- Added docs-only boundary validation and smoke coverage.
- Added upstream bug/feature reporting helper.
- Added preview-before-submit and redaction safeguards.
- Added report-upstream smoke coverage.
- Added repo doctor helper.
- Added doctor smoke coverage.
- Added downstream install/update helper.
- Added local prepare-release helper for version checks, dry-run previews, apply updates, and machine JSON output.
- Added downstream install docs and smoke coverage.
- Included `repo-automation/tests/lib/test-common.sh` in downstream `--include-tests` install plans and apply sets.
- Fixed add-doc-pr smoke baseline and installer remote fallback contract checks.
- Added installer output contract audit coverage in smoke tests.
- Added public workflow audit checklist product seed.
- Updated installer/config/testing docs for downstream contract auditing.

### Changed

- Documented public-alpha known limitations and refreshed docs navigation before release-readiness.
- Clarified that CI/Termux are the supported validation path while arbitrary container rehydration remains best-effort.

### Not Implemented

- Kept package manager install and subtree sync out of v0.1.0.
