# CI Status

`repo-automation/bin/ci-status` prints a read-only CI snapshot from GitHub.

Supported flags:

- `--pr=NUMBER` checks a pull request directly
- `--branch=NAME` checks a branch by looking for its PR first and then recent workflow runs
- `--json` returns compact machine-readable output
- `--machine-json` keeps the legacy/specialized machine-readable output shape
- `--quiet` suppresses the compact clean `pass` line
- `--explain` prints the full compact status report

Behavior:

- uses `gh pr checks` for PR status where practical
- falls back to `gh run list` for branch workflow status where practical
- fails cleanly when `gh` is missing, not authenticated, offline, or when no PR / workflow run can be found
- never creates, updates, merges, closes, or deletes anything
- default success is compact: `pass` or `wait`

Examples:

    repo-automation/bin/ci-status --pr=123
    repo-automation/bin/ci-status --branch=feature/example
    repo-automation/bin/ci-status --pr=123 --json
