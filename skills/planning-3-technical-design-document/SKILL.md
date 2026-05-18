---
name: technical-design-document
description: >
  Generates a Technical Design Document (TDD) from a Spec Funcional and domain document.
  Use whenever the user wants to create a technical design doc, TDD, design doc, architecture doc,
  "diseño técnico", or "documento de diseño". Trigger phrases: "generate a technical design",
  "write a design doc", "create a TDD", "document the technical solution", "genera el diseño
  técnico", "crea el TDD". Requires a Spec Funcional as input — do not generate a TDD without one.
  Covers: problem statement, solution with ASCII flows and diagrams, component architecture,
  data model, API design, security, and integrations. NOT a functional spec — use skill-1 instead.
  Spanish triggers: "genera el documento de diseño", "documenta la solución técnica".
---

# Technical Design Document Generator

Generates a focused **Technical Design Document (TDD)** from a Spec Funcional and domain document.
The TDD owns architecture, data model, APIs, security, and integrations — not functional flows or
scope (those live in the Spec and Epics).

**Audience**: Engineering teams, architects, tech leads.
**Output format**: `.docx` by default; `.md` if requested.
**Language**: Always English.

---

## Phase 0 — Orient & Surface Technical Decisions

### Step 0a — Workflow position

Ask once:

> "Are you creating the TDD **before** the epics (architecture-first) or **after** (epics already exist)?"

- **TDD first**: Section 4.3 uses proposed Epic IDs derived from the Spec.
- **TDD after epics**: read existing `docs/epics/` folders to populate section 4.3 accurately.

### Step 0b — Resolve Epic ID

If "TDD first":
- Check if `docs/epics/` has any existing folders.
- If yes: list them and ask which epic this TDD covers (or confirm a new one).
- If no: propose an Epic ID derived from the primary flow in the Spec (e.g., `E-001_<slug>`). Show the proposal and wait for confirmation before continuing.

If "TDD after epics": the Epic ID is known from the existing folder — no question needed.

### Step 0c — Load Context Documents

Read silently in this order (skip any that don't exist):

1. `docs/project_context.md`
2. `docs/domain_model.md` — **required if present**. Extract entity names, invariants, state machine terms, and DBML schema. These are the canonical terms for the entire TDD.
3. Spec Funcional — **required**. If missing, stop and ask the user to provide one.
   - PDF: extract all pages
   - DOCX: convert with pandoc
   - MD/TXT: read directly

If `docs/domain_model.md` is missing, warn once:
> "`docs/domain_model.md` not found. The TDD will use vocabulary from the Spec Funcional. Consider generating the domain model first with `/domain-model-generator`."

Then continue.

### Step 0d — Derive & Present Technical Questions

From the Spec and domain model, derive 4–8 targeted technical questions that must be resolved before committing to a design. Focus on:
- Consistency requirements for entity state transitions
- API contract decisions (sync vs async, pagination, error shape)
- Data ownership and migration strategy
- Security constraints (auth, rate limiting, PII)
- Integration boundaries (what is this system responsible for vs external)

Do NOT ask about:
- Details already answered in any loaded document
- Non-technical concerns (UX, business rules) — those belong in the Spec
- Anything you can infer unambiguously from the Spec

Present all questions as a numbered list:
> "Before designing, I have [N] technical questions. You can answer all of them or tell me which to skip — skipped ones will be marked [TO BE DEFINED]:"
>
> 1. ...

### Step 0e — Ask One at a Time

Ask each chosen question individually. Use exact terms from `docs/domain_model.md` — no generic alternatives. Wait for each response before continuing.

Once done, proceed to Step 1.

---

## Content Principles

- **Domain vocabulary first.** Use exact terms from `docs/domain_model.md` throughout — entity names, invariants, state machine terms. If domain_model.md is absent, use terms as defined in the Spec.
- **Decisions, not surveys.** Each section states what was decided and why. No "Option A vs Option B" paragraphs — those belong in the grilling session, not the TDD.
- **Dense prose.** Assume the reader is an engineer who knows the domain. No filler, no passive voice.
- **`[TO BE DEFINED]` only for genuine unknowns** — not as a placeholder for questions the grilling session already resolved.

---

## Step 1 — Verify Context

Context documents and Spec Funcional were loaded in Phase 0. If Phase 0 was skipped, load them now following the same instructions in Steps 0c.

Existing epic files from `docs/epics/` — read only if "TDD after epics" path.

---

## Step 2 — Extract Technical Context from Spec

From the Spec, identify:
- Epics (E-XXX) and systems involved
- Integration points and external services
- Non-functional requirements (performance, security, scale)

Do NOT copy functional flows — those stay in the Spec. Mark unknowns as `[TO BE DEFINED]`.

---

## Step 3 — Generate the TDD

Read the canonical template before generating:

```bash
cat /mnt/skills/user/technical-design-document/references/template.md
```

Follow the template structure exactly. All diagrams must be **ASCII only — no Mermaid**.

---

## Step 4 — Produce the Output File

**Output path:** `docs/epics/E-XXX_<slug>/tdd.md`

**The TDD relationship with epics is strictly 1:1** — one TDD per epic, one epic per TDD. If the user describes a feature that spans multiple epics, generate a separate TDD for each epic.

- **TDD after epics**: the folder already exists — write `tdd.md` there.
- **TDD first**: create the epic folder (`docs/epics/E-XXX_<slug>/`) before writing the file. The epic generator (skill-3) will add `epic.md` and `stories/` later.

### DOCX output (optional)

If the user requests `.docx`, read `/mnt/skills/public/docx/SKILL.md` before generating.

Key formatting:
- **No H1 title** — document starts with the metadata table
- **Section headers**: numbered per the template (1., 2., 3., 4., 4.1., etc.)
- **ASCII diagrams**: use monospace font, light gray background
- **Tables**: for API endpoints, data model fields
- Output to: `docs/epics/E-XXX_<slug>/tdd.docx`

---

## Step 5 — Present and Offer Iteration

1. Call `present_files` with the output path.
2. Brief summary: feature name, epics documented, key architectural decisions.
3. Offer: "Would you like to adjust any section or add detail to a specific area?"
4. After approval, offer: "Would you like me to generate individual epic documents from this TDD?" (skill-3)

---

## Quality Checklist

Before delivering, verify:

- [ ] No H1 title — document starts with the metadata table
- [ ] No scope section (in scope / out of scope)
- [ ] No Mermaid diagrams anywhere — all diagrams are ASCII
- [ ] Business rules (TR-XX) are purely technical: constraints, invariants, system rules
- [ ] No functional flow descriptions in section 4.3 (Epics)
- [ ] Glossary is a list (`- **Term**: Definition`), not a table
- [ ] Component diagram (4.4) is ASCII
- [ ] Data model section references `docs/domain_model.md` for entity definitions, invariants, and DBML schema
- [ ] Missing information uses `[TO BE DEFINED]` — never invented
- [ ] All terms match `docs/domain_model.md` vocabulary (or Spec if domain model absent)
- [ ] No "Option A vs B" survey paragraphs — each section states the decision made
- [ ] No `[TO BE DEFINED]` for items resolved in Phase 0 grilling
- [ ] Document is ≤ 500 lines
- [ ] Language is English
- [ ] File written to `docs/epics/E-XXX_<slug>/tdd.md` (not to `docs/` root or outputs folder)
- [ ] One TDD per epic — if feature spans multiple epics, each epic has its own TDD
