---
name: plan
description: Break work into small verifiable tasks with acceptance criteria and dependency ordering
---

Invoke the agent-skills:planning-and-task-breakdown skill.

Read the existing spec (SPEC.md or equivalent) and the relevant codebase sections. Then:

1. Enter plan mode — read only, no code changes
2. Identify the dependency graph between components
3. Slice work vertically (one complete path per task, not horizontal layers)
4. Write tasks with acceptance criteria and verification steps
5. Add checkpoints between phases
6. Present the plan for human review

**Output paths:**

- With a story file: save to `docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/plan.md` and `todo.md` in the same folder.
- Without a story file (standalone spec): save to `plan.md` and `todo.md` in the project root (or wherever `SPEC.md` lives).
