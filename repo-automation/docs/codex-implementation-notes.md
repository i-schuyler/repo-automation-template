# Codex Implementation Notes

## Purpose

This doc captures public-safe implementation learnings from Codex repairs that are useful for future repo maintainers.

## Update contract

- Add a short entry when a PR produced material implementation learning.
- Keep the tone public-safe and third-person.
- Keep entries compact and focused on repo-level improvements, not private debugging detail.

## Entry format

Each entry should answer:

- What challenges did Codex encounter with this repo?
- What would have made it easier and more straightforward?
- What improvements does Codex recommend?

## Entries

### 2026-06-11 copied-helper self-target contract

Challenges:
- The active `slice-handoff` helper can be named as a target inside Codex prompts, but the running helper cannot safely edit itself without a copied-helper boundary.
- PR #249 left a duplicate branch-presence guard in `codex-slice-preflight` after validation-manifest enforcement; that cleanup is separate from this slice.

Recommended improvements:
- Keep copied-helper/self-target support behind an explicit immutable snapshot contract before allowing self-target execution.
- Leave snapshot directories writable enough for run-dir cleanup while keeping snapshot files read-only and executable where needed.
- Restore any fake runtime helpers that mutate the smoke repo so later contract scenarios keep a clean baseline.
- Track the duplicate branch-presence guard as future cleanup rather than folding it into self-target contract work.

### 2026-06-09 codex-slice-preflight nested wrapper fixture repair

Challenges:
- A nested repair fixture relied on developer-global Git identity, so its first commit failed silently in CI and surfaced as a misleading outer JSON-wrapper failure.

Recommended improvements:
- Configure Git identity inside repos that focused contracts clone for commit-based branch-shape tests, and include nested JSON failure details in wrapper assertions.

### 2026-06-09 slice-handoff repair routing

Challenges:
- Repair routing crossed validator, branch preflight, Codex resume, existing-PR submit, and operator-output boundaries while preserving implementation behavior.

Recommended improvements:
- Keep repair mode explicit in both CLI and metadata, and keep child-helper fakes at the repo-relative paths used at runtime.

### 2026-06-09 codex-run resume-session final-output contract repair

Challenges:
- Resume support needed the non-interactive `codex exec resume` entrypoint so the adapter could keep a real final-output file instead of copying stdout into `codex-final.txt`.
- The wrapper had to preserve resume controls (`--cd`, `--sandbox`, `--profile`) while also failing explicitly when the final-output artifact was missing or empty.

What would have helped:
- A short note beside the adapter contract making the `codex resume` interactive picker and `codex exec resume` non-interactive path clearly distinct.

Recommended improvements:
- Keep resume adapters file-backed for final output and fail explicitly when the artifact is absent.
- Document entrypoint differences (`codex resume` vs `codex exec resume`) next to the adapter contract so stdout is never mistaken for the durable final artifact.

### 2026-06-08 slice-handoff operator-output and run-context repair

Challenges:
- The slice-handoff boundary output needed to stop surfacing nested `reason=...` fragments and instead show a readable failure heading with explicit details.
- Submit-mode handoffs also needed a stable `CODEX RUN CONTEXT` block sourced from `codex-status --recent=1`, which meant a repo-local recent-status fake and a small parser for required session/rate-limit fields.

What would have helped:
- A shared labeled failure envelope for child-helper boundaries, including a consistent `details:` section and explicit context artifacts.
- A small recent-status fixture builder that can omit one required field on demand without changing the runtime helper wiring.

Recommended improvements:
- Keep child-boundary failures human-readable first, then preserve repair metadata under `details:`.
- Keep submit-context capture repo-local and JSON-driven so the wrapper can validate required Codex re-entry fields before it hands off.

### PR #221

Challenges:
- A few harness paths failed before any useful events were recorded, so debugging required tracing shared wrapper/capture behavior.
- The smoke/pr-body-check fixtures were tightly coupled to temp-repo setup, which made it easy for one missing path to cause misleading wrapper failures.
- Managed-file coverage had to stay aligned across several manifests/registries, so one new file required multiple small updates.

What would have helped:
- A single, explicit registration checklist for new repo-automation/ files.
- A smaller, more isolated test fixture for contract wrappers, so one contract can fail without depending on a full smoke repo rebuild.
- A documented expected JSON shape section for each helper in one place, not split across code/tests/docs.

