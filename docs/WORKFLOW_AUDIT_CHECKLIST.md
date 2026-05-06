# Workflow Audit Checklist

This is a public, practical seed for the workflow audit checklist product. It is useful now as a quick terminal-first review, and any paid/support path remains coming soon.

## Who This Is For

- maintainers who install `repo-automation-template` into downstream repos
- teams that want a fast health check before asking for help
- agents or humans who want a short readiness pass before shipping automation changes

## 15-Minute Quick Audit

1. Run the read-only repo doctor.

       scripts/repo-doctor --quick

2. Run the local validation entrypoint.

       scripts/run-tests

3. Check whether the repo-local install and downstream context are current.

       scripts/repo-automation-install --target /path/to/downstream --json

4. Review version placement and changelog alignment.

       scripts/repo-doctor --check version

5. Check branch, PR, and CI helper safety contracts.

       scripts/repo-doctor --check scripts

## Repo Automation Install Health

- `.repo-automation.conf` exists and loads cleanly
- `REPO_AUTOMATION_VERSION` matches the source version line
- installed docs show the upstream repo, installed version/ref, installed date, and local overrides doc
- unsupported downstream origins normalize `EXPECTED_REMOTE_URL` to `""`
- `scripts/repo-doctor --quick --no-run-tests` stays read-only and avoids GitHub auth

## Agent Safety Rails

- use `scripts/codex-slice-preflight` before branch work
- keep `scripts/branch-cleanup` on plan-only unless `--apply` is explicit
- use `scripts/pr-finish` only for explicit status, watch, and merge flows
- keep `scripts/add-doc-pr` on docs-only boundaries
- preview upstream issues before submission with `scripts/repo-automation-report-upstream`

## Branch / PR / CI Safety

- confirm the current branch is not `main`
- confirm the worktree is clean before apply/merge actions
- require green checks before `scripts/pr-finish --merge`
- never force-delete local branches or delete remote branches from terminal helpers
- keep CI permissions minimal and read-only by default

## Versioning / Changelog Consistency

- `VERSION` and `REPO_AUTOMATION_VERSION` should agree
- `CHANGELOG.md` should carry the matching unreleased heading
- README-visible version text should match the tracked version
- `docs/DECISIONS.md` and `docs/VERSIONING.md` should stay in sync with the version-placement contract
- downstream examples and installed docs should show the same installed version/ref shape

## Downstream Support / Readiness

- make sure downstream installs preserve local overrides
- keep the installed context block copyable for upstream bug reports
- use the terminal helper instead of browser issue forms when possible
- record whether the downstream remote is supported, missing, or unsupported rather than leaking raw origin details

## Monetization / Support Readiness

- GitHub Sponsors tiers coming soon
- paid setup guide coming soon
- low-cost done-for-you repo setup coming soon
- workflow audit checklist product coming soon
- sponsors-only early recipes/templates coming soon
- paid support for adapting to non-GitHub providers coming soon

## When To Ask For Help

- the quick audit returns `FAIL`
- `scripts/run-tests` fails locally
- a downstream install cannot validate its config
- a branch helper wants to delete something unsafe
- a PR helper blocks on checks you do not understand

The checklist is intentionally public and lightweight. It is meant to reduce churn before support, not to hide support behind a paywall.


## Low-noise diagnostic output

A healthy repo automation setup should make diagnostics easy to share without dumping pages of passing checks. Prefer compact summaries, warning/failure JSON, and temp log files for full detail.
