---
name: build
description: Implement the next task incrementally — build, test, verify, commit
---

## Step 0 — Context Cleanup (suggest first, always)

Before doing anything else, suggest:

> "Antes de continuar, te recomiendo limpiar el contexto con `/clear` para asegurarte de que el agente trabaje con contexto fresco y sin residuos de sesiones anteriores. ¿Quieres que lo hagamos ahora?"

Wait for the user's response. If they confirm, stop and let them run `/clear`. If they decline, proceed to Step 1.

---

## Step 1 — Context Loading Gate

Ask the user for the following artifacts before proceeding. If any is missing, stop and request it explicitly:

1. **Story file** — path to the `.md` story file (e.g. `docs/epics/E-001_slug/stories/E-001_S-001_slug/E-001_S-001_slug.md`)
2. **spec.md** — path to the spec for this story
3. **plan.md + todo.md** — path to the plan and task list for this story

Once paths are provided, read all three files. Then verify:

- Epic exists: read `docs/epics/E-XXX_slug/epic.md` (infer from the story path)
- Acceptance criteria in the story file match the spec

If the story file, spec, or plan is missing, stop and tell the user:
> "Faltan artefactos de planificación. Ejecuta `/spec` y `/plan` antes de `/build`."

---

## Step 2 — Build Summary

Before writing any code, print a brief build plan:

```
STORY:   E-XXX_S-YYY — {title}
EPIC:    E-XXX — {epic title}
STACK:   {detected stacks}
TASKS:   {N} pending from todo.md
NEXT:    {first pending task from todo.md}
```

State any assumptions explicitly and wait for confirmation before proceeding.

---

## Chaining Rules

**Auto-apply within this command** (no need to ask the user):

| Skill | When |
|-------|------|
| `dev-incremental-implementation` | Always — primary execution skill for /build |
| `dev-test-driven-development` | Always — tests are part of every build increment |
| `dev-debugging-and-error-recovery` | Any build step, test, or type check fails |
| `dev-browser-testing-with-devtools` | Change involves browser-rendered code (React, Next.js pages, UI components) |

**Suggest to the user when the increment is complete** (do not auto-invoke):

> "Increment committed. When you're ready, run `/review` (`dev-code-review-and-quality`)."

---

## Step 3 — Incremental Execution

Invoke the `dev-incremental-implementation` skill alongside `dev-test-driven-development`.

Pick the next pending task from `todo.md`. For each task:

1. Read the task's acceptance criteria from `spec.md`
2. Load relevant context (existing code, patterns, types)
3. Write a failing test for the expected behavior (RED)
4. Implement the minimum code to pass the test (GREEN)
5. Run the full test suite to check for regressions
6. Run the build to verify compilation
7. Commit with a descriptive message
8. Mark the task complete in `todo.md` and move to the next one

If any step fails, follow the `dev-debugging-and-error-recovery` skill.
