# Implementation Friction Ledger

## Purpose

This is a lightweight repo-maintainer ledger for recurring implementation friction. It is not a replacement for tests, issues, PR review, or private project current-state planning.

## Update Contract

- Every implementation PR should update this ledger.
- If material friction occurred, update the relevant scored item and add a per-slice signal.
- If no material friction occurred, add a compact per-slice signal with `none` and `score_delta=0`.
- Do not duplicate long friction narratives in the Codex UI report; the ledger diff is the durable record.
- Codex UI report should only include a compact line naming ledger IDs changed or saying no material friction.
- Do not add noise for formatting-only or typo-only PRs unless friction actually occurred.
- Keep entries compact and reviewer-readable.

## Scoring Rules

- +1 mild friction: extra attention, mild ambiguity, or small manual review overhead.
- +2 repeated friction: repeated manual assertion, repeated fixture ambiguity, repeated command-shape uncertainty.
- +3 validation friction: caused failed local validation, same-PR repair, or non-obvious debugging.
- +5 trust/flow blocker: blocked submit/merge/CI, produced misleading operator output, or caused a high-risk wrong workflow step.
- -1 to -3 mitigation credit: reduce score when a PR clearly reduces the friction class.
- `resolved`: use status `resolved` when the issue no longer needs active prioritization but should remain historically visible.

## Score Thresholds

- score 0: resolved or historical.
- score 1–2: monitor.
- score 3–4: consider when nearby code is touched.
- score 5–7: candidate stabilization slice.
- score 8+: prioritize unless higher-risk work is active.

## Scored Friction Items

| ID | Score | Status | Last seen | Evidence | Suggested next action |
| --- | ---: | --- | --- | --- | --- |
| `summary-helper-long-positional-call` | 3 | active | PR #182 | Submit summary helper now accepts optional trailing fields; Codex noted long positional helper calls make optional fields easy to get wrong. | consider named-arg style wrapper or option parser if the interface grows again |
| `summary-rendering-split-paths` | 1 | mitigated | PR #182 | PR #182 consolidated duplicate submit FINAL SUMMARY construction through the shared helper. | monitor for new duplicate summary construction |
| `grep-awk-summary-assertions` | 1 | mitigated | PR #181 | PR #181 added shared FINAL SUMMARY assertion helpers and converted targeted repo-flow submit assertions. | continue using shared helpers for new summary contracts |
| `submit-fixture-shared-state` | 2 | mitigated-monitoring | PR #180 | PR #180 added gh-stub reset support; broader one-subtle-scenario-per-temp-repo topology remains deferred. | only revisit if fixture leakage or ambiguity recurs |
| `quiet-failure-diagnostics-collapse` | 0 | resolved | PR #179 | PR #179 added uppercase `FAIL:` extraction and focused wrapper regression coverage. | none unless a similar failure detail collapse recurs |
| `manifest-registration-drift` | 3 | mitigated-monitoring | PR #183 | New repo-automation docs file was indexed but not added to `repo-automation/manifest.json` or `repo-automation/bin/repo-automation-install`, causing CI/starter-template readiness failure. Guardrails now include `managed-file-check`, `managed-file-add`, `version-consistency.sh` manifest-vs-installer coverage, and the AGENTS.md reminder. | keep using the existing guardrails when repo-automation files change; revisit only if drift recurs |
| `actions-checkout-node24` | 0 | resolved | PR #185 | CI checkout updated from `actions/checkout@v4` to `actions/checkout@v6` to clear the Node.js 20 compatibility warning. | none unless checkout compatibility warnings recur |
| `ci-evidence-pr-lookup-brittle` | 3 | mitigated-monitoring | PR #189 | slice-handoff-plan-validator CI failed but `ci-log-dump --pr` could not recover the failed PR run; repo inference and PR run lookup were too brittle. | keep ChatGPT/operator workflows evidence-first: resolve CI evidence before Codex repairs, using run-id fallback when needed |
| `slice-handoff-smoke-fixture-coverage` | 3 | mitigated-monitoring | PR #189 | helper metadata referenced slice-handoff, but smoke fixture did not copy/chmod it into the temp repo. | keep metadata-driven helper-bin fixture copying in place for new public helpers |
| `smoke-registry-contract-path-guard` | 2 | mitigated-monitoring | PR #189 | metadata `contract_test_path` can drift from the full smoke registry. | keep validating repeated registration surfaces instead of relying on manual updates |
| `full-smoke-timeout-budget-drift` | 0 | mitigated-monitoring | PR #190 | full smoke exceeded the default run-tests timeout while focused contracts passed; run-tests now separates the 300s outer smoke-suite budget from 120s top-level checks and reports outer suite timeout blame. | monitor for future full-suite growth against the separate smoke-suite budget |
| `metadata-object-drift-slice-handoff` | 3 | active | PR #190 | helper metadata drifted onto the wrong object (`add-doc-pr`) before the focused slice-handoff metadata assertion caught it. | keep object-specific metadata assertions near the affected contract |
| `slice-handoff-contract-opacity` | 3 | mitigated-monitoring | PR #200 | the slice-handoff smoke wrapper hid the first failing subcheck and preserved capture paths were too ephemeral; a direct body entrypoint and a documented preflight smoke recipe would cut diagnosis time. | keep first-failure extraction, durable failure logs, and body-only isolation hooks in place |
| `smoke-fixture-reseed-ordering` | 2 | mitigated-monitoring | PR #201 | the slice-handoff contract body depended on canonical handoff files surviving later subchecks; re-seeding fixtures or making each block self-contained avoids brittle ordering dependencies. | keep late-block fixture re-seeding or per-block fixture setup where contract bodies reuse the same canonical files |
| `slice-handoff-fake-codex-fixture-dirt` | 3 | mitigated-monitoring | 2026-05-31 | execution-mode smoke copied or staged dirt into the preflight repo copy before slice-handoff ran preflight. | keep fake Codex/capture artifacts outside the execution repo and gate execution-mode tests with a clean-tree sentinel |
| `preflight-prefix-temp-cleanup-gap` | 3 | mitigated-monitoring | PR #206 | clean-test-cache missed approved repo-automation temp prefixes under tmp until prefix cleanup was added. | keep the approved prefix list narrow and preserve-path aware |
| `slice-handoff-temp-lifecycle-fragmentation` | 4 | mitigated-monitoring | 2026-06-01 | ad hoc top-level slice-handoff fixture dirs caused cleanup-prefix whack-a-mole until execution and remote fixtures moved under the registered smoke parent, nested fixtures were seeded as git repos before execution-mode assertions, and isolated TMPDIR/HOME was needed so nested cleanup would not target the outer smoke root. | keep disposable smoke fixtures under the registered smoke parent and reserve top-level cleanup for legacy prefixes only |
| `slice-handoff-submit-boundary-drift` | 5 | mitigated-monitoring | PR #204 | dry-run preview and validation ownership around the submit boundary could mislead operators about when submit is authorized. | keep bare-`--submit` boundary wording and preview-vs-execution separation explicit |
| `slice-handoff-codex-run-contract-drift` | 3 | active | PR #203 | review found an embedded Python indentation bug in slice-handoff plus undocumented codex-path override behavior and stale docs around the new adapter wiring. | keep slice-handoff JSON-excerpt helpers, PATH-based fake Codex tests, and docs aligned with the adapter contract |
| `focused-contract-parallel-temp-collision` | 1 | active | 2026-05-30 | Running multiple focused contract wrappers in parallel produced quiet failures for `review-pack` and `repair-prompt`, while sequential quiet and explain runs passed. | run focused contract wrappers sequentially unless their temp roots/stubs are isolated |
| `run-tests-smoke-capture-cleaned` | 0 | resolved | 2026-05-30 | Full audit quiet validation exited 0 but printed a missing smoke capture `cat` error when smoke cleanup removed the run-owned capture before log append. | none unless quiet full-audit capture noise recurs |

