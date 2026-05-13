# Downstream Install Contract

Downstream installs should make the automation visible, inspectable, and safe to report upstream.

## Installed Files

Default installer-managed paths:

- `repo-automation/bin/`
- `repo-automation/lib/`
- `repo-automation/docs/`
- `.repo-automation.conf`
- generated `repo-automation/docs/README.md`
- optional `repo-automation/tests/lib/test-common.sh`, `repo-automation/tests/lib/smoke-common.sh`, `repo-automation/tests/contracts/`, `repo-automation/tests/smoke.sh`, `repo-automation/tests/version-consistency.sh`, and `repo-automation/bin/run-tests` when `--include-tests` is used
- installed `repo-automation/bin/failure-log`, `repo-automation/bin/status-packet`, `repo-automation/bin/post-codex-packet`, and `repo-automation/bin/repo-zip` as part of the default downstream install contract
- optional `.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/automation-bug.yml`, and `.github/ISSUE_TEMPLATE/automation-feature.yml` when `--starter-template` is used
- optional `.github/workflows/ci.yml` when `--include-ci` is used

Public config must not contain secrets or machine-local values.
Installer apply mode must not commit, push, create PRs, merge, or delete branches in target repos.
If the target origin is missing, local, file-based, HTTPS, or otherwise unsupported, the generated downstream `EXPECTED_REMOTE_URL` should be empty rather than copying a raw URL.

Downstream repos should have a visible repo-automation README showing:

- installed automation version/ref
- upstream issue path
- local override location
- redaction rules
- when to file upstream versus local
- a copyable installed-version/context block for upstream bug reports

When available, downstream installs should include `repo-automation/bin/repo-automation-report-upstream` so upstream shared automation bugs/features can be prepared with preview/redaction safeguards before submission.
Downstream installs should use `repo-automation/bin/repo-automation-install --target=<repo>` in plan mode first, then explicit `--apply`.
Installer smoke tests should audit the downstream contract in temp repos before real rollout.
The starter-template profile must stay conservative: it can add reusable repo automation templates, but it must not broaden workflow permissions, install app/product CI, or imply ownership of the downstream app/product version or any starter-template version.
