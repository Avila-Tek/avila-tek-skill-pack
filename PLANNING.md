# Planning Track — Complete Guide

> **Audience:** Tech Lead / PM
> **Goal:** Produce all planning artifacts — from the Design Doc to story files ready for developers to pick up.
> **Note:** "TDD" in this project = **Technical Design Document**, never Test-Driven Development.

This document is the authoritative reference for the Planning Track. The [README](README.md) gives you the overview; read this file to understand every skill's behavior, rules, inputs, outputs, and edge cases before running the track on a real project.

---

## The Problem This Solves

Planning knowledge lives in people's heads, scattered docs, and lost Slack threads. When development starts, the context has degraded — engineers don't have the "why", PMs have no traceability, and the team wastes cycles re-aligning. This track produces structured, versioned artifacts that persist in the repo and in Lark, keeping the entire team aligned from day one.

---

## How to Invoke Planning Skills

Planning skills activate with **natural language phrases** in Claude Code. Each also has an equivalent slash command.

| Say something like... | Equivalent command |
|---|---|
| "generate the project context" | `/project-context-generator` |
| "create the domain model" | `/domain-model-generator` |
| "generate a functional spec for E-002" | `/functional-spec-generator` |
| "create a TDD" | `/technical-design-document` |
| "generate epics from the spec" | `/epic-generator` |
| "generate stories for E-002" | `/story-generator` |
| "sync E-002 E-003 to Lark" | `/write-epics-and-hu-in-base` |

---

## Full Workflow

```
┌──────────────────────────────────────────────────────────────────────┐
│  INPUT: Design Doc or Intake Brief  (written manually by the team)   │
│  Place in: docs/inputs/design_doc.pdf  or  intake_brief.docx         │
└────────────────────────┬─────────────────────────────────────────────┘
                         │
              ┌──────────▼───────────┐
              │  /project-context-   │  skill-0
              │  generator           │
              │                      │  Output: docs/project_context.md
              │  Master context.     │  WHY + WHAT + glossary + business
              │  Created once,       │  rules + scope + constraints.
              │  iterated always.    │  All downstream artifacts reference it.
              └──────────┬───────────┘
                         │
              ┌──────────▼───────────┐
              │  /domain-model-      │  skill-1                ▲
              │  generator           │                          │
              │                      │  Output: docs/           │ Re-run
              │  Living document.    │  domain_model.md         │ when new entities
              │  Run early,          │  Entities, states,       │ or rules emerge
              │  update after each   │  invariants, events,     │ from specs, TDDs,
              │  epic or TDD         │  DBML schema             │ or epics
              └──────────┬───────────┘                          │
                         │                                      │
              ┌──────────▼───────────┐                         │
              │  /functional-spec-   │  skill-2                │
              │  generator           │                          │
              │                      │  Output: Lark Wiki       │
              │  One per epic.       │  (Markdown, in Spanish)  │
              │  Bridge between      │  Step-by-step flows,     │
              │  Design Doc and      │  rules, ACs, edge cases  │
              │  the backlog.        │                          │
              └──────┬───────────────┘                         │
                     │            │                            │
           ┌─────────▼──────┐     └──────► ┌────────────────┐ │
           │  /epic-         │  skill-4     │  /technical-   │─┘
           │  generator      │              │  design-       │  skill-3
           │                 │◄─────────────│  document      │  (optional)
           │  Output:        │  TDD         │                │
           │  docs/epics/    │  enriches    │  Output:       │
           │  E-XXX_slug/    │  epics       │  docs/epics/   │
           │  epic.md        │              │  E-XXX/tdd.md  │
           └─────────┬───────┘              └────────────────┘
                     │
           ┌─────────▼────────────┐
           │  /story-generator    │  skill-5
           │                      │
           │  One folder per HU.  │  Output:
           │  The folder is the   │  docs/epics/E-XXX_slug/
           │  dev workspace.      │  stories/E-XXX_S-YYY_slug/
           │                      │  E-XXX_S-YYY_slug.md
           │  ← HANDOFF to dev →  │
           └─────────┬────────────┘
                     │
           ┌─────────▼────────────┐
           │  /write-epics-and-   │  skill-6
           │  hu-in-base          │
           │                      │  Reads .md files → translates to Spanish
           │  Keeps Lark Base     │  → POST to Avila Tools API
           │  in sync with repo   │  Requires: Epic IDs + API Key + Base ID
           │                      │  Supports upsert. Shows preview before POST.
           └──────────────────────┘
```

---

## Skills Reference

### `/project-context-generator` — skill-0

