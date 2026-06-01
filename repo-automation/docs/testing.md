# Testing

Run local validation from repo root:

    repo-automation/bin/run-tests

CI runs the same core checks:

- `git diff --check`
- Bash syntax checks for scripts and tests
- ShellCheck for scripts and tests via the metadata-driven file set from `repo-automation/bin/shellcheck-ci-parity --print-paths`
- portability drift scan via `repo-automation/bin/check-portability`
- smoke tests for branch cleanup and codex slice preflight
- smoke coverage for `repo-automation/bin/pr-finish` help and safe no-auth/no-gh failure behavior
- smoke coverage for `repo-automation/bin/add-doc-pr` docs-only plan validation, create-pr docs checks, and blocked-file boundary behavior
- smoke coverage for `repo-automation/bin/pr-create` mixed-change PR creation behavior with stubbed GitHub calls
- smoke coverage for `repo-automation/bin/repo-automation-report-upstream` bug/feature previews and secret-scan stop behavior
- smoke coverage for `repo-automation/bin/run-tests` compact defaults, quiet success silence, `--smoke`, `--docs`, `--version`, `--changed`, `--explain`, JSON levels, log files, and no-log behavior
- smoke coverage for `repo-automation/bin/repo-doctor` compact defaults, quiet success silence, the repo-root artifact guard, `--explain`, JSON levels, log files, and missing-config safe failure behavior
- smoke coverage for `repo-automation/bin/check-tooling` first-run tool audit reporting, compact defaults, quiet success silence, `--explain`, JSON output, and platform-specific install suggestions
- smoke coverage for `repo-automation/bin/github-settings-check` read-only settings reporting, machine JSON, and repo-doctor integration when GitHub CLI auth and a GitHub remote are available
- smoke coverage for `repo-automation/bin/managed-file-check` changed-path review and `repo-automation/bin/managed-file-add` manifest/installer updates
- smoke coverage for `repo-automation/bin/failure-log` latest log excerpts, kind filtering, line limits, and machine JSON
- smoke coverage for `repo-automation/bin/touched-files` commit-range output, working-tree fallback, and machine JSON
- smoke coverage for `repo-automation/bin/ci-status` read-only PR and branch snapshots, auth/offline/no-PR failures, and machine JSON
- smoke coverage for `repo-automation/bin/ci-watch` read-only polling, timeout handling, and machine JSON
- smoke coverage for `repo-automation/bin/ci-log-dump` read-only failed-run discovery, durable log capture, tail excerpts, and machine JSON
- smoke coverage for `repo-automation/bin/contract-debt-report` advisory report generation, strict flag parsing, compact human output, JSON parseability, and seeded debt/advisory warnings
- smoke coverage for `repo-automation/bin/status-packet` human default output, `--explain` FINAL SUMMARY output, machine JSON, and compact repo state reporting
- smoke coverage for `repo-automation/bin/post-codex-review` default FINAL SUMMARY output, `--quiet`, `--explain`, `--json`, `--packet` bundle creation, and ≤25-line output contract
- smoke coverage for `repo-automation/bin/post-codex-packet` packet assembly, tracked and staged diff capture, safe untracked file copying, skip rules, and zip output
- smoke coverage for `repo-automation/bin/repo-zip` repository snapshot assembly, tracked and untracked file inclusion, ignored-file exclusion, `.git/` exclusion, and generated artifact exclusion
- smoke coverage for `repo-automation/bin/evidence-bundle` bundle assembly, nested subdirectory invocation, optional post-codex and repo-zip coordination, optional CI log capture, and default no-network behavior
- smoke coverage for `repo-automation/bin/review-pack` fallback review bundle / prompt generation, review-target validation, and no-Codex invocation behavior
- smoke coverage for `repo-automation/bin/repair-prompt` CI/local evidence gathering, prompt redaction, evidence-file support, and no-Codex invocation behavior
- smoke coverage for artifact-safety fixtures covering `.env`, ignored cache files, safe dotfiles, safe untracked docs, generated packet/log artifacts, build outputs, and nested dependency/cache directories
- smoke coverage for `repo-automation/bin/automation-freshness` human default output, `--machine-json`, and `--source-root=/path/to/checkout`
- smoke coverage for `repo-automation/bin/starter-template-ready` human default output, `--machine-json`, `--source-root=/path/to/checkout`, and `--check-current`
- smoke coverage for `repo-automation/bin/repo-automation-install` plan/json, dry-run, apply-to-temp-repo, update detection, local-overrides preservation, starter-template profile template installation, and downstream install contract auditing in temporary repos, with manifest-driven checks for installed helpers/tests, executable surfaces, and `--include-tests` contract coverage under `repo-automation/tests/contracts/`
- starter-template install smoke coverage that exercises `repo-automation/bin/repo-automation-install --starter-template --apply` in a temporary target repo, verifies `repo-automation/bin/starter-template-ready --check-current`, verifies `repo-automation/bin/repo-doctor --quick --no-run-tests`, and checks that the source repo artifact guard stays clean after the run
- smoke coverage for `repo-automation/bin/prepare-release` help, check, dry-run, apply, machine-JSON, and managed version placement updates in a temporary repo
- lightweight docs CI via `repo-automation/tests/docs-check.sh` for markdown link validation, docs index coverage, stale phrasing, public entry-point navigation, portability-hostile temp-path/GNU-flag examples, and basic Markdown formatting checks; it follows the quiet-first contract where success prints `pass`, `--quiet` stays silent, and `--explain` keeps detailed progress lines
- JSON parseability checks for branch cleanup and preflight
- version consistency guard via `repo-automation/bin/prepare-release --check`, plus manifest-vs-installer coverage drift detection and helper-metadata config-key drift detection in `repo-automation/tests/version-consistency.sh`; it also follows the quiet-first contract where success prints `pass`, `--quiet` stays silent, and `--explain` keeps detailed progress lines

