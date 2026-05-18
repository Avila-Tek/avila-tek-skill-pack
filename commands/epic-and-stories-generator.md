---
name: epic-and-stories-generator
description: Generate Epic documents and Story files from a Spec Funcional — one epic.md per epic, one folder per story — genera las épicas / crea las historias
---

Invoke the planning-4-epic-and-stories-generator skill.

**Phase 1 — Epics**

Read in order:
1. `docs/project_context.md` (if it exists)
2. The Spec Funcional (from `docs/inputs/`, uploaded file, or conversation context)
3. TDD (optional — read if available)

Parse the Spec Funcional to identify all epics. Present the list and ask which ones to generate (all or specific ones).

For each selected epic, generate a slim epic document (50–150 lines) with: objective, scope (in/out), happy path (ASCII, max 6 steps), unhappy paths, optional KPIs (ask + suggest), and stories table (title + user statement + max 2 ACs).

Write each epic to:
```
docs/epics/E-XXX_slug/epic.md
```

**Phase 2 — Stories**

After epics are written, ask: "Generate stories now? (all, or specify: E-001, E-003...)"

For each story: ask for Figma URL, resolve open questions, generate full Block A + Block B story file.

Write each story to:
```
docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/E-XXX_S-YYY_slug.md
```

The developer starts from the story file using `/spec` (Story-Driven Mode) → `/plan` → `/build`.
