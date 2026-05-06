# Downstream Install Contract

Downstream installs should make the automation visible, inspectable, and safe to report upstream.

## Installed Files

Default installer-managed paths:

- `scripts/`
- `scripts/lib/`
- `docs/repo-automation/`
- `.repo-automation.conf`
- generated `docs/repo-automation/README.md`
- optional `tests/` and `scripts/run-tests` when `--include-tests` is used
- optional `.github/workflows/ci.yml` when `--include-ci` is used

Public config must not contain secrets or machine-local values.
Installer apply mode must not commit, push, create PRs, merge, or delete branches in target repos.

Downstream repos should have a visible repo-automation README showing:

- installed version/ref
- upstream issue path
- local override location
- redaction rules
- when to file upstream versus local
- a copyable installed-version/context block for upstream bug reports

When available, downstream installs should include `scripts/repo-automation-report-upstream` so upstream shared automation bugs/features can be prepared with preview/redaction safeguards before submission.
Downstream installs should use `scripts/repo-automation-install --target <repo>` in plan mode first, then explicit `--apply`.
