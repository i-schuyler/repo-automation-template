# Testing

Run local validation from repo root:

    scripts/run-tests

CI runs the same core checks:

- `git diff --check`
- Bash syntax checks for scripts and tests
- ShellCheck for scripts and tests
- smoke tests for branch cleanup and codex slice preflight
- smoke coverage for `scripts/pr-finish` help and safe no-auth/no-gh failure behavior
- smoke coverage for `scripts/add-doc-pr` docs-only plan validation and blocked-file boundary behavior
- smoke coverage for `scripts/repo-automation-report-upstream` bug/feature previews and secret-scan stop behavior
- smoke coverage for `scripts/repo-doctor` help, quick/json mode, and missing-config safe failure behavior
- smoke coverage for `scripts/repo-automation-install` plan/json, dry-run, apply-to-temp-repo, update detection, local-overrides preservation, and downstream install contract auditing in temporary repos
- JSON parseability checks for branch cleanup and preflight
- version consistency guard

The test scaffold does not require GitHub auth and does not create issues or PRs.
`scripts/pr-finish` smoke coverage does not perform real merges.
`scripts/add-doc-pr` smoke coverage does not create real PRs.
`scripts/repo-automation-report-upstream` smoke coverage does not create real issues.
`scripts/repo-doctor` smoke coverage is local/no-auth and does not create GitHub objects.
`scripts/repo-automation-install` smoke coverage only uses temporary local target repos and does not touch real downstream repos.

Installer smoke coverage also checks that temporary downstream installs can load and validate config, keep scripts executable, normalize unsupported `EXPECTED_REMOTE_URL` values to empty, and run `scripts/repo-doctor --quick --no-run-tests` without needing GitHub auth.

Smoke tests use temporary directories under `${TMPDIR:-$HOME/.cache}/repo-automation-template-tests`.

Tests do not delete remote branches and do not use force delete for local branches.

ShellCheck is required in CI. Locally, `scripts/run-tests` runs ShellCheck when available and warns when missing.
