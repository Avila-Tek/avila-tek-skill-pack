---
name: story-generator
description: >
  Generate engineering Story files (.md) from an epic. Triggers: "write story S-XXX",
  "create story", "generate stories for this epic", "expand S-XXX", "next story", or any
  request to produce a story document when an epic is present.
---

# Story Generator

Turns an epic into an implementation-ready Story file with a **2-block structure**:

- **Block A** — Dev reads before estimating: user story, acceptance criteria, estimation.
- **Block B** — Dev consults during implementation: technical scope, rules, data, testing.

**Input priority:** operator context > Spec Funcional > epic > TDD > inference (never invent).

---

## Workflow

### Step 1 — Read inputs

- **Epic** (required) — from uploads, conversation context, or path provided by user
- **Spec Funcional** (use if available) — source for functional flow context
- **TDD** (use if available) — source for technical components and data model

### Step 2 — List stories

Scan the epic for S-XXX references. Show the list with one-line descriptions. Skip if the user already specified a story.

### Step 3 — Resolve open questions

Detect questions that would block a complete, accurate story:
- Open questions in the epic relevant to this story
- Ambiguities in the scope or flow of this specific story
- **Figma URL** — always ask for the Figma URL if not provided by the user. This field is required for Lark sync. If the user does not have it yet, use the placeholder `[PENDIENTE — agregar URL de Figma antes de sincronizar con Lark]` and count it as a [PENDIENTE]. If the user provides a URL, validate the format before accepting it: must start with `https://`, domain must be `figma.com` or `www.figma.com`, path must contain `/design/` or `/file/`, and must not contain URL-encoded characters (`%3A`). If invalid, show the specific problem and ask the user to provide the correct URL.

Ask the operator one at a time. Record answers. If the user cannot answer a question, mark it as [PENDIENTE] and proceed. Never generate a story with more than 2 [PENDIENTE] items in Block A. Only proceed to Step 4 when all resolvable questions are addressed.

### Step 4 — Generate

Follow the template below. Rules:
- Block A sections (User Story, Acceptance Criteria, Ranked Tasks) must always be complete. A story with incomplete Block A is not ready to generate.
- Block B sections (Technical Scope, Business Rules, Data Model, etc.): omit any section that has no real content for this specific story. Do not add placeholder text.
- Never invent features, endpoints, or behaviors outside the epic scope
- Section 9 (open questions) records only answers — no unresolved questions

### Step 5 — Write file

Each story lives in its **own folder** inside `stories/`. The folder name and the file name are identical — only the file has the `.md` extension.

```
docs/epics/E-XXX_slug/
└── stories/
    └── E-XXX_S-YYY_slug/           ← create this folder
        └── E-XXX_S-YYY_slug.md     ← write the story here
```

**slug** = 3–5 snake_case words from the story title (e.g. `sign_up_with_email`)

**Claude Code:** write directly to `docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/E-XXX_S-YYY_slug.md` in the project repo.

**Claude Desktop:** write to `/mnt/user-data/outputs/E-XXX_S-YYY_slug.md` and tell the user: *"Place this file inside `docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/` — create the folder first."*

The story folder is the developer's workspace. The dev will add `spec.md`, `plan.md`, and `todo.md` to it during implementation. Do not create those files here.

Return ONLY the story document. No preamble.

### Step 6 — Quality check

- [ ] Correct story (S-XXX), not a neighbor
- [ ] File is named `E-XXX_S-YYY_slug.md` and lives inside a folder with the same name (no `.md`)
- [ ] Block A alone is sufficient to estimate — no need to read Block B
- [ ] Acceptance criteria are testable (clear pass/fail, no vague language)
- [ ] Must tasks = required by an AC or hard business rule
- [ ] Block B sections with no content are omitted
- [ ] Section 9 has only resolved answers, or states no questions arose
- [ ] **Figma URL is present** in `## 0) Snapshot` — not empty, not `TBD`, not a `[PENDIENTE` placeholder. If missing, warn the user: *"Esta HU no tiene Figma URL. El sync a Lark quedará bloqueado hasta que la agregues."*
- [ ] **Figma URL format is valid** — starts with `https://`, domain is `figma.com` or `www.figma.com`, path contains `/design/` or `/file/`, no URL-encoded characters (`%3A`). If invalid, warn the user with the specific problem before writing the file.

