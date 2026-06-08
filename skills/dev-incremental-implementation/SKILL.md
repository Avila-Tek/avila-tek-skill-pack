---
name: incremental-implementation
description: >
  Delivers changes incrementally. Use when implementing any feature or change that touches more than one file. Use when you're about to write a large amount of code at once, or when a task feels too big to land in one step. Spanish triggers: "implementa esto", "construye esto paso a paso", "implementación incremental".
---

# Incremental Implementation

## Stack Activation Gate

Detect the active stack from the project's package files. State it explicitly: "Active stack: {name}".

| Stack | Detection signal |
|-------|-----------------|
| NestJS | `@nestjs/core` in `package.json` |
| Next.js | `next` in `package.json` (not Angular, not React Native) |
| Go | `go.mod` present |
| Spring Boot | `pom.xml` or `build.gradle` containing `spring-boot` |
| React Native | `react-native` in `package.json` |
| Flutter | `pubspec.yaml` containing `flutter:` |
| Angular | `angular.json` present or `@angular/core` in `package.json` |

**Required before any code output — do not skip:**
1. Derive the skill directory from the path this SKILL.md was loaded from.
2. Read the matching reference file from the sibling skill:
   - NestJS → `../dev-api-and-interface-design/references/nestjs.md`
   - Next.js → `../dev-frontend-ui-engineering/references/nextjs.md`
   - Go → `../dev-api-and-interface-design/references/go.md`
   - Spring Boot → `../dev-api-and-interface-design/references/spring-boot.md`
   - React Native → `../dev-frontend-ui-engineering/references/react-native.md`
   - Flutter → `../dev-frontend-ui-engineering/references/flutter.md`
   - Angular → `../dev-frontend-ui-engineering/references/angular.md`
3. Apply the patterns from that file and run its Verification Checklist before completing any output.

> Before each slice: check the Red Flags section of the loaded reference. If any hit, fix before proceeding. Run the full Verification Checklist when the last slice is complete.

## Overview

Build in thin vertical slices — implement one piece, test it, verify it, then expand. Avoid implementing an entire feature in one pass. Each increment should leave the system in a working, testable state. This is the execution discipline that makes large features manageable.

## Before You Start: Load the Shared Inventory

Each implementation session is stateless — it does not remember helpers written in earlier stories. To substitute for that missing memory, load the shared-code index once at the start:

1. Read `docs/shared-inventory.md` if it exists — a generated, one-line-per-export index of everything in `shared/` and `packages/`. This is cheap (~tens of lines) and tells you what already exists without scanning the repo.
2. If it does not exist, fall back to a scoped listing of shared locations (`shared/`, `packages/*/src`, `lib/`) — filenames and exports only, not file bodies.

The inventory is your reuse map for the whole session. Consult it during every Reuse Scan before reaching for `rg`. (See `dev-context-engineering` for the inventory format and `dev-harness-eslint` for how it is generated.)

## When to Use

- Implementing any multi-file change
- Building a new feature from a task breakdown
- Refactoring existing code
- Any time you're tempted to write more than ~100 lines before testing

**When NOT to use:** Single-file, single-function changes where the scope is already minimal.

## Prototype Mode

Use before The Increment Cycle when you don't yet know if an approach will work.

**When to prototype:**
- The technical approach is uncertain (new library, novel pattern, unclear feasibility)
- You need to explore two competing implementations before committing to one
- A core assumption needs to be validated before building on it

**Rules for prototype code:**
- Mark files clearly: `// PROTOTYPE — delete before merging`
- No tests, no error handling, no production-quality naming required
- Single command to run — no setup steps
- In-memory or ephemeral state only — no schema changes, no migrations

**After prototyping:**
1. Capture the finding in a single note: what worked, what didn't, which approach to use and why
2. Delete all prototype code before starting the real implementation
3. Begin The Increment Cycle with the validated approach

If the prototype fails: that's the point. Fail fast, learn, try the next approach. Do not preserve prototype code "just in case" — it creates confusion about what is real.

## The Increment Cycle

```
┌──────────────────────────────────────────────────────┐
│                                                      │
│  RED ─→ SCAN ─→ GREEN ─→ CLEAN ─→ Verify ──┐         │
│   ▲                                        │         │
│   └──────────────── Commit ◄───────────────┘         │
│                        │                             │
│                        ▼                             │
│                   Next slice                         │
│                                                      │
└──────────────────────────────────────────────────────┘
```

For each slice:

