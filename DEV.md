# Dev Track — Complete Guide

> **Audience:** Developer
> **Goal:** Implement a story in a structured way — spec → plan → code → review → ship.

This document is the authoritative reference for the Dev Track. The [README](README.md) gives you the overview; read this file to understand every command's behavior, how auto-chaining works, Story-Driven Mode, and when to invoke each skill before you start implementing.

---

## The Dev Track Works With or Without Planning

**With a story file** (the Tech Lead ran planning skills 0–5): A story file exists at `docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/E-XXX_S-YYY_slug.md`. This is your primary input. `/spec` reads it and enters Story-Driven Mode — you skip most clarifying questions because the story already contains the acceptance criteria, technical scope, and business rules.

**Without a story file** (external repo, greenfield task, no planning track): `/spec` runs in standard mode — asks about objective, users, features, stack, constraints, and boundaries, then generates the spec from scratch. Every other command works exactly the same.

The dev workflow is identical in both cases. The story file just eliminates Q&A redundancy.

---

## Three Activation Mechanisms

### 1. Slash commands — explicit invocation

The main entry points for the dev workflow.

| Command | What it does |
|---|---|
| `/spec` | Write a spec before writing code |
| `/plan` | Break the spec into ordered tasks |
| `/build` | Implement the next task incrementally |
| `/review` | Five-axis code review before merging |
| `/test` | TDD workflow — write tests first |
| `/ship` | Pre-launch checklist before production |
| `/code-simplify` | Simplify code without changing behavior |

### 2. Auto-chaining — transparent

When you run a command, Claude activates secondary skills automatically based on what happens. You never need to invoke them manually.

```
/build
  ├── always chains:        dev-test-driven-development
  ├── if something fails:   dev-debugging-and-error-recovery  (auto)
  ├── on commit:            dev-git-workflow-and-versioning    (auto)
  └── if browser/UI code:   dev-browser-testing-with-devtools  (auto)

/review
  ├── if security finding:     dev-security-and-hardening      (auto)
  └── if performance finding:  dev-performance-optimization    (auto)
```

Think of it as a GP who refers to specialists. You talk to `/build`; `/build` routes to `debugging`, `security`, or `devtools` based on what surfaces.

### 3. Natural language — contextual

All skills also activate when you describe the situation in plain language:

```
"there's a memory leak in this component"    → dev-performance-optimization
"I want to migrate from REST to GraphQL"     → dev-deprecation-and-migration
"write an ADR for this decision"             → dev-documentation-and-adrs
"design the API for this feature"            → dev-api-and-interface-design
"set up the CI pipeline"                     → dev-ci-cd-and-automation
"I want to explore the approach first"       → dev-idea-refine
"this test is failing"                       → dev-debugging-and-error-recovery
```

---

## Story-Driven Mode (with planning artifacts)

When the Tech Lead generated stories with planning skill-5, you start here:

```
docs/epics/E-002_auth/stories/E-002_S-001_sign_up/
└── E-002_S-001_sign_up.md    ← start here
```

### What the story file contains

The story has two blocks:

**Block A** — read before estimating:
- Section 1: User Story ("As a [role], I want [action] so that [outcome]")
- Section 2: Acceptance Criteria — numbered, testable conditions
- Section 3: Ranked Tasks (Must / Important / Optional / Nice to have)

**Block B** — consult during implementation:
- Section 4: Technical Scope (API endpoints, DB changes, auth, config)
- Section 5: Business Rules (references to Spec Funcional: BR-001, BR-002…)
- Section 6: Data Model (schema changes for this story)
- Section 7: Telemetry (events and metrics)
- Section 8: Testing Guidance (unit, integration, E2E expectations)

### Story → Spec mapping

When `/spec` runs in Story-Driven Mode, it maps story sections to spec sections:

| Story section | Spec section |
|---|---|
| Section 1 — User Story | Objective |
| Section 2 — Acceptance Criteria | Success Criteria |
| Section 3 — Ranked Tasks | base for Tasks |
| Section 4 — Technical Scope | Tech Stack + Boundaries |
| Section 5 — Business Rules | Boundaries (constraints) |
| Section 6 — Data Model | Project Structure (if schema changes) |

