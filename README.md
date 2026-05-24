# repo-automation-template

Current version: 0.1.0

`repo-automation-template` is a phone-friendly repo automation template for repeatable GitHub/Codex workflows. It is meant to make branch setup, docs PRs, PR finishing, issue handoff, cleanup, release checks, and repo health checks easier to repeat from a terminal-first workflow.

Primary users:

- solo developers maintaining multiple small repos
- mobile and Termux users who need short, predictable commands
- multi-repo maintainers who copy the same repo workflow conventions often
- Codex and agent-assisted developers who need stable, explicit repo contracts

## Starter Surface

For a first pass in a new repo, start with:

- `repo-automation/bin/codex-slice-preflight` for branch setup and safety checks
- `repo-automation/bin/repo-flow` for submit / merge / watch flows
- `repo-automation/bin/pr-finish` for the explicit merge/delete/sync step
- `repo-automation/bin/repo-doctor` for read-only health checks
- `repo-automation/bin/run-tests` for the standard test harness

For the full helper reference, see:

- [docs/INDEX.md](docs/INDEX.md)
- [repo-automation/docs/helper-contracts.md](repo-automation/docs/helper-contracts.md)
- [repo-automation/docs/script-routing.md](repo-automation/docs/script-routing.md)

The complete machine-readable helper inventory is `repo-automation/helper-metadata.json`.

Representative supporting helpers:

- `repo-automation/bin/prepare-release`
- `repo-automation/bin/automation-freshness`
- `repo-automation/bin/touched-files`
- `repo-automation/bin/ci-log-dump`

## Current Maturity

This repo is in early public read-only/low-attention mode. Issues are welcome. External PRs may be deferred until the public helper surface and folder layout stabilize.

## Start Here

- Read [docs/INDEX.md](docs/INDEX.md) for the canonical docs order.
- Read [docs/VERSIONING.md](docs/VERSIONING.md) before changing version numbers.
- Read [repo-automation/docs/version-modes.md](repo-automation/docs/version-modes.md) for the version ownership model.
- Read [docs/INSTALL_MODELS.md](docs/INSTALL_MODELS.md) before copying this template into downstream repos.
- Read [docs/WORKFLOW_AUDIT_CHECKLIST.md](docs/WORKFLOW_AUDIT_CHECKLIST.md) before running audit-style checks.

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
