# Codex Slice Preflight

`repo-automation/bin/codex-slice-preflight` runs a repeatable slice setup flow before edits begin.

The script requires `--branch=<name>`. It validates branch safety and rejects the default branch.

Preflight requires valid config. Invalid config, secret-scan failure, or config source failure stops execution.

Before branch setup, preflight checks disk space with the same 1.5G guard used by `run-tests`. If the guard fails, the stop report includes the available bytes, the threshold, and a compact cleanup hint. Rerun with `--clean-test-cache --explain`, then rerun normal preflight.
The explain summary also prints human-friendly `disk_free`, `disk_threshold`, `disk_used`, and `disk_available` fields alongside the byte fields for scripts.

`--check-only` validates config, remote expectations, current worktree status, and branch-cleanup planning without checking out or creating the requested branch.
If the requested local branch already exists, it checks that branch’s divergence from `<remote>/<default>` without switching to it.
It stops when that existing requested branch is behind or diverged, matching normal preflight safety behavior.
Use `--json` for machine-readable cleanup and branch diagnostics; it emits JSON only on stdout.
Use `--explain` for the detailed operator-facing preflight report; default success is compact `pass`.
`--explain` ends with a compact `===== FINAL SUMMARY =====` handoff block.

`--clean-test-cache` removes the recurring repo-automation test/cache roots under `${TMPDIR:-$HOME/.cache}` and `$HOME/.cache`, plus approved repo-automation temp fixture prefixes such as `repo-automation-slice-handoff-fixture.*`, `repo-automation-slice-handoff-dirty.*`, and `clean-repo-automation-template.*` under `${TMPDIR:-$HOME/.cache}` and the `tmp` subdirectory under `$HOME/.cache` when present. It does not clean unrelated `tmp` cache directories, npm cache paths, or `.codex` cache paths. `--preserve-path=<path>` can be combined with `--clean-test-cache` to keep an active run directory or any containing cleanup root from being deleted; the preserve path must already exist. With no `--branch`, cleanup exits after cleanup. With `--branch=<name>`, it cleans first and then continues normal preflight branch setup. `--json` returns machine-readable cleanup state, including preserved/skipped paths and free-space fields; `--explain` keeps the same details in INFO lines and a final summary block.

`--delete-safe-stale` allows local safe stale deletion by calling `repo-automation/bin/branch-cleanup --apply`. Without this flag, branch cleanup stays in plan mode.

`--json` emits valid JSON only on stdout. Human INFO/WARN/STOP logs are sent to stderr. JSON mode includes structured branch-cleanup status and does not parse human branch-cleanup text.

STOP behavior is conservative. The script returns non-zero when safety cannot be confirmed, including:

- remote mismatch against configured expected SSH remote
- dirty worktree before edits
- branch still on default after checkout logic
- ambiguous or invalid branch input
- divergent requested branch or `origin/<default-branch>...HEAD` where ahead and behind are both non-zero

This script does not create PRs and does not merge PRs.

Usage examples:

    repo-automation/bin/codex-slice-preflight --branch=feature/my-slice
    repo-automation/bin/codex-slice-preflight --check-only --branch=feature/my-slice
    repo-automation/bin/codex-slice-preflight --branch=feature/my-slice --delete-safe-stale
    repo-automation/bin/codex-slice-preflight --clean-test-cache --explain
    repo-automation/bin/codex-slice-preflight --clean-test-cache --preserve-path=/path/to/active-run --explain

Test coverage:

- `repo-automation/tests/smoke.sh` validates check-only behavior and JSON parseability for preflight output.
