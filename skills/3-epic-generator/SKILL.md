---
name: epic-doc-generator
description: >
  Generates individual Epic documents from a Technical Design Document (TDD). Each epic gets its
  own structured document with objective, scope, workflow, KPIs, user stories, acceptance criteria,
  and technical notes. Use this skill whenever the user wants to generate epics from a TDD, break
  down a design doc into epics, create epic documents, "genera las épicas", "crea los documentos
  de épica", "break this TDD into epics", "generate epic docs from the design", or asks to produce
  backlog-ready epic files. Also trigger when the user has just finished a TDD (via the
  technical-design-doc skill) and wants to continue into epic generation. Supports both uploaded
  TDD files (PDF, DOCX, MD) and chaining from a TDD generated in the same session. Outputs .md
  by default, .docx on request. If someone mentions "epic document", "epic breakdown", or
  "épica" in the context of a design doc, use this skill.
---

# Epic Document Generator

Generates individual **Epic documents** from a Technical Design Document (TDD). Each epic
identified in the TDD's section 5.3 (Specific Flows / Epics) becomes a standalone document
that an engineering team can use for sprint planning, backlog management, and implementation.

**Audience**: Engineering teams, product managers, tech leads, scrum masters.
**Output format**: `.md` by default; `.docx` if the user requests it.
**Language**: Match the language of the input TDD. If Spanish, write in Spanish. If English,
write in English.

---

## Step 1 — Obtain the TDD Content

The TDD can arrive in two ways. Determine which applies:

### A) Chained from the same session

If a TDD was just generated (via the `technical-design-doc` skill or manually) in this
conversation, the content is already available. Look for the TDD output file:

```bash
# Check if a TDD was already generated in this session
ls /mnt/user-data/outputs/tdd_*
```

If found, read it:
```bash
cat /mnt/user-data/outputs/tdd_*.md
# or for docx:
pandoc /mnt/user-data/outputs/tdd_*.docx -t markdown
```

### B) Uploaded file

Read the uploaded TDD file using the appropriate method:

**PDF:**
```python
from pypdf import PdfReader
r = PdfReader("/mnt/user-data/uploads/<file>")
text = "\n".join(page.extract_text() for page in r.pages)
print(text)
```

**DOCX:**
```bash
pandoc /mnt/user-data/uploads/<file>.docx -t markdown
```

**MD / TXT:**
```bash
cat /mnt/user-data/uploads/<file>
```

### C) No TDD available

If no TDD is found and the user hasn't uploaded one, explain that this skill needs a TDD as
input and offer two paths:
1. "Upload a Technical Design Document and I'll generate the epics from it."
2. "Describe your feature and I can generate the TDD first, then break it into epics."

---

## Step 2 — Extract Epics from the TDD

Parse the TDD and extract the following for each epic found in section 5.3:

For each epic (E-001, E-002, ...):
- **Epic ID**: the `E-XXX` identifier
- **Title**: the flow/epic name
- **Flow Objective**: from the TDD
- **User Type**: who interacts with this flow
- **Participating Systems**: services, databases, external APIs involved
- **Business Rules**: the BR-XX rules that apply (from TDD section 5.1)
- **Flow Description**: the step-by-step process
- **Diagrams**: any Mermaid diagrams associated with this flow

Also extract global context that applies to all epics:
- **Problem statement** (TDD section 1)
- **Glossary** (TDD section 2, if present)
- **Global scope** (TDD section 3)
- **Component architecture** (TDD section 5.4)
- **Data model** (TDD section 5.5, if present)
- **API design** (TDD section 5.6, if present)
- **Security considerations** (TDD section 5.8, if present)

If the TDD doesn't use E-XXX identifiers, assign them sequentially based on the order of
flows in section 5.3 (first flow → E-001, second → E-002, etc.).

---

## Step 3 — Ask the User Which Epics to Generate

Present the list of identified epics:

