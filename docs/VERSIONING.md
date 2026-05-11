# Versioning

Current version: 0.1.0

See [Version Modes](../repo-automation/docs/version-modes.md) for the ownership model behind the version fields below.

## Automation Repo Release Version

The upstream `repo-automation-template` release version is the value in `VERSION`.
That value is the source of truth for the automation repo release line.

## Version Placements

Version numbers must stay aligned in these automation-repo-owned places:

- `VERSION`
- `CHANGELOG.md`
- `README.md` visible current version
- `docs/DECISIONS.md` current version decision
- `docs/VERSIONING.md`
- future release bundle metadata
- future script metadata
- `examples/downstream/.repo-automation.conf.example`
- generated downstream installed docs (`repo-automation/docs/README.md`)
- `repo-automation/tests/version-consistency.sh` guard expectations

## Installed Automation Provenance

Downstream installs also record provenance, but that is a separate version mode.

- `.repo-automation.conf` stores `REPO_AUTOMATION_VERSION` for the upstream automation release version
- `.repo-automation.conf` stores `INSTALLED_VERSION_OR_REF` for the installed automation ref
- `INSTALLED_VERSION_OR_REF` may be a tag, branch, commit, or explicit installed ref
- `REPO_AUTOMATION_CONF_VERSION` is the config schema version and is not touched by release helpers

## CI Guard

The version consistency check must fail when the automation release version drifts.

Required behavior:

- `CHANGELOG.md` bump and `VERSION` bump must agree.
- README visible current version must match `VERSION`.
- Decision docs must match the active version line.
- `.repo-automation.conf` `REPO_AUTOMATION_VERSION` must stay aligned with `VERSION`.
- `.repo-automation.conf` `INSTALLED_VERSION_OR_REF` must remain an installed automation ref, not a downstream product version.
- Future release bundle metadata must match the release version.
- Future script metadata must match the release version.
- Installed downstream examples must show the same upstream automation version or an explicit placeholder ref.

CI enforces this through `repo-automation/tests/version-consistency.sh`.

## Prepare Release Helper

Use `repo-automation/bin/prepare-release` when you are ready to preview or apply an automation repo release version update.

Human-readable examples:

```sh
repo-automation/bin/prepare-release --check
repo-automation/bin/prepare-release --version=0.2.0 --dry-run
repo-automation/bin/prepare-release --version=0.2.0 --apply
```

Machine-readable example:

```sh
repo-automation/bin/prepare-release --check --machine-json
```

Mode summary:

- `--check` reads `VERSION` as the expected automation repo release version and reports managed placement drift.
- `--version=<semver>` sets the automation repo release version target for dry-run or apply flows.
- `--dry-run` reports planned file changes without modifying files.
- `--apply` updates the managed automation release version placements.
- `--machine-json` emits parseable JSON.
- `--help` prints a usage summary.

The helper keeps changelog edits conservative, does not touch `REPO_AUTOMATION_CONF_VERSION`, and only updates automation release version placements when the expected pattern is already present. It does not update starter-template versions or downstream app/product versions.
