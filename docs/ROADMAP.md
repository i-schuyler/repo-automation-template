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

## Slice 4: pr-finish + JSON Status (Future)

- `pr-finish`
- `--json` structured output
- CI failure evidence extraction
- compact command summaries

## Slice 5: add-doc-pr + Plan/Parse/Check Profiles (Future)

- clearer `add-doc-pr` modes
- check profiles
- `--plan` / `--dry-run`
- package as template directory

## Slice 6: repo-automation-report-upstream Terminal Issue Helper (Future)

- downstream upstream-report helper
- preview-before-submit behavior
- terminal GitHub CLI issue creation
- local-vs-upstream issue body fields
- redaction reminders

## Slice 7: repo-doctor + Explain UX (Future)

- `--doctor`
- `--explain`
- compatibility checks

## Slice 8: Downstream Installer/Import/Update Helper (Future)

- future import/update helper
- provenance recording
- installed version/ref checks
- copyable installed-version/context block
- local override preservation

## Slice 9: Release Guard Extensions (Future)

- changelog/version release guard
- future CI guard for `VERSION`, `CHANGELOG.md`, README, decisions, script metadata, release metadata, and installed examples
- version consistency checks across downstream installed docs and config examples

## Additional Planned Work

- compatibility mode for CI/PR providers
- reusable GitHub Actions workflows as CI-only complement
- package as template directory
