# Roadmap

## Slice 0: Docs-Only Bootstrap, Issue Forms, Versioning Canon

- canonical public docs
- issue forms and PR template
- downstream feedback process
- install model decisions
- versioning and changelog canon
- monetization funnel copy

## Slice 1: Config + Shared Bash Library Scaffold (Completed)

- repo-local config file
- shared Bash library
- compact command summaries
- safer branch naming defaults
- config and common-library docs

## Slice 2: Branch Cleanup + Preflight (Completed)

- stale branch cleanup helper
- branch deletion ambiguity handling
- `--plan` and `--apply`
- safer branch naming defaults
- codex slice preflight helper
- preflight check-only mode
- explicit `--delete-safe-stale` preflight deletion mode
- JSON stdout parseability hardening and stderr human-log split
- strict config failure stop behavior for behavior-changing scripts
- all-local-branch classification with explicit skipped reasons

## Slice 3: CI/Test Scaffold + Version Consistency Guard (Completed)

- GitHub Actions CI scaffold with minimal permissions
- `scripts/run-tests` local validation entrypoint
- smoke tests for branch cleanup and preflight
- JSON parseability checks in local and CI paths
- version consistency guard via `tests/version-consistency.sh`

## Slice 4: PR Finish + JSON Status (Completed)

- `pr-finish`
- `--plan`/`--status` default no-merge path
- explicit `--watch` and explicit `--merge` gating
- `--json` structured output
- explicit post-merge branch deletion flag handling

## Slice 5: add-doc-pr + Plan/Parse/Check Profiles (Completed)

- clearer `add-doc-pr` modes
- check profiles
- `--plan` / `--dry-run`
- docs-only changed-file boundary enforcement
- explicit `--create-pr` gate

## Slice 6: repo-automation-report-upstream Terminal Issue Helper (Completed)

- downstream upstream-report helper
- preview-before-submit behavior
- terminal GitHub CLI issue creation
- local-vs-upstream issue body fields
- redaction reminders

## Slice 7: repo-doctor + Explain UX (Completed)

- `repo-doctor` read-only helper
- PASS/WARN/FAIL health findings
- `--quick` / `--full` modes
- `--json` structured output
- smoke coverage and run-tests integration

## Slice 8: Downstream Installer/Import/Update Helper (Completed)

- `scripts/repo-automation-install` install/update helper
- provenance recording
- installed version/ref checks
- copyable installed-version/context block
- local override preservation

## Slice 9: Release Guard Extensions (Future)

- changelog/version release guard
- future CI guard for `VERSION`, `CHANGELOG.md`, README, decisions, script metadata, release metadata, and installed examples
- version consistency checks across downstream installed docs and config examples

## Slice 10: Final Audit Fixes + Workflow Audit Checklist Seed (Completed)

- add-doc-pr smoke baseline fixture now commits the full automation baseline before docs-only boundary tests
- installer remote fallback normalizes unsupported `EXPECTED_REMOTE_URL` values to empty
- installer smoke coverage audits downstream contract behavior in temporary repos
- public workflow audit checklist product seed

## Additional Planned Work

- compatibility mode for CI/PR providers
- reusable GitHub Actions workflows as CI-only complement
- package as template directory
- output-mode contract now implemented for `scripts/run-tests` and `scripts/repo-doctor`; remaining scripts may adopt it later.


- Output-mode contract: compact summaries, temp log files, `--explain`, and JSON levels for lower-token diagnostics.
