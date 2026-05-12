# Repo Doctor

`repo-automation/bin/repo-doctor` is a read-only terminal helper that reports repo-automation install health.

It does not fix anything automatically. It does not create branches, commits, PRs, issues, merges, or deletions.

Default behavior is safe and read-only.

- Default human output is `--summary`.
- `--explain` prints the full PASS/WARN/FAIL detail.
- `--quiet` keeps only the final result and warning/failure hints.
- `--audit` is a compact alias for the full read-only diagnostic path.
- `--timeout=SECONDS` passes a per-check timeout through to `repo-automation/bin/run-tests`.
- `--log-file=FILE` captures full details in a temp log.
- `--no-log` suppresses log creation when explicitly requested.
- `--json --json-level=fail|warn|all` keeps stdout machine-readable and filters returned check detail.
- `--quick` runs lighter checks and skips `repo-automation/bin/run-tests`.
- `--full` includes `repo-automation/bin/run-tests`.
- `--no-run-tests` explicitly skips `repo-automation/bin/run-tests`.
- `--check=NAME` runs one named check (`artifact-guard`, `git`, `config`, `scripts`, `json`, `tests`, `version`, `ci`, `automation-freshness`, `docs`, `issue-templates`, `starter-template-readiness`, `github-settings-readiness`).

Human output uses PASS/WARN/FAIL when details are shown, but default summary output stays compact:

- `pass`: no failures
- `warn`: warnings only
- `fail`: one or more failures

JSON mode contract:

- `--json` writes valid JSON only to stdout.
- human INFO/WARN/STOP logs go to stderr.
- `--json-level=fail|warn|all` filters the `checks` array.
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

- repo-root artifact and cache guard for accidental temp files and directories
- git repo/branch/worktree/remote health
- config presence/load/validation/secret scan
- script existence/executable/syntax checks, with optional `repo-automation/bin/run-tests` support in installed downstream targets that intentionally omit the helper
- automation manifest freshness checks
- JSON contract spot checks for branch cleanup and preflight
- optional `repo-automation/bin/run-tests` execution
- automation release version consistency guard
- CI workflow minimal-permissions checks
- docs index helper-link coverage
- automation issue-template presence
- starter-template readiness gate
- GitHub settings readiness helper checks when `gh` and a GitHub remote are available

Usage examples:

    repo-automation/bin/repo-doctor
    repo-automation/bin/repo-doctor --summary
    repo-automation/bin/repo-doctor --explain
    repo-automation/bin/repo-doctor --quiet
    repo-automation/bin/repo-doctor --quick
    repo-automation/bin/repo-doctor --full
    repo-automation/bin/repo-doctor --json --quick --json-level=warn
    repo-automation/bin/repo-doctor --audit --timeout=120
    repo-automation/bin/repo-doctor --check=artifact-guard
    repo-automation/bin/repo-doctor --check=config
    repo-automation/bin/repo-doctor --check=automation-freshness
    repo-automation/bin/repo-doctor --check=starter-template-readiness
    repo-automation/bin/repo-doctor --check=github-settings-readiness