CI stores the detailed failure logs for `repo-automation/bin/run-tests` and ShellCheck in `run-tests.log` and `shellcheck.log` artifacts, plus the flat `repo-automation/bin/ci-failure-artifacts` bundle with stable names such as `failure-log.txt`, `failure-excerpt.txt`, `policy-summary.md`, `machine-summary.json`, and the copied raw logs from the CI failure step. The advisory `repo-automation/bin/contract-debt-report` helper also writes `contract-debt-report.md` and `contract-debt-report.json` into that same CI failure artifact directory when the failure-artifact step runs, but it never blocks CI on debt findings. `repo-automation/bin/run-tests` still prints a referenced path only for durable logs (explicit `--log-file=<path>` or `--no-clean-temp`).

The test scaffold does not require GitHub auth and does not create issues or PRs.
`repo-automation/bin/pr-finish` smoke coverage does not perform real merges.
`repo-automation/bin/add-doc-pr` smoke coverage does not create real PRs.
`repo-automation/bin/pr-create` smoke coverage does not create real PRs.
`repo-automation/bin/repo-automation-report-upstream` smoke coverage does not create real issues.
`repo-automation/bin/repo-doctor` smoke coverage is local/no-auth and does not create GitHub objects. It also checks the repo-root artifact guard against accidental root-level temp/cache files in temporary repositories.
`repo-automation/bin/repo-automation-install` smoke coverage only uses temporary local target repos and does not touch real downstream repos. It also verifies downstream `AGENTS.md` guidance is copied into the target repo root.
`repo-automation/bin/run-tests` smoke coverage does not create or modify GitHub objects.

Installer smoke coverage also checks that temporary downstream installs can load and validate config, keep scripts executable, normalize unsupported `EXPECTED_REMOTE_URL` values to empty, and run `repo-automation/bin/repo-doctor --quick --no-run-tests` without needing GitHub auth.
Starter-template smoke coverage uses a temporary target repo under `${TMPDIR:-$HOME/.cache}` and keeps the install contract bounded to the conservative template profile plus the quick doctor/readiness path.

Smoke tests use temporary directories under `${TMPDIR:-$HOME/.cache}/repo-automation-template-tests`.
Smoke tests source `repo-automation/tests/lib/smoke-common.sh` (which loads `repo-automation/tests/lib/test-common.sh`) for named subchecks, timeout ownership, registered temp-dir cleanup, and the shared focused-wrapper runner.
`repo-automation/tests/smoke.sh` and focused contract wrappers such as `repo-automation/tests/contracts/repo-flow.sh`, `repo-automation/tests/contracts/ci-log-dump.sh`, `repo-automation/tests/contracts/post-codex-review.sh`, and `repo-automation/tests/contracts/review-pack.sh` follow the shared quiet-first test contract: default success prints `pass`, `--quiet` stays silent on success, `--explain` keeps RUNNING/PASS/FAIL progress, and `--json` emits JSON only on stdout. Focused wrapper `--help` output uses the wrapper's own path. `repo-automation/bin/repo-flow submit` appends an `## Update log` section to existing PR bodies by default and uses `--replace-body` for intentional full-body replacement. Quiet failures should include the check label plus the smallest useful next fix or log/path clue.
Smoke scenario execution is split across `repo-automation/tests/contracts/*.sh` plus focused shared modules in `repo-automation/tests/lib/contracts/*.sh`, with `repo-automation/tests/smoke.sh` as the orchestrator.
The shared harness owns child-process cleanup, temp-dir cleanup, and timeout fallback warnings.

## Temp fixture lifecycle policy

Disposable smoke fixtures live under the registered smoke test parent and are aggressively cleaned with the current test/run. Completed previous smoke fixtures are not durable evidence; only the current active fixture parent should survive while the test is running.

Nested helper invocations that perform cleanup must use isolated `TMPDIR`/`HOME` values so they cannot target the outer smoke harness root.

Operator/evidence run dirs are different: preserve the current active run, keep a small rolling window (for example the last 5–10), and cap by age (for example 7 days) where the helper supports it.

