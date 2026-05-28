# AGENTS.md

Keep changes small, scoped, and evidence-driven. Prefer the simplest patch that satisfies the task.

Use repo-relative paths with `patch`/`apply_patch`. If patching fails or path handling gets awkward, use `python3` with `pathlib`.

Use `${TMPDIR:-$HOME/.cache}` for temp files; never assume `/tmp`.

Do not run tests, commit, push, merge, tag, publish releases, or perform GitHub write operations unless explicitly asked.

For implementation PRs, update `repo-automation/docs/implementation-friction-ledger.md`.

Successful implementation output should be exactly this shape unless the prompt asks otherwise:

Implementation complete.
Validation: required checks passed.
Friction ledger: <compact ledger line>

Do not list changed files or every validation command on success unless scope changed, an expected file was not touched, an unexpected file was touched, a check was skipped, substituted, or failed, or the prompt explicitly asks for detailed reporting.

If material friction occurred, update the relevant ledger item and use a compact final line naming the ID and score delta.
If no material friction occurred, use:
`Friction ledger: no material friction; no score changes`

On failure, keep the blocker-style report:
- blocker
- exact failing command when known
- exit code when known
- relevant excerpt
- smallest recommended fix
