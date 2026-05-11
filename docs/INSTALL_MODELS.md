# Install Models

## 1. Recommended v0.1.0 Default: Pinned Copy Bundle

The v0.1.0 default is to copy a pinned release bundle into each downstream repo and record provenance. This keeps the downstream repo self-contained and easy to inspect from a phone or terminal.

Downstream installed files must include provenance and upstream issue instructions.
Use `repo-automation/bin/repo-automation-install` as the default repo-local install/update path for this pinned/copy model.

## 2. GitHub Template Repo For New Repos

GitHub template repository mode may be useful after the folder layout and scripts stabilize. It is best for new repos that want the whole convention at creation time.

## 3. Installer/Import/Update Helper

`repo-automation/bin/repo-automation-install` now provides the install/update helper path. It preserves local overrides, records installed automation version/ref, keeps the upstream issue flow visible, and offers a conservative `--starter-template` profile for reusable starter-template repos without broadening workflow permissions, starter-template version ownership, or downstream app/product version ownership.

## 4. Future Git Subtree Advanced Mode

Future git subtree support is deferred because:

- early script API instability
- phone/Codex sync complexity
- repo-local customizations
- merge/sync friction
- subtree mode is better after a stable folder boundary exists

## 5. Reusable GitHub Actions Workflows

Reusable GitHub Actions workflows may become a CI-only complement. They are not a replacement for repo-local scripts and docs because downstream repos still need terminal-friendly local behavior, provenance, and issue instructions.
