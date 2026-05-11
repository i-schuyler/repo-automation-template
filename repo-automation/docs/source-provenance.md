# Source Provenance

This repo is seeded from a portable repo automation working set dated 2026-05-06.

Public docs intentionally avoid private chat/project identity content.

Future releases should record:

- version
- date
- source commit
- installed files
- local overrides

`repo-automation/bin/repo-automation-install` writes downstream provenance into:

- `.repo-automation.conf` (`INSTALLED_VERSION_OR_REF`, `INSTALLED_AT`, upstream source fields)
- `repo-automation/docs/README.md` installed context block

When the target origin is unsupported, the downstream config should keep `EXPECTED_REMOTE_URL=""` rather than copying a raw local/file/HTTPS URL. That keeps provenance public-safe while still letting downstream repos document their installed version/ref and installation date.
