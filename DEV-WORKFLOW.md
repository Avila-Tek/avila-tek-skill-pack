# DEV-WORKFLOW.md — Development Workflow with Claude

This document defines the complete development workflow for building features using Claude's slash commands.

> Claude MUST follow this workflow. Commands reference this file for artifact locations and gates.
>
> For the full skill reference (every command explained in detail), see [DEV.md](DEV.md).

---

## Lifecycle

```
DEFINE        PLAN          BUILD         VERIFY        REVIEW        SHIP
  |             |             |             |             |             |
/spec         /plan         /build        /test        /review       /ship
                                                       /code-simplify
```

Each phase has a **gate** — do not advance until the gate is met.

---

## Artifact structure

### With planning track (story file exists)

When the Tech Lead has run the planning skills, artifacts live inside the story folder:

```
docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/
  E-XXX_S-YYY_slug.md   ← story file (planning output — do not modify)
  spec.md               ← /spec output
  plan.md               ← /plan output
  todo.md               ← /plan output
```

### Without planning track (standalone feature)

When there is no story file, artifacts live under `docs/features/<feature>/`:

```
docs/features/<feature>/
  spec.md        ← /spec output
  plan.md        ← /plan output
  todo.md        ← /plan output
```

**Naming conventions for `<feature>`:**
- Use kebab-case: `auth`, `payments`, `user-profile`, `order-tracking`
- If the feature maps to a ticket, use the ticket ID: `TASK-379`

**Examples:**
```
docs/features/auth/spec.md
docs/features/TASK-420/plan.md
```

---

## Phase 1 — DEFINE (`/spec`)

**Goal:** Write a structured specification before writing any code.

**Usage:**
```
/spec
/spec <feature-name>
```

**What Claude does:**

*With story file (Story-Driven Mode — activates silently):*
1. Reads the story file completely (Block A + Block B)
2. Maps story sections to spec sections (ACs → Success Criteria, Technical Scope → Boundaries, etc.)
3. Asks only about gaps the story doesn't cover (build commands, test framework, code style)
4. Writes `spec.md` to the story folder

*Without story file (standard mode):*
1. Asks clarifying questions about: objective, users, acceptance criteria, tech stack, constraints, out-of-scope
2. Generates a spec covering 6 areas:
   - Objective and target users
   - Commands and tech stack
   - Project structure (where code lives)
   - Code style (with real snippets from the repo)
   - Testing strategy
   - Boundaries (always do / ask first / never do)
3. Saves to `docs/features/<feature>/spec.md`

**Gate to advance:**
- [ ] Spec is written and saved
- [ ] User has reviewed and approved the spec

---

## Phase 2 — PLAN (`/plan`)

**Goal:** Break the spec into small, verifiable tasks ordered by dependency.

**Usage:**
```
/plan
```

**What Claude does:**
1. Reads `spec.md` from the active feature folder
2. Enters read-only mode (no code changes during planning)
3. Identifies the dependency graph between components
4. Slices work **vertically** — each task delivers a complete path through the stack, not a horizontal layer
5. Writes tasks with acceptance criteria and verification steps
6. Adds checkpoints between phases
7. Presents the plan for human review
8. Saves:
   - `plan.md` — detailed plan with phases, task descriptions, ACs, and checkpoints
   - `todo.md` — flat executable checklist

**Task sizing:**

| Size | Files touched | Action |
|------|--------------|--------|
| S | 1–2 | Fine as-is |
| M | 3–5 | Fine — a complete vertical slice |
| L | 5–8 | Complex — consider splitting |
| XL+ | 8+ | Too large — must split |

**Gate to advance:**
- [ ] Plan is written with tasks ordered by dependency
- [ ] Each task has clear acceptance criteria
- [ ] User has reviewed and approved the plan

---

## Phase 3 — BUILD (`/build`)

**Goal:** Implement the next task from the plan incrementally.

**Usage:**
```
/build
```

**What Claude does:**
1. Reads the next pending task from `todo.md`
2. Loads relevant context (existing code, patterns, types)
3. Writes a failing test for the expected behavior **(RED)**
4. Implements the minimum code to pass the test **(GREEN)**
5. Runs the full test suite to check for regressions
6. Runs the build to verify compilation
7. Commits with a descriptive message
8. Marks the task as completed in `todo.md`

**Critical rules:**
1. **Simplicity first** — the simplest solution that works
2. **Scope discipline** — only touch what the task requires
3. **One thing at a time** — each increment changes one logical thing
4. **Always compilable** — after each increment, project builds and tests pass
5. **Feature flags** — incomplete features behind toggles when needed

**Cycle per task:**
```
Write failing test (RED)
  → Implement minimum code (GREEN)
    → Verify: tests pass + build compiles
      → Commit
        → Mark done in todo.md
          → Next task
```

