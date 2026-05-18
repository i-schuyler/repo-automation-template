# Post Codex Review

`repo-automation/bin/post-codex-review` prints a compact operator-ready final summary for the current repo state.

## Behavior

- default output is a single `===== FINAL SUMMARY =====` block
- the summary stays within 25 lines
- includes branch, status count, changed, staged, untracked, first-failure label, log path, and packet path
- does not print diffs or long logs
- if a recent `run-tests` or `repo-doctor` failure log is available, it reports only the log path and first failure label when that is cheap to discover

## Packet Mode

- `--packet` creates a `post-codex-packet` review bundle and records the packet zip path in the summary

## Examples

    repo-automation/bin/post-codex-review
    repo-automation/bin/post-codex-review --packet

This helper is intended for the last step before ChatGPT/operator review: use it instead of custom shell blocks when you want one concise repo-native summary.
