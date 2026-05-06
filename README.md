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
- `scripts/pr-finish`
- `scripts/add-doc-pr`
- `scripts/repo-doctor`
- `scripts/repo-automation-report-upstream`

## Start Here

- Read [docs/INDEX.md](docs/INDEX.md) for the canonical docs order.
- Read [docs/INSTALL_MODELS.md](docs/INSTALL_MODELS.md) before copying this template into downstream repos.
- Read [docs/DOWNSTREAM_FEEDBACK.md](docs/DOWNSTREAM_FEEDBACK.md) before filing shared automation bugs or features.
- Read [docs/repo-automation/config.md](docs/repo-automation/config.md) before editing `.repo-automation.conf`.
- Read [docs/repo-automation/common-library.md](docs/repo-automation/common-library.md) before adding future workflow scripts.
- Read [docs/repo-automation/branch-cleanup.md](docs/repo-automation/branch-cleanup.md) before deleting local branches.
- Read [docs/repo-automation/codex-slice-preflight.md](docs/repo-automation/codex-slice-preflight.md) before running slice preflight automation.
- Read [docs/repo-automation/testing.md](docs/repo-automation/testing.md) before changing scripts or version placements.
- Read [docs/VERSIONING.md](docs/VERSIONING.md) before changing version numbers.

## Testing and CI

CI now validates Bash syntax, smoke behavior, JSON parseability, and version consistency for current scripts.

Run locally:

    scripts/run-tests

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
