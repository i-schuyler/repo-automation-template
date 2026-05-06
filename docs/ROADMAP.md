# Roadmap

## Slice 0: Docs-Only Bootstrap, Issue Forms, Versioning Canon

- canonical public docs
- issue forms and PR template
- downstream feedback process
- install model decisions
- versioning and changelog canon
- monetization funnel copy

## Slice 1: Config + Shared Bash Library Scaffold

- repo-local config file
- shared Bash library
- compact command summaries
- safer branch naming defaults

## Slice 2: Branch Cleanup + Preflight

- stale branch cleanup helper
- branch deletion ambiguity handling
- `--plan` / `--dry-run`
- safer branch naming defaults

## Slice 3: pr-finish + JSON Status

- `pr-finish`
- `--json` structured output
- CI failure evidence extraction
- compact command summaries

## Slice 4: add-doc-pr + Plan/Parse/Check Profiles

- clearer `add-doc-pr` modes
- check profiles
- `--plan` / `--dry-run`
- package as template directory

## Slice 5: repo-automation-report-upstream Terminal Issue Helper

- downstream upstream-report helper
- preview-before-submit behavior
- terminal GitHub CLI issue creation
- local-vs-upstream issue body fields
- redaction reminders

## Slice 6: Tests + Doctor/Explain UX

- small test suite
- `--doctor`
- `--explain`
- compatibility checks

## Slice 7: Downstream Installer/Import/Update Helper

- future import/update helper
- provenance recording
- installed version/ref checks
- copyable installed-version/context block
- local override preservation

## Slice 8: Version Consistency CI + Release Guard

- version consistency CI
- changelog/version release guard
- future CI guard for `VERSION`, `CHANGELOG.md`, README, decisions, script metadata, release metadata, and installed examples
- version consistency checks across downstream installed docs and config examples

## Additional Planned Work

- compatibility mode for CI/PR providers
- reusable GitHub Actions workflows as CI-only complement
- package as template directory
