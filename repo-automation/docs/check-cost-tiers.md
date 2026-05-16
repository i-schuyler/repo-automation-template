# Check-Cost Tiers

This doc is the source of truth for check-cost tier definitions. [Helper Contracts](helper-contracts.md) summarizes the public surface.

| Tier | Meaning |
| --- | --- |
| `instant` | tiny read-only check; usually phone-safe |
| `targeted-local` | local and narrow; scoped to a path or state |
| `network-read` | GitHub/API read-only helper |
| `broad-local` | broader local validation |
| `CI-owned` | the work is owned by CI or CI logs |
| `mutating` | writes files, git state, or artifacts |

Phone default behavior: `instant`, `targeted-local`, and selected `network-read` helpers only.

- Broad local checks are explicit.
- CI-owned checks do not run by surprise inside phone helpers.
- Helpers that call `run-tests` internally must declare changed, docs-only, targeted, or broad mode.
- Product-helper commands must declare read-only, mutating, network-read, or CI-owned phases.

## Helper phase rule

| Command family | Required phase declaration |
| --- | --- |
| helpers that may call `run-tests` | changed / docs-only / targeted / broad |
| product-helper commands | read-only / mutating / network-read / CI-owned |