Claude **only asks about gaps the story doesn't cover** (e.g. build commands, test framework, code style). It does not ask about scope, ACs, or technical boundaries already defined in the story.

### Step-by-step workflow

```
                    Story file
                        │
                 ┌──────▼───────┐
      /spec       │              │  Reads Block A + Block B
 Story-Driven     │   spec.md    │  Maps story sections to spec template
     Mode         │              │  Asks only about uncovered gaps
                  └──────┬───────┘  Writes spec.md in the story folder
                         │
                  ┌──────▼───────┐
      /plan        │              │  Reads spec.md
                   │   plan.md    │  Decomposes into ordered tasks
                   │   todo.md    │  Each task: one vertical slice
                  └──────┬───────┘  Writes plan.md + todo.md in story folder
                         │
                  ┌──────▼───────┐
      /build       │              │  Reads spec.md + plan.md
                   │   Code       │  Implements task by task
                   │   Tests      │  RED → GREEN → REFACTOR → commit
                  └──────┬───────┘  Iterates until all tasks complete
                         │
                  ┌──────▼───────┐
      /review      │              │  Verifies each AC from story Section 2
                   │   Review     │  Five-axis review (see below)
                  └──────────────┘  Outputs structured findings with file:line refs
```

### All artifacts for a story live together

```
docs/epics/E-002_auth/stories/E-002_S-001_sign_up/
├── E-002_S-001_sign_up.md    ← story file (planning output — do not modify)
├── spec.md                   ← /spec
├── plan.md                   ← /plan
└── todo.md                   ← /plan
```

---

## Skills Reference — Commands

---

### `dev-spec-driven-development` → `/spec`

Writes a structured spec before any code. The spec is the shared source of truth between the developer and Claude — it defines what is being built, why, and how you'll know it's done.

#### With story file (Story-Driven Mode)
- Reads the story file completely
- Maps all available sections to the spec template
- Only asks about gaps (build commands, test framework, code style)
- Never asks about scope, ACs, or technical boundaries already in the story
- Activates silently — no announcement needed

#### Without story file (standard mode)
Asks about:
1. Objective — what problem does this solve?
2. Users — who uses it and in what role?
3. Core features — what are the must-have capabilities?
4. Tech stack — what languages, frameworks, libraries?
5. Constraints — performance, security, compatibility limits
6. Out of scope — what explicitly isn't included?

#### Output format
The spec covers: objective, users, core features, success criteria, tech stack, project structure, constraints, and open questions.

| | |
|---|---|
| **Output** | `spec.md` (in story folder if it exists, otherwise where specified) |

---

### `dev-planning-and-task-breakdown` → `/plan`

Decomposes the spec into small, verifiable tasks with explicit acceptance criteria and dependency order.

#### Vertical slicing

Each task delivers a complete path through the stack — not a horizontal layer. A task is never "write the database schema" — it's "user can create an account: POST /auth/register returns 201 with user ID, unit test passes, migration runs". This means every task produces something runnable.

#### Task sizing rule

No task should touch more than ~5 files. If it does, decompose it further.

#### Output structure

`plan.md` — the full plan with phases, task descriptions, ACs per task, and checkpoints.

`todo.md` — a flat checklist of tasks for quick progress tracking:
```markdown
- [ ] Task 1: POST /auth/register endpoint
- [ ] Task 2: Password hashing with bcrypt
- [ ] Task 3: JWT token generation on login
...
```

| | |
|---|---|
| **Input** | Approved `spec.md` |
| **Output** | `plan.md` + `todo.md` (in story folder) |

---

### `dev-incremental-implementation` → `/build`

Implements in thin vertical slices: one piece, test it, verify it, commit it, then the next. Each increment leaves the system in a functional and testable state.

#### The increment cycle

```
1. Read the next task from plan.md
2. Write the failing test (RED)
3. Implement the minimum code to pass it (GREEN)
4. Refactor for clarity (REFACTOR)
5. Verify: run tests, check linting
6. Commit with a clear message
7. Mark task complete in todo.md
8. Repeat
```

#### Auto-chaining from /build

- **Always:** `dev-test-driven-development` — write the failing test before any implementation
- **If test or build fails:** `dev-debugging-and-error-recovery` activates automatically
- **If browser/UI code:** `dev-browser-testing-with-devtools` activates automatically
- **On commit:** follows `dev-git-workflow-and-versioning` standards

