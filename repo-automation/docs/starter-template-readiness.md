# Starter Template Readiness

`repo-automation/bin/starter-template-ready` checks whether a checkout has the automation-managed files and discoverability needed to behave like a starter-template repo.

It is read-only.

The gate checks:

- repo automation config exists at the expected root
- the managed automation files are fresh according to `repo-automation/bin/automation-freshness`
- the starter-template ownership files are present
- `docs/INDEX.md` still exposes the repo-automation docs that the starter-template profile relies on

Default human output:

    repo-automation/bin/starter-template-ready

Clean success prints `pass`; failures print a single `fail:` line on stderr.

Check the current repo explicitly:

    repo-automation/bin/starter-template-ready --check-current

Check another checkout:

    repo-automation/bin/starter-template-ready --source-root=/path/to/checkout

Machine output:

    repo-automation/bin/starter-template-ready --machine-json

The helper reports actionable failures when the repo is missing starter-template automation files or when the managed automation tree is stale.
