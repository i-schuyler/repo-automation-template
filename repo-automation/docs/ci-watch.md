# CI Watch

`repo-automation/bin/ci-watch` polls read-only GitHub CI status until it passes, fails, or times out.

Supported flags:

- `--pr=NUMBER` watches a pull request directly
- `--branch=NAME` watches a branch through the same CI snapshot logic
- `--poll-seconds=SECONDS` sets the polling interval
- `--timeout=SECONDS` sets the overall wait limit
- `--json` returns compact machine-readable output
- `--machine-json` keeps the legacy/specialized machine-readable output shape
- `--quiet` suppresses the clean-success `pass` line
- `--explain` prints the elapsed status report

Behavior:

- reuses the read-only CI status checks from `repo-automation/bin/ci-status`
- never creates, updates, merges, closes, or deletes anything
- exits non-zero on CI failure, timeout, or GitHub access problems
- default success is compact `pass`

Examples:

    repo-automation/bin/ci-watch --pr=123 --poll-seconds=10 --timeout=600
    repo-automation/bin/ci-watch --branch=feature/example --json
