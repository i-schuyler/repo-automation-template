# repo-automation-template

Current version: 0.1.0

`repo-automation-template` is a phone-friendly repo automation template for repeatable GitHub/Codex workflows. It is meant to make branch setup, docs PRs, PR finishing, issue handoff, cleanup, release checks, and repo health checks easier to repeat from a terminal-first workflow.

Primary users:

- solo developers maintaining multiple small repos
- mobile and Termux users who need short, predictable commands
- multi-repo maintainers who copy the same repo workflow conventions often
- Codex and agent-assisted developers who need stable, explicit repo contracts

## Current Helper Surface

The repo automation entry points live under `repo-automation/`:

- `repo-automation/bin/codex-slice-preflight`
- `repo-automation/bin/branch-cleanup`
- `repo-automation/bin/pr-finish`
- `repo-automation/bin/add-doc-pr`
- `repo-automation/bin/pr-create`
- `repo-automation/bin/repo-doctor`
- `repo-automation/bin/run-tests`
- `repo-automation/bin/prepare-release`
- `repo-automation/bin/repo-automation-install`
- `repo-automation/bin/repo-automation-report-upstream`
- `repo-automation/bin/automation-freshness`
- `repo-automation/bin/github-settings-check`
- `repo-automation/bin/failure-log`
- `repo-automation/bin/touched-files`
- `repo-automation/bin/ci-status`
- `repo-automation/bin/ci-watch`
- `repo-automation/bin/ci-log-dump`
- `repo-automation/bin/status-packet`
- `repo-automation/bin/post-codex-packet`
- `repo-automation/bin/evidence-bundle`
- `repo-automation/bin/starter-template-ready`
- `repo-automation/lib/common.sh`
- `repo-automation/tests/lib/test-common.sh`
- `repo-automation/tests/lib/smoke-common.sh`
- `repo-automation/tests/docs-check.sh`
- `repo-automation/tests/contracts/`
- `repo-automation/tests/smoke.sh`
- `repo-automation/tests/version-consistency.sh`

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