Recommended improvements:
- Keep smoke/contract regressions fixture-light and isolated from the full template restore path.
- Add a helper to generate/update managed-file registrations consistently.
- Standardize quiet/default/JSON envelopes in shared test helpers, with a tiny per-helper contract spec next to each script.

### 2026-06-07 run-tests output-contract baseline

Challenges:
- Umbrella `run-tests` failures needed a reason fallback that could read child stderr/excerpt details when the first recorded failure line was just `failed`.
- JSON contract updates had to switch to `result`/`status` without regressing quiet success silence or explain-mode readability.

What would have helped:
- A shared umbrella-failure helper that treats "generic fail line but useful child reason in the log" as a first-class case.
- A tiny focused JSON fixture that checks `result`, `status`, counts, and JSON purity together.

Recommended improvements:
- Keep umbrella failure renderers able to mine child excerpts when the first recorded failure line is generic.
- Keep helper JSON contracts on `result`/`status` and assert those fields in focused tests before removing legacy aliases.

### 2026-06-07 codex-status recent-session list mode

Challenges:
- Recent-session discovery needed its own isolated fixture tree so newer malformed files would not disturb single-session `--latest` checks.
- The bounded list mode also needed explicit ShellCheck-visible helper-arg usage when the fixture builder accepted timing fields that otherwise only appeared inside generated JSON.

What would have helped:
- Separate temp repos for single-session and recent-list contract coverage from the start.
- A small shared fixture builder that makes every JSON field reference visible to ShellCheck.

Recommended improvements:
- Keep recent-list smoke fixtures isolated from single-session fixtures.
- Make helper-arg wiring explicit in fixture helpers so static checks see the intended parameter use.

### 2026-06-04 smoke output-contract follow-up

Challenges:
- Focused-wrapper parse failures needed to stay compact while still distinguishing mode conflicts, unknown flags, and unknown arguments across quiet/default/JSON output.
- The shared quiet-envelope helper had to accept optional QDE fields without falling back to brittle line-count assertions.

What would have helped:
- A single shared renderer for focused-wrapper parse errors, plus a tiny table of expected codes/reasons/fixes.
- A quiet-envelope assertion helper that explicitly models optional fields instead of hard-coding five-line envelopes.

Recommended improvements:
- Keep output-mode parse errors and failure envelopes centralized in shared test helpers.

### 2026-06-04 smoke named-check propagation repair

Challenges:
- Timeout-wrapped named checks could lose child `test_fail` labels unless the harness preserved the first failure metadata across the subshell boundary.
- A newly added smoke-harness fixture path literal tripped the portability contract until it was rewritten to use temp-root paths.

What would have helped:
- A shared child-failure metadata channel for timeout-wrapped named checks.
- A quick portability scan of the focused smoke harness fixture strings before landing.

Recommended improvements:
- Keep named-check failure metadata explicit when checks run under timeout subshells.
- Prefer temp-root-derived paths in contract fixtures so portability checks stay quiet.

### 2026-06-05 slice-handoff blocker boundary repair

Challenges:
- The slice-handoff wrapper needed to distinguish Codex final-output blockers from ordinary child failures without letting later submit phases start.
- Failure output had to stay short but still carry the child step, command class, artifact paths, and next action for operator handoff.

What would have helped:
- A shared child-boundary error envelope for execution helpers, with explicit fields for artifact paths and the next action.
- Focused contract fixtures that assert downstream helpers stay uninvoked after the first failing boundary.

Recommended improvements:
- Keep child failure metadata explicit across subprocess boundaries.
- Prefer negative downstream-invocation assertions near the trust boundary.

### 2026-06-06 slice-handoff execution-submit scenario split

Challenges:
- One overloaded execution-submit smoke chain mixed plain success, false-positive blocker protection, and true blocker semantics with stale stdout-shape assumptions.

What would have helped:
- Separate scenario helpers for success, false-positive blocker, and true blocker; keep stdout shape assertions aligned with actual helper output instead of line-count heuristics.

Recommended improvements:
- Split trust-boundary subcases into named helpers whenever the same command path can succeed, false-positive, or hard-stop.

### 2026-06-06 pr-finish mergeability refresh and review-request ergonomics

Challenges:
- GitHub mergeability can lag behind a green CI watch, so merge gating needed an explicit metadata refresh before treating `UNKNOWN` as a hard block.
- `repo-flow submit` only prints a PR Review block when a review-request source is supplied, so submit guidance had to be explicit about `--body-file` versus review-request flags.

