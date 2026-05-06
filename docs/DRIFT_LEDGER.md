# Drift Ledger

| risk | mitigation | status | owner |
| --- | --- | --- | --- |
| parallel helper stacks | keep one canonical shared helper set and document install boundaries | open | maintainers |
| copied scripts diverging | record installed version/ref and plan update helper | open | maintainers |
| stale downstream installed versions | require downstream provenance and future report/update metadata | open | maintainers |
| docs/code mismatch | keep docs tied to script names and add future doctor checks | open | maintainers |
| version mismatch across VERSION, CHANGELOG, script metadata, release metadata, and installed examples | define version placements and add future CI consistency guard | open | maintainers |
| private context leaking into public docs | keep public-safe provenance only and avoid private chat/project identity content | open | maintainers |
| build/cache artifacts committed | root `.gitignore` excludes common local, build, cache, archive, log, and env files | active | maintainers |
| branch deletion ambiguity | document safer branch cleanup defaults before implementation | open | maintainers |
| CI status misread by automation | require explicit evidence extraction and structured status output before automated decisions | open | maintainers |
