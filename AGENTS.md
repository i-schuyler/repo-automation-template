# AGENTS.md

## Global Codex workflow defaults

- Prefer PR-first workflow for repo work.
- Include branch checkout commands in suggested workflows before edit slices.
- After successful slice work, include push commands and `gh pr create` commands.
- After merge, include both remote and local cleanup commands.
- Clipboard payload must match the prompt-defined output contract exactly.
- Prefer repo-scoped changes over broader environment changes.
- Do not assume network access; respect repo/project configuration.
- Keep suggested workflows practical, copy/pasteable, and minimal.

## Safety defaults

- Prefer the smallest safe scope.
- Do not broaden sandbox assumptions beyond project config.
- Do not assume auto-merge/PR monitoring exists unless explicitly configured by project automation.
- Patch edits: use repo-relative paths with `patch`/`apply_patch`. If patch fails or path handling gets awkward, use `python3` + `pathlib`.
