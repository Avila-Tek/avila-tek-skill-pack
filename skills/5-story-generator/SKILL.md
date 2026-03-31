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

Ask the operator one at a time. Record answers. Only proceed to Step 4 when all are resolved.

### Step 4 — Generate

Follow the template below. Rules:
- Never leave a section empty — omit the whole section instead of writing N/A
- Never invent features, endpoints, or behaviors outside the epic scope
- Block B sections with no real content for this story are omitted entirely
- Section 9 (open questions) records only answers — no unresolved questions

### Step 5 — Write file

**Name:** `E-{epic}_S-{story}_{slug}.md` (slug = 3–5 snake_case words from title)
**Write to:** `/mnt/user-data/outputs/`
**Repo path:** `docs/epics/E-XXX_.../stories/E-XXX_S-XXX_slug.md`

Return ONLY the story document. No preamble.

### Step 6 — Quality check

- [ ] Correct story (S-XXX), not a neighbor
- [ ] Block A alone is sufficient to estimate — no need to read Block B
- [ ] Acceptance criteria are testable (clear pass/fail, no vague language)
- [ ] Must tasks = required by an AC or hard business rule
- [ ] Block B sections with no content are omitted
- [ ] Section 9 has only resolved answers, or states no questions arose

---

## Template

```markdown
# Story E-{epic}_S-{story} — {Story Name}

## 0) Snapshot

| | |
|---|---|
| **Epic** | E-{epic} — {Epic Name} |
| **Status** | Draft |
| **Owner** | TBD |
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
