# avila-tek-skill-pack

AI-assisted planning skills for Avila Tek projects. This repo contains Claude Code skills that guide the end-to-end planning process — from Design Doc to a repo ready for engineers to execute.

---

## Project Structure

```
avila-tek-skill-pack/
├── CLAUDE.md                              ← This file
├── README.md                              ← Process overview and skill reference
└── skills/
    ├── 0-project-context-generator/
    │   └── SKILL.md                       ← Generates docs/project_context.md
    ├── 1-domain-model-generator/
    │   └── SKILL.md                       ← Generates docs/domain_model.md
    ├── 2-functional-spec-generator/
    │   ├── SKILL.md                       ← Generates Spec Funcional (Lark Wiki)
    │   └── references/
    │       └── template.md                ← Spec Funcional canonical template
    ├── 3-technical-design-document/
    │   ├── SKILL.md                       ← Generates TDD (.docx/.md)
    │   └── references/
    │       └── template.md                ← TDD canonical template
    ├── 4-epic-generator/
    │   ├── SKILL.md                       ← Generates docs/epics/E-XXX_slug/epic.md
    │   └── references/
    │       └── template.md                ← Epic document canonical template
    ├── 5-story-generator/
    │   └── SKILL.md                       ← Generates docs/epics/E-XXX_slug/stories/
    └── 6-write-epics-and-hu-in-base/
        └── SKILL.md                       ← Syncs epics + stories to Lark Base
```

---

## Docs Structure (target project repos)

Skills generate artifacts into this layout inside the target project:

```
docs/
├── inputs/                                ← Source documents placed here before running skills
│   ├── design_doc.pdf                     ← Design Doc exported from Lark Wiki
│   └── intake_brief.docx                  ← Intake Brief (alternative starting point)
├── project_context.md                     ← Master context (WHY/WHAT/constraints/glossary)
├── domain_model.md                        ← Domain entities, invariants, events, DBML schema
├── epics/
│   ├── E-000_slug/
│   │   ├── epic.md
│   │   ├── tdd.md                         ← Technical Design Document for the epic
│   │   └── stories/
│   │       ├── E-000_S-001_slug.md
│   │       └── E-000_S-002_slug.md
│   ├── E-001_slug/
│   │   ├── epic.md
│   │   ├── tdd.md
│   │   └── stories/
│   └── E-XXX_slug/
│       ├── epic.md
│       ├── tdd.md
│       └── stories/
├── plans/                                 ← Implementation plans — written by devs per story (after spec)
├── specs/                                 ← Technical specs — written by devs per story (before plan)
└── adrs/                                  ← Architecture Decision Records
```

**Epic folder naming:** `E-{3-digit-number}_{lowercase_slug}` — e.g. `E-002_authentication-and-registration-foundation`

**Story file naming:** `E-{epic}-_S-{3-digit-number}_{lowercase_slug}.md` — e.g. `E-002_S-001_sign_up_with_email_password.md`

---

## Skills

> **Note:** "TDD" in this project means **Technical Design Document**, not Test-Driven Development.

| # | Skill | Status | Trigger |
|---|---|---|---|
| 0 | project-context-generator | ✅ | "generate project context", "create master context" |
| 1 | domain-model-generator | ✅ | "domain model", "generate domain model", "modelo de dominio" — run early or re-run after any spec/TDD/epic |
| 2 | functional-spec-generator | ✅ | "generate functional spec", "spec funcional" |
| 3 | technical-design-document | ✅ | "generate a technical design", "write a design doc", "create a TDD" |
| 4 | epic-generator | ✅ | "generate epics", "genera las épicas", "break this spec into epics" |
| 5 | story-generator | ✅ | "generate stories for E-XXX" |
| 6 | lark-backlog-sync | ✅ | "sync to Lark", "push E-XXX to Lark" |

---

## Conventions

- Every skill lives in `skills/{number}-{name}/SKILL.md`
- YAML frontmatter with `name` and `description` fields required
- `description` must start with a trigger phrase pattern (what the user says to activate it)
- Supporting reference files go in `skills/{name}/references/` — only create them if content exceeds ~100 lines
- Skills are numbered by process order (0 → 6), not by importance
- Never duplicate content between skills — cross-reference instead

---

## Artifact Ownership

| Artifact | Lives in | Created by |
|---|---|---|
| Design Doc | Lark Wiki | Team (manual) |
| project_context.md | Repo (`docs/`) | skill-0 |
| domain_model.md | Repo (`docs/`) | skill-1 |
| Spec Funcional | Lark Wiki | skill-2 |
| TDD (.docx/.md) | Repo (`docs/epics/E-XXX/tdd.md`) | skill-3 |
| epic.md | Repo (`docs/epics/`) | skill-4 |
| Story `.md` files | Repo (`docs/epics/E-XXX/stories/`) | skill-5 |
| Lark Base records | Lark Base | skill-6 |

---

## Boundaries

- **Always:** Keep skill numbering aligned with the process order
- **Always:** Write SKILL.md output paths explicitly (where the file goes in the target repo)
- **Never:** Add vague advice — every skill must have concrete steps and a clear output artifact
- **Never:** Duplicate business logic between skills — if two skills share a concept, reference the primary one
- **Never:** Invent field values or business rules when generating artifacts — use `[PENDIENTE]` for gaps