## Per-Slice Signals

- 2026-05-30 / PR #200 / contract-debt-report shared-body repair / ids=none / score_delta=0 / signal=updated shared-contract coverage fixture ordering and ignored local variable names in shared-function detection; no material friction
- 2026-05-30 / strict-value-flag-parser / ids=focused-contract-parallel-temp-collision / score_delta=+1 / signal=parallel focused wrapper validation produced false quiet failures; sequential focused validation passed
- 2026-05-30 / strict-value-flag-parser / ids=run-tests-smoke-capture-cleaned / score_delta=0 / signal=guarded missing smoke capture log appends and added quiet regression coverage
- 2026-05-28 / PR #179 / focused-diagnostics / ids=quiet-failure-diagnostics-collapse / score_delta=0 / signal=added focused wrapper diagnostics coverage and collapsed nested uppercase failure reporting
- 2026-05-28 / PR #180 / submit-fixture-isolation / ids=submit-fixture-shared-state / score_delta=-1 / signal=added gh-stub state reset to reduce leakage risk
- 2026-05-28 / PR #181 / final-summary-assertions / ids=grep-awk-summary-assertions / score_delta=-1 / signal=added shared FINAL SUMMARY assertion helpers and converted targeted submit checks
- 2026-05-28 / PR #182 / submit-summary-consolidation / ids=summary-rendering-split-paths|summary-helper-long-positional-call / score_delta=0 / signal=consolidated duplicate FINAL SUMMARY construction; noted optional-field positional-call friction
- 2026-05-27 / PR #183 / implementation-friction-ledger repair / ids=manifest-registration-drift / score_delta=+0 / signal=manifest registration was fixed, then installer coverage drift was discovered and repaired in the same PR
- 2026-05-28 / PR #185 / ci-checkout-update / ids=none / score_delta=0 / signal=updated checkout to actions/checkout@v6; no material friction
- 2026-05-28 / PR #186 / smoke-temp-dir-hygiene / ids=none / score_delta=0 / signal=cleaned child-owned smoke temp dirs on successful runs while preserving failed artifacts
- 2026-05-28 / managed-file-guardrail-calibration / ids=manifest-registration-drift / score_delta=-2 / signal=surfaced repo-automation managed-file guardrails in AGENTS.md and recalibrated drift from active blocker to monitored
- 2026-05-29 / slice-handoff-plan-only-validator / ids=none / score_delta=0 / signal=implemented non-executing slice-handoff plan-only helper with contract coverage
- 2026-05-29 / PR #189 / slice-handoff-plan-validator / ids=ci-evidence-pr-lookup-brittle / score_delta=+3 / issue=CI failed but ci-log-dump --pr could not recover the failed PR run; repo inference and PR run lookup were too brittle / fix=hardened ci-log-dump repo inference and PR run lookup, then repaired any proven PR #189 failure / lesson=ChatGPT investigates CI evidence first; Codex repairs from proven evidence
- 2026-05-29 / slice-handoff-smoke-fixture-coverage / ids=slice-handoff-smoke-fixture-coverage|smoke-registry-contract-path-guard / score_delta=+5 / issue=helper metadata referenced slice-handoff, but smoke fixture did not copy/chmod it into the temp repo; metadata contract_test_path can drift from full smoke registry / fix=metadata-driven helper-bin smoke fixture copying plus slice-handoff registry coverage and a metadata contract path guard / lesson=new public helpers need metadata, managed files, installer, shellcheck parity, smoke fixture, and smoke registry coverage; derive or validate repeated registration surfaces
- 2026-05-29 / slice-handoff-local-artifacts / ids=full-smoke-timeout-budget-drift / score_delta=+1 / issue=full smoke exceeded the default run-tests timeout while focused contracts passed / fix=current slice validated with `run-tests --quiet --timeout=300`; defer smoke/run-tests timeout-budget separation / lesson=distinguish outer smoke-suite timeout from named smoke-check timeout before blaming the active contract
- 2026-05-29 / slice-handoff-local-artifacts / ids=metadata-object-drift-slice-handoff / score_delta=+3 / issue=helper metadata drifted onto the wrong object (`add-doc-pr`) before the focused slice-handoff metadata assertion caught it / fix=added object-specific metadata assertion and restored the intended slice-handoff helper flags / lesson=assert the intended JSON object, not just matching keys
- 2026-05-30 / PR #200 / slice-handoff-execution-preflight / ids=slice-handoff-contract-opacity / score_delta=+3 / signal=smoke wrapper hid the first failing subcheck and preserved capture paths were too ephemeral until the contract/body and harness were hardened
- 2026-05-30 / PR #201 / slice-handoff-execution-semantics / ids=smoke-fixture-reseed-ordering / score_delta=+2 / signal=contract body needed explicit fixture re-seeding to keep later subchecks self-contained and avoid brittle ordering dependencies
- 2026-05-31 / slice-handoff-phase2-fixture-cleanliness / ids=slice-handoff-fake-codex-fixture-dirt / score_delta=+3 / signal=execution-mode smoke needed a clean-tree sentinel and externalized fake Codex artifacts before preflight
- 2026-05-31 / PR #203 / slice-handoff-codex-run-drift / ids=slice-handoff-codex-run-contract-drift / score_delta=+3 / signal=review caught slice-handoff JSON excerpt indentation drift, stale adapter docs, and undocumented codex-path override behavior
- 2026-05-31 / PR #204 / slice-handoff-submit-authorization / ids=slice-handoff-submit-boundary-drift|slice-handoff-contract-opacity|slice-handoff-fake-codex-fixture-dirt|submit-fixture-shared-state / score_delta=+5 / signal=post-PR204 docs/contract drift across dry-run submit authorization, PR-body validation ownership, execution-submit expectations, smoke fixture setup, and fake repo/pr-body baseline clarity
- 2026-05-31 / PR #206 / preflight-prefix-temp-cleanup / ids=preflight-prefix-temp-cleanup-gap / score_delta=+3 / signal=clean-test-cache gained approved prefix cleanup for repo-automation temp fixtures under tmp; contract tests now use isolated HOME/TMPDIR to avoid capture deletion
- 2026-06-01 / slice-handoff-temp-lifecycle-fragmentation / ids=slice-handoff-temp-lifecycle-fragmentation / score_delta=+4 / signal=ad hoc top-level slice-handoff fixture dirs caused cleanup-prefix whack-a-mole until execution and remote fixtures moved under the registered smoke parent; nested fixtures must be seeded git repos before execution-mode assertions and nested cleanup needs isolated TMPDIR/HOME
- 2026-06-01 / slice-handoff-pr-review-presets / ids=none / score_delta=0 / signal=added explicit review-request precedence, prompt-preset resolution, and post-submit URL rewrite with no material friction
- 2026-05-29 / run-tests-smoke-timeout-separation / ids=full-smoke-timeout-budget-drift / score_delta=-1 / signal=separated outer smoke-suite timeout from per-command timeout, defaulted smoke suite to 300s, preserved explicit --timeout legacy intent, and added outer-timeout blame coverage

## Maintenance Notes

- Keep entries compact.
- Prefer updating existing IDs over creating near-duplicates.
- Create a new ID only for a distinct recurring friction pattern.
- If a score reaches 5+, consider whether it should influence the next stabilization priority.
- If a row grows too large, split details into an issue or design note later.
- This file should remain implementation-specific and public-repo-safe.
