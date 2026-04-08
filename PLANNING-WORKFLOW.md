# PLANNING-WORKFLOW.md — Planning Workflow with Claude

This document defines the complete planning workflow for moving from a Design Doc to story files ready for development.

> Claude MUST follow this workflow. Skills reference this file for artifact locations, gates, and sequence.
>
> For the full skill reference (every planning skill explained in detail), see [PLANNING.md](PLANNING.md).

---

## Lifecycle

```
CONTEXT        DOMAIN         SPEC          TDD           EPICS        STORIES        SYNC
  |              |              |             |              |             |              |
/project-    /domain-      /functional-  /technical-    /epic-       /story-       /write-epics-
context-     model-        spec-         design-        generator    generator     and-hu-in-base
generator    generator     generator     document
                                         (optional)
```

Each phase has a **gate** — do not advance until the gate is met.

---

## Artifact structure

All planning artifacts live in the target project repo under `docs/`:

```
docs/
├── inputs/
│   ├── design_doc.pdf         ← Source document (manual — place here before starting)
│   └── intake_brief.docx
├── project_context.md         ← skill-0 output
├── domain_model.md            ← skill-1 output (living document)
├── epics/
│   └── E-XXX_slug/
│       ├── epic.md            ← skill-4 output
│       ├── tdd.md             ← skill-3 output (optional)
│       └── stories/
│           └── E-XXX_S-YYY_slug/
│               ├── E-XXX_S-YYY_slug.md   ← skill-5 output (HANDOFF to dev)
│               ├── spec.md               ← dev output (/spec)
│               ├── plan.md               ← dev output (/plan)
│               └── todo.md               ← dev output (/plan)
└── adrs/
```

**Naming conventions:**
- Epic folder: `E-{3-digit-number}_{lowercase_slug}` → `E-002_authentication`
- Story folder: `E-{epic}_S-{3-digit-number}_{lowercase_slug}` → `E-002_S-001_sign_up`
- Story file: same as folder + `.md` → `E-002_S-001_sign_up.md`

---

## Phase 1 — CONTEXT (`/project-context-generator`)

**Goal:** Produce the master context document — the foundation every downstream artifact references.

**Usage:**
```
/project-context-generator
```

**Prerequisite:** Design Doc or Intake Brief placed in `docs/inputs/`.

**What Claude does:**

*Create mode (new project):*
1. Reads the source document from `docs/inputs/`
2. Asks clarifying questions one at a time
3. Waits for confirmation before generating
4. Creates `docs/project_context.md`

*Update mode (existing project):*
1. Reads the existing `project_context.md`
2. Asks what changed and why
3. Updates affected sections only
4. Appends an entry to the Change Log at the bottom
5. Never rewrites history

**What the document captures:** north star, domain glossary, business goals, success metrics, roles and permissions, scope (in/out), business rules, data policy, delivery constraints.

**Rules:**
- English only
- Max 500 lines — dense, high-signal
- Only WHY and WHAT — never HOW, never implementation details
- Uses `[PENDING]` for gaps, never invents business rules

**Gate to advance:**
- [ ] `docs/project_context.md` exists and is committed
- [ ] Domain glossary is populated
- [ ] Scope (in/out) is explicitly defined
- [ ] Team has reviewed and approved

---

## Phase 2 — DOMAIN MODEL (`/domain-model-generator`)

**Goal:** Establish the shared vocabulary of the system — entities, states, invariants, events, and schema.

**Usage:**
```
/domain-model-generator
```

**What Claude does:**
1. Reads `docs/project_context.md`
2. Asks clarifying questions one at a time
3. Generates or updates `docs/domain_model.md`

**What the document captures:** entity catalog with attributes and types, invariants per entity, state machines for stateful entities, domain events and triggers, aggregates, cross-entity workflows, DBML database schema.

**When to re-run:**
- After each Spec Funcional that reveals new entities
- After each TDD that defines a new data model
- When a developer raises a naming inconsistency
- Whenever epics or stories expose gaps in the model

This is a **living document** — each run is additive. Never rewrites. Appends to the Change Log.

**Rules:**
- English only
- Uses exact glossary terms from `project_context.md` — no synonyms, no paraphrasing
- Uses `[PENDING]` for gaps, never invents facts

