# Managed Files

`repo-automation/manifest.json` is the repo-owned manifest for automation files under `repo-automation/`.

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

## Freshness Check

`repo-automation/bin/automation-freshness` reads the manifest and checks that the managed paths exist in the selected checkout.

Default human output:

    repo-automation/bin/automation-freshness

Machine output:

    repo-automation/bin/automation-freshness --machine-json

Check another checkout or source root:

    repo-automation/bin/automation-freshness --source-root=/path/to/checkout
    repo-automation/bin/automation-freshness --source-root=/path/to/checkout --machine-json

## Boundary

This manifest tracks repo-owned automation files only.

It does not cover downstream app files, release artifacts, generated logs, or private local state.