#### Rule

Never write more than ~100 lines without running tests. If the tests aren't green, don't move on.

| | |
|---|---|
| **Input** | `spec.md` + `plan.md` |
| **Output** | Code + tests committed, `todo.md` updated |

---

### `dev-test-driven-development` → `/test` · auto-chained from `/build`

Test-driven development: write the failing test first, then implement the minimum code to pass it, then refactor.

#### The RED → GREEN → REFACTOR cycle

**RED:** Write a test that fails because the feature doesn't exist yet. The test should be as specific as possible — test one behavior.

**GREEN:** Write the minimum implementation to make the test pass. Resist the urge to write "complete" code here. Minimal is correct.

**REFACTOR:** Now that the test is green and behavior is locked, clean the code. Extract, rename, simplify. Tests stay green throughout.

#### Bug fix pattern — Prove-It

When fixing a bug:
1. Write a test that reproduces the bug (it will fail)
2. Confirm the test fails for the right reason
3. Fix the bug
4. Confirm the test now passes
5. Check no other tests broke

This proves the bug existed, proves the fix works, and prevents regression.

---

### `dev-code-review-and-quality` → `/review`

Multi-axis code review: Correctness, Readability, Architecture, Security, Performance. In projects with a story file, also verifies that every Acceptance Criterion (Block A, Section 2) is covered by tests and implementation.

#### The five axes

| Axis | What it checks |
|---|---|
| **Correctness** | Does the code do what the spec says? Are edge cases handled? Are error paths correct? |
| **Readability** | Is the intent obvious from the code? Are names clear? Is complexity justified? |
| **Architecture** | Does this fit the existing architecture? Are layer boundaries respected? Is the abstraction level appropriate? |
| **Security** | Is user input validated? Are secrets handled correctly? Are auth/authz rules enforced? Any injection risks? |
| **Performance** | Any N+1 queries? Unbounded loops? Unnecessary re-renders? Bundle size regressions? |

#### Severity labels

- **Critical** — must fix before merge (security, correctness bugs, broken contracts)
- **Important** — should fix before merge (architecture violations, performance issues)
- **Suggestion** — worth discussing (style, naming, alternative approaches)

#### Output format

Every finding includes:
- Axis label
- Severity label
- `file:line` reference
- Description of the problem
- Suggested fix (concrete, not vague)

#### AC verification (Story-Driven Mode)

When a story file exists, `/review` runs through each numbered AC in Section 2 and confirms:
- A test covers it
- The implementation satisfies it
- The behavior is observable in the running system

| | |
|---|---|
| **Auto-chains** | `dev-security-and-hardening` on security findings |
| **Auto-chains** | `dev-performance-optimization` on performance findings |

---

### `dev-code-simplification` → `/code-simplify`

Refactors code for clarity without changing behavior. Targets: unnecessary abstraction, code that is harder to read than it needs to be, accumulated complexity.

#### What it looks for

- Abstractions with only one call site
- Functions doing more than one thing
- Names that require context to understand
- Code that can be replaced by a standard library call
- Nested logic that can be flattened

#### Rule

Tests must pass before and after. Never changes behavior. If a simplification would require changing a test, the simplification is wrong.

---

### `dev-shipping-and-launch` → `/ship`

Pre-launch checklist before going to production. Runs through every category and produces a pass/fail report plus a rollback plan.

#### Checklist categories

| Category | What it checks |
|---|---|
| **Code Quality** | All tests passing, build clean, linting green, no dead code |
| **Security** | Dependency audit, no secrets in code, auth/authz verified, input validation in place |
| **Performance** | Core Web Vitals within budget, N+1 queries resolved, bundle size within limits |
| **Accessibility** | Keyboard navigation, screen reader labels, color contrast |
| **Infrastructure** | Env vars set, DB migrations run, monitoring configured, health checks working |
| **Documentation** | README updated, ADRs written for decisions, changelog entry added |

#### Output

A report showing passing/failing checks, with action items for any failures, plus a rollback plan before proceeding.

---

## Skills Reference — Automatic and Natural Language

These skills activate without a slash command — via auto-chaining or natural language.

