# Config Schema

This doc is the source of truth for config key/schema coverage. [Repo Automation Config](config.md) remains the public loading and behavior guide.

## Supported keys

The public schema supports the config keys listed in `repo-automation/docs/config.md` and
`examples/downstream/.repo-automation.conf.example`.

## Required and defaulted keys

| Class | Keys |
| --- | --- |
| required | `REPO_AUTOMATION_CONF_VERSION`, `REPO_AUTOMATION_VERSION`, `UPSTREAM_REPO_FULL_NAME`, `UPSTREAM_ISSUE_URL`, `INSTALLED_FROM`, `INSTALLED_VERSION_OR_REF`, `INSTALLED_AT`, `LOCAL_OVERRIDES_DOC`, `DEFAULT_BRANCH`, `DOCS_DIR`, `DOCS_INDEX`, `STATE_DIR_NAME`, `REMOTE_NAME`, `EXPECTED_REMOTE_URL`, `PREFLIGHT_REQUIRE_CLEAN_WORKTREE`, `CI_PROVIDER`, `PR_PROVIDER`, `MERGE_MODE`, `DOC_PR_TIMEOUT_SECONDS`, `DOC_PR_POLL_SECONDS`, `IMPLEMENTATION_PR_TIMEOUT_SECONDS`, `IMPLEMENTATION_PR_POLL_SECONDS`, `DOC_BRANCH_PREFIX`, `FEATURE_BRANCH_PREFIX`, `FIX_BRANCH_PREFIX`, `CHECK_PROFILE_DEFAULT`, `CHECK_PROFILE_DOCS_COMMANDS`, `CHECK_PROFILE_NONE_COMMANDS` |
| defaulted | values supplied by the installer when the target repo omits a public-safe setting |

## Public-safe example values

- repo and issue URLs
- branch prefixes
- docs directory paths
- timeout integers
- `MERGE_MODE="squash"` or another supported merge mode
- `CHECK_PROFILE_DEFAULT="starter-template"` in the downstream example

## Disallowed values

- secrets, tokens, passphrases, or private keys
- private hostnames or machine-local paths
- downstream app/product version ownership
- anything that would make the config non-public-safe

## Output directory behavior

The installer writes config and docs into the target repo only. It does not use the source repo as an output directory.

## Downstream install behavior

`repo-automation/bin/repo-automation-install` generates downstream `.repo-automation.conf` with the same public-safe key shape.
Unsupported remote origins normalize `EXPECTED_REMOTE_URL` to an empty string.

## Validation behavior

- config validation is public-safe and fails fast on invalid or secret-bearing values
- downstream config drift should surface in the installer or version-consistency checks
- invalid config must stop behavior-changing helpers instead of silently falling back

## Relationship to the example

`examples/downstream/.repo-automation.conf.example` is the public example of this schema.
Keep it aligned with the supported key set and the installer-generated downstream shape.
