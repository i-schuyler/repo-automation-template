# Repo Automation Config

`.repo-automation.conf` is the repo-local entry point for public-safe automation settings.

## What It Is

The config file records the public, installable shape of the repo automation template:

- upstream repo identity
- installed version and installation date
- local override documentation path
- branch, docs, provider, timeout, and check-profile defaults

The file is meant to be sourceable by Bash and readable in downstream repos without exposing secrets, tokens, host credentials, private keys, or machine-local private paths.

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
- installed version/ref
- installed date
- local overrides doc

That installed context is what downstream users can paste into bug reports when filing upstream issues.

## Version Drift

Config values are part of the version drift surface. Changes here should stay aligned with `VERSION`, `CHANGELOG.md`, README-visible version text, `docs/DECISIONS.md`, and `docs/VERSIONING.md`.

See [docs/VERSIONING.md](../VERSIONING.md) for the current versioning contract.

## Loading Rule

Future workflow scripts must load configuration through `scripts/lib/repo-automation-common.sh` instead of re-implementing config lookup or validation.
