# Changelog

This project uses Keep-a-Changelog-style sections without requiring an external dependency.

## [0.1.0] - Unreleased

- Implemented compact output modes for `scripts/run-tests` and `scripts/repo-doctor`.
- Hardened audit/test portability with per-check timeout guards, compact audit mode, and named smoke subcheck reporting.
- Moved smoke scenario execution into the shared harness and removed global timeout shadowing.
- Added bounded smoke harness cleanup, named subchecks, and timeout-safe child cleanup.
### Added

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
- Added downstream install docs and smoke coverage.
- Fixed add-doc-pr smoke baseline and installer remote fallback contract checks.
- Added installer output contract audit coverage in smoke tests.
- Added public workflow audit checklist product seed.
- Updated installer/config/testing docs for downstream contract auditing.

### Not Implemented

- Documented public-alpha known limitations and refreshed docs navigation before release-readiness.
- Clarified that CI/Termux are the supported validation path while arbitrary container rehydration remains best-effort.
