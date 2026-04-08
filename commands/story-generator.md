---
name: story-generator
description: Generate Story files for an epic — one folder per story under docs/epics/E-XXX/stories/
---

Invoke the planning-5-story-generator skill.

Ask the user which epic to generate stories for if not already specified. Then read:
1. `docs/epics/E-XXX_slug/epic.md` (required)
2. The Spec Funcional (if available — for functional flow context)
3. `docs/epics/E-XXX_slug/tdd.md` (if available — for technical scope)

List all S-XXX stories found in the epic. Ask which ones to generate (all or specific ones).

Resolve any open questions with the user before generating — the final document must contain no unresolved ambiguities.

Each story has two blocks:
- Block A — user story, acceptance criteria, ranked tasks (Must/Important/Optional/Nice to have). Sufficient for estimation.
- Block B — technical scope, business rules, data model, telemetry, testing guidance. Omit sections with no real content.

Write each story to its own folder:
```
docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/E-XXX_S-YYY_slug.md
```

The developer starts from this file using /spec (Story-Driven Mode) → /plan → /build.
