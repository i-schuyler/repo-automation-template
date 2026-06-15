# AGENTS.md

Keep changes small, scoped, and evidence-driven. Prefer the simplest patch that satisfies the task.

Use repo-relative paths with `patch`/`apply_patch`. If patching fails or path handling gets awkward, use `python3` with `pathlib`.

Use `${TMPDIR:-$HOME/.cache}` for temp files; never assume `/tmp`.

When adding, moving, or deleting files under `repo-automation/`, keep managed-file coverage aligned with `repo-automation/bin/managed-file-add`, `repo-automation/bin/managed-file-check --changed --quiet`, and `repo-automation/tests/version-consistency.sh --quiet`.

When testing a parent helper that invokes a repo-relative child helper, install child fakes at the same repo-relative path the parent resolves at runtime, usually:
`$smoke_test_dir/repo-automation/bin/<child-helper>`

Do not rely on PATH-only or env-only fake injection to prove child-helper wiring. Environment variables may configure an installed fake, but they must not select the fake.

Use or add smoke helper assertions that fail actionably when the runtime helper is missing.

Preserve child failure detail in parent helpers. Wrapper output may add context, but it must not replace the most specific child blocker, failure card, expected/actual pair, or evidence path.

For bundled test assertions, prefer named actionable checks over long `&&` chains. Use fail-fast named assertions when later checks depend on earlier setup or would cascade; aggregate named failures only when checks are independent, cheap, and useful together. Failure output should name the failed invariant and include expected/actual/path when cheap to compute.

Keep derived timing fields source-labeled or conservatively named. Distinguish current helper invocation elapsed time from Codex-reported work time and any timestamp-span-derived session time.

Do not run tests, commit, push, merge, tag, publish releases, or perform GitHub write operations unless explicitly asked.

For implementation PRs, update `repo-automation/docs/implementation-friction-ledger.md`.
If material implementation learning occurred, also update `repo-automation/docs/codex-implementation-notes.md`.

Successful implementation output should be exactly this shape unless the prompt asks otherwise:

Implementation complete.
Validation: required checks passed.
Friction ledger: <compact ledger line>
Codex notes: <updated/no material notes>

Do not list changed files or every validation command on success unless scope changed, an expected file was not touched, an unexpected file was touched, a check was skipped, substituted, or failed, or the prompt explicitly asks for detailed reporting.

If material friction occurred, update the relevant ledger item and use a compact final line naming the ID and score delta.
If no material friction occurred, use:
`Friction ledger: no material friction; no score changes`
For Codex implementation notes, use:
`Codex notes: updated`
or
`Codex notes: no material notes`

On failure, keep the blocker-style report:
- blocker
- exact failing command when known
- exit code when known
- relevant excerpt
- smallest recommended fix
