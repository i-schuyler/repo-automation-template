# Repo Automation Config

`.repo-automation.conf` is the repo-local entry point for public-safe automation settings.
`.repo-automation.local.conf` is the optional local override layer for workflow-only values.

This doc is the public loading and behavior guide. The schema contract lives in [Config Schema](config-schema.md).

## What It Is

The config file records the public, installable shape of the repo automation template:

- upstream repo identity
- installed automation version/ref and installation date
- local override documentation path
- branch, docs, provider, timeout, and check-profile defaults

The file is meant to be sourceable by Bash and readable in downstream repos without exposing secrets, tokens, host credentials, private keys, or machine-local private paths.
Tracked defaults should stay fork-friendly; put local hook values and similar workflow-only settings in `.repo-automation.local.conf`.

## Version Fields

- `REPO_AUTOMATION_CONF_VERSION` is the config schema version, not the release version
- `REPO_AUTOMATION_VERSION` is the upstream repo-automation-template release version from `VERSION`
- `INSTALLED_VERSION_OR_REF` is the installed automation ref recorded in the downstream repo; it may be a tag, branch, commit, or other explicit ref

## Required Variables

The current config scaffold includes these required values:

- `REPO_AUTOMATION_CONF_VERSION`
- `REPO_AUTOMATION_VERSION`
- `UPSTREAM_REPO_FULL_NAME`
- `UPSTREAM_ISSUE_URL`
- `INSTALLED_FROM`
- `INSTALLED_VERSION_OR_REF`
- `INSTALLED_AT`
- `LOCAL_OVERRIDES_DOC`
- `DEFAULT_BRANCH`
- `DOCS_DIR`
- `DOCS_INDEX`
- `STATE_DIR_NAME`
- `REMOTE_NAME`
- `EXPECTED_REMOTE_URL`
- `PREFLIGHT_REQUIRE_CLEAN_WORKTREE`
- `CI_PROVIDER`
- `PR_PROVIDER`
- `MERGE_MODE`
- `DOC_PR_TIMEOUT_SECONDS`
- `DOC_PR_POLL_SECONDS`
- `IMPLEMENTATION_PR_TIMEOUT_SECONDS`
- `IMPLEMENTATION_PR_POLL_SECONDS`
- `DOC_BRANCH_PREFIX`
- `FEATURE_BRANCH_PREFIX`
- `FIX_BRANCH_PREFIX`
- `CHECK_PROFILE_DEFAULT`
- `CHECK_PROFILE_DOCS_COMMANDS`
- `CHECK_PROFILE_NONE_COMMANDS`

## Boundary

Keep this file public-safe. It should not include secrets, machine credentials, private hostnames, passphrases, private paths, or private identity content.

Downstream installed configs should keep recording:

- upstream repo
- installed automation version/ref
- installed date
- local overrides doc

That installed context is what downstream users can paste into bug reports when filing upstream issues.

`repo-automation/bin/repo-automation-install` generates downstream `.repo-automation.conf` and keeps the same variable shape. `EXPECTED_REMOTE_URL` is only populated when the target origin is a supported GitHub SSH remote; missing, local, file-based, HTTPS, or otherwise unsupported target origins are normalized to an empty `EXPECTED_REMOTE_URL=""` so downstream config stays public-safe. Downstream maintainers can fill it in later if they want stricter remote matching.

Installer smoke tests should also audit the generated downstream config and helper outputs against the downstream install contract in a temporary repo before any real downstream rollout.

## Version Drift

Config values are part of the version drift surface. Changes here should stay aligned with `VERSION`, `CHANGELOG.md`, README-visible version text, `docs/DECISIONS.md`, `docs/VERSIONING.md`, and `repo-automation/docs/version-modes.md`.

See [docs/VERSIONING.md](../../docs/VERSIONING.md) and [version-modes.md](version-modes.md) for the current versioning contract.

## Loading Rule

Future workflow scripts must load configuration through `repo-automation/lib/common.sh` instead of re-implementing config lookup or validation.

For behavior-changing scripts such as branch cleanup and preflight, invalid config, secret-scan failure, or source failure must stop execution instead of silently falling back.

Loading order is tracked config first, then `.repo-automation.local.conf` when present, so local values override tracked defaults without editing the tracked file. Config updates must not overwrite or clear local override files.

The local override layer may also carry review-pack transfer defaults:

- `REVIEW_PACK_COPY_TO`
- `REVIEW_PACK_SCP_TO`

These are local-only override keys; do not install them into the public tracked downstream config by default.
Set only one of those values when you want `repo-automation/bin/review-pack --target=review` to copy or scp the final bundle automatically.
