---
name: domain-model-generator
description: >
  Generates and iterates the domain model document (docs/domain_model.md) for a project.
  Use when the user says: "generate the domain model", "create the domain model",
  "domain model", "update the domain model", "model the domain of [feature]",
  "genera el domain model", "modelo de dominio",
  or any variation requesting a domain model, entity model, or data model document.
  Spanish triggers: "crea el modelo de dominio", "actualiza el modelo de dominio", "modela el dominio".
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

## Step 3 — Surface ambiguities (4–8 questions)

From `docs/project_context.md` and any provided inputs, derive 4–8 targeted questions that cannot be answered from existing documents. Focus on:

- Main tables and their primary keys
- Critical fields and their types/constraints
- Key relationships and cardinalities
- Uniqueness constraints, nullability, indexes
- Any field whose meaning is ambiguous from the name alone

Do NOT ask about:
- Domain events or workflows — only include if the user volunteers them
- Details already in `docs/project_context.md` or provided inputs
- Anything you can infer unambiguously from context

Present all questions as a numbered list before asking any:
> "Before generating, I have [N] questions. Answer all or tell me which to skip — skipped ones will be marked [PENDING]:"
>
> 1. ...

Ask each chosen question individually and wait for the response. Once done, confirm: "Ready to draft Domain Model v{N}?"

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
# Domain Model — <Project Name> (v<version>)

---

## Entities

### <EntityName>
**Description:** <what it is in business terms — one sentence>
**Table:** `<table_name>`

**Attributes:**
| Field | Type | Constraints | Description |
|---|---|---|---|
| `id` | `uuid` | PK | — |
| `<field>` | `<type>` | <NOT NULL / UNIQUE / FK / —> | <meaning> |

**Relationships:**
- `<EntityName>` 1..N `<OtherEntity>` — <why>

**State / lifecycle** *(omit if entity has no lifecycle)*
- States: `<STATE_A>`, `<STATE_B>`
- `<STATE_A>` → `<STATE_B>` when `<condition>`

**Invariants** *(omit if none)*
- INV-1: <rule>

---

## DB Schema (DBML — dbdiagram.io compatible)

\`\`\`dbml
Table <table_name> {
  id uuid [pk]
  <field> <type> [not null, note: "<meaning>"]
}

Ref: <table_a.field> > <table_b.field>
\`\`\`

---

## Schema Evolution Log (append-only)
| Version | Migration | Reason |
|---|---|---|
| v0.1 | Initial schema | — |
```

---

## No-invention rule

- All content must come from `docs/project_context.md`, existing domain model, or direct user answers.
- If a fact is unknown: use `[PENDING: <description>]`.
- Never use general knowledge to fill in entities, rules, or relationships.

---

## Cross-references

- Vocabulary source: `docs/project_context.md` (Domain Glossary + Business Rules)
- Consumers of this artifact: `planning-4-epic-and-stories-generator`, `planning-3-technical-design-document`
