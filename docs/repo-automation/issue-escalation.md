# Issue Escalation

Use this guide to decide whether a problem belongs upstream or local.

## File Upstream

File upstream when a bug or feature affects shared automation behavior.

Examples:

- branch cleanup logic
- PR status parsing
- docs PR command behavior
- common config parsing
- version/provenance reporting

## Keep Local

Keep issues local when they are repo-specific:

- CI command
- docs path
- board config
- app behavior
- deploy path
- private operational rule

## Security

Never paste tokens, env values, private keys, passphrases, private hostnames if sensitive, or raw logs containing secrets.

If unsure, file upstream as `triage` with redacted context.

Terminal flow must be supported by `scripts/repo-automation-report-upstream` in a later slice.
