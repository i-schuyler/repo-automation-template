# Repo Doctor

`scripts/repo-doctor` is a read-only terminal helper that reports repo-automation install health.

It does not fix anything automatically. It does not create branches, commits, PRs, issues, merges, or deletions.

Default behavior is safe and read-only.

- `--quick` runs lighter checks and skips `scripts/run-tests`.
- `--full` includes `scripts/run-tests`.
- `--no-run-tests` explicitly skips `scripts/run-tests`.
- `--check NAME` runs one named check (`git`, `config`, `scripts`, `json`, `tests`, `version`, `ci`, `docs`, `issue-templates`).

Human output uses PASS/WARN/FAIL and an overall result:

- `pass`: no failures
- `warn`: warnings only
- `fail`: one or more failures

JSON mode contract:

- `--json` writes valid JSON only to stdout.
- human INFO/WARN/STOP logs go to stderr.
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
    scripts/repo-doctor --quick
    scripts/repo-doctor --full
    scripts/repo-doctor --json --quick
    scripts/repo-doctor --check config
