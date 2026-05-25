# CI Failure Artifacts

`repo-automation/bin/ci-failure-artifacts` builds a flat, stable CI failure bundle from local log files already present on disk.

It is meant for:

- phone-friendly failure review
- AI/Codex handoff
- repo-doctor context capture on CI failure

Usage:

```bash
repo-automation/bin/ci-failure-artifacts --out-dir=/path/to/bundle
repo-automation/bin/ci-failure-artifacts --out-dir=/path/to/bundle --json
```

Stable outputs include compact `failure-log.txt`, `failure-excerpt.txt`, `policy-summary.md`, `machine-summary.json`, and copied raw logs such as `run-tests.log`, `shellcheck.log`, `check-portability.log`, and `repo-doctor.*`.

`machine-summary.json` uses `overall_status: "fail"` for the CI handoff and `artifact_generation_status: "pass"` when helper assembly succeeds.
