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

### Backend services

<!-- Only services directly involved in this story. Source: TDD component architecture + domain model — never invent.
     Format: ServiceName — operation — `METHOD /path` → `status { field1, field2 }` [exists: src/path] or [new] [shared with E-XXX_S-YYY if applicable] -->
- {ServiceName} — {operation} — `{METHOD /path}` → `{status} { fields }` [{exists: src/path/to/module} | new]

### Views / screens
- `/{path}` — {what the dev builds or modifies}

### Ranked tasks

<!-- Ranking criteria:
  Must        = required by an AC or hard business rule — cannot ship without it
  Important   = part of the primary flow but not blocking the happy path
  Optional    = alternate flow or mentioned enhancement — include if time allows
  Nice to have = UX improvement or future feature — no AC requires it
-->

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
