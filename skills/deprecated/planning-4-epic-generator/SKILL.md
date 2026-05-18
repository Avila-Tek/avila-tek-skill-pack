---
name: epic-doc-generator
description: >
  Generates individual Epic documents from a Spec Funcional and optionally a TDD. Use this skill
  whenever the user wants to generate epics, break down a feature into epics, "genera las épicas",
  "crea los documentos de épica", "break this spec into epics", "generate epic docs from the design",
  or has just finished a Spec Funcional or TDD and wants to continue into epic generation.
  Outputs .md by default, .docx on request.
---

# Epic Document Generator

Generates individual **Epic documents** from a **Spec Funcional** (primary source) and an optional **TDD**. Each epic becomes a standalone document for sprint planning and backlog management.

**Audience**: Engineering teams, product managers, tech leads.
**Output format**: `.md` by default; `.docx` if requested.
**Language**: All generated epic documents must be in English.

> **Note:** "TDD" in this project means **Technical Design Document**, not Test-Driven Development.

---

## Step 1 — Read Context Documents (mandatory)

Before extracting any epics, read ALL available context in this order:

**1. `docs/project_context.md`** (required if it exists)
```bash
cat docs/project_context.md
```

**2. Spec Funcional** (primary source — required)

PDF:
```python
from pypdf import PdfReader
r = PdfReader("/mnt/user-data/uploads/<file>")
text = "\n".join(page.extract_text() for page in r.pages)
print(text)
```
DOCX: `pandoc /mnt/user-data/uploads/<file>.docx -t markdown`
MD/TXT: `cat /mnt/user-data/uploads/<file>`

If the Spec Funcional was generated in this session, use the content already in context.

**3. TDD** (optional — read if available, same methods above)

If no Spec Funcional is found, ask the user to provide one or offer to generate it first.

---

## Step 2 — Extract Epics

Parse section 5 "Definición de Flujos" of the Spec Funcional. For each flow/epic extract:
- **Epic ID**: assign sequentially (E-001, E-002, ...) or use existing E-XXX identifiers
- **Title**: the flow name
- **Objective**: the purpose of this flow
- **User type**: who interacts with this flow
- **Steps**: the step-by-step process
- **Business Rules**: any BR-XX rules referenced

If only a TDD is available (no Spec Funcional), extract from TDD section 5.3 as fallback.

> **Epic-level technical notes (architecture, data model, API changes, risks) are documented in the TDD — do not include them in epic documents.**

---

## Step 3 — Confirm Epics with User

Present the identified epics:

> I found N epics in the Spec Funcional:
> - E-001 — [Title]
> - E-002 — [Title]
>
> Generate all, or specific ones?

---

## Step 4 — Generate Each Epic Document

Read the template before generating:
```bash
cat /mnt/skills/user/epic-doc-generator/references/template.md
```

### Content Principles

- **Derive, don't invent.** Every field traces back to the source documents. Use `[TO BE DEFINED]` for gaps.
- **Be specific.** "The system works correctly" is not an acceptance criterion.
- **Stay compact.** Target 150–200 lines per epic document.
- **Stories are summaries.** Detail goes in skill-4 (story generator). Each story: title + user statement + max 3 ACs.
- **KPIs must be measurable.** Tie each metric to a real data source.

### Structure

Each epic document has exactly these sections:

- **0) References** — Dependencies and Related Docs only (no Status, no Owner)
- **1) Objective** — one paragraph, business outcome for non-technical readers
- **2) Scope** — in scope / out of scope / assumptions
- **3) Happy Path** — ASCII flow, max 8 steps, no Mermaid diagrams
- **4) KPIs & Measurement** — Product Metrics (max 3) + Logs/Events to Persist (max 5)
- **5) User Stories** — 3–8 stories, each with user statement + max 3 ACs, no technical notes per story

### Epic Numbering

- Epic ID: use E-XXX from the source. If not present, assign sequentially.
- Story IDs: `HU-<epic_number>.<story_number>` — e.g., HU-001.01, HU-001.02

---

## Step 5 — Output Files

```
docs/epics/E-001_<snake_case_title>/epic.md
docs/epics/E-002_<snake_case_title>/epic.md
```

For `.docx` output, read `/mnt/skills/public/docx/SKILL.md` first.

---

## Step 6 — Present and Offer Iteration

1. Call `present_files` with all generated paths.
2. Summary: number of epics, total user stories.
3. Per epic: ID, title, story count.
4. Offer refinement: "Would you like to adjust any epic or refine the acceptance criteria?"

---

## Quality Checklist

Before delivering each epic, verify:

- [ ] Sections present: 0, 1, 2, 3, 4, 5 (no section 6)
- [ ] No Status or Owner fields in section 0
- [ ] No Mermaid diagrams — ASCII flow only
- [ ] Product Metrics ≤ 3 and each has a measurable target + source
- [ ] Log/Events ≤ 5
- [ ] Each story has user statement (As a / I want / So that) + max 3 ACs
- [ ] No Technical Notes, telemetry, or dependencies inside individual stories
- [ ] 3–8 stories per epic
- [ ] No invented content — `[TO BE DEFINED]` for gaps
- [ ] Document fits ~150–200 lines