1. **RED** — write a failing test for the expected behavior. The test must fail before any implementation begins. A test that passes immediately proves nothing.
2. **SCAN** — before writing any helper, util, mapper, validator, formatter, or domain function, run the **Reuse Scan** (see below). Search for an existing implementation, then decide: adopt / extend / promote / build. Emit the evidence. Skip only for code that is obviously unique to this slice.
3. **GREEN** — write the minimum code to make the test pass, **placed per the Reuse Scan decision** (a new generic helper goes in `shared/`, not the feature folder). Resist the urge to write more than what the test requires.
4. **CLEAN** — tidy without changing behavior, then run the **Clean Step Checklist** (see below) to catch size/complexity/duplication before it compounds. Run tests after every change to confirm they stay green.
5. **Verify** — run the project's test, build, and lint commands to confirm no regressions. Lint enforces the mechanical limits (file/function size, layer & cross-feature import boundaries) — a lint failure means the slice is not done.
6. **Commit** — save progress with a descriptive message (see `git-workflow-and-versioning` for atomic commit guidance). If the slice added or changed a `shared/`/`packages/` export, regenerate the shared inventory first (see below).
7. **Move to the next slice** — carry forward, don't restart.

## Reuse Scan

The most common duplication failure is a fresh session re-writing a helper that already exists in `shared/` or `packages/`. The fix is a mandatory search before writing any reusable-shaped code (helper, util, mapper, validator, formatter, parser, domain function).

**Run the scan:**

1. Check the shared inventory you loaded at session start.
2. If not found there, grep the shared locations for the concept (name + likely synonyms), reading signatures, not bodies:
   ```
   rg -i "formatcurrency|formatmoney|currency" shared/ packages/ src/lib/
   ```
3. Emit the evidence and the decision before writing code:
   ```
   REUSE SCAN — before writing `formatCurrency`:
     inventory: no match
     rg → packages/utils/money.ts: formatMoney(cents: number): string
   DECISION: reuse formatMoney. Not writing a new helper.
   ```

**Decision matrix:**

| Search result | Action |
|---|---|
| Exact match exists | Import it. Do not re-implement. |
| Close match (needs a tweak) | Extend the existing one in place (add a parameter/overload) — don't fork. |
| No match, **pure technical helper** (formatter, parser, validator — zero feature-specific logic) | Write it **directly in `shared/`/`packages/`** on first use, not in the feature folder. |
| No match, **UI or domain code** | Keep it colocated in the feature. Promote to `shared/` only when a 2nd feature needs it. |
| No match, feature-specific anything | Keep it colocated in the feature. |

**Placement rule (why first-write promotion is split):** A pure technical helper has no feature coupling, so the next stateless session will re-create it unless it lives in `shared/` now — promote it on first write. UI and domain code often *looks* generic but carries feature assumptions, so the "wait for the 2nd use" rule still applies there to avoid premature abstraction. When in doubt whether something is a pure helper, keep it colocated and let the next Reuse Scan promote it.

This overrides the "always wait for 2 uses" guidance in `import-boundaries.md` **only** for pure technical helpers. Cross-feature and cross-layer import boundaries are enforced by lint (see `dev-harness-eslint`), so a misplaced import fails the Verify step regardless of session memory.

## Clean Step Checklist

The CLEAN step is where size and complexity get controlled before they compound across slices. The numeric thresholds are defined once in `dev-code-simplification` — this checklist references them; it does not restate the numbers. Lint hard-enforces the mechanical ones during Verify (warn-first on existing repos), so this checklist is the early catch, not the gate.

After GREEN, before Verify, check the slice:

```
CLEAN CHECKLIST:
□ Any function over the size threshold?   → split into focused functions (lint: max-lines-per-function)
□ Any file over its budget?               → extract a module (lint: max-lines)
□ Nesting deeper than 3 levels?           → guard clauses / early returns (lint: max-depth)
□ 5+ duplicated lines?                     → extract, then run the Reuse Scan on the extraction target
□ Generic name (data, result, temp)?       → rename to describe content
□ New shared/ or packages/ export?         → add a one-line doc comment, regenerate the inventory
```

See `dev-code-simplification` for the threshold definitions and the over-simplification traps to avoid.

## Slicing Strategies

### Vertical Slices (Preferred)

Build one complete path through the stack:

```
Slice 1: Create a task (DB + API + basic UI)
    → Tests pass, user can create a task via the UI

Slice 2: List tasks (query + API + UI)
    → Tests pass, user can see their tasks

Slice 3: Edit a task (update + API + UI)
    → Tests pass, user can modify tasks

Slice 4: Delete a task (delete + API + UI + confirmation)
    → Tests pass, full CRUD complete
```

Each slice delivers working end-to-end functionality.

### Contract-First Slicing

When backend and frontend need to develop in parallel:

```
Slice 0: Define the API contract (types, interfaces, OpenAPI spec)
Slice 1a: Implement backend against the contract + API tests
Slice 1b: Implement frontend against mock data matching the contract
Slice 2: Integrate and test end-to-end
```

### Risk-First Slicing

Tackle the riskiest or most uncertain piece first:

```
Slice 1: Prove the WebSocket connection works (highest risk)
Slice 2: Build real-time task updates on the proven connection
Slice 3: Add offline support and reconnection
```

If Slice 1 fails, you discover it before investing in Slices 2 and 3.

## Implementation Rules

### Rule 0: Simplicity First

Before writing any code, ask: "What is the simplest thing that could work?"

