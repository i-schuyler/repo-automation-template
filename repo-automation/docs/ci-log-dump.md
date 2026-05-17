# CI Log Dump

`repo-automation/bin/ci-log-dump` is a read-only helper that saves a failed GitHub Actions log to a durable directory and prints the saved path plus either a tail excerpt or a compact first-failure diagnosis.

## What It Does

- resolves the target repo from `--repo=OWNER/REPO` or the current repo's `origin` remote
- finds a failed run by `--run-id`, by repo-wide `--latest-failed`, by PR head branch, or by the current branch
- defaults to failed-only log output
- writes the log to the configured output directory
- prints a human summary or machine JSON

`--latest-failed` selects the most recent failed workflow run for the target repo regardless of branch.

## Usage

    repo-automation/bin/ci-log-dump --help
    repo-automation/bin/ci-log-dump --run-id=123456789
    repo-automation/bin/ci-log-dump --pr=34
    repo-automation/bin/ci-log-dump --repo=OWNER/REPO --latest-failed
    repo-automation/bin/ci-log-dump --first-failure
    repo-automation/bin/ci-log-dump --machine-json

## Output Directory

The helper writes to:

1. `/storage/emulated/0/Documents/HeartloomVault/40_STAGING/log-dump` when that path can be created
2. otherwise `${TMPDIR:-$HOME/.cache}/repo-automation-log-dump`

The saved file name uses the format `actions_run_<run-id>_<timestamp>.log`.

## Machine Output

`--first-failure` parses the saved failed log locally and reports the first actionable failure label, excerpt, and next fix hint using the shared CI failure taxonomy.

`--machine-json` emits a single JSON object with the repo, PR number when present, run id, saved path, file size, and tail excerpt. With `--first-failure`, it also includes `first_failure_label`, `first_failure_excerpt`, and `recommended_fix`.

`--quiet` suppresses clean-success output. `--explain` prints the detailed human summary. Default success is the saved path only.
