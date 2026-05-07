# Known Limitations

`repo-automation-template` is currently a public-alpha, terminal-first automation kit.

The project is intended to reduce repeatable repo maintenance churn for phone-first, Codex-assisted, and GitHub PR workflows. It is useful now, but it is not yet a fully packaged release system.

## Current support boundary

The supported validation path is:

    scripts/run-tests --audit --timeout 200
    scripts/repo-doctor --full --timeout 200
    GitHub Actions validate check

If those pass in the working repo and CI is green, the repo is considered healthy for current public-alpha use.

## Container rehydration limitation

Some external or rehydrated audit environments may still interrupt long nested smoke-test runs in ways that leave child processes behind or cause incomplete cleanup.

This has been observed in assistant-side container audits, even when:

- Termux verification passed
- GitHub Actions passed
- PR branch validation passed
- the repo’s own timeout and smoke harness checks passed

This is not currently treated as a release blocker for public-alpha use.

## What is intentionally not guaranteed yet

The project does not yet guarantee:

- perfect cleanup after arbitrary external hard-kills
- full portability across every CI/container shell environment
- packaged release bundles
- package-manager installation
- Git subtree install mode
- automatic downstream commits or PRs
- full support for non-GitHub providers

## What is supported now

The repo currently supports:

- local branch cleanup planning
- Codex slice preflight checks
- PR finishing through GitHub CLI
- docs-only PR helper flow
- upstream bug/feature reporting
- repo doctor diagnostics
- downstream install/update helper
- compact diagnostic output
- JSON diagnostic output
- timeout-guarded audit runs
- named smoke-test scenarios

## Practical guidance

Use this repo when you want a transparent, inspectable automation kit that can be copied into downstream repos.

Do not use it yet as an unattended release/deployment system.

## How to report issues

Use:

    scripts/repo-automation-report-upstream --type bug --title "Short issue title" --dry-run

Preview the issue first, confirm no secrets are included, then submit explicitly when ready.

## Future improvement areas

Likely future improvements include:

- packaged release bundles
- docs CI completeness checks
- markdown/link validation
- better cross-container smoke-test portability
- optional multi-file smoke-test scenario split
- non-GitHub provider adaptation
