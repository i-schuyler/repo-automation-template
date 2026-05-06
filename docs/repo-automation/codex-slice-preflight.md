# Codex Slice Preflight

`scripts/codex-slice-preflight` runs a repeatable slice setup flow before edits begin.

The script requires `--branch <name>`. It validates branch safety and rejects the default branch.

`--check-only` validates config, remote expectations, current worktree status, and branch-cleanup planning without checking out or creating the requested branch.

`--delete-safe-stale` allows local safe stale deletion by calling `scripts/branch-cleanup --apply`. Without this flag, branch cleanup stays in plan mode.

STOP behavior is conservative. The script returns non-zero when safety cannot be confirmed, including:

- remote mismatch against configured expected SSH remote
- dirty worktree before edits
- branch still on default after checkout logic
- ambiguous or invalid branch input
- divergent `origin/<default-branch>...HEAD` where ahead and behind are both non-zero

This script does not create PRs and does not merge PRs.

Usage examples:

    scripts/codex-slice-preflight --branch feature/my-slice
    scripts/codex-slice-preflight --check-only --branch feature/my-slice
    scripts/codex-slice-preflight --branch feature/my-slice --delete-safe-stale
