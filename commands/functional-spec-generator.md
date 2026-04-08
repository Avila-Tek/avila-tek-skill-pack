---
description: Generate a Functional Spec (Spec Funcional) in Spanish from a Design Doc — one per epic
---

Invoke the planning-2-functional-spec-generator skill.

Look for the source document in this order:
1. `docs/inputs/` in the current repo (preferred)
2. A file the user uploaded or referenced in the conversation
3. Ask the user for a path if nothing is found

The output is always in Spanish. Ask the user which epic this spec covers if not already specified.

Generate the complete Spec Funcional document covering: context, actors, functional flows (step-by-step), business rules, edge cases, acceptance criteria, integrations, and open questions.

This document is intended for Lark Wiki — present it for the user to copy or export. Do not write it to the repo.
