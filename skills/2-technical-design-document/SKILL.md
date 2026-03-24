---
name: technical-design-document
description: >
  Generates a Technical Design Document (TDD) from a brief requirement description provided by a
  PM, Staff Engineer, or Tech Lead. Use whenever the user wants to create a technical design doc,
  TDD, design doc, architecture doc, "diseño técnico", or "documento de diseño". Trigger phrases:
  "generate a technical design", "write a design doc", "create a TDD", "document the technical
  solution", "genera el diseño técnico", "crea el TDD". Also trigger when a file (PDF, DOCX, MD)
  with requirements is uploaded and a technical design is requested. Covers: problem statement,
  scope, solution with flows and diagrams, component architecture, data model, API design, security,
  and integrations. NOT a functional spec or PRD — use those skills instead. If someone says
  "design doc" or "technical design" even casually, use this skill.
---

# Technical Design Document Generator

Generates a comprehensive **Technical Design Document (TDD)** from a brief requirement description.
The input comes from a Product Manager, Staff Engineer, or Tech Lead who describes a new feature
or product. The output is a structured document that an engineering team can use to understand,
review, and implement the solution.

**Audience**: Engineering teams, architects, tech leads, and technical stakeholders.
**Output format**: `.docx` by default; `.md` if the user requests it.
**Language**: Match the language of the input. If the input is in Spanish, write in Spanish. If
English, write in English. If ambiguous, ask.

---

## Step 1 — Gather the Requirement Input

Determine how the requirement is provided:

### A) Uploaded file (PDF, DOCX, MD, TXT)

Read the uploaded file first. Use the appropriate method:

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

### B) Text provided in chat

Use the requirement description directly from the conversation.

### C) Insufficient information

If the description is too vague to produce a meaningful design (e.g., "build a login system" with
no further context), ask targeted clarifying questions. Focus on:

- What problem does this solve and for whom?
- What systems or codebases are involved (new build vs. modification)?
- Are there known constraints (tech stack, integrations, deadlines)?
- What is the expected scale or load?

Keep questions to a maximum of 4-5. The goal is to get enough context to produce a useful first
draft — the document can be refined afterward. Don't over-interrogate; a brief description from
a senior engineer often contains enough implicit context to get started.

---

## Step 2 — Analyze the Requirements

Before writing, extract and organize the following from the input:

- **Problem being solved**: the core user or business pain point
- **Actors**: end users, internal systems, third-party services
- **Existing systems**: any legacy code, databases, or services being modified
- **Distinct flows or epics**: group the work into logical units (e.g., user registration,
  payment processing, notification dispatch)
- **Business rules**: constraints, validations, policies that govern behavior
- **Integration points**: external APIs, services, or systems
- **Data entities**: key objects and their relationships
- **Non-functional requirements**: performance, security, scalability (explicit or implied)

This analysis drives the content of every section. If something is not mentioned or cannot be
reasonably inferred, mark it as `[TO BE DEFINED]` — never invent technical details.

---

## Step 3 — Generate the Technical Design Document

Populate the document using the canonical template (see next section). The template includes
inline guidance for each section, including when "(if applicable)" sections should be included
or omitted.

---

## Canonical TDD Template

The reference file at `references/template.md` contains the full template with examples and
guidance for each section. Read it before generating the document:

```bash
cat /mnt/skills/user/technical-design-document/references/template.md
```

Follow the template structure exactly (sections 1–5.9). Each section has inline guidance on
what to include and when to use `[TO BE DEFINED]`.

---

## Step 4 — Generate Diagrams

Diagrams are a core differentiator of a good TDD. Use **Mermaid syntax** for all diagrams so
they are portable, version-controllable, and renderable in most documentation tools.

### When to use which diagram type

| Situation | Diagram Type | Mermaid keyword |
|-----------|-------------|-----------------|
| How actors and systems interact over time | Sequence Diagram | `sequenceDiagram` |
| Step-by-step process with decisions | Activity/Flowchart | `flowchart TD` |
| Object lifecycle (e.g., order states) | State Diagram | `stateDiagram-v2` |
| System components and their relationships | Component Diagram | `flowchart LR` (with subgraphs) |
| Data entities and relationships | ER Diagram | `erDiagram` |

### Diagram guidelines

- Every Specific Flow (section 5.3) should have at least one diagram — typically a sequence
  diagram showing the interaction between user, frontend, backend, and external services.
- The Component Diagram (section 5.4) is always required. Use `flowchart LR` with subgraphs
  to represent services, databases, and external systems.
- The Data Model (section 5.5), when included, should have an ER diagram.
- State diagrams are valuable when an entity has a meaningful lifecycle (orders, subscriptions,
  tickets, etc.).
- Keep diagrams focused. A diagram with 15+ nodes becomes unreadable — split into multiple
  diagrams instead.

### Embedding in DOCX

When producing `.docx` output, embed Mermaid code blocks as formatted code blocks in the
document, preceded by a note: *"Render this Mermaid diagram using any compatible tool
(mermaid.live, GitHub, VS Code, etc.)."*

When producing `.md` output, use standard Mermaid fenced code blocks:
````
```mermaid
sequenceDiagram
    ...
```
````

---

## Step 5 — Produce the Output File

### DOCX output (default)

Read `/mnt/skills/public/docx/SKILL.md` before generating.

Key formatting:
- **Title** (large, bold): `Technical Design Document: [Feature/Product Name]`
- **Metadata table**: Project, Author, Date, Version, Status (Draft/Review/Approved)
- **Section headers**: numbered per the template (1., 2., 3., 4., 5., 5.1., etc.)
- **Mermaid code blocks**: use monospace font, light gray background
- **Tables**: for API endpoints, data model fields, glossary terms
- **Page size**: A4/Letter based on user locale
- Output to: `/mnt/user-data/outputs/tdd_<feature_name>.docx`

### Markdown output

Output to: `/mnt/user-data/outputs/tdd_<feature_name>.md`

---

## Step 6 — Present and Offer Iteration

1. Call `present_files` with the output path.
2. Brief summary: feature name, number of flows documented, key architectural decisions.
3. Offer: "Would you like to adjust any section or add more detail to a specific flow?"
4. After the user is satisfied, offer: "Would you like me to generate individual epic
   documents from this TDD? I can produce a detailed epic doc for each of the E-XXX flows."
   (This uses the `epic-generator` skill — skill 3.)

---

## Quality Checklist

Before delivering, verify:

- [ ] All applicable sections from the template are present
- [ ] Every Specific Flow has: Epic ID (E-XXX), Title, Objective, User Type, Participating Systems, and at least one diagram
- [ ] Epic IDs are sequential (E-001, E-002, ...) and unique
- [ ] Component Diagram (5.4) is present and shows all major system components
- [ ] Missing information uses `[TO BE DEFINED]` — never invented
- [ ] Diagrams use valid Mermaid syntax
- [ ] Business rules are numbered (BR-XX) and referenced by the flows that use them
- [ ] Scope clearly distinguishes what's in vs. out
- [ ] Language matches the input document
- [ ] The document is useful to an engineer who wasn't in the room when requirements were discussed
