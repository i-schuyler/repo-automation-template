# Versioning

Current version: 0.1.0

## Version Placements

Version numbers must stay aligned in these places:

- `VERSION`
- `CHANGELOG.md`
- `README.md` visible current version
- `docs/DECISIONS.md` current version decision
- `.repo-automation.conf`
- `REPO_AUTOMATION_CONF_VERSION`
- `REPO_AUTOMATION_VERSION`
- future release bundle metadata
- future script metadata
- `examples/downstream/.repo-automation.conf.example`
- generated downstream installed docs (`repo-automation/docs/README.md`)
- `repo-automation/tests/version-consistency.sh` guard expectations

## CI Guard

The version consistency check must fail when version numbers drift.

Required behavior:

- `CHANGELOG.md` bump and `VERSION` bump must agree.
- README visible current version must match `VERSION`.
- Decision docs must match the active version line.
- `.repo-automation.conf` version fields must stay aligned with `VERSION`.
- `REPO_AUTOMATION_VERSION` must stay aligned with `VERSION`.
- Future release bundle metadata must match the release version.
- Future script metadata must match the release version.
- Installed downstream examples must show the same version or an explicit placeholder.

CI enforces this through `repo-automation/tests/version-consistency.sh`.

## Prepare Release Helper

Use `repo-automation/bin/prepare-release` when you are ready to preview or apply a version update.

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

- `--check` reads `VERSION` as the expected version and reports any managed placement drift.
- `--version=<semver>` sets the release target version for dry-run or apply flows.
- `--dry-run` reports planned file changes without modifying files.
- `--apply` updates all managed version placements.
- `--machine-json` emits parseable JSON.
- `--help` prints a usage summary.

The helper keeps changelog edits conservative, does not touch `REPO_AUTOMATION_CONF_VERSION`, and only updates placements when the expected pattern is already present.
