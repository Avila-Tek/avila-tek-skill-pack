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
    ├── 1-functional-spec-generator/
    │   ├── SKILL.md                       ← Generates Spec Funcional (Lark Wiki)
    │   └── references/
    │       └── template.md                ← Spec Funcional canonical template
    ├── 2-epic-generator/
    │   └── SKILL.md                       ← Generates docs/epics/E-XXX_slug/epic.md
    ├── 3-story-generator/
    │   └── SKILL.md                       ← Generates docs/epics/E-XXX_slug/stories/
    └── 4-write-epics-and-hu-in-base/
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
├── epics/
│   ├── E-000_slug/
│   │   ├── epic.md
│   │   └── stories/
│   │       ├── E-000_S-001_slug.md
│   │       └── E-000_S-002_slug.md
│   ├── E-001_slug/
│   │   ├── epic.md
│   │   └── stories/
│   └── E-XXX_slug/
│       ├── epic.md
│       └── stories/
├── plans/                                 ← Implementation plans — written by devs per story (after spec)
├── specs/                                 ← Technical specs — written by devs per story (before plan)
└── adrs/                                  ← Architecture Decision Records
```

**Epic folder naming:** `E-{3-digit-number}_{lowercase_slug}` — e.g. `E-002_authentication-and-registration-foundation`

**Story file naming:** `E-{epic}-_S-{3-digit-number}_{lowercase_slug}.md` — e.g. `E-002_S-001_sign_up_with_email_password.md`

---

## Skills

| # | Skill | Status | Trigger |
|---|---|---|---|
| 0 | project-context-generator | ✅ | "generate project context", "create master context" |
| 1 | functional-spec-generator | ✅ | "generate functional spec", "spec funcional" |
| 2 | epic-generator | 🚧 | "generate epic for E-XXX" |
| 3 | story-generator | ✅ | "generate stories for E-XXX" |
| 4 | lark-backlog-sync | ✅ | "sync to Lark", "push E-XXX to Lark" |

---

## Conventions

- Every skill lives in `skills/{number}-{name}/SKILL.md`
- YAML frontmatter with `name` and `description` fields required
- `description` must start with a trigger phrase pattern (what the user says to activate it)
- Supporting reference files go in `skills/{name}/references/` — only create them if content exceeds ~100 lines
- Skills are numbered by process order (0 → 4), not by importance
- Never duplicate content between skills — cross-reference instead

---

## Artifact Ownership

| Artifact | Lives in | Created by |
|---|---|---|
| Design Doc | Lark Wiki | Team (manual) |
| project_context.md | Repo (`docs/`) | skill-0 |
| Spec Funcional | Lark Wiki | skill-1 |
| epic.md | Repo (`docs/epics/`) | skill-2 |
| Story `.md` files | Repo (`docs/epics/E-XXX/stories/`) | skill-3 |
| Lark Base records | Lark Base | skill-4 |

---

## Boundaries

- **Always:** Keep skill numbering aligned with the process order
- **Always:** Write SKILL.md output paths explicitly (where the file goes in the target repo)
- **Never:** Add vague advice — every skill must have concrete steps and a clear output artifact
- **Never:** Duplicate business logic between skills — if two skills share a concept, reference the primary one
- **Never:** Invent field values or business rules when generating artifacts — use `[PENDIENTE]` for gaps
