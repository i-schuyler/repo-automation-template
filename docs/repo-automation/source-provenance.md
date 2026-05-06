# Source Provenance

This repo is seeded from a portable repo automation working set dated 2026-05-06.

Public docs intentionally avoid private chat/project identity content.

Future releases should record:

- version
- date
- source commit
- installed files
- local overrides

`scripts/repo-automation-install` writes downstream provenance into:

- `.repo-automation.conf` (`INSTALLED_VERSION_OR_REF`, `INSTALLED_AT`, upstream source fields)
- `docs/repo-automation/README.md` installed context block
