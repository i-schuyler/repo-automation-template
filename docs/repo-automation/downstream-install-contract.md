# Downstream Install Contract

Downstream installs should make the automation visible, inspectable, and safe to report upstream.

## Installed Files

Expected installed paths:

- `scripts/`
- `scripts/lib/`
- `docs/repo-automation/`
- `.repo-automation.conf`
- optional `examples/`
- visible installed version/provenance note
- upstream issue instructions

Public config must not contain secrets or machine-local values.

Downstream repos should have a visible repo-automation README showing:

- installed version/ref
- upstream issue path
- local override location
- redaction rules
- when to file upstream versus local
- a copyable installed-version/context block for upstream bug reports

When available, downstream installs should include `scripts/repo-automation-report-upstream` so upstream shared automation bugs/features can be prepared with preview/redaction safeguards before submission.