**Gate to advance:**
- [ ] `docs/domain_model.md` exists and is committed
- [ ] All entities discovered so far are documented
- [ ] State machines defined for stateful entities
- [ ] DBML schema present

---

## Phase 3 — FUNCTIONAL SPEC (`/functional-spec-generator`)

**Goal:** Produce a complete functional specification per epic — the bridge between the Design Doc and the engineering backlog.

**Usage:**
```
/functional-spec-generator
```

**What Claude does:**
1. Reads the Design Doc and `docs/project_context.md`
2. Asks which epic to generate the spec for
3. Generates the Spec Funcional in Markdown (in Spanish)
4. Presents the output for the user to copy/export to Lark Wiki

**What the document captures:** actors, step-by-step flows (main + alternative), business rules (numbered BR-001, BR-002…), external integrations, edge cases, acceptance criteria, open questions with owner and due date.

**Rules:**
- Output always in Spanish (source language doesn't matter)
- One spec per epic — not a multi-epic document
- Lives in Lark Wiki — not written to the repo
- Business rules are numbered so stories can reference them (BR-001, BR-002…)
- No implementation details

**Gate to advance:**
- [ ] Spec Funcional created for the target epic
- [ ] Pasted to Lark Wiki and shared with team
- [ ] Business rules are numbered and complete
- [ ] No unresolved open questions that block the next phase

---

## Phase 4 — TDD (`/technical-design-document`) *(optional)*

**Goal:** Produce the technical blueprint for an epic — architecture, data model, API contracts, security model.

**Usage:**
```
/technical-design-document
```

**When to use it:** High technical complexity, new infrastructure, external integrations, security-sensitive flows (auth, payments, PII), multi-team coordination on a shared contract. Skip for simple CRUD epics.

**First question Claude always asks:** "Should the TDD be created before or after the epics?" — the answer changes how Epic IDs are populated in section 4.3.

**What the document captures:** problem statement, solution architecture (ASCII diagram), component design, data model anchored to `domain_model.md`, API endpoints with request/response shapes, security considerations, integration contracts, rollout plan.

**Rules:**
- English only
- ASCII diagrams only — no Mermaid
- Every architectural decision has a stated reason
- Entity names match `domain_model.md` exactly

**Gate to advance:**
- [ ] `docs/epics/E-XXX_slug/tdd.md` committed
- [ ] Architecture diagram present
- [ ] API contracts defined
- [ ] Data model anchored to domain model
- [ ] Security considerations documented

---

## Phase 5 — EPICS (`/epic-generator`)

**Goal:** Generate individual epic documents from the Spec Funcional — the units of sprint planning.

**Usage:**
```
/epic-generator
```

**What Claude does:**
1. Reads the Spec Funcional
2. If a TDD exists in `docs/epics/E-XXX/tdd.md`, reads it automatically to enrich technical details
3. Presents the discovered epics (IDs + one-line descriptions)
4. Asks which epics to generate
5. Generates one `epic.md` per requested epic

**What each `epic.md` contains:** objective, scope (in/out), happy path ASCII flow (max 8 steps), KPIs, user stories (3–8 with abbreviated ACs).

**Rules:**
- 150–200 lines per epic — focused, not exhaustive
- Uses `[TO BE DEFINED]` for gaps — never invents content
- Epic IDs: `E-{3-digit-number}` (E-001, E-002…)
- User stories inside `epic.md` are abbreviated — full stories come from `/story-generator`

**Gate to advance:**
- [ ] `docs/epics/E-XXX_slug/epic.md` committed for each target epic
- [ ] Scope (in/out) explicitly defined per epic
- [ ] Happy path flow present
- [ ] KPIs defined

---

## Phase 6 — STORIES (`/story-generator`)

**Goal:** Generate all User Stories (HUs) for an epic — the handoff artifact to the development team.

**Usage:**
```
/story-generator
```

**What Claude does:**
1. Reads `epic.md` + Spec Funcional + `tdd.md` (if exists)
2. Resolves all open questions before generating — no ambiguities in the final output
3. Generates one folder + story file per HU

**What each story file contains:**

*Block A — read before estimating:*
- Section 1: User Story
- Section 2: Acceptance Criteria (numbered, testable)
- Section 3: Ranked Tasks (Must / Important / Optional / Nice to have)

*Block B — consult during implementation:*
- Section 4: Technical Scope (API, DB, auth, config)
- Section 5: Business Rules (references to Spec Funcional: BR-XXX)
- Section 6: Data Model (schema changes)
- Section 7: Telemetry (events and metrics)
- Section 8: Testing Guidance (unit, integration, E2E)

**Pre-generation checklist (Claude verifies before writing):**
- All ACs are testable — not vague ("should work correctly" → rejected)
- All technical scope references real entities from `domain_model.md`
- All business rules trace back to the Spec Funcional
- No open questions remain

**Rules:**
- No ambiguities in the final document
- ACs must be measurable and testable
- Block B must be concrete — no "TBD"
- Do not modify story files after committing — they are planning output

**Gate to advance:**
- [ ] All stories for the target epic committed
- [ ] Each story has its own folder
- [ ] All ACs are testable
- [ ] Block B is complete with no gaps
- [ ] Story files reviewed and approved by the team

---

## Phase 7 — SYNC (`/write-epics-and-hu-in-base`)

**Goal:** Keep Lark Base synchronized with the repo — epics and stories as structured records.

**Usage:**
```
/write-epics-and-hu-in-base
```

**Requires before running:**

| Input | Description |
|---|---|
| Epic IDs | Which epics to sync (e.g. `E-002 E-003`) |
| API Key | Bearer token `sk-xxxx...` (get from project lead) |
| Base ID | Target Lark Base identifier (visible in the Base URL) |

**What Claude does:**
1. Reads `epic.md` and all story `.md` files for the requested epics
2. Translates content fields to Spanish
3. Builds the payload and shows a **preview**
4. Waits for explicit confirmation before sending
5. POSTs to `https://your-api.example.com/your/full/path`
6. Reports success/failure per record

**Rules:**
- Always shows preview and waits for confirmation before the POST
- Never invents field values — only uses data present in the `.md` files
- Supports upsert — existing records updated, new ones created
- Supports partial sync — one epic at a time

**Gate:**
- [ ] Preview reviewed and confirmed
- [ ] All records synced to Lark Base
- [ ] Lark Base shows correct epic and story data

---

## Handoff to development

Once story files are committed, the planning track is done. The developer picks up the story file and runs the Dev Track:

```
/spec → /plan → /build → /test → /review → /ship
```

See [DEV-WORKFLOW.md](DEV-WORKFLOW.md) for the complete development workflow.

---

## Full example flow

```
1.  Place docs/inputs/design_doc.pdf in the repo

2.  /project-context-generator
    → Claude asks questions, generates master context
    → Saved to docs/project_context.md
    → Team reviews and approves, commit

3.  /domain-model-generator
    → Claude asks questions, generates entity model
    → Saved to docs/domain_model.md
    → Team reviews and approves, commit

4.  /functional-spec-generator  (repeat per epic)
    → Claude generates Spec Funcional in Spanish
    → Team pastes to Lark Wiki

5.  /technical-design-document  (optional, per complex epic)
    → Claude asks "before or after epics?"
    → Saved to docs/epics/E-XXX_slug/tdd.md
    → Team reviews and approves, commit

6.  /epic-generator
    → Claude presents discovered epics, asks which to generate
    → Saved to docs/epics/E-XXX_slug/epic.md
    → Team reviews and approves, commit

7.  /story-generator  (per epic)
    → Claude resolves open questions, generates all HUs
    → Saved to docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/
    → Team reviews and approves, commit

8.  /write-epics-and-hu-in-base
    → Claude shows preview → team confirms
    → Records synced to Lark Base

9.  HANDOFF → developer picks up story file and runs /spec
```

---

## General rules

1. **Every artifact is confirmed before the next phase starts**
2. **Never invent business rules** — use `[PENDING]` for gaps
3. **One question at a time** — Claude never dumps a list of questions
4. **Artifacts are additive** — re-running skill-0 or skill-1 updates, never overwrites
5. **English everywhere except skill-2** — Spec Funcional is always in Spanish
6. **The story file is immutable after commit** — it is planning output; developers must not modify it
