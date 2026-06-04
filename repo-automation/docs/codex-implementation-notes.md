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

### 2026-06-04 smoke output-contract follow-up

Challenges:
- Focused-wrapper parse failures needed to stay compact while still distinguishing mode conflicts, unknown flags, and unknown arguments across quiet/default/JSON output.
- The shared quiet-envelope helper had to accept optional QDE fields without falling back to brittle line-count assertions.

What would have helped:
- A single shared renderer for focused-wrapper parse errors, plus a tiny table of expected codes/reasons/fixes.
- A quiet-envelope assertion helper that explicitly models optional fields instead of hard-coding five-line envelopes.

Recommended improvements:
- Keep output-mode parse errors and failure envelopes centralized in shared test helpers.
