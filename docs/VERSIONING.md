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
- `tests/version-consistency.sh` guard expectations

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

CI enforces this through `tests/version-consistency.sh`.