After writing code, review it against these checks:
- Can this be done in fewer lines?
- Are these abstractions earning their complexity?
- Would a staff engineer look at this and say "why didn't you just..."?
- Am I building for hypothetical future requirements, or the current task?

```
SIMPLICITY CHECK:
✗ Generic EventBus with middleware pipeline for one notification
✓ Simple function call

✗ Abstract factory pattern for two similar components
✓ Two straightforward components with shared utilities

✗ Config-driven form builder for three forms
✓ Three form components
```

Three similar lines of code is better than a premature abstraction. Implement the naive, obviously-correct version first. Optimize only after correctness is proven with tests.

### Rule 0.5: Scope Discipline

Touch only what the task requires.

Do NOT:
- "Clean up" code adjacent to your change
- Refactor imports in files you're not modifying
- Remove comments you don't fully understand
- Add features not in the spec because they "seem useful"
- Modernize syntax in files you're only reading

If you notice something worth improving outside your task scope, note it — don't fix it:

```
NOTICED BUT NOT TOUCHING:
- src/utils/format.ts has an unused import (unrelated to this task)
- The auth middleware could use better error messages (separate task)
→ Want me to create tasks for these?
```

### Rule 1: One Thing at a Time

Each increment changes one logical thing. Don't mix concerns:

**Bad:** One commit that adds a new component, refactors an existing one, and updates the build config.

**Good:** Three separate commits — one for each change.

### Rule 2: Keep It Compilable

After each increment, the project must build and existing tests must pass. Don't leave the codebase in a broken state between slices.

### Rule 3: Feature Flags for Incomplete Features

If a feature isn't ready for users but you need to merge increments:

```typescript
// Feature flag for work-in-progress
const ENABLE_TASK_SHARING = process.env.FEATURE_TASK_SHARING === 'true';

if (ENABLE_TASK_SHARING) {
  // New sharing UI
}
```

This lets you merge small increments to the main branch without exposing incomplete work.

### Rule 4: Safe Defaults

New code should default to safe, conservative behavior:

```typescript
// Safe: disabled by default, opt-in
export function createTask(data: TaskInput, options?: { notify?: boolean }) {
  const shouldNotify = options?.notify ?? false;
  // ...
}
```

### Rule 5: Rollback-Friendly

Each increment should be independently revertable:

- Additive changes (new files, new functions) are easy to revert
- Modifications to existing code should be minimal and focused
- Database migrations should have corresponding rollback migrations
- Avoid deleting something in one commit and replacing it in the same commit — separate them

## Working with Agents

When directing an agent to implement incrementally:

```
"Let's implement Task 3 from the plan.

Start with just the database schema change and the API endpoint.
Don't touch the UI yet — we'll do that in the next increment.

After implementing, run `npm test` and `npm run build` to verify
nothing is broken."
```

Be explicit about what's in scope and what's NOT in scope for each increment.

## Increment Checklist

After each increment, verify:

- [ ] The change does one thing and does it completely
- [ ] All existing tests still pass (`npm test`)
- [ ] The build succeeds (`npm run build`)
- [ ] Type checking passes (`npx tsc --noEmit`)
- [ ] Linting passes (`npm run lint`)
- [ ] The new functionality works as expected
- [ ] The change is committed with a descriptive message
## Red Flags

- More than 100 lines of code written without running tests
- Multiple unrelated changes in a single increment
- "Let me just quickly add this too" scope expansion
- Skipping RED (writing the failing test) and going straight to implementation
- Writing a helper/util/validator without running the Reuse Scan first
- A new pure technical helper placed in a feature folder instead of `shared/`/`packages/`
- A `shared/`/`packages/` export added without a doc comment or without regenerating the inventory
- Build or tests broken between increments
- Large uncommitted changes accumulating
- Building abstractions before the third use case demands it
- Touching files outside the task scope "while I'm here"
- Creating new utility files for one-time operations

## Verification

After completing all increments for a task:

- [ ] Each increment was individually tested and committed
- [ ] The full test suite passes
- [ ] The build is clean
- [ ] The feature works end-to-end as specified
- [ ] No uncommitted changes remain

## Story Update Gate

After all increments are complete, check if a story file exists in the story folder (`E-XXX_S-YYY_slug.md`).

If yes, run a final verification: compare the story's Block A, Block B, and Open Questions against `spec.md`, `plan.md`, `todo.md`, and recent commits. Identify any fields that diverged from what was actually built.

If differences are found, report them to the dev:
> "Implementation complete. The following story fields appear to be out of date:
> - {field}: {what the story says} → {what was actually built}
> - ...
> Run `planning-4-epic-and-stories-generator` Update Mode to sync the story."

If no differences are found:
> "Implementation complete. Story S-XXX is up to date."

Do not update the story automatically.

## Next Step

When all increments are complete, suggest to the user:
> "Implementation complete. When you're ready, run `/review` to review the change (`dev-code-review-and-quality`)."

Do not invoke `/review` automatically.
