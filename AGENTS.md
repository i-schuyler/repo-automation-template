# AGENTS.md

Keep changes small, scoped, and evidence-driven. Prefer the simplest patch that satisfies the task.

Use repo-relative paths with `patch`/`apply_patch`. If patching fails or path handling gets awkward, use `python3` with `pathlib`.

Use `${TMPDIR:-$HOME/.cache}` for temp files; never assume `/tmp`.

Do not run tests, commit, push, merge, tag, publish releases, or perform GitHub write operations unless explicitly asked.

Keep final output short. If an output contract asks for success-only output, print `pass`. On failure, report only the blocker, relevant excerpt, and smallest recommended fix.
