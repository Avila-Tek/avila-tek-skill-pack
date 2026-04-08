---
description: Implement the next task incrementally — build, test, verify, commit
---

## Chaining Rules

**Auto-apply within this command** (no need to ask the user):

| Skill | When |
|-------|------|
| `dev-test-driven-development` | Always — tests are part of every build increment |
| `dev-debugging-and-error-recovery` | Any build step, test, or type check fails |
| `dev-browser-testing-with-devtools` | Change involves browser-rendered code (React, Next.js pages, UI components) |

**Suggest to the user when the increment is complete** (do not auto-invoke):

> "Increment committed. When you're ready, run `/review` (`dev-code-review-and-quality`)."

Invoke the agent-skills:incremental-implementation skill alongside agent-skills:test-driven-development.

Pick the next pending task from the plan. For each task:

1. Read the task's acceptance criteria
2. Load relevant context (existing code, patterns, types)
3. Write a failing test for the expected behavior (RED)
4. Implement the minimum code to pass the test (GREEN)
5. Run the full test suite to check for regressions
6. Run the build to verify compilation
7. Commit with a descriptive message
8. Mark the task complete and move to the next one

If any step fails, follow the agent-skills:debugging-and-error-recovery skill.
