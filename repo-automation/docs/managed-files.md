# Managed Files

`repo-automation/manifest.json` is the repo-owned manifest for automation files under `repo-automation/`.
`repo-automation/helper-metadata.json` is the repo-owned inventory for current public helpers.

The compact human helper contract summary lives in [Helper Contracts](helper-contracts.md).

The manifest stays intentionally small and hand-editable:

- only repo-owned automation files are listed
- paths stay under `repo-automation/`
- no secrets, machine-specific paths, build artifacts, generated logs, or downstream app files are listed

## Manifest Shape

The current manifest uses a compact JSON shape:

- `schema` identifies the manifest format
- `repository` names the owning repo
- `managed_root` records the tracked automation subtree
- `managed_files` lists the managed paths and their intended ownership

Each managed file entry records:

- `path`
- `owner`
- `kind`

That is enough for a quick human edit and for the freshness helper to compare the manifest with the working tree, including source-repo files that exist on disk but were not added to the manifest. The version-consistency check also compares `repo-automation/manifest.json` against `repo-automation/bin/repo-automation-install` managed-file coverage so manifest/install drift fails fast instead of surfacing in a downstream install.

The helper-inventory check compares `repo-automation/helper-metadata.json` against the manifest/install coverage for the current public helper surface.

## Freshness Check

`repo-automation/bin/automation-freshness` reads the manifest and checks that the managed paths exist in the selected checkout.

Default human output:

    repo-automation/bin/automation-freshness

Clean success prints `pass`; failures print a single `fail:` line on stderr.

Machine output:

    repo-automation/bin/automation-freshness --machine-json

Check another checkout or source root:

    repo-automation/bin/automation-freshness --source-root=/path/to/checkout
    repo-automation/bin/automation-freshness --source-root=/path/to/checkout --machine-json

## Managed-File Helpers

These helpers keep the manifest and installer coverage aligned:

| Helper | Shape | Source of truth |
| --- | --- | --- |
| `repo-automation/bin/managed-file-check` | `--changed [--quiet]` | reviews changed `repo-automation/` paths against the manifest and helper inventory; `--quiet` suppresses the success `pass` line |
| `repo-automation/bin/managed-file-add` | `--path=<path> --kind=<kind>` | updates `repo-automation/manifest.json` and `repo-automation/bin/repo-automation-install` coverage together |

If a new `repo-automation/` path also changes the public helper surface, update `repo-automation/helper-metadata.json` in the same slice.

## Boundary

This manifest tracks repo-owned automation files only.

It does not cover downstream app files, release artifacts, generated logs, or private local state.
