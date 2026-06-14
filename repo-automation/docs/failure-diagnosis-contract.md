# Failure Diagnosis Contract v1

Failure cards are the durable handoff between helpers and operators when a child failure matters more than wrapper plumbing.

## Fields

- `failure_card_version`
- `contract_id`
- `layer`
- `owner`
- `failing_command`
- `status_code`
- `reason`
- `expected`
- `actual`
- `evidence_path`
- `child_failure_preserved`
- `repair_surface`
- `operator_next`

Not every field must be populated, but preserved child fields should stay visible.

## Rules

- Parent helpers may add context, but they must not replace the most specific child blocker, failure card, expected/actual pair, or evidence path.
- Any derived metric must name its source or use a conservative label.
- Keep current helper invocation elapsed time distinct from Codex-reported work time and from any timestamp-span-derived session time.
- When Codex blocks a run, map the blocker into a failure card with `reason`, `evidence_path`, `child_failure_preserved`, `repair_surface`, and `operator_next` populated when known.

## Output shape

- Human output should stay compact and point at the card or evidence path.
- Machine output should be a plain `key=value` card file.
