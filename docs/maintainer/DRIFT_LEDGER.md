# Drift Ledger

| risk | mitigation | status | owner |
| --- | --- | --- | --- |
| parallel helper stacks | keep one canonical shared helper set and document install boundaries | open | maintainers |
| copied scripts diverging | record installed version/ref and plan update helper | open | maintainers |
| stale downstream installed versions | require downstream provenance and future report/update metadata | open | maintainers |
| docs/code mismatch | keep docs tied to script names and add future doctor checks | open | maintainers |
| version drift across VERSION, CHANGELOG.md, README visible version, docs/DECISIONS.md, docs/VERSIONING.md, future script metadata, future release bundle metadata, examples/downstream/.repo-automation.conf.example, and downstream installed docs | define version placements and add future CI consistency guard | active | maintainers |
| private context leaking into public docs | keep public-safe provenance only and avoid private chat/project identity content | open | maintainers |
| build/cache artifacts committed | root `.gitignore` excludes common local, build, cache, archive, log, and env files | active | maintainers |
| branch deletion ambiguity | document safer branch cleanup defaults before implementation | open | maintainers |
| CI status misread by automation | require explicit evidence extraction and structured status output before automated decisions | open | maintainers |
