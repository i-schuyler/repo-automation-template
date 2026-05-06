# Downstream Repo Automation

Downstream repos should keep this file visible after installing shared repo automation.

Record:

- installed version/ref
- upstream issue URL
- local overrides document
- when to file upstream bug/feature
- redaction rules

## Installed Context Block

Copy this into upstream bug reports and fill in the local details:

```text
Repo automation installed context:
- Upstream repo: i-schuyler/repo-automation-template
- Installed version/ref: 0.1.0-EXAMPLE
- Installed at: YYYY-MM-DD
- Local overrides doc: docs/repo-automation/local-overrides.md
- Local overrides present: yes/no/unknown
- Command run:
- Expected behavior:
- Actual behavior:
- Redacted logs attached/pasted: yes/no
```

File upstream when a bug or feature affects shared automation behavior. Keep repo-specific CI commands, docs paths, deploy paths, board config, app behavior, and private operational rules local.

Terminal reporting helper:

```sh
scripts/repo-automation-report-upstream --type bug --title "Short title" --command "..." --expected "..." --actual "..." --dry-run
```

Before filing, redact secrets, tokens, private keys, passphrases, private env values, sensitive private hostnames, and raw logs containing secrets.