> I found N epics in the TDD:
> - E-001 — [Title]
> - E-002 — [Title]
> - E-003 — [Title]
>
> Should I generate documents for all of them, or specific ones?

If the user says "all", generate all. If they name specific ones, generate only those.

---

## Step 4 — Generate Each Epic Document

For each selected epic, produce a document following the canonical template. Read the full
template with guidance before generating:

```bash
cat /mnt/skills/user/epic-doc-generator/references/template.md
```

The template has these sections:

- **0) Snapshot** — status, owner, dependencies, related docs
- **1) Objective** — business outcome in one paragraph
- **2) Scope** — in scope, out of scope, assumptions
- **3) Epic Overview** — plain-language summary + primary happy-path workflow
- **4) KPIs and Measurement** — primary KPI, supporting events, business rules, constraints
- **5) User Stories** — individual HUs with acceptance criteria and technical notes
- **6) Technical Notes** — architecture decisions, data model impact, API changes, risks

### Content Principles

- **Derive, don't invent.** Every piece of content must trace back to the TDD. If the TDD
  says the reconciliation flow has 3 steps, the epic doc describes those 3 steps — not 5.
  Use `[TO BE DEFINED]` for anything the TDD doesn't cover.
- **Be specific about acceptance criteria.** "The system works correctly" is not an acceptance
  criterion. "Given a matched transaction, the status field reads 'reconciled' and no alert
  is sent" is.
- **User stories should be implementable.** Each story should be small enough for one
  developer to complete in 1-3 days. If a story feels like it takes a week, split it.
- **KPIs must be measurable.** Don't write "improve user experience" — write
  "reconciliation completion rate >= 95% within first month."
- **Cross-reference the TDD.** Reference BR-XX business rules, component names, and API
  endpoints from the TDD so readers can trace decisions back to the design.

### Epic Numbering and Versioning

- Epic ID: Use the E-XXX from the TDD. If the TDD doesn't have them, assign sequentially.
- Version: Start at v1.0 for newly generated documents.
- User story IDs within an epic: Use `HU-<epic_number>.<story_number>` format
  (e.g., HU-001.01, HU-001.02 for stories in E-001).

---

## Step 5 — Produce the Output Files

### Markdown output (default)

Create one file per epic:
```
/mnt/user-data/outputs/epic_E-001_<snake_case_title>.md
/mnt/user-data/outputs/epic_E-002_<snake_case_title>.md
...
```

### DOCX output (on request)

Read `/mnt/skills/public/docx/SKILL.md` before generating.

Key formatting:
- **Title** (large, bold): `Epic E-XXX — [Title] (v1.0)`
- **Section headers**: numbered per the template (0, 1, 2, 3, 4, 5, 6)
- **User story cards**: each story as a bordered section or table
- **Mermaid code blocks**: monospace font, light gray background
- **Page size**: A4/Letter based on locale

Output to:
```
/mnt/user-data/outputs/epic_E-001_<snake_case_title>.docx
/mnt/user-data/outputs/epic_E-002_<snake_case_title>.docx
...
```

---

## Step 6 — Present and Offer Iteration

1. Call `present_files` with all generated epic file paths.
2. Brief summary: number of epics generated, total user stories across all epics.
3. For each epic, list: Epic ID, title, and number of user stories.
4. Offer: "Would you like to adjust any epic, add more stories, or refine the acceptance
   criteria?"

---

## Quality Checklist

Before delivering each epic, verify:

- [ ] All 7 sections (0-6) are present
- [ ] Epic ID matches the TDD's E-XXX identifier
- [ ] Objective traces back to the TDD's flow objective
- [ ] Scope is consistent with the TDD's global scope (not contradictory)
- [ ] At least one KPI with a measurable target
- [ ] Each user story has: ID (HU-XXX.YY), title, description (As a... I want... So that...),
      acceptance criteria (Given/When/Then), and technical notes
- [ ] Business rules reference BR-XX from the TDD
- [ ] Missing information uses `[TO BE DEFINED]` — never invented
- [ ] Language matches the TDD
