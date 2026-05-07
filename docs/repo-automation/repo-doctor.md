# Repo Doctor

`scripts/repo-doctor` is a read-only terminal helper that reports repo-automation install health.

It does not fix anything automatically. It does not create branches, commits, PRs, issues, merges, or deletions.

Default behavior is safe and read-only.

- Default human output is `--summary`.
- `--explain` prints the full PASS/WARN/FAIL detail.
- `--quiet` keeps only the final result and warning/failure hints.
- `--log-file FILE` captures full details in a temp log.
- `--no-log` suppresses log creation when explicitly requested.
- `--json --json-level fail|warn|all` keeps stdout machine-readable and filters returned check detail.
- `--quick` runs lighter checks and skips `scripts/run-tests`.
- `--full` includes `scripts/run-tests`.
- `--no-run-tests` explicitly skips `scripts/run-tests`.
- `--check NAME` runs one named check (`git`, `config`, `scripts`, `json`, `tests`, `version`, `ci`, `docs`, `issue-templates`).

Human output uses PASS/WARN/FAIL when details are shown, but default summary output stays compact:

- `pass`: no failures
- `warn`: warnings only
- `fail`: one or more failures

JSON mode contract:

- `--json` writes valid JSON only to stdout.
- human INFO/WARN/STOP logs go to stderr.
- `--json-level fail|warn|all` filters the `checks` array.
- JSON includes:
  - `mode`
  - `overall_status`
  - `checks`
  - `pass_count`
  - `warn_count`
  - `fail_count`
  - `skipped_count`
  - `action_taken`
  - `stop_reason`
  - `json_level`
  - `log_file`

Checks include:

- git repo/branch/worktree/remote health
- config presence/load/validation/secret scan
- script existence/executable/syntax checks
- JSON contract spot checks for branch cleanup and preflight
- optional `scripts/run-tests` execution
- version consistency guard
- CI workflow minimal-permissions checks
- docs index helper-link coverage
- automation issue-template presence

Usage examples:

    scripts/repo-doctor
    scripts/repo-doctor --summary
    scripts/repo-doctor --explain
    scripts/repo-doctor --quiet
    scripts/repo-doctor --quick
    scripts/repo-doctor --full
    scripts/repo-doctor --json --quick --json-level warn
    scripts/repo-doctor --check config
