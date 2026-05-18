# Repo Automation Install

`repo-automation/bin/repo-automation-install` installs or updates managed repo-automation files into a downstream git repo.

## Behavior

- defaults to plan-only preview
- requires `--target=<path>`
- requires explicit `--apply` before writing files
- never commits, pushes, creates PRs, merges, or deletes branches in the target repo
- supports JSON output with valid JSON on stdout and human logs on stderr
- keeps the selected install profile explicit in human and JSON output
- `--explain` prints the detailed human summary; default success is compact `plan` or `pass`

If mode is not explicitly passed:

- install mode is inferred when target has no `.repo-automation.conf`
- update mode is inferred when target already has `.repo-automation.conf`

## Managed Files

By default, the helper manages:

- shared scripts in `repo-automation/bin/` and `repo-automation/lib/`
- default downstream helpers `repo-automation/bin/failure-log`, `repo-automation/bin/status-packet`, `repo-automation/bin/post-codex-packet`, `repo-automation/bin/repo-zip`, `repo-automation/bin/evidence-bundle`, and `repo-automation/bin/pr-create`
- repo-automation docs in `repo-automation/docs/`
- generated downstream `.repo-automation.conf`
- generated downstream `repo-automation/docs/README.md`
- downstream `AGENTS.md` copied from the source repo root so patch-edit guidance stays aligned

Optional installation:

- `--include-tests` adds `repo-automation/tests/lib/test-common.sh`, `repo-automation/tests/lib/smoke-common.sh`, `repo-automation/tests/contracts/`, `repo-automation/tests/docs-check.sh`, `repo-automation/tests/smoke.sh`, `repo-automation/tests/version-consistency.sh`, and `repo-automation/bin/run-tests` (including the mixed-change `repo-automation/tests/contracts/pr-create.sh` contract)
- `--include-ci` adds `.github/workflows/ci.yml` (with warning because downstream CI usually needs adaptation)
- `--starter-template` adds `.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/automation-bug.yml`, and `.github/ISSUE_TEMPLATE/automation-feature.yml` without broadening workflow permissions or installing app/product CI

## Profiles

- default profile: the current downstream install/update contract
- `--starter-template`: conservative starter-template profile for reusable repos; it installs repo-automation-owned PR and issue templates, but not workflow files, app/product CI, starter-template version fields, or downstream app/product version fields

## Local Overrides

- downstream `repo-automation/docs/local-overrides.md` is preserved when already present
- the file is created only when missing
- config updates must leave `.repo-automation.local.conf` alone; do not overwrite or clear local override files

## Generated Installed Context

The helper writes downstream install context into:

- `.repo-automation.conf` (`INSTALLED_VERSION_OR_REF`, `INSTALLED_AT`, `UPSTREAM_REPO_FULL_NAME`, target defaults)
- `repo-automation/docs/README.md` (copyable installed automation context, doctor/report-upstream commands)
- `EXPECTED_REMOTE_URL` is set only when the target origin is a supported GitHub SSH remote; unsupported or local/file/HTTPS origins are normalized to `""`

## Installer Output Audit

The installer plan/apply output should stay auditable in temporary repos:

- JSON output must remain parseable and should report `present`, `missing`, or `unsupported` target remote status instead of raw remote URLs
- the selected profile should be visible in both plan and apply output
- downstream config should still validate with the shared Bash library
- downstream `repo-doctor --quick --no-run-tests` should succeed or warn only in a valid temp repo
- no target commits, pushes, PRs, or merges should be created

Starter-template smoke workflow for a temp target repo:

    repo-automation/bin/repo-automation-install --target=/path/to/downstream --starter-template --apply
    cd /path/to/downstream && repo-automation/bin/starter-template-ready --check-current
    cd /path/to/downstream && repo-automation/bin/repo-doctor --quick --no-run-tests

The smoke path stays read-only outside the fixture repo and is intended to prove the conservative starter-template profile end to end without broadening workflow permissions or requiring GitHub auth. The source repo also keeps `repo-automation/manifest.json` aligned with this installer coverage through `repo-automation/tests/version-consistency.sh`. Downstream installs also receive an `AGENTS.md` at the repo root with compact patch-editing guidance.

## JSON Contract

With `--json`, stdout includes:

- `mode`
- `source_root`
- `target_root`
- `apply`
- `dry_run`
- `profile`
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

    repo-automation/bin/repo-automation-install --target=/path/to/downstream
    repo-automation/bin/repo-automation-install --target=/path/to/downstream --json
    repo-automation/bin/repo-automation-install --target=/path/to/downstream --apply
    repo-automation/bin/repo-automation-install --target=/path/to/downstream --update --apply --include-tests
    repo-automation/bin/repo-automation-install --target=/path/to/downstream --starter-template --json
    repo-automation/bin/repo-automation-install --target=/path/to/downstream --apply --installed-version=0.1.0 --installed-at=2026-05-06