Generates or updates `docs/project_context.md` from a Design Doc or Intake Brief. This is the **master document** for the project — every downstream artifact references it for business goals, glossary, and constraints.

#### What it captures

| Section | Content |
|---|---|
| North Star | The single sentence that defines project success |
| Domain Glossary | Canonical terms — used verbatim across all artifacts |
| Business Goals | What the product achieves and why |
| Success Metrics | Measurable KPIs |
| Roles & Permissions | User types and their capabilities |
| Scope (In / Out) | What is and isn't included in this delivery |
| Business Rules | Invariants that can never be broken |
| Data Policy | Retention, privacy, regulatory constraints |
| Delivery Constraints | Deadlines, dependencies, technical limits |

#### Two modes

**Create mode** — first time on a new project:
- Reads the Design Doc or Intake Brief from `docs/inputs/`
- Asks clarifying questions one at a time (never a wall of questions)
- Waits for confirmation before generating
- Creates `docs/project_context.md`

**Update mode** — iterating an existing project:
- Reads the existing `project_context.md`
- Asks what changed and why
- Updates only the affected sections
- Appends an entry to the Change Log at the bottom
- Never rewrites history — previous versions remain visible

#### Rules

- English only, regardless of the source language
- Max 500 lines — dense, high-signal content only
- Only WHY and WHAT — never HOW. No implementation details.
- Uses `[PENDING]` for gaps, never invents business rules
- Must be confirmed by the team before other planning skills run

| | |
|---|---|
| **Input** | `docs/inputs/design_doc.pdf` or `intake_brief.docx` |
| **Output** | `docs/project_context.md` |
| **Language** | Always English |
| **Limit** | Max 500 lines |

---

### `/domain-model-generator` — skill-1

Generates or iterates `docs/domain_model.md` — the shared vocabulary of the system. Covers entities, invariants, lifecycle states, domain events, workflows, and the DBML database schema.

#### Why it matters

The domain model establishes a shared vocabulary that every engineer, PM, and designer uses. When the model is wrong or absent, different parts of the codebase use different names for the same concept — bugs follow.

#### What it documents

| Section | Content |
|---|---|
| Entity catalog | All domain entities with attributes and types |
| Invariants | Rules that can never be violated per entity |
| State machines | Lifecycle diagrams for stateful entities |
| Domain events | Events that trigger state transitions |
| Aggregates | Entities that must change together atomically |
| Workflows | Cross-entity processes (step-by-step) |
| DBML schema | Database schema anchored to domain entities |

#### Living document behavior

The domain model is **never replaced** — it grows. Each run:
- Adds new entities discovered from the current epic or spec
- Extends existing entities with new attributes or states
- Appends a Change Log entry with what changed and why

Run it:
- Right after `/project-context-generator` to establish the initial vocabulary
- After each Spec Funcional that reveals new entities
- After each TDD that defines a new data model
- Whenever a developer raises a naming inconsistency

#### Rules

- English only
- Uses exact glossary terms from `project_context.md` — no synonyms, no paraphrasing
- Never invents facts — uses `[PENDING]` for gaps
- Asks one question at a time before drafting
- Confirms before generating

| | |
|---|---|
| **Input** | `docs/project_context.md` + interactive Q&A |
| **Output** | `docs/domain_model.md` |
| **Language** | Always English |

---

### `/functional-spec-generator` — skill-2

Generates a complete Functional Spec in Spanish from a Design Doc for a specific epic. This is the bridge between the Design Doc (product vision) and the engineering backlog (execution).

#### Why Spanish

The Spec Funcional lives in Lark Wiki and is read by the entire team — including stakeholders who work primarily in Spanish. The source Design Doc may be in any language; the output is always Spanish.

#### What it documents

| Section | Content |
|---|---|
| Actors | Who uses this feature and in what role |
| Step-by-step flows | Main flow + alternative flows |
| Business rules | Numbered list — referenced in stories |
| Integrations | External systems and contracts |
| Edge cases | What happens when things go wrong |
| Acceptance criteria | Measurable conditions for completion |
| Open questions | Unresolved items with owner and due date |

#### Process

1. Reads the Design Doc and `docs/project_context.md`
2. Asks clarifying questions about the target epic
3. Generates the Spec Funcional in Markdown
4. Presents the output for the user to copy/export to Lark Wiki

**Important:** This artifact lives in Lark Wiki, not in the repo. The skill presents the output but does not write it to disk.

#### Rules