Cleanup should not be generalized to npm cache paths, `.codex`, or unrelated cache directories.

Tests do not delete remote branches and do not use force delete for local branches.

`repo-automation/bin/run-tests` defaults to a 120-second per-check timeout. Use `--timeout=SECONDS` to change it and `--audit` for the compact full suite. If the `timeout` command is unavailable, the scripts warn once and continue without timeout guards instead of failing the whole run.
It keeps run-owned temp output under `${TMPDIR:-$HOME/.cache}/repo-automation-template/run-tests-*`, recreates `TEST_TEMP_ROOT` when needed, prunes stale children older than `REPO_AUTOMATION_STALE_TEMP_HOURS` (default 12) when `REPO_AUTOMATION_CLEAN_STALE_TEMP=1` (default), and cleans the current run temp root on success and failure by default. Use `--no-clean-temp` to keep run-owned temp output for debugging or `--clean-temp` to reassert the default. Default failures that lose their temp log print `log: cleaned` plus `fix: use --log-file=<path> or --no-clean-temp for durable logs`; explicit `--log-file=<path>` output is preserved. In JSON mode, cleaned default logs report `log_status=cleaned`, `log_policy=run-temp-cleaned-by-default`, and the same `log_fix` hint instead of a durable `log_file`.
`RUN_TESTS_DF_BIN` or `REPO_AUTOMATION_DF_BIN` can point the low-disk check at a deterministic `df` seam for tests. `repo-automation/bin/run-tests` also reads optional defaults from `.repo-automation.conf` or `.repo-automation.local.conf`, secret-scans them before sourcing, and keeps environment variables taking precedence. The guard stops before heavy checks when `/` drops below 1.5G free or the legacy under-15%-free threshold is crossed, and `--disk-diagnostic` prints the current snapshot plus compact top temp/cache dirs.
`repo-automation/bin/run-tests --explain` reports `temp_cleanup=...`, `stale_temp_hours=...`, `disk_guard=enabled`, and `log_policy=...` policy lines alongside the compact check summary.

If `repo-automation/bin/codex-slice-preflight` stops on disk, rerun it with `--clean-test-cache --explain` to clear the recurring repo-automation temp/cache roots, then rerun the normal preflight command.

The freshness helper keeps a smaller contract: human output by default, `--machine-json` for machine output, and `--source-root=/path/to/checkout` when checking a different checkout.

ShellCheck is required in CI. Locally, `repo-automation/bin/run-tests` runs ShellCheck when available and warns when missing.
When CI reports a ShellCheck failure, open the `shellcheck.log` artifact instead of rerunning the full suite locally on Android.


## Output modes

The shared output-mode contract is documented in [output-modes.md](output-modes.md), and the shared command-shape contract is documented in [command-shape.md](command-shape.md). `repo-automation/bin/run-tests` and `repo-automation/bin/repo-doctor` now implement compact summaries by default, temp log-file detail capture, `--explain`, `--quiet`, and `--json-level=fail|warn|all`.
`repo-automation/bin/failure-log`, `repo-automation/bin/touched-files`, `repo-automation/bin/ci-status`, `repo-automation/bin/ci-watch`, and `repo-automation/bin/status-packet` are the lightweight read-only helpers for when you need a log excerpt, a touched-file list, a GitHub CI snapshot, or a repo state packet instead of a fresh diagnostic run. `repo-automation/bin/post-codex-packet` is the uploadable packet helper when you need a zip bundle of tracked diffs, staged diffs, and safe untracked files for review. `repo-automation/bin/repo-zip` is the snapshot helper when you need an uploadable repository zip for all tracked files plus untracked non-ignored files. `repo-automation/bin/evidence-bundle` is the review bundle helper when you want one uploadable packet that can coordinate status, failure-log, post-codex, repo-zip, and CI log evidence. `repo-automation/bin/review-pack` is the fallback review artifact helper, and `repo-automation/bin/repair-prompt` is the compact recovery prompt helper for CI or local failure evidence.

`repo-automation/tests/docs-check.sh` is the standalone docs drift gate. It is also included in `repo-automation/bin/run-tests`, so local audit runs and GitHub Actions both catch broken markdown links, missing `docs/INDEX.md` coverage, stale public phrasing, missing public navigation links, and basic Markdown formatting regressions.
The formatting pass checks for trailing whitespace, missing terminal newlines in Markdown files, balanced fenced code blocks, and blank-line separation around headings.

## Known limitation

The supported validation path is `repo-automation/bin/run-tests --audit --timeout=200`, `repo-automation/bin/repo-doctor --full --timeout=200`, and the GitHub Actions `validate` check.

External container rehydration or arbitrary hard-kill environments may still interrupt nested smoke-test cleanup. This is documented in `docs/KNOWN_LIMITATIONS.md` and is not currently treated as a public-alpha blocker when Termux and GitHub Actions are green.
