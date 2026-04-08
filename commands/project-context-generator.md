---
description: Generate or update the Project Master Context (docs/project_context.md) from a Design Doc or Intake Brief
---

Invoke the planning-0-project-context-generator skill.

Look for the source document in this order:
1. `docs/inputs/` in the current repo (preferred)
2. A file the user uploaded or referenced in the conversation
3. Ask the user for a path if nothing is found

If `docs/project_context.md` already exists, run in Update mode — apply changes surgically and append a Change Log entry. If it does not exist, run in Create mode and generate the full document from scratch.

Ask clarifying questions one at a time before drafting. Do not generate the document until the user confirms.

Write the output to `docs/project_context.md`.
