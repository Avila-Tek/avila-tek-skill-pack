---
name: epic-and-stories-generator
description: >
  Use this skill whenever the user wants to generate epics, stories (HUs), or break a Spec Funcional
  into implementation-ready artifacts — even if they don't say "epic" or "story" explicitly.
  Trigger on: "generate epics", "genera las épicas", "break this spec into epics",
  "generate epics and stories", "genera épicas e historias", "crea los documentos de épica e historias",
  "I have a spec and want to start planning", "tengo el spec, ¿qué sigue?",
  "create the planning documents", "quiero las historias de usuario".
  Phase 1 generates slim epic.md files (50–150 lines, navigation layer only).
  Phase 2 generates full Block A + Block B story files for developer handoff.
  Both phases run in one command — do not suggest running /epic-generator or /story-generator separately.
---

# Epic and Stories Generator

Generates **Epic documents** and **Story files (HUs)** from a Spec Funcional in one command.

- **Phase 1** — generates slim `epic.md` files (50–150 lines each): navigation layer, not a restatement of the Spec Funcional.
- **Phase 2** — generates full `E-XXX_S-YYY.md` story files using the standard Block A + Block B format.

**Language**: All output in English.

> **Note:** "TDD" in this project means **Technical Design Document**, not Test-Driven Development.

---

## Phase 0 — Load Context & Surface Ambiguities

### Step 0a — Load Context Documents

