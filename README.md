# repo-automation-template

Current version: 0.1.0

`repo-automation-template` is a phone-friendly repo automation template for repeatable GitHub/Codex workflows. It is meant to make branch setup, docs PRs, PR finishing, issue handoff, cleanup, and repo checks easier to repeat from a terminal-first workflow.

Primary users:

- solo developers maintaining multiple small repos
- mobile and Termux users who need short, predictable commands
- multi-repo maintainers who copy the same repo workflow conventions often
- Codex and agent-assisted developers who need stable, explicit repo contracts

## Current Maturity

This repo is in early public read-only/low-attention mode. Issues are welcome. External PRs may be deferred until the public script API and folder layout stabilize.

## v0.1.0 Scope

v0.1.0 is a docs-first bootstrap. It establishes:

- canonical public docs
- versioning conventions
- config conventions
- downstream feedback process
- issue forms
- roadmap
- public coming-soon support and monetization paths
- repo-local config and shared Bash library scaffold for future scripts
- first workflow scaffolds for branch cleanup and codex slice preflight
- pr finish helper scaffold for status/watch/explicit merge flows
- repo doctor read-only health helper scaffold
- downstream install/update helper scaffold

## Not In v0.1.0

v0.1.0 does not include:

- most script implementation
- release automation
- package manager install
- subtree sync

## Intended Future Scripts

These names define the intended shape of slices.

- `scripts/codex-slice-preflight` (implemented in first scaffold form)
- `scripts/branch-cleanup` (implemented in first scaffold form)
- `scripts/pr-finish` (implemented in first scaffold form)
- `scripts/add-doc-pr` (implemented in first scaffold form)
- `scripts/repo-automation-report-upstream` (implemented in first scaffold form)
- `scripts/repo-doctor` (implemented in first scaffold form)
- `scripts/repo-automation-install` (implemented in first scaffold form)

## Start Here

- Read [docs/INDEX.md](docs/INDEX.md) for the canonical docs order.
- Read [docs/INSTALL_MODELS.md](docs/INSTALL_MODELS.md) before copying this template into downstream repos.
- Read [docs/DOWNSTREAM_FEEDBACK.md](docs/DOWNSTREAM_FEEDBACK.md) before filing shared automation bugs or features.
- Read [docs/repo-automation/config.md](docs/repo-automation/config.md) before editing `.repo-automation.conf`.
- Read [docs/repo-automation/common-library.md](docs/repo-automation/common-library.md) before adding future workflow scripts.
- Read [docs/repo-automation/branch-cleanup.md](docs/repo-automation/branch-cleanup.md) before deleting local branches.
- Read [docs/repo-automation/codex-slice-preflight.md](docs/repo-automation/codex-slice-preflight.md) before running slice preflight automation.
- Read [docs/repo-automation/pr-finish.md](docs/repo-automation/pr-finish.md) before watching checks or merging from terminal helper flows.
- Read [docs/repo-automation/add-doc-pr.md](docs/repo-automation/add-doc-pr.md) before creating docs-only pull requests from terminal helper flows.
- Read [docs/repo-automation/repo-automation-report-upstream.md](docs/repo-automation/repo-automation-report-upstream.md) before submitting upstream automation bug/feature reports.
- Read [docs/repo-automation/repo-doctor.md](docs/repo-automation/repo-doctor.md) before running read-only health diagnostics.
- Read [docs/repo-automation/repo-automation-install.md](docs/repo-automation/repo-automation-install.md) before installing/updating automation into downstream repos.
- Read [docs/repo-automation/testing.md](docs/repo-automation/testing.md) before changing scripts or version placements.
- Read [docs/VERSIONING.md](docs/VERSIONING.md) before changing version numbers.

## Testing and CI

CI now validates Bash syntax, smoke behavior, JSON parseability, and version consistency for current scripts.

Run locally:

    scripts/run-tests

The smoke suite now uses `tests/lib/test-common.sh` for named scenario execution, timeout ownership, and cleanup.

## Coming Soon

The basic workflow should remain useful as open source. Paid paths should fund maintenance, examples, and support instead of locking away the core workflow.

- GitHub Sponsors tiers coming soon
- paid setup guide coming soon
- low-cost done-for-you repo setup coming soon
- workflow audit checklist product coming soon
- sponsors-only early recipes/templates coming soon
- paid support for adapting to non-GitHub providers coming soon

Do not add live payment links here unless a support path is actually live and clickable.

## Support

Use GitHub Issues for bugs and feature requests. Downstream repo users should start with [docs/DOWNSTREAM_FEEDBACK.md](docs/DOWNSTREAM_FEEDBACK.md) so local repo-specific requests stay local and shared automation problems are filed upstream.
Downstream repos can now use `scripts/repo-automation-report-upstream` to prepare and submit upstream bug/feature reports from terminal after preview/redaction checks.
`scripts/repo-doctor` now provides a read-only PASS/WARN/FAIL health summary for config, scripts, tests, CI permissions, docs links, and issue templates.
`scripts/repo-automation-install` now provides terminal preview/apply flows for installing or updating managed repo automation files into downstream repos.
The public workflow audit checklist seed lives in [docs/WORKFLOW_AUDIT_CHECKLIST.md](docs/WORKFLOW_AUDIT_CHECKLIST.md) and remains coming soon.


### Low-token diagnostics

The output-mode contract in `docs/repo-automation/output-modes.md` now keeps `scripts/run-tests` and `scripts/repo-doctor` compact by default: summary output first, detailed logs in temp files, `--explain` for full detail, `--audit` for the compact full suite, `--timeout` for bounded subchecks, and JSON modes for warnings/failures.

### Public-alpha limitations

Known limitations are documented in `docs/KNOWN_LIMITATIONS.md`. The supported health check path is `scripts/run-tests --audit --timeout 200`, `scripts/repo-doctor --full --timeout 200`, and the GitHub Actions `validate` check.
