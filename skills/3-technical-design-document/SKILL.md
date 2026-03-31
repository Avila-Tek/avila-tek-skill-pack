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
---

# Technical Design Document Generator

Generates a focused **Technical Design Document (TDD)** from a Spec Funcional and domain document.
The TDD owns architecture, data model, APIs, security, and integrations — not functional flows or
scope (those live in the Spec and Epics).

**Audience**: Engineering teams, architects, tech leads.
**Output format**: `.docx` by default; `.md` if requested.
**Language**: Always English.

---

## Step 0 — Clarify Workflow Position

Before doing anything, ask the tech lead:

> "Are you creating the TDD **before** the epics (architecture-first) or **after** (epics already exist)?"

- **TDD first**: Section 4.3 (Epics — Technical Summary) is generated as a draft with proposed Epic IDs. Run the epic generator (skill-3) afterward.
- **TDD after epics**: Epic IDs and titles are known — read existing epic files from `docs/epics/` to populate section 4.3 accurately.

Both paths require a Spec Funcional.

---

## Step 1 — Read Context (mandatory, in order)

1. `docs/project_context.md`
2. `docs/domain_model.md` — **required if it exists**. Use entity definitions, invariants, state lifecycles, and DBML schema from this document to inform the data model and technical rules sections.
3. Spec Funcional — **required**. If missing, stop and ask the user to provide one before continuing.
4. Existing epic files from `docs/epics/` — only if "TDD after epics" path.

**Read the Spec Funcional:**
```bash
cat /path/to/spec_funcional.md
# or for uploaded files:
pandoc /mnt/user-data/uploads/<file>.docx -t markdown
```

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
- [ ] Document is ≤ 500 lines
- [ ] Language is English
- [ ] File written to `docs/epics/E-XXX_<slug>/tdd.md` (not to `docs/` root or outputs folder)
- [ ] One TDD per epic — if feature spans multiple epics, each epic has its own TDD
