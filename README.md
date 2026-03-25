# Avila Tek Planning Skills

**AI-assisted planning skills that create shared context across planning and development.**

A set of skills for Claude Code that encode the end-to-end planning process — from first discovery to a repo ready for engineers to execute. Every artifact has a defined home, every step has a clear owner, and every collaborator (PM, lead, developer) works from the same source of truth.

---

## The Problem This Solves

Planning knowledge lives in people's heads, scattered docs, and lost Slack threads. By the time development starts, the context has degraded — engineers lack the "why", PMs lack traceability, and teams waste cycles re-aligning. These skills fix that by producing structured, AI-assisted artifacts that persist in the repo and in Lark, keeping the full team in sync from day one.

---

## The Planning Process

> **Note:** "TDD" in this project means **Technical Design Document** — not Test-Driven Development.

The process has two parallel tracks that converge at the epic level:

```
┌─────────────────────────────────────────────────────────────────┐
│                        INPUT                                    │
│              Design Doc (written manually by team)              │
│                    Lives in: Lark Wiki                          │
└────────────────────┬───────────────────┬────────────────────────┘
                     │                   │
          ┌──────────▼──────┐   ┌────────▼───────────┐
          │  Project Context │   │  Spec Funcional    │
          │   (iterative)    │   │  (per epic,        │
          │  skill-0 ✅      │   │   optional but     │
          │  Lives in: repo  │   │   recommended)     │
          │  docs/           │   │  skill-1 ✅        │
          │  project_context │   │  Lives in:         │
          │  .md             │   │  Lark Wiki         │
          └──────────────────┘   └────────┬───────────┘
                                          │         │
                                 ┌────────▼───────┐ │ ┌──────────────────────┐
                                 │      Epic      │ └─► TDD (optional)       │
                                 │  skill-3 🚧    │   │  skill-2 🚧           │
                                 │  Lives in: repo│ ◄─┤  Enriches epics with  │
                                 │  docs/epics/   │   │  technical details    │
                                 │  E-XXX_name/   │   │  if available         │
                                 │  epic.md       │   └──────────────────────┘
                                 └────────┬───────┘
                                          │
                                 ┌────────▼───────────┐
                                 │     Stories (HUs)  │
                                 │  skill-4 ✅        │
                                 │  Lives in: repo    │
                                 │  docs/epics/       │
                                 │  E-XXX_name/       │
                                 │  stories/          │
                                 └────────┬───────────┘
                                          │
                                 ┌────────▼───────────┐
                                 │   Lark Base Sync   │
                                 │  skill-5 ✅        │
                                 │  Pushes epics +    │
                                 │  stories to the    │
                                 │  project Base      │
                                 └────────────────────┘
```

---

## Artifact Map

| Artifact | Who creates it | Tool | Where it lives |
|---|---|---|---|
| Design Doc | PM / Tech Lead — manually | — | Lark Wiki |
| Project Context | AI-assisted | skill-0 | `docs/project_context.md` (repo) |
| Spec Funcional | AI-assisted | skill-1 | Lark Wiki |
| TDD (Technical Design Document) | AI-assisted | skill-2 | `docs/` (repo) or download (.docx/.md) |
| Epic (`epic.md`) | AI-assisted | skill-3 ✅ | `docs/epics/E-XXX_name/epic.md` (repo) |
| Stories | AI-assisted | skill-4 | `docs/epics/E-XXX_name/stories/` (repo) |
| Lark Base records | Automated | skill-5 | Lark Base |

---

## Repository Structure

All planning artifacts that live in the repo follow this layout:

```
docs/
├── inputs/                     ← Source documents (Design Docs, Intake Briefs) — see below
│   ├── design_doc.pdf          ← Download from Lark Wiki and place here
│   └── intake_brief.docx       ← Or any other input document
├── project_context.md          ← Master context (single source of truth)
├── epics/
│   ├── E-000_tech_platform/
│   │   ├── epic.md
│   │   └── stories/
│   │       ├── E-000_S-001_monorepo_bootstrap.md
│   │       └── E-000_S-002_app_scaffolding.md
│   ├── E-001_public_home/
│   │   ├── epic.md
│   │   └── stories/
│   └── E-XXX_slug/
│       ├── epic.md
│       └── stories/
├── plans/                      ← Implementation plans — written by devs per story (after spec)
├── specs/                      ← Technical specs — written by devs per story (before plan)
└── adrs/                       ← Architecture Decision Records
```

**`docs/specs/` and `docs/plans/`** are created by developers when working on each story — not by the planning skills. The per-story flow is:

1. **Technical spec** (`docs/specs/`) — the dev analyzes the story, documents the technical approach, dependencies, and design decisions.
2. **Implementation plan** (`docs/plans/`) — once the spec is approved, the dev details the concrete implementation steps.

These artifacts are owned by the development team and are elaborated during sprint execution.

---

