# Downstream Repo Automation

Downstream repos should keep this file visible after installing shared repo automation.

Record:

- installed version/ref
- upstream issue URL
- local overrides document
- when to file upstream bug/feature
- redaction rules

File upstream when a bug or feature affects shared automation behavior. Keep repo-specific CI commands, docs paths, deploy paths, board config, app behavior, and private operational rules local.

Planned terminal reporting helper:

```sh
scripts/repo-automation-report-upstream
```

Before filing, redact secrets, tokens, private keys, passphrases, private env values, sensitive private hostnames, and raw logs containing secrets.
