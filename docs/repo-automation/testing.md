# Testing

Run local validation from repo root:

    scripts/run-tests

CI runs the same core checks:

- `git diff --check`
- Bash syntax checks for scripts and tests
- ShellCheck for scripts and tests
- smoke tests for branch cleanup and codex slice preflight
- smoke coverage for `scripts/pr-finish` help and safe no-auth/no-gh failure behavior
- JSON parseability checks for branch cleanup and preflight
- version consistency guard

The test scaffold does not require GitHub auth and does not create issues or PRs.
`scripts/pr-finish` smoke coverage does not perform real merges.

Smoke tests use temporary directories under `${TMPDIR:-$HOME/.cache}/repo-automation-template-tests`.

Tests do not delete remote branches and do not use force delete for local branches.

ShellCheck is required in CI. Locally, `scripts/run-tests` runs ShellCheck when available and warns when missing.
