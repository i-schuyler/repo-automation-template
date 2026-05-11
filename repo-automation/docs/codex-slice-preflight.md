# Codex Slice Preflight

`repo-automation/bin/codex-slice-preflight` runs a repeatable slice setup flow before edits begin.

The script requires `--branch <name>`. It validates branch safety and rejects the default branch.

Preflight requires valid config. Invalid config, secret-scan failure, or config source failure stops execution.

`--check-only` validates config, remote expectations, current worktree status, and branch-cleanup planning without checking out or creating the requested branch.

`--delete-safe-stale` allows local safe stale deletion by calling `repo-automation/bin/branch-cleanup --apply`. Without this flag, branch cleanup stays in plan mode.

`--json` emits valid JSON only on stdout. Human INFO/WARN/STOP logs are sent to stderr. JSON mode includes structured branch-cleanup status and does not parse human branch-cleanup text.

STOP behavior is conservative. The script returns non-zero when safety cannot be confirmed, including:

- remote mismatch against configured expected SSH remote
- dirty worktree before edits
- branch still on default after checkout logic
- ambiguous or invalid branch input
- divergent `origin/<default-branch>...HEAD` where ahead and behind are both non-zero

This script does not create PRs and does not merge PRs.

Usage examples:

    repo-automation/bin/codex-slice-preflight --branch=feature/my-slice
    repo-automation/bin/codex-slice-preflight --check-only --branch=feature/my-slice
    repo-automation/bin/codex-slice-preflight --branch=feature/my-slice --delete-safe-stale

Test coverage:

- `repo-automation/tests/smoke.sh` validates check-only behavior and JSON parseability for preflight output.
