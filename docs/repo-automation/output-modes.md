# Repo Automation Output Modes

This document defines the shared output contract for repo automation scripts, starting with the highest-noise commands:

- scripts/run-tests
- scripts/repo-doctor

The goal is to reduce ChatGPT/Codex token churn while preserving full diagnostic evidence in local logs.

## Default output posture

Long-running or high-detail commands should default to compact human output:

- one start line
- one final result line
- pass/warn/fail/skipped totals
- log path when details exist
- failing and warning check names only when action is needed
- `--summary` is the default human mode for the implemented commands.
- `--quiet` suppresses the start line and keeps only final totals plus warning/failure hints.

Default output should not print every passing check.

## Required output modes

Scripts that implement this contract should support:

- --summary
  - compact human summary
  - default for long-running diagnostics

- --explain
  - detailed human output
  - prints pass/warn/fail detail

- --quiet
  - only final result plus failure/warning hints

- --log-file FILE
  - write full detailed logs to FILE

- --no-log
  - disable detailed log creation when explicitly requested

- --audit
  - compact full-audit preset for diagnostic runs

- --timeout SECONDS
  - per-check timeout guard for long-running checks
  - default conservative timeout is 120 seconds in `scripts/run-tests` and `scripts/repo-doctor`
  - when the `timeout` command is unavailable, scripts warn once and continue without timeout guards

- --json
  - stdout must be valid JSON only
  - human logs must go to stderr or log files

- --json-level fail|warn|all
  - fail: include failures only
  - warn: include failures and warnings
  - all: include all checks

## Default log location

When logs are enabled and no file is supplied, use:

    ${TMPDIR:-$HOME/.cache}/repo-automation-template/<script>-<timestamp>.log

Scripts must print the log path in compact human output.

## Recommended human output

Example successful run:

    RUNNING repo automation tests...
    RESULT: pass=42 warn=0 fail=0 skipped=0
    Log: /path/to/run-tests-2026-05-06T120000.log

Example warning run:

    RUNNING repo automation tests...
    RESULT: pass=41 warn=1 fail=0 skipped=0
    WARN:
    - repo-doctor: expected remote URL not configured
    Log: /path/to/run-tests-2026-05-06T120000.log
    Next: scripts/run-tests --explain

Example failure run:

    RUNNING repo automation tests...
    RESULT: pass=38 warn=1 fail=1 skipped=0
    FAIL:
    - tests/smoke.sh (smoke:report-upstream-secret-scan - report-upstream secret scan blocks likely secret logs)
    Log: /path/to/run-tests-2026-05-06T120000.log
    Next: scripts/run-tests --explain

For smoke-test failures, the compact summary should point at the named smoke subcheck and the log file when one exists. Timed-out smoke checks should say so explicitly when the named check is available.

## Recommended Codex usage

For low-token automation handoff:

    scripts/run-tests --json --json-level warn
    scripts/repo-doctor --json --quick --json-level warn

Codex should report warning/failure summaries and log paths instead of pasting full passing output.

## Scope

This contract should be implemented first for:

- scripts/run-tests
- scripts/repo-doctor

Other scripts may adopt the same contract later when their output becomes noisy enough to justify it.

## Non-goals

This contract does not require:

- terminal spinners
- progress bars
- curses-style UI
- background/asynchronous behavior
- hidden failures

Terminal polish can come later. The priority is lower token usage, clear failures, and preserved evidence.

## Safety requirements

- JSON mode must keep stdout as valid JSON only.
- Detailed logs must not print secrets.
- Log files should live under ${TMPDIR:-$HOME/.cache} by default.
- Failure summaries must identify enough context to act without dumping full logs.
- Passing details should be available through --explain or log files, not default output.
