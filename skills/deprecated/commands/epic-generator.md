---
name: epic-generator
description: Generate Epic documents (epic.md) from a Spec Funcional — one folder per epic
---

Invoke the planning-4-epic-generator skill.

Read in order:
1. `docs/project_context.md` (if it exists)
2. The Spec Funcional (from `docs/inputs/`, uploaded file, or conversation context)
3. TDD (optional — read if available to enrich technical details)

Parse the Spec Funcional to identify all epics. Present the list to the user and ask which ones to generate (all or specific ones).

For each selected epic, generate a standalone epic document with: objective, scope (in/out), happy path (ASCII flow), KPIs, and user stories (3–8 per epic, each with user statement + max 3 ACs).

Write each epic to:
```
docs/epics/E-XXX_slug/epic.md
```

Target 150–200 lines per epic. Use [TO BE DEFINED] for gaps — never invent content.
