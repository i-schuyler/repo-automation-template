# Testing

Run local validation from repo root:

    repo-automation/bin/run-tests

CI runs the same core checks:

- `git diff --check`
- Bash syntax checks for scripts and tests
- ShellCheck for scripts and tests
- smoke tests for branch cleanup and codex slice preflight
- smoke coverage for `repo-automation/bin/pr-finish` help and safe no-auth/no-gh failure behavior
- smoke coverage for `repo-automation/bin/add-doc-pr` docs-only plan validation and blocked-file boundary behavior
- smoke coverage for `repo-automation/bin/repo-automation-report-upstream` bug/feature previews and secret-scan stop behavior
- smoke coverage for `repo-automation/bin/run-tests` compact defaults, `--explain`, JSON levels, log files, and no-log behavior
- smoke coverage for `repo-automation/bin/repo-doctor` compact defaults, `--explain`, JSON levels, log files, and missing-config safe failure behavior
- smoke coverage for `repo-automation/bin/automation-freshness` human default output, `--machine-json`, and `--source-root=/path/to/checkout`
- smoke coverage for `repo-automation/bin/repo-automation-install` plan/json, dry-run, apply-to-temp-repo, update detection, local-overrides preservation, and downstream install contract auditing in temporary repos, including the `repo-automation/tests/lib/test-common.sh` harness dependency under `--include-tests`
- lightweight docs CI via `repo-automation/tests/docs-check.sh` for markdown link validation, docs index coverage, stale phrasing, public entry-point navigation, and basic Markdown formatting checks
- JSON parseability checks for branch cleanup and preflight
- version consistency guard

The test scaffold does not require GitHub auth and does not create issues or PRs.
`repo-automation/bin/pr-finish` smoke coverage does not perform real merges.
`repo-automation/bin/add-doc-pr` smoke coverage does not create real PRs.
`repo-automation/bin/repo-automation-report-upstream` smoke coverage does not create real issues.
`repo-automation/bin/repo-doctor` smoke coverage is local/no-auth and does not create GitHub objects.
`repo-automation/bin/repo-automation-install` smoke coverage only uses temporary local target repos and does not touch real downstream repos.
`repo-automation/bin/run-tests` smoke coverage does not create or modify GitHub objects.

Installer smoke coverage also checks that temporary downstream installs can load and validate config, keep scripts executable, normalize unsupported `EXPECTED_REMOTE_URL` values to empty, and run `repo-automation/bin/repo-doctor --quick --no-run-tests` without needing GitHub auth.

Smoke tests use temporary directories under `${TMPDIR:-$HOME/.cache}/repo-automation-template-tests`.
Smoke tests source `repo-automation/tests/lib/test-common.sh` for named subchecks, timeout ownership, and registered temp-dir cleanup.
Smoke scenario execution stays in `repo-automation/tests/smoke.sh` for now; do not split it into many files yet.
The shared harness owns child-process cleanup, temp-dir cleanup, and timeout fallback warnings.

Tests do not delete remote branches and do not use force delete for local branches.

`repo-automation/bin/run-tests` defaults to a 120-second per-check timeout. Use `--timeout=SECONDS` to change it and `--audit` for the compact full suite. If the `timeout` command is unavailable, the scripts warn once and continue without timeout guards instead of failing the whole run.

The freshness helper keeps a smaller contract: human output by default, `--machine-json` for machine output, and `--source-root=/path/to/checkout` when checking a different checkout.

ShellCheck is required in CI. Locally, `repo-automation/bin/run-tests` runs ShellCheck when available and warns when missing.


## Output modes

The shared output-mode contract is documented in [output-modes.md](output-modes.md). `repo-automation/bin/run-tests` and `repo-automation/bin/repo-doctor` now implement compact summaries by default, temp log-file detail capture, `--explain`, `--quiet`, and `--json-level fail|warn|all`.

`repo-automation/tests/docs-check.sh` is the standalone docs drift gate. It is also included in `repo-automation/bin/run-tests`, so local audit runs and GitHub Actions both catch broken markdown links, missing `docs/INDEX.md` coverage, stale public phrasing, missing public navigation links, and basic Markdown formatting regressions.
The formatting pass checks for trailing whitespace, missing terminal newlines in Markdown files, balanced fenced code blocks, and blank-line separation around headings.

## Known limitation

The supported validation path is `repo-automation/bin/run-tests --audit --timeout=200`, `repo-automation/bin/repo-doctor --full --timeout=200`, and the GitHub Actions `validate` check.

External container rehydration or arbitrary hard-kill environments may still interrupt nested smoke-test cleanup. This is documented in `docs/KNOWN_LIMITATIONS.md` and is not currently treated as a public-alpha blocker when Termux and GitHub Actions are green.
