# Artifact Safety

This doc is the source of truth for artifact include/exclude/warn/success rules and fixture cases. [Helper Contracts](helper-contracts.md) summarizes the public surface.

## Safety contract

| Rule | Contract |
| --- | --- |
| include | tracked files, safe untracked non-ignored files, useful dotfiles |
| exclude | `.git`, ignored files, caches, build outputs, dependency folders, generated binaries, secrets |
| warn | skipped sensitive untracked file |
| success | path-only or compact artifact result |

Artifact helpers write only to the requested artifact root or temp evidence area. They do not write to the repo root by default.

## Fixture cases

| Case | Expected |
| --- | --- |
| `.env` | excluded and warned if untracked |
| ignored cache file | excluded |
| safe dotfile | included |
| safe untracked doc | included |
| generated packet/log artifact | included only when it is the requested artifact |
| `review-pack` / `repair-prompt` outputs | excluded from repo snapshots by default |
| build output directory | excluded |
| nested dependency/cache directory | excluded |