---

### `dev-debugging-and-error-recovery`

Systematic root-cause debugging. Diagnoses why tests fail, builds break, or behavior doesn't match expectations. Structured approach: reproduce → isolate → identify cause → fix → verify. Never guess-and-patch.

**Auto-activated:** When `/build` encounters a failure.

**Natural language:** "this test is failing", "the build broke", "fix this error", "why is this crashing"

#### The debugging loop

```
1. Reproduce the failure reliably
2. Read the error message carefully — the answer is usually there
3. Isolate: find the smallest code change that triggers the failure
4. Identify the root cause (not the symptom)
5. Fix the root cause
6. Verify: the failing test now passes, no other tests broke
```

---

### `dev-security-and-hardening`

Security review and hardening for code that handles user input, authentication, data storage, or external integrations. Checks: input validation, secret handling, auth/authz, SQL injection, XSS, dependency vulnerabilities.

**Auto-activated:** From `/review` when security findings appear.

**Natural language:** "security review", "is this input safe", "harden this endpoint", anything touching auth/authz, secrets, or user-controlled data

#### Common checks

- User input validated and sanitized before use
- Secrets in environment variables, not in code
- Parameterized queries, never string concatenation in SQL
- Auth guards on all protected routes
- Rate limiting on sensitive endpoints
- Dependencies audited for known CVEs

---

### `dev-performance-optimization`

Profiling and performance optimization. Targets: N+1 queries, unbounded operations, Core Web Vitals, load times, memory leaks. **Measure before optimizing — never guess.**

**Auto-activated:** From `/review` when performance findings appear.

**Natural language:** "this is slow", "optimize this query", "memory leak", "Core Web Vitals", "bundle is too big"

#### Rule

Always establish a baseline metric before changing anything. "Feels slow" is not a metric. Profile first to find the actual bottleneck, then optimize that specific thing.

---

### `dev-api-and-interface-design`

Design stable APIs and module boundaries. Covers: REST and GraphQL endpoint design, type contracts between modules, frontend/backend boundaries, versioning strategies. Emphasizes stability — a poorly designed API is expensive to change.

**Natural language:** "design this API", "what should this interface look like", "define the contract", "REST endpoint design"

#### Key principles

- Resource-oriented URLs (nouns, not verbs)
- Consistent error response shape
- Versioning strategy decided up front (URI path, header, or query param)
- Input/output types documented and enforced
- Breaking changes require a deprecation plan

---

### `dev-frontend-ui-engineering`

Building production-quality UIs. Covers: component architecture, state management, layout, performance (re-renders, bundle size), basic accessibility, and the gap between AI-generated UI and production-quality UI.

**Natural language:** "build this UI", "this component needs work", "frontend patterns", "state management"

#### What separates production UI from prototype UI

- Components have single responsibility and are testable in isolation
- State is co-located with the component that owns it, not hoisted unnecessarily
- List renders are keyed and memoized where needed
- Forms have loading, error, and empty states
- Accessibility is built in, not added at the end

---

### `dev-documentation-and-adrs`

Writes documentation and Architecture Decision Records (ADRs). ADRs record *why* a technical decision was made — invaluable when the original author leaves or the question resurfaces months later.

**Natural language:** "write an ADR for this decision", "document this", "why did we choose X", "record this decision"

#### ADR structure

```
# ADR-XXX: [Decision Title]

**Status:** Proposed / Accepted / Deprecated / Superseded
**Date:** YYYY-MM-DD

## Context
What problem were we solving? What forces were in play?

## Decision
What did we decide to do?

## Rationale
Why this option over the alternatives?

## Alternatives considered
What else did we evaluate? Why did we reject it?

## Consequences
What does this mean going forward? What becomes easier or harder?
```

**Output:** `docs/adrs/ADR-XXX_slug.md`

---

### `dev-git-workflow-and-versioning`

Structures git practices: atomic commits, branch naming, conflict resolution, parallel stream organization. Each commit is a logical unit — not a checkpoint or a save.

**Auto-activated:** From `/build` on commit.

**Natural language:** "how should I commit this", "branch naming", "resolve this conflict", "git workflow"

#### Commit message format

```
type(scope): short description

- What changed and why (not what files changed)
- Any breaking changes or migration notes
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`