## Skills Reference

### skill-0 — Project Context Generator ✅

Generates or updates `docs/project_context.md` from a Design Doc or Intake Brief.

This is the **canonical shared context** for the entire project — the single document that all derived artifacts reference. It captures the WHY, WHAT, glossary, business rules, scope, and constraints in a stable, structured format that both humans and AI agents can rely on.

- **Input:** Design Doc (PDF/DOCX/MD) or Intake Brief
- **Output:** `docs/project_context.md`
- **Cadence:** Created once, updated iteratively as the project evolves
- **Trigger phrases:** "generate project context", "update the project context", "create master context"

### skill-1 — Functional Spec Generator ✅

Generates a complete Spec Funcional from a Design Doc for a specific epic.

The Spec Funcional is the bridge between the Design Doc and the engineering backlog. It documents flows step by step, business rules, integrations, edge cases, acceptance criteria, and open questions — giving the team a shared reference before stories are written.

- **Input:** Design Doc + epic name
- **Output:** Spec Funcional document (DOCX or MD)
- **Cadence:** One per epic, generated before creating the epic.md
- **Where it lives:** Lark Wiki (under Design Docs)
- **Trigger phrases:** "generate the spec for this epic", "create a functional spec", "spec funcional"

### skill-2 — Technical Design Document (TDD) ✅

Generates a comprehensive **Technical Design Document** from a brief requirement description or uploaded file.

The TDD is the technical blueprint for a feature or product. It documents the problem, solution architecture, specific flows (E-XXX), component diagram, data model, API design, security considerations, and all Mermaid diagrams — giving engineers everything they need to understand, review, and implement the solution. Once complete, the TDD feeds directly into the epic generator (skill-3).

- **Input:** Requirement description (text), or uploaded file (PDF/DOCX/MD)
- **Output:** `tdd_<feature_name>.docx` (default) or `.md`
- **Sections:** Problem, Scope, Business Rules, Specific Flows (E-XXX), Component Architecture, Data Model, API Design, Security, Integrations
- **Trigger phrases:** "generate a technical design", "write a design doc", "create a TDD", "genera el diseño técnico"

### skill-3 — Epic Generator ✅

Generates individual Epic documents from a Spec Funcional (primary). TDD enriches epics with technical details if available.

- **Input:** Spec Funcional (required) + TDD (optional, enriches technical detail)
- **Output:** `docs/epics/E-XXX_slug/epic.md`
- **Trigger phrases:** "generate epics", "genera las épicas", "break this spec into epics"

### skill-4 — Story Generator ✅

Generates all user stories (HUs) for an epic from its `epic.md`. Before generating, the skill resolves open questions with the operator — the final document contains no ambiguities.

Each story has two blocks:
- **Block A** — user story, acceptance criteria, and effort ranking (Must / Important / Optional / Nice to have). Sufficient for estimation.
- **Block B** — technical scope, business rules, data model, telemetry, and testing notes. Omitted if not applicable.

- **Input:** `epic.md`
- **Output:** `docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug.md` (one file per story)
- **Trigger phrases:** "generate stories for E-XXX", "write the stories for this epic"

### skill-5 — Lark Base Sync ✅

Reads epic and story `.md` files from the repo, translates content to Spanish, and pushes them to the Lark Base via the Avila Tools API.

Supports upsert — existing records are updated, new records are created. Requires: Epic IDs, API Key, and Base ID.

- **Input:** Epic IDs (e.g. `E-002 E-003`), API Key, Base ID
- **Output:** Epics and stories synced to Lark Base
- **Trigger phrases:** "sync to Lark", "push epic to Lark", "sincroniza el backlog"

---

## Placing Input Documents

Before running any skill, download the source documents from Lark Wiki and place them in `docs/inputs/` inside your project repository.

```
your-project/
└── docs/
    └── inputs/
        ├── design_doc.pdf        ← Design Doc exported from Lark Wiki
        └── intake_brief.docx     ← Or an Intake Brief, if that's your starting point
```

**How to do it:**

1. Open the Design Doc in Lark Wiki
2. Export it as PDF or DOCX (top-right menu → Export)
3. Create the folder `docs/inputs/` in your project repo if it doesn't exist
4. Move the downloaded file into `docs/inputs/`
5. Commit the file (optional but recommended so the whole team has the source)

When you run a skill, point it to the file:

> "Generate the project context from `docs/inputs/design_doc.pdf`"

Skills also accept files dragged into the Claude Code chat window — but placing them in `docs/inputs/` keeps a persistent record and lets the whole team run skills without re-uploading.

---

## Step-by-Step Workflow

### 1. Write the Design Doc (manual)

The PM or Tech Lead writes the Design Doc in Lark Wiki. This is the primary source of truth for the product. It covers product vision, flows, integrations, security constraints, and the full epic list.

No skill yet — this step is manual.

### 2. Generate the Project Context