**Auto-chaining (transparent — no action needed):**
- `dev-test-driven-development` — always active during build
- `dev-debugging-and-error-recovery` — auto-activates if test or build fails
- `dev-browser-testing-with-devtools` — auto-activates if UI/browser code is touched
- `dev-git-workflow-and-versioning` — applied on every commit

**Gate to advance:**
- [ ] All tasks from the plan are completed
- [ ] Typecheck passes
- [ ] Lint passes
- [ ] All relevant tests pass

---

## Phase 4 — VERIFY (`/test`)

**Goal:** Verify everything works with TDD and the Prove-It pattern for bugs.

**Usage:**
```
/test
```

**For new features:**
1. Write tests that describe expected behavior (they should FAIL first)
2. Implement code to make them pass
3. Refactor while keeping tests green

**For bug fixes (Prove-It pattern):**
1. Write a test that reproduces the bug (must FAIL)
2. Confirm the test fails for the right reason (bug is real)
3. Implement the fix
4. Confirm the test now passes
5. Run the full test suite to catch regressions

**Gate to advance:**
- [ ] Tests cover the acceptance criteria from the spec
- [ ] All tests pass
- [ ] No regressions introduced

---

## Phase 5 — REVIEW (`/review` + `/code-simplify`)

**Goal:** Quality review before merge.

**Usage:**
```
/review
/code-simplify
```

### `/review` — Five-axis review

| Axis | What it evaluates |
|------|-------------------|
| **Correctness** | Matches spec? Edge cases handled? Error paths correct? ACs covered by tests? |
| **Readability** | Clear names? Straightforward logic? Well-organized? |
| **Architecture** | Follows existing patterns? Clean layer boundaries? Right abstraction level? |
| **Security** | Input validated? Secrets safe? Auth/authz enforced? No injection risks? |
| **Performance** | N+1 queries? Unbounded operations? Unnecessary re-renders? Bundle regressions? |

**Severity labels:**
- **Critical** — must fix before merge (security bugs, correctness failures, broken contracts)
- **Important** — should fix before merge (architecture violations, performance issues)
- **Suggestion** — worth discussing (style, naming, alternative approaches)
- **Nitpick** — optional

Every finding includes: axis, severity, `file:line` reference, problem description, and a concrete suggested fix.

**Auto-chaining (transparent):**
- `dev-security-and-hardening` — auto-activates if security findings appear
- `dev-performance-optimization` — auto-activates if performance findings appear

### `/code-simplify` — Simplification

Reduces complexity without changing behavior. Targets:
- Deep nesting → guard clauses
- Long functions → split by single responsibility
- Nested ternaries → if/else
- Generic names (`data`, `result`, `temp`) → descriptive names
- Dead code → remove
- Duplicated logic → shared functions

**Rule:** Tests must pass before and after. Never changes behavior.

**Gate to advance:**
- [ ] No Critical findings pending
- [ ] Important findings resolved or explicitly accepted with justification
- [ ] Code simplified where applicable

---

## Phase 6 — SHIP (`/ship`)

**Goal:** Pre-production checklist and deployment.

**Usage:**
```
/ship
```

**6-area checklist:**

| Area | What it verifies |
|------|-----------------|
| **Code Quality** | Tests pass, build clean, lint clean, no TODOs, no `console.log` left |
| **Security** | Dependency audit clean, no secrets in code, auth/authz in place, security headers configured |
| **Performance** | Core Web Vitals within budget, no N+1 queries, images optimized, bundle size controlled |
| **Accessibility** | Keyboard navigation works, screen reader labels present, WCAG 2.1 AA contrast |
| **Infrastructure** | Env vars set in target environment, DB migrations ready, monitoring configured, health checks working |
| **Documentation** | README updated, ADRs written for decisions made, changelog entry added |

**Output:** Pass/fail report for all 6 areas + rollback plan before proceeding.

**Final gate:**
- [ ] All 6 areas verified (or failures documented with accepted risk)
- [ ] Rollback plan defined
- [ ] Branch pushed and PR created

---

## Full example flow

```
1.  /spec auth
    → Claude asks questions (or reads story file silently)
    → Saved to docs/features/auth/spec.md (or story folder)
    → User reviews and approves

2.  /plan
    → Claude reads spec, generates plan and tasks
    → Saved to plan.md and todo.md
    → User reviews and approves

3.  /build  (repeat for each task)
    → Claude picks next task, writes failing test, implements, commits
    → Marks task done in todo.md

4.  /test
    → Verify coverage
    → Prove-It pattern for any bugs found

5.  /review
    → Five-axis review
    → Resolve Critical and Important findings

6.  /code-simplify
    → Clean up without changing behavior

7.  /ship
    → Six-area pre-production checklist
    → Rollback plan defined
    → PR created
```

---

## General rules

1. **No code without an approved spec**
2. **No implementation without an approved plan**
3. **Every task is verified before advancing** — typecheck + lint + tests
4. **Atomic commits** — each commit does one logical thing
5. **Descriptive commit messages** — explain the "why", not just the "what"
6. **Never advance a phase with a failing gate** — fix the gate, then move on
