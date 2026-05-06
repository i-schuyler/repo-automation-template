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

## Not In v0.1.0

v0.1.0 does not include:

- script implementation
- CI workflows
- release automation
- package manager install
- subtree sync

## Intended Future Scripts

These names define the intended shape of later slices. They are not implemented yet.

- `scripts/codex-slice-preflight`
- `scripts/pr-finish`
- `scripts/add-doc-pr`
- `scripts/branch-cleanup`
- `scripts/repo-doctor`
- `scripts/repo-automation-report-upstream`

## Start Here

- Read [docs/INDEX.md](docs/INDEX.md) for the canonical docs order.
- Read [docs/INSTALL_MODELS.md](docs/INSTALL_MODELS.md) before copying this template into downstream repos.
- Read [docs/DOWNSTREAM_FEEDBACK.md](docs/DOWNSTREAM_FEEDBACK.md) before filing shared automation bugs or features.
- Read [docs/VERSIONING.md](docs/VERSIONING.md) before changing version numbers.

## Coming Soon

The basic workflow should remain useful as open source. Paid paths should fund maintenance, examples, and support instead of locking away the core workflow.

- GitHub Sponsors tiers coming soon
- paid setup guide coming soon
- low-cost done-for-you repo setup coming soon
- workflow audit checklist product coming soon
- sponsors-only early recipes/templates coming soon
- paid support for adapting to non-GitHub providers coming soon

## Support

Use GitHub Issues for bugs and feature requests. Downstream repo users should start with [docs/DOWNSTREAM_FEEDBACK.md](docs/DOWNSTREAM_FEEDBACK.md) so local repo-specific requests stay local and shared automation problems are filed upstream.