Place the Design Doc in `docs/inputs/` (see [Placing Input Documents](#placing-input-documents)), then open Claude Code in the project repository and run:

> "Generate the project context from `docs/inputs/design_doc.pdf`"

The skill will ask clarifying questions, then write `docs/project_context.md`. This document is referenced by all downstream artifacts — keep it updated as the project evolves.

### 3. Generate Spec Funcionales (per epic)

For each epic you are about to plan:

> "Generate a functional spec for the [epic name] epic from `docs/inputs/design_doc.pdf`"

The skill produces a structured Spec Funcional and saves it as a DOCX. Upload it to Lark Wiki under the project's Design Docs space. This is optional but strongly recommended — it surfaces ambiguities before stories are written.

### 4. Generate the Technical Design Document (TDD) (optional)

> "Generate a technical design from `docs/inputs/design_doc.pdf`"

Applies to projects with high technical complexity. Can be skipped if the Spec Funcional provides enough detail for the team to proceed.

The skill asks a few clarifying questions, then produces a TDD with the full solution architecture: specific flows (E-XXX), component diagram, data model, API endpoints, security considerations, and Mermaid diagrams. Output is a `.docx` by default.

### 5. Generate the Epics

> "Generate epics from the Spec Funcional"

The skill reads the Spec Funcional, lists the epics it found (E-001, E-002, ...), and asks which ones to generate. Each epic becomes a `docs/epics/E-XXX_slug/epic.md`. If the TDD is available, the skill uses it automatically to enrich the epics with technical details.

### 6. Generate Stories

> "Generate stories for E-XXX from the epic"

The skill reads the `epic.md`, resolves any ambiguities with the operator before generating, then creates one `.md` file per story under `docs/epics/E-XXX_slug/stories/`. Block A (user story + AC + effort ranking) is sufficient for estimation — developers can read Block B for technical detail when implementing.

### 8. Sync to Lark Base

Once epics and stories are committed to the repo:

> "Sync E-002 E-003 to Lark" (+ provide API Key and Base ID when prompted)

The skill reads the `.md` files, translates content to Spanish, and pushes everything to the Lark Base. Run this after any update to keep Lark in sync with the repo.

---

## Installation

### Claude Desktop

No installation required. The skills are configured at the Avila Tek organization level and are available automatically to all team members.

To use them:

1. Open the Claude app and make sure you are logged in with your Avila Tek organization account
2. Create or open a **Project** for the product you are planning (e.g. "Zoom Emprendedores")
3. Start a conversation inside that Project and the skills will be active

That's it. You do not need to paste or configure anything.

---

### Claude Code

**Step 1 — Install Claude Code** (one time per machine)

Open your terminal and run:

```bash
npm install -g @anthropic-ai/claude-code
```

> If you see an error, download Node.js first from [nodejs.org](https://nodejs.org) and then run the command again.

**Step 2 — Copy the skills into your project**

Inside your project repository, create the folder `.claude/skills/` if it does not exist. Then copy the skill folders from this repository into it:

```
your-project/
└── .claude/
    └── skills/
        ├── 0-project-context-generator/
        │   └── SKILL.md
        ├── 1-functional-spec-generator/
        │   ├── SKILL.md
        │   └── references/
        │       └── template.md
        ├── 2-epic-generator/
        │   └── SKILL.md
        ├── 3-story-generator/
        │   └── SKILL.md
        └── 4-write-epics-and-hu-in-base/
            └── SKILL.md
```

You can do this in Finder (Mac) or Explorer (Windows) — copy the `skills/` folder from this repository and paste it inside the `.claude/` folder of your project. Commit this folder to the repo so the whole team gets the skills when they clone the project.

**Step 3 — Open Claude Code inside your project**

```bash
cd your-project
claude
```

Claude Code starts and detects the skills automatically. No further setup needed.

---

## Lark Setup

The sync skill requires access to the Avila Tools API:

| Input | Description |
|---|---|
| API Key | Bearer token (`sk-xxxx...`) — obtain from the project lead |
| Base ID | Target Lark Base identifier — found in the Base URL |

The endpoint used is `https://your-api.example.com/your/full/path`.

---

## Design Principles

**Artifacts have one home.** Project context lives in the repo. Specs and the Design Doc live in Lark Wiki. Backlog records live in Lark Base. No duplication, no ambiguity about which version is current.

**The repo is the execution layer.** When development starts, everything needed is already in `docs/` — epics with scope and acceptance criteria, stories with dependencies and t-shirt sizing, a project context with business rules and glossary. Engineers don't need to chase context across wikis.

**Planning is iterative.** The project context is updated as decisions are made. Stories are refined before they are scheduled. The Lark Base reflects the repo — sync is one command.

**AI assists, humans decide.** Skills ask questions before generating. They flag gaps and open questions. They never invent business rules. The final content is always reviewed and committed by the team.
