---
name: domain-model-generator
description: >
  Generates and iterates the domain model document (docs/domain_model.md) for a project.
  Use when the user says: "generate the domain model", "create the domain model",
  "domain model", "update the domain model", "model the domain of [feature]",
  "genera el domain model", "modelo de dominio",
  or any variation requesting a domain model, entity model, or data model document.
---

# Domain Model Generator

## Purpose

Generate or iterate `docs/domain_model.md` — a project-level living document that captures domain entities, invariants, domain events, workflows, and the DB schema (DBML). This artifact lives at the same level as `project_context.md`.

**When to run:**
- **Recommended:** right after generating the project context, before specs, TDDs, and epics — so all downstream artifacts share a consistent vocabulary and data model from the start.
- **Also valid:** later in the process, or on a second pass, if the domain was not well understood at the start.
- **Re-run anytime:** after a Spec Funcional, TDD, or epic generation reveals new entities, invariants, or business rules that are not yet captured.

Each run is additive — new content is appended to the change log and schema evolution log; history is never rewritten.

**This skill does NOT generate application code.** It produces a structured document for humans and AI assistants to reason about the domain.

---

## Step 1 — Detect mode

- If `docs/domain_model.md` **exists** → **Update mode**: iterate the existing document.
- If `docs/domain_model.md` **does not exist** → **Create mode**: new document starting from scratch.

---

## Step 2 — Gather inputs

Read the following files (if they exist):

1. `docs/project_context.md` — extract **Domain Glossary** and **Business Rules** sections as the base vocabulary.
2. `docs/domain_model.md` — previous version (Update mode only).
3. Any epic or flow file the user explicitly mentions.

---

## Step 3 — Interactive exploration (one question at a time)

Ask high-value questions **one at a time**. Use exact terms from the Domain Glossary — no synonyms.

Cover the following areas (not all questions are required — stop when enough information is gathered):

- **Entities:** What are the main business objects?
- **Attributes:** What are the core attributes of each entity?
- **State/lifecycle:** Does this entity have states? What triggers transitions?
- **Invariants:** What rules must always hold (e.g., an Order must have at least one item)?
- **Relationships:** How do entities relate? What are the cardinalities?
- **Domain events:** What significant things happen in the system? What do they trigger?
- **Workflows:** Walk me through the happy path. What are the edge cases?

Rules:
- Never invent facts. If something is unknown, record it as an Open Question in the document.
- When enough information is gathered, confirm: "Ready for me to draft/update Domain Model v{N}?"

---

## Step 4 — Generate document

Only after user confirmation. Use the canonical template below exactly.

- Output language: **English**.
- Vocabulary: Use Domain Glossary terms — no synonyms.
- Gaps: Use `[PENDING: <description>]` — never invent values or rules.

---

## Step 5 — Write file

Write output to `docs/domain_model.md` in the target project repo.

- **Create mode:** Write the full document.
- **Update mode:** Append new entries to Change Log and Schema Evolution Log — never rewrite history.

---

## Canonical template

```markdown
# Domain Model & Data Model — <Project Name> (v<version>)

> **Purpose:** Living source of truth for domain concepts + how they map to the system's data model.
> **Audience:** Humans + AI assistants.
> **Rule:** Uses the **Domain Glossary** from `/docs/project_context.md` as the vocabulary contract.
> **Update rule:** Append changes to logs; don't rewrite history without recording it.

---

## 0) How to read and use this document

### What this model represents
- **Domain Model:** The business concepts (entities, states, rules) independent of implementation.
- **Data Model:** The current persisted representation (database schema) that supports those concepts.
- **Relationship:** The data model is an evolving approximation of the domain model (tradeoffs allowed, must be documented).

### How it evolves
- We iterate this document whenever: a new workflow is added/changed, a business rule changes, an entity/state/event changes, the DB schema changes.

### Source links
- Master Context: `/docs/project_context.md`
- Epics: `/docs/epics/`

---

## 1) Domain Glossary alignment
- Glossary source: `/docs/project_context.md#2-domain-glossary`
- Terms used heavily in this doc: <list terms>

---

## 2) Domain entities (conceptual)

### Entity: <EntityName>
**Description:** <what it is in business terms>

**Core attributes:**
- `<attr>`: <meaning>

**State / lifecycle (if applicable):**
- States: `<STATE_A>`, `<STATE_B>`, ...
- Valid transitions:
  - `<STATE_A>` → `<STATE_B>` when `<condition>`

**Invariants (must always hold):**
- INV-1: <rule>

**Relationships:**
- `<EntityName>` 1..N `<OtherEntity>` because <why>

---

## 3) Domain events (if applicable)

- **Event: `<EventName>`**
  - Trigger: <what causes it>
  - Payload (conceptual): <fields>
  - Consumers (conceptual): <who cares>

---

## 4) Main workflows

### Workflow: <Name> (happy path)
1. <Step>
2. <Step>

### Edge cases
- <Case>: <handling>

---

## 5) DB Schema (DBML — dbdiagram.io compatible)

\`\`\`dbml
Table <table_name> {
  id uuid [pk]
  <field> <type> [note: "<meaning>"]
}

Ref: <table_a.field> > <table_b.field>
\`\`\`

### Schema evolution notes
- v0.1: <what was added/changed and why>

---

## Change Log (append-only)
| Version | Date | Author | Summary |
|---|---|---|---|
| v0.1 | <date> | <author> | Initial draft |

## Schema Evolution Log (append-only)
| Version | Migration | Reason |
|---|---|---|
| v0.1 | Initial schema | - |
```

---

## No-invention rule

- All content must come from `docs/project_context.md`, existing domain model, or direct user answers.
- If a fact is unknown: use `[PENDING: <description>]`.
- Never use general knowledge to fill in entities, rules, or relationships.

---

## Cross-references

- Vocabulary source: `docs/project_context.md` (Domain Glossary + Business Rules)
- Consumers of this artifact: skill-4 (epic-generator), skill-5 (story-generator), skill-3 (technical-design-document)