What would have helped:
- A tiny helper for refreshing PR metadata after CI watch succeeds.
- One short docs note near submit examples explaining that PR Review blocks require `--review-request-file` or `--review-request-id`.

Recommended improvements:
- Keep CI status and GitHub mergeability separate in finish workflows.
- Document review-block source requirements next to standard submit guidance.


### 2026-06-05 slice-validator capability gate

Challenges:
- The new gate needed to preserve the handoff shape while separating static run-contract validation from repo/worktree preflight.
- PR-body validation was reused through `pr-body-check`, so the helper needed a clear boundary between body validity, submit authorization, and unrelated capabilities.

What would have helped:
- A tiny manifest schema example and direct-call helper spec next to the handoff docs.
- A dedicated validator contract test that exercises default, quiet, JSON, and submit/non-submit capability splits.

Recommended improvements:
- Keep capability-grant manifests explicit and separate them from preflight readiness.
- Reuse PR-body validation as a distinct helper contract instead of embedding body checks in multiple places.

### 2026-06-06 slice-handoff validator wiring

Challenges:
- The orchestrator needed to consume validator manifest paths rather than assume fixed artifact names.
- Validate-only dry runs for submit-capable handoffs needed to stay allowed when bare `--submit` was not requested.
- Repo-relative child-helper tests needed to install or assert helpers inside the smoke temp repo, not rely on PATH/env selection.
- Validation-manifest copies needed their artifact paths rewritten to the final out-dir/run-dir locations so the public summaries stayed inspectable.

What would have helped:
- A single manifest-path contract example showing how orchestrators map validator output back into helper state.
- One focused test for the submit-mode/no-submit split before the execution run dir starts.

Recommended improvements:
- Keep orchestrator glue manifest-driven and avoid hardcoding validator artifact paths.
- Preserve the validate-only path for submit-capable handoffs until bare `--submit` crosses the trust boundary.
- Add a small reusable smoke helper for repo-relative child-helper assertions and fake installation.
- When copying validator manifests into public artifacts, rewrite artifact paths to the final published locations.

### PR #235 slice-handoff smoke preflight stability

Challenges:
- Execution-mode slice-handoff smoke could trip the preflight disk guard in low-space developer environments before the contract path under test ran.

What would have helped:
- A small healthy-disk stub in the execution-mode smoke fixture so the contract could focus on slice-handoff behavior instead of host disk pressure.

Recommended improvements:
- Keep execution-mode smoke using an explicit healthy `df` stub when the contract is meant to exercise preflight and downstream artifact behavior.

### PR #233 slice-handoff modularization and preset resolution

Challenges:
- One large slice-handoff smoke body made execution-submit failures hard to classify, so the wrapper needed named scenario checks and reusable helper builders.
- `pr_review_prompt_id` had to resolve from repo-root `.prompts/<id>.md` so handoff files outside the repo root could still use the shared preset library.
- Execution fixture setup was sensitive to when fake Codex behavior was configured, so blocker-path tests needed the override to be present before the helper installation ran.
- Submit-success coverage also needs per-scenario artifact isolation; a shared execution fixture can make the wrapper fail even when the success run-dir artifacts themselves are correct.
- The current blocker came from submit subcases reusing fake Codex/repo-flow artifacts across scenarios, so each execution-submit scenario should own its own isolated artifact bundle.
- For blocker-path assertions, prefer the scenario run dir's own `pr-body-check.*` and `repo-flow-submit.*` artifacts over shared fake-args placeholders when the helper is already proving the submit boundary in its final summary.
- Sourced contract-library globals inside a helper function may need an explicit no-op reference or narrow directive so ShellCheck sees their intended later use instead of SC2034 noise.

What would have helped:
- Separate named checks for metadata/help, dry-run, validation, lifecycle, and execution scenarios from the start.
- A repo-root-relative preset lookup rule documented beside the validator contract.

Recommended improvements:
- Keep smoke wrappers as a short list of named scenarios, not one monolithic body.
- Treat shared prompt presets as repo-root assets so out-of-tree handoff files can reuse them.
- When execution-mode smoke depends on fake child behavior, set the override before the fake helper is installed or invoked.
- Keep submit-success and blocker subcases from sharing mutable fake Codex/repo-flow artifacts unless the fixture is explicitly reseeded between them.
- Prefer one scenario-owned fake artifact bundle per execution-submit case so assertions never accidentally read reused state from a later subcase.
- For sourced libraries, make harness globals visible to ShellCheck in the same function scope that initializes them.