#### Branch naming

`{type}/{E-XXX_S-YYY}-{short-description}`

Example: `feat/E-002_S-001-sign-up-endpoint`

---

### `dev-ci-cd-and-automation`

Setup and modification of CI/CD pipelines. Covers: quality gates, test runners in CI, deployment strategies, build automation. A CI pipeline is the safety net that catches regressions before they reach production.

**Natural language:** "set up CI", "automate the build", "configure the pipeline", "deployment strategy"

#### Quality gate order in CI

```
1. lint
2. type-check
3. unit tests
4. integration tests
5. build
6. e2e tests (staging only)
7. deploy
```

Fail fast — stop at the first failing gate.

---

### `dev-browser-testing-with-devtools`

Tests browser behavior using Chrome DevTools MCP. Inspects the DOM, captures console errors, analyzes network requests, profiles performance, verifies visual output with real runtime data.

**Auto-activated:** From `/build` when browser features are being built.

**Natural language:** "test this in the browser", "inspect the DOM", "check network requests", "DevTools", "what's happening in the console"

---

### `dev-context-engineering`

Configures and optimizes the context Claude has access to in each step. Loads the right files, avoids saturating the agent with irrelevant content, configures rules files for a project. Better context = better output.

**Natural language:** "what context do I need for this", "load the right files", "configure the context", "agent context"

---

### `dev-deprecation-and-migration`

Manages the removal of old systems, APIs, or features and migration to new ones. Covers: deprecation warnings, migration paths, backwards compatibility windows, deciding when to sunset versus maintain.

**Natural language:** "deprecate this API", "migrate from X to Y", "how do we sunset this feature"

---

### `dev-using-agent-skills`

Meta-skill: discovers which skill applies to the current task and how to invoke it. Use at the start of a session if it's unclear which skill to use, or when a task doesn't fit an obvious category.

**Natural language:** "which skill should I use for this", "how do I use the skills", "what's the right approach"

---

### `dev-idea-refine`

Explore and refine ideas through structured divergent and convergent thinking before committing to a spec. Use when the problem isn't fully defined, when multiple approaches exist, or when you need to think before building.

**Natural language:** "idea-refine", "let's explore this approach before committing", "I'm not sure what to build", "refine this idea"

---

## All Skills — Quick Reference

| Skill | Activation | When to use |
|---|---|---|
| `dev-spec-driven-development` | `/spec` | Before writing any code |
| `dev-planning-and-task-breakdown` | `/plan` | After spec is approved |
| `dev-incremental-implementation` | `/build` | Implementing tasks |
| `dev-test-driven-development` | `/test` or auto from `/build` | Writing tests first |
| `dev-code-review-and-quality` | `/review` | Before merging |
| `dev-code-simplification` | `/code-simplify` | Reducing complexity |
| `dev-shipping-and-launch` | `/ship` | Before deploying |
| `dev-debugging-and-error-recovery` | auto from `/build` or natural language | Tests/build failing |
| `dev-security-and-hardening` | auto from `/review` or natural language | Auth, input, secrets |
| `dev-performance-optimization` | auto from `/review` or natural language | Slow queries, bundle size |
| `dev-api-and-interface-design` | natural language | Designing endpoints |
| `dev-frontend-ui-engineering` | natural language | Building UI |
| `dev-documentation-and-adrs` | natural language | Writing ADRs |
| `dev-git-workflow-and-versioning` | auto from `/build` or natural language | Commits, branches |
| `dev-ci-cd-and-automation` | natural language | CI/CD setup |
| `dev-browser-testing-with-devtools` | auto from `/build` or natural language | Browser behavior |
| `dev-context-engineering` | natural language | Context setup |
| `dev-deprecation-and-migration` | natural language | Removing old APIs |
| `dev-using-agent-skills` | natural language | Discovering the right skill |
| `dev-idea-refine` | natural language | Exploring before committing |

---

## Installation

See [README.md](README.md) for the full install steps. In short:

```bash
claude plugin marketplace add avila-tek github:avila-tek/avila-tek-skill-pack
claude plugin install avila-tek-skill-pack@avila-tek --scope project
```

If you also use the planning track, see [PLANNING.md](PLANNING.md).
