# Repo Automation Install

`scripts/repo-automation-install` installs or updates managed repo-automation files into a downstream git repo.

## Behavior

- defaults to plan-only preview
- requires `--target PATH`
- requires explicit `--apply` before writing files
- never commits, pushes, creates PRs, merges, or deletes branches in the target repo
- supports JSON output with valid JSON on stdout and human logs on stderr

If mode is not explicitly passed:

- install mode is inferred when target has no `.repo-automation.conf`
- update mode is inferred when target already has `.repo-automation.conf`

## Managed Files

By default, the helper manages:

- shared scripts in `scripts/` and `scripts/lib/`
- repo-automation docs in `docs/repo-automation/`
- generated downstream `.repo-automation.conf`
- generated downstream `docs/repo-automation/README.md`

Optional installation:

- `--include-tests` adds `tests/lib/test-common.sh`, `tests/smoke.sh`, `tests/version-consistency.sh`, and `scripts/run-tests`
- `--include-ci` adds `.github/workflows/ci.yml` (with warning because downstream CI usually needs adaptation)

## Local Overrides

- downstream `docs/repo-automation/local-overrides.md` is preserved when already present
- the file is created only when missing

## Generated Installed Context

The helper writes downstream install context into:

- `.repo-automation.conf` (`INSTALLED_VERSION_OR_REF`, `INSTALLED_AT`, `UPSTREAM_REPO_FULL_NAME`, target defaults)
- `docs/repo-automation/README.md` (copyable installed context, doctor/report-upstream commands)
- `EXPECTED_REMOTE_URL` is set only when the target origin is a supported GitHub SSH remote; unsupported or local/file/HTTPS origins are normalized to `""`

## Installer Output Audit

The installer plan/apply output should stay auditable in temporary repos:

- JSON output must remain parseable and should report `present`, `missing`, or `unsupported` target remote status instead of raw remote URLs
- downstream config should still validate with the shared Bash library
- downstream `repo-doctor --quick --no-run-tests` should succeed or warn only in a valid temp repo
- no target commits, pushes, PRs, or merges should be created

## JSON Contract

With `--json`, stdout includes:

- `mode`
- `source_root`
- `target_root`
- `apply`
- `dry_run`
- `include_ci`
- `include_tests`
- `installed_version_or_ref`
- `target_remote_status`
- `files_to_add`
- `files_to_update`
- `files_to_skip`
- `blocked_files`
- `generated_files`
- `target_dirty`
- `action_taken`
- `stop_reason`

## Examples

    scripts/repo-automation-install --target /path/to/downstream
    scripts/repo-automation-install --target /path/to/downstream --json
    scripts/repo-automation-install --target /path/to/downstream --apply
    scripts/repo-automation-install --target /path/to/downstream --update --apply --include-tests
    scripts/repo-automation-install --target /path/to/downstream --apply --installed-version 0.1.0 --installed-at 2026-05-06