Read silently in this order (skip any that don't exist):

1. `docs/project_context.md`
2. `docs/domain_model.md`
3. TDD (any `tdd.md` in scope)

If `docs/domain_model.md` is missing, warn once:
> "`docs/domain_model.md` not found. Epics will use vocabulary from the Spec Funcional. Consider generating the domain model first with `/domain-model-generator`."

Then continue.

### Step 0b — Read the Spec Funcional

Read the full Spec Funcional:
- PDF: extract all pages
- DOCX: convert with pandoc
- MD/TXT: read directly
- If generated in this session: use content already in context

If no Spec Funcional is found, ask the user to provide one or offer to generate it with `/functional-spec-generator`.

When you encounter a section that is ambiguous or references modules/actors not fully described, apply zoom-out: map the relevant modules and callers at one level of abstraction above, using domain model vocabulary. Use this map to decide whether the ambiguity warrants a question or can be resolved from context.

### Step 0c — Derive & Present Questions

From what you've read, derive 4–8 targeted questions that cannot be answered by any loaded document. Questions must be blockers for Objective, Scope, or Happy Path of at least one epic.

Do NOT ask about:
- Details already present in any loaded document
- Optional enhancements — mark `[TO BE DEFINED]` and continue
- KPIs — asked separately in Step 4

Present all questions as a numbered list before asking any of them:
> "Before generating, I have [N] questions. You can answer all of them or tell me which to skip — skipped ones will be marked [TO BE DEFINED]:"
>
> 1. ...
> 2. ...

### Step 0d — Ask One at a Time

For each question the user chooses to answer, ask it individually and wait for the response before continuing. Use domain model vocabulary in every question — no paraphrasing of canonical terms.

Once all chosen questions are answered or skipped, proceed to Phase 1.

---

## Phase 1 — Generate Epics

### Step 1 — Verify Context

Context documents and Spec Funcional were loaded in Phase 0. If Phase 0 was skipped, load them now following the same instructions in Steps 0a–0b.

### Step 2 — Extract Epics

Parse section 5 "Definición de Flujos" of the Spec Funcional. For each flow extract:
- **Epic ID**: use existing E-XXX identifiers or assign sequentially (E-001, E-002, ...)
- **Title**: the flow name
- **Objective**: the purpose of this flow
- **User type**: who interacts with this flow
- **Steps**: the step-by-step process (happy path + unhappy paths)
- **Business Rules**: any BR-XX rules referenced

### Step 3 — Confirm Epics

Present the identified epics:

> I found N epics in the Spec Funcional:
> - E-001 — [Title]
> - E-002 — [Title]
>
> Generate all, or specific ones?

### Step 4 — Generate Each `epic.md`

#### Content Principles

- **Domain vocabulary.** Use exact terms from `docs/domain_model.md` throughout — no synonyms, no paraphrasing. If domain_model.md was missing, use terms as defined in the Spec Funcional.
- **Navigation layer, not restatement.** If it's already in the Spec Funcional verbatim, omit it.
- **Derive, don't invent.** Use `[TO BE DEFINED]` for gaps.
- **No passive voice.** No "the system will...", no filler phrases ("This section describes...", "In order to...").
- **Dense prose.** Assume the reader knows the domain.
- **Target: 50–150 lines per epic.**
- **Derive PRD Signal from epic content.** Do not summarize the Spec Funcional. Problem Statement = the business gap this epic fills. Solution = what the epic delivers. Implementation Decisions = which services/modules are touched (derive from Happy Path and Scope).

#### Epic Template

Read the template before generating:
```
skills/planning-4-epic-and-stories-generator/references/epic-template.md
```

#### KPI Handling

Ask **once** before generating any epic:
> "Do you want KPIs in the epics? I'll suggest domain-specific metrics for each one as I go. (yes / no / decide per epic)"

- **Yes**: add a `## KPIs` section to every epic with 2–3 suggestions derived from its content.
- **No**: omit the section from all epics.
- **Decide per epic**: after generating each epic body, show 2–3 suggestions and ask.

Format when included:
```markdown
## KPIs
- {Metric} — {target} — {source}
```

### Step 5 — Write Epic Files

```
docs/epics/E-XXX_<snake_case_title>/epic.md
```

### Step 6 — Phase 1 Quality Checklist

Before moving to Phase 2, verify each epic:

- [ ] Sections present: Objective, Scope, Happy Path, Unhappy Paths, PRD Signal, Stories (KPIs only if confirmed)
- [ ] `## PRD Signal` has Problem Statement, Solution, and at least one Implementation Decision
- [ ] No Mermaid diagrams — ASCII flow only
- [ ] Happy Path ≤ 6 steps
- [ ] Each story row: ID + title + user statement + max 2 ACs
- [ ] No content copied verbatim from the Spec Funcional
- [ ] No passive voice, no "the system will...", no filler phrases
- [ ] 50–150 lines per epic
- [ ] No invented content — `[TO BE DEFINED]` for gaps
- [ ] All terms match `docs/domain_model.md` vocabulary (or Spec Funcional if domain model absent)
- [ ] No ambiguity surfaced in Phase 0 left unaddressed — either answered or marked `[TO BE DEFINED]`

---

## Phase 2 — Generate Stories (HUs)

After all epics are written, ask:

> "Epics generated. Generate stories now? (all epics, or specify: E-001, E-003...)"

If the user confirms, first collect Figma URLs in batch, then generate all stories.

### Step 7 — Batch Figma URLs

Before generating any story, present the full list of stories and ask for all Figma URLs at once:

> "Before I generate the stories, please share the Figma URLs for each one (or leave blank if you don't have it yet):
> - S-001 — {Title}: ___
> - S-002 — {Title}: ___
> ..."

For each URL provided:
- Validate: must start with `https://`, domain `figma.com` or `www.figma.com`, path contains `/design/` or `/file/`, no URL-encoded characters (`%3A`).
- If invalid: show the specific problem and ask for that URL again before proceeding.
- If left blank: use `[PENDIENTE — add Figma URL before syncing to Lark]`.

### Step 7b — Resolve Open Questions Per Story

For each story, ask about any ambiguities in scope or flow not answered by the epic or Spec Funcional.
- Ask one question at a time.
- If the user cannot answer, mark as `[PENDIENTE]`.
- Never generate a story with more than 2 `[PENDIENTE]` items in Block A.

### Step 8 — Generate Each Story File

Read the template before generating. Block A must always be complete. Omit Block B sections with no real content.

#### Populating `### Backend services`

For each service identified from the TDD and domain model:

1. **List only services directly involved in this story** — not the whole system.

2. **Find existing module**: search the codebase for the service by class name (`AuthService`, `auth.service.ts`) then by folder (`src/auth/`). If found, annotate `[exists: src/path/to/module]`. If not found, search for the specific endpoint path in source files. If still not found, annotate `[new]`.

3. **Detect shared services**: read sibling story files in `docs/epics/E-XXX_slug/stories/*/` and check if the same service name appears in their `### Backend services` sections. If yes, annotate `[shared with E-XXX_S-YYY]`.

4. **Format each line**:
   ```
   ServiceName — operation — `METHOD /path` → `status { field1, field2 }` [exists: src/path] [shared with E-XXX_S-YYY]
   ```
   - HTTP endpoint when one exists; prose types (`userId: string → token: string`) for internal services with no HTTP route.
   - Source: TDD component architecture + domain model — never invent.
```
skills/planning-4-epic-and-stories-generator/references/story-template.md
```

### Step 9 — Write Story Files

Each story lives in its own folder inside `stories/`. Folder name and file name are identical — only the file has `.md`:

```
docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/E-XXX_S-YYY_slug.md
```

**slug** = 3–5 snake_case words from the story title (e.g. `sign_up_with_email`)

The story folder is the developer's workspace. Do not create `spec.md`, `plan.md`, or `todo.md` here.

### Step 10 — Phase 2 Quality Checklist

- [ ] Correct story (S-XXX), not a neighbor
- [ ] File named `E-XXX_S-YYY_slug.md` inside a folder with the same name (no `.md`)
- [ ] Block A alone is sufficient to estimate — no need to read Block B
- [ ] Acceptance criteria are testable (clear pass/fail, no vague language)
- [ ] Must tasks = required by an AC or hard business rule
- [ ] Block B sections with no content are omitted
- [ ] Section 9 has only resolved answers, or states no questions arose
- [ ] **Figma URL is present** in `## 0) Snapshot` — if missing, warn: *"This story has no Figma URL. Lark sync will be blocked until you add it."*
- [ ] **Figma URL format is valid** — starts with `https://`, domain `figma.com` or `www.figma.com`, path contains `/design/` or `/file/`, no `%3A`

---


