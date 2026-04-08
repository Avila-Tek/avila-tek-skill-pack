---
name: technical-design-document
description: Generate a Technical Design Document (TDD) from a Spec Funcional and domain model
---

Invoke the planning-3-technical-design-document skill.

Before reading any files, ask the tech lead:
"Are you creating the TDD before the epics (architecture-first) or after (epics already exist)?"

Then read in order:
1. `docs/project_context.md`
2. `docs/domain_model.md`
3. The Spec Funcional (from `docs/inputs/`, uploaded file, or conversation context)
4. Existing epic files from `docs/epics/` — only if TDD is being created after epics

The TDD covers: problem statement, solution architecture (ASCII diagrams), component design, data model, API design, security, and integrations. It does NOT duplicate functional flows or scope from the Spec — reference those instead.

Write the output to `docs/epics/E-XXX_slug/tdd.md`. Ask the user for the target epic folder if not specified.
