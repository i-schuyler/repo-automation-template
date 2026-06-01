Please review this PR before merge:

<PR_URL>

Slice: <TITLE>
Branch: <BRANCH>
Run dir: <RUN_DIR>

Use the canonical private project review sources:
1. `prompts/PR_REVIEW_PROMPT.md`
2. `projects/repo-automation-template/PROMPTS.md` → `PR Review Wrapper`
3. `projects/repo-automation-template/CURRENT_STATE.md` for current guardrails, deferred hardening, and recent PR context.

Review the changed files and related docs, tests, metadata, helper contracts, output contracts, examples, and workflow routing for drift.

Return the full project review shape, including:
- Verdict
- Audit Coverage
- Findings
- Contract Drift Matrix
- Search Terms Used
- Tests / Enforcement Needing Updates
- Questions I Should Be Asking
- Selected Repair Architecture
- Consolidated Repair Prompt

Merge remains explicit and outside slice-handoff.