- Output always in Spanish
- One spec per epic — not a multi-epic document
- No implementation details (that's what the TDD is for)
- Business rules are numbered (BR-001, BR-002…) so stories can reference them

| | |
|---|---|
| **Input** | Design Doc + epic name |
| **Output** | Spec Funcional `.md` ready to paste into Lark Wiki |
| **Language** | Always Spanish |
| **Cadence** | One per epic, before generating `epic.md` |

---

### `/technical-design-document` — skill-3 *(optional)*

Generates a Technical Design Document — the technical blueprint for an epic. Apply on projects with high technical complexity or when the Spec Funcional is insufficient for the team to make architecture decisions.

#### When to use it

Use the TDD when the epic involves:
- New infrastructure or external integrations
- Complex data model changes
- Security-sensitive flows (auth, payments, PII)
- Performance-critical paths
- Multiple teams need to coordinate on a shared contract

Skip it for simple CRUD epics where the Spec Funcional is self-explanatory.

#### What it documents

| Section | Content |
|---|---|
| Problem statement | Why this technical approach is needed |
| Solution architecture | ASCII diagram of components and data flow |
| Component design | Each component's responsibility and interface |
| Data model | Schema changes anchored to `domain_model.md` |
| API endpoints | Routes, request/response shapes, auth |
| Security considerations | Threats, mitigations, auth/authz model |
| Integrations | External systems, contracts, failure modes |
| Rollout plan | Phased delivery, feature flags, migrations |

#### First question

Before drafting, always ask: **"Should the TDD be created before or after the epics?"**

- **Before epics:** The TDD defines the technical scope. `/epic-generator` uses it to populate story technical scope automatically.
- **After epics:** Epics already exist with placeholders. The TDD fills in the technical details retroactively.

This changes how Epic IDs are populated in section 4.3.

#### Rules

- English only
- ASCII diagrams only — no Mermaid (portability)
- No vague statements — every decision has a stated reason
- Sections can reference `domain_model.md` entities by their exact names

| | |
|---|---|
| **Input** | Spec Funcional + `docs/domain_model.md` + `docs/project_context.md` |
| **Output** | `docs/epics/E-XXX_slug/tdd.md` |
| **Language** | Always English |

---

### `/epic-generator` — skill-4

Generates individual Epic documents from a Spec Funcional. Each epic is a standalone document for sprint planning and story generation. If a TDD exists, it is used automatically to enrich with technical details.

#### What each `epic.md` contains

| Section | Content |
|---|---|
| Objective | What this epic achieves and why it matters |
| Scope (In / Out) | What is and isn't included |
| Happy path | ASCII flow diagram — max 8 steps |
| KPIs | Measurable success criteria |
| User stories | 3–8 per epic with short ACs |

#### Process

1. Reads the Spec Funcional
2. If a TDD exists in `docs/epics/E-XXX/tdd.md`, reads it automatically
3. Presents the discovered epics (with IDs and one-line descriptions)
4. Asks which epics to generate (can be all or a subset)
5. Generates one `epic.md` per requested epic

#### Rules

- Each `epic.md` is 150–200 lines max — focused, not exhaustive
- Uses `[TO BE DEFINED]` for gaps — never invents content
- Epic IDs follow the format `E-{3-digit-number}` (E-001, E-002…)
- Folder naming: `E-{number}_{lowercase_slug}` (e.g. `E-002_authentication`)
- User stories inside the epic file are abbreviated — full stories come from `/story-generator`

| | |
|---|---|
| **Input** | Spec Funcional (required) + TDD (optional) |
| **Output** | `docs/epics/E-XXX_slug/epic.md` per epic |
| **Limit** | 150–200 lines per epic |

---

### `/story-generator` — skill-5

Generates all User Stories (HUs) for an epic. Before generating, resolves all open questions with the operator — the final document has no ambiguities.

#### Story structure — two blocks

Every story file has two blocks designed for different moments in the dev workflow:

**Block A — Read before estimating**

| Section | Content |
|---|---|
| 1. User Story | "As a [role], I want [capability] so that [outcome]" |
| 2. Acceptance Criteria | Numbered list — becomes the test checklist |
| 3. Ranked Tasks | Must / Important / Optional / Nice to have |

**Block B — Reference during implementation**

| Section | Content |
|---|---|
| 4. Technical Scope | API endpoints, DB changes, auth requirements, config |
| 5. Business Rules | Numbered references to Spec Funcional rules (BR-XXX) |
| 6. Data Model | Schema changes for this story |
| 7. Telemetry | Events and metrics to track |
| 8. Testing Guidance | Unit, integration, E2E expectations |

#### File naming convention

```
docs/epics/E-XXX_slug/stories/
└── E-XXX_S-YYY_slug/               ← story folder (one per HU)
    └── E-XXX_S-YYY_slug.md         ← story file (same name as folder)
```

Example:
```
docs/epics/E-002_authentication/stories/
└── E-002_S-001_sign_up/
    └── E-002_S-001_sign_up.md
```

The folder is the dev workspace. After the story is committed, the developer adds `spec.md`, `plan.md`, and `todo.md` to the same folder when implementing.

#### Pre-generation checklist

Before generating any story, the skill verifies:
- All ACs are testable (not vague like "should work correctly")
- All technical scope sections reference real entities from `domain_model.md`
- All business rules are traceable to the Spec Funcional
- No open questions remain — if any, resolve them first

#### Rules

- No ambiguities in the final document
- ACs must be measurable and testable
- Technical scope must be concrete — no "TBD" in Block B
- Story IDs: `S-{3-digit-number}` within the epic (S-001, S-002…)
- Do not modify story files after committing — they are planning output

| | |
|---|---|
| **Input** | `epic.md` + Spec Funcional (if exists) + `tdd.md` (if exists) |
| **Output** | `docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/E-XXX_S-YYY_slug.md` |

Once committed, the developer takes this file and runs `/spec` → `/plan` → `/build`. See [DEV.md](DEV.md).

---

### `/write-epics-and-hu-in-base` — skill-6

Reads epic and story `.md` files from the repo, translates content fields to Spanish, and pushes them to Lark Base via the Avila Tools API. Supports upsert — existing records are updated, new ones are created.

#### Required inputs

| Input | Description |
|---|---|
| **Epic IDs** | Which epics to sync (e.g. `E-002 E-003`) |
| **API Key** | Bearer token — `sk-xxxx...` (get from project lead) |
| **Base ID** | Target Lark Base identifier (visible in the Base URL) |

#### Process

1. Reads `epic.md` and all story `.md` files for the requested epics
2. Translates content fields to Spanish
3. Builds the payload and shows a preview
4. Waits for confirmation before sending
5. POSTs to `https://your-api.example.com/your/full/path`
6. Reports success/failure per record

#### Rules

- Always shows preview and waits for confirmation before the POST
- Never invents field values — only uses data present in the `.md` files
- Never clones the repo or modifies files
- Supports partial sync — you can push a single epic without touching others

| | |
|---|---|
| **Output** | Epics and stories synced in Lark Base |

---

## Artifact Map

| Artifact | Where it lives | Created by |
|---|---|---|
| Design Doc | Lark Wiki | Team (manual) |
| `project_context.md` | `docs/` | skill-0 |
| `domain_model.md` | `docs/` | skill-1 |
| Spec Funcional | Lark Wiki | skill-2 |
| `tdd.md` | `docs/epics/E-XXX/` | skill-3 |
| `epic.md` | `docs/epics/E-XXX/` | skill-4 |
| Story folder + `.md` | `docs/epics/E-XXX/stories/E-XXX_S-YYY_slug/` | skill-5 |
| Lark Base records | Lark Base | skill-6 |

---

## Docs layout in the target repo

```
docs/
├── inputs/
│   ├── design_doc.pdf
│   └── intake_brief.docx
├── project_context.md
├── domain_model.md
├── epics/
│   └── E-XXX_slug/
│       ├── epic.md
│       ├── tdd.md              ← optional
│       └── stories/
│           └── E-XXX_S-YYY_slug/
│               ├── E-XXX_S-YYY_slug.md   ← planning output (do not modify)
│               ├── spec.md               ← dev output (/spec)
│               ├── plan.md               ← dev output (/plan)
│               └── todo.md               ← dev output (/plan)
└── adrs/
```

---

## Key principles

**One question at a time.** Every planning skill asks questions one at a time — never dumps a list of questions and waits. This keeps the interaction focused and prevents the operator from being overwhelmed.

**Confirm before generating.** Every skill shows a summary of what it's about to generate and waits for explicit confirmation. Nothing is written to disk before the operator approves.

**No invented facts.** If the source documents don't contain the answer, the skill writes `[PENDING]` and flags it as an open question. It never guesses business rules.

**Artifacts are additive.** Running skill-0 or skill-1 again does not overwrite — it updates and appends. The history of decisions is preserved in the repo.

**English everywhere except skill-2.** All artifacts in the repo are in English. The Spec Funcional (skill-2) is Spanish because it lives in Lark Wiki and is read by the broader team.

---

## Installation

Copy the entire skill pack into `.claude/` in your project — see [README.md](README.md) for the one-command install. All six folders are required; do not copy only the planning skills in isolation.

When the planning track is done and story files are committed, hand off to the developer. See [DEV.md](DEV.md).
