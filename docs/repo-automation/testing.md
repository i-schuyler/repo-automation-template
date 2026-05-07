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
- smoke coverage for `scripts/run-tests` compact defaults, `--explain`, JSON levels, log files, and no-log behavior
- smoke coverage for `scripts/repo-doctor` compact defaults, `--explain`, JSON levels, log files, and missing-config safe failure behavior
- smoke coverage for `scripts/repo-automation-install` plan/json, dry-run, apply-to-temp-repo, update detection, local-overrides preservation, and downstream install contract auditing in temporary repos
- lightweight docs CI via `tests/docs-check.sh` for markdown link validation, docs index coverage, stale phrasing, and public entry-point navigation
- JSON parseability checks for branch cleanup and preflight
- version consistency guard

The test scaffold does not require GitHub auth and does not create issues or PRs.
`scripts/pr-finish` smoke coverage does not perform real merges.
`scripts/add-doc-pr` smoke coverage does not create real PRs.
`scripts/repo-automation-report-upstream` smoke coverage does not create real issues.
`scripts/repo-doctor` smoke coverage is local/no-auth and does not create GitHub objects.
`scripts/repo-automation-install` smoke coverage only uses temporary local target repos and does not touch real downstream repos.
`scripts/run-tests` smoke coverage does not create or modify GitHub objects.

Installer smoke coverage also checks that temporary downstream installs can load and validate config, keep scripts executable, normalize unsupported `EXPECTED_REMOTE_URL` values to empty, and run `scripts/repo-doctor --quick --no-run-tests` without needing GitHub auth.

Smoke tests use temporary directories under `${TMPDIR:-$HOME/.cache}/repo-automation-template-tests`.
Smoke tests source `tests/lib/test-common.sh` for named subchecks, timeout ownership, and registered temp-dir cleanup.
Smoke scenario execution stays in `tests/smoke.sh` for now; do not split it into many files yet.
The shared harness owns child-process cleanup, temp-dir cleanup, and timeout fallback warnings.

Tests do not delete remote branches and do not use force delete for local branches.

`scripts/run-tests` defaults to a 120-second per-check timeout. Use `--timeout SECONDS` to change it and `--audit` for the compact full suite. If the `timeout` command is unavailable, the scripts warn once and continue without timeout guards instead of failing the whole run.

ShellCheck is required in CI. Locally, `scripts/run-tests` runs ShellCheck when available and warns when missing.


## Output modes

The shared output-mode contract is documented in [docs/repo-automation/output-modes.md](output-modes.md). `scripts/run-tests` and `scripts/repo-doctor` now implement compact summaries by default, temp log-file detail capture, `--explain`, `--quiet`, and `--json-level fail|warn|all`.

`tests/docs-check.sh` is the standalone docs drift gate. It is also included in `scripts/run-tests`, so local audit runs and GitHub Actions both catch broken markdown links, missing `docs/INDEX.md` coverage, stale public phrasing, and missing public navigation links.

## Known limitation

The supported validation path is `scripts/run-tests --audit --timeout 200`, `scripts/repo-doctor --full --timeout 200`, and the GitHub Actions `validate` check.

External container rehydration or arbitrary hard-kill environments may still interrupt nested smoke-test cleanup. This is documented in `docs/KNOWN_LIMITATIONS.md` and is not currently treated as a public-alpha blocker when Termux and GitHub Actions are green.
