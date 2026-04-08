---
name: domain-model-generator
description: Generate or update the Domain Model (docs/domain_model.md) from project context and interactive Q&A
---

Invoke the planning-1-domain-model-generator skill.

Read the following files first (if they exist):
1. `docs/project_context.md` — extract Domain Glossary and Business Rules as vocabulary base
2. `docs/domain_model.md` — previous version if updating

If `docs/domain_model.md` exists, run in Update mode — append new entries to the Change Log and Schema Evolution Log without rewriting history. If it does not exist, run in Create mode.

Ask high-value questions one at a time about entities, states, invariants, relationships, domain events, and workflows. Use exact terms from the Domain Glossary — no synonyms. Never invent facts; record gaps as [PENDING].

Confirm with the user before generating. Write the output to `docs/domain_model.md`.
