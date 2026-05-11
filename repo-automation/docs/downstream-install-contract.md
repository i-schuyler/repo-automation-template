# Downstream Install Contract

Downstream installs should make the automation visible, inspectable, and safe to report upstream.

## Installed Files

Default installer-managed paths:

- `repo-automation/bin/`
- `repo-automation/lib/`
- `repo-automation/docs/`
- `.repo-automation.conf`
- generated `repo-automation/docs/README.md`
- optional `repo-automation/tests/lib/test-common.sh`, `repo-automation/tests/smoke.sh`, `repo-automation/tests/version-consistency.sh`, and `repo-automation/bin/run-tests` when `--include-tests` is used
- optional `.github/workflows/ci.yml` when `--include-ci` is used

Public config must not contain secrets or machine-local values.
Installer apply mode must not commit, push, create PRs, merge, or delete branches in target repos.
If the target origin is missing, local, file-based, HTTPS, or otherwise unsupported, the generated downstream `EXPECTED_REMOTE_URL` should be empty rather than copying a raw URL.

Downstream repos should have a visible repo-automation README showing:

- installed version/ref
- upstream issue path
- local override location
- redaction rules
- when to file upstream versus local
- a copyable installed-version/context block for upstream bug reports

When available, downstream installs should include `repo-automation/bin/repo-automation-report-upstream` so upstream shared automation bugs/features can be prepared with preview/redaction safeguards before submission.
Downstream installs should use `repo-automation/bin/repo-automation-install --target=<repo>` in plan mode first, then explicit `--apply`.
Installer smoke tests should audit the downstream contract in temp repos before real rollout.