---

## Template

```markdown
# Story E-{epic}_S-{story} — {Story Name}

## 0) Snapshot

| | |
|---|---|
| **Epic** | E-{epic} — {Epic Name} |
| **Status** | Backlog |
| **Owner** | TBD |
| **Figma** | {figma_url} <!-- REQUIRED: provide the Figma URL before syncing to Lark --> |
| **Refs** | `docs/epics/{epic_folder}/epic.md` |

---

<!-- ══ BLOCK A — Read before estimating ══ -->

## 1) User story

As a {user type}, I want {action}, so that {outcome}.

---

## 2) Acceptance criteria

- **AC-01:** Given [precondition], when [action], then [expected result].

---

## 3) Estimation considerations

### Services & components
- {Service} — {role in this story}

### Views / screens
- `/{path}` — {what the dev builds or modifies}

### Ranked tasks

| Priority | Task |
|---|---|
| Must | {required by an AC — cannot ship without} |
| Important | {primary flow, non-blocking — factor into estimate} |
| Optional | {alternate flow — include if time allows} |
| Nice to have | {UX improvement — out of scope unless trivial} |

---

<!-- ══ BLOCK B — Reference during implementation ══ -->

## 4) Technical scope

Only include lines that have real content for this story. Omit empty categories.

- **API:** `METHOD /path` — {description}
- **Auth/guards:** {which routes or operations require auth}
- **DB:** `{table}(field type)` — {new or modified}
- **External:** {service} — {purpose}
- **Config:** `ENV_VAR` — {what it controls}
- **Security:** {constraint or rule}

---

## 5) Business rules

- **BR-01:** {rule — sourced from epic or Spec Funcional, not invented}

---

## 6) Data model impact

> Omit this section if no schema changes.

- **New:** `{table}` — {columns and purpose}
- **Modified:** `{table}.{field}` — {change}

---

## 7) Telemetry & logs

> Omit if no specific telemetry requirements for this story.

- `{event_name}` — {when it fires, what it captures}

---

## 8) Testing guidance

- **Unit:** {what to cover}
- **Integration:** {what to verify end-to-end}
- **Manual:** {what to check before marking done}

---

## 9) Open questions (resolved)

- **OQ-01:** {question} → **Resolution:** {answer confirmed by operator}

If none: "No open questions. All decisions resolved from epic and context."
```

---

## Dev Handoff

Once a story is committed, the developer's workflow starts from the story file:

```
/spec  →  reads story file (Story-Driven Mode)  →  writes spec.md
/plan  →  reads spec.md                          →  writes plan.md + todo.md
/build →  reads spec.md + plan.md               →  implements tasks
```

All artifacts land in the same story folder:

```
docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/
├── E-XXX_S-YYY_slug.md   ← this file (planning output)
├── spec.md               ← written by /spec
├── plan.md               ← written by /plan
└── todo.md               ← task checklist from /plan
```

---

## Ranking guide

| Label | Criteria |
|---|---|
| **Must** | Required by an AC or hard business rule — cannot ship without it |
| **Important** | Part of the primary flow but not blocking the happy path |
| **Optional** | Alternate flow or mentioned enhancement — include if time allows |
| **Nice to have** | UX improvement or future feature — no AC requires it |

**Services & components** → derived from section 4 (Technical scope) + epic
**Views / screens** → derived from Spec Funcional flows or epic overview
**Tasks** → derived from ACs and business rules — never invented
