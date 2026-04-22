---
name: spec-driven-development
description: Creates specs before coding. Use when starting a new project, feature, or significant change and no specification exists yet. Use when requirements are unclear, ambiguous, or only exist as a vague idea.
---

# Spec-Driven Development

## Stack Activation Gate

Identify the active stack from the session-start hook output. State it explicitly: "Active stack: {name}".
If not injected, use the detection signals in CLAUDE.md → Stack System.
Apply this stack's STACK.md Key Patterns and Verification Checklist before completing any output.

> Spec sections covering API design and tech stack must reflect the detected stack's patterns and architecture boundaries.

## Step 0 — Mode Detection (ALWAYS run first)

1. Check if a story file exists at `docs/epics/E-*/stories/E-*_S-*/*.md`
2. **If YES:**
   - Tell the user: "Story file found at `[path]`. Running Story-Driven Mode."
   - Validate: file has Block A (sections 1–3) and Block B (sections 4+)
   - If incomplete → tell the user which sections are missing. Ask to complete them, or confirm switching to standard Q&A Mode.
   - Proceed only with a validated story file.
3. **If NO:** Tell the user: "No story file found. Running standard Q&A Mode." Proceed with Phase 1 below.

---

## Overview

Write a structured specification before writing any code. The spec is the shared source of truth between you and the human engineer — it defines what we're building, why, and how we'll know it's done. Code without a spec is guessing.

> **Avila Tek projects:** If a story file exists at `docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/E-XXX_S-YYY_slug.md`, use **Story-Driven Mode** (see end of this document). The story produced by `planning-5-story-generator` is your primary input — it replaces the need for clarifying questions on scope, ACs, and technical boundaries.

## When to Use

- Starting a new project or feature
- Requirements are ambiguous or incomplete
- The change touches multiple files or modules
- You're about to make an architectural decision
- The task would take more than 30 minutes to implement

**When NOT to use:** Single-line fixes, typo corrections, or changes where requirements are unambiguous and self-contained.

## The Gated Workflow

Spec-driven development has four phases. Do not advance to the next phase until the current one is validated.

```
SPECIFY ──→ PLAN ──→ TASKS ──→ IMPLEMENT
   │          │        │          │
   ▼          ▼        ▼          ▼
 Human      Human    Human      Human
 reviews    reviews  reviews    reviews
```

### Phase 1: Specify

Start with a high-level vision. Ask the human clarifying questions until requirements are concrete.

**Surface assumptions immediately.** Before writing any spec content, list what you're assuming:

```
ASSUMPTIONS I'M MAKING:
1. This is a web application (not native mobile)
2. Authentication uses session-based cookies (not JWT)
3. The database is PostgreSQL (based on existing Prisma schema)
4. We're targeting modern browsers only (no IE11)
→ Correct me now or I'll proceed with these.
```

Don't silently fill in ambiguous requirements. The spec's entire purpose is to surface misunderstandings *before* code gets written — assumptions are the most dangerous form of misunderstanding.

**Write a spec document covering these six core areas:**

1. **Objective** — What are we building and why? Who is the user? What does success look like?

2. **Commands** — Full executable commands with flags, not just tool names.
   ```
   Build: npm run build
   Test: npm test -- --coverage
   Lint: npm run lint --fix
   Dev: npm run dev
   ```

3. **Project Structure** — Where source code lives, where tests go, where docs belong.
   ```
   src/           → Application source code
   src/components → React components
   src/lib        → Shared utilities
   tests/         → Unit and integration tests
   e2e/           → End-to-end tests
   docs/          → Documentation
   ```

4. **Code Style** — One real code snippet showing your style beats three paragraphs describing it. Include naming conventions, formatting rules, and examples of good output.

5. **Testing Strategy** — What framework, where tests live, coverage expectations, which test levels for which concerns.

6. **Boundaries** — Three-tier system:
   - **Always do:** Run tests before commits, follow naming conventions, validate inputs
   - **Ask first:** Database schema changes, adding dependencies, changing CI config
   - **Never do:** Commit secrets, edit vendor directories, remove failing tests without approval

**Spec template:**

```markdown
# Spec: [Project/Feature Name]

## Objective
[What we're building and why. User stories or acceptance criteria.]

## Tech Stack
[Framework, language, key dependencies with versions]

## Commands
[Build, test, lint, dev — full commands]

## Project Structure
[Directory layout with descriptions]

## Code Style
[Example snippet + key conventions]

## Testing Strategy
[Framework, test locations, coverage requirements, test levels]

## Boundaries
- Always: [...]
- Ask first: [...]
- Never: [...]

## Success Criteria
[How we'll know this is done — specific, testable conditions]

## Open Questions
[Anything unresolved that needs human input]
```

**Reframe instructions as success criteria.** When receiving vague requirements, translate them into concrete conditions:

```
REQUIREMENT: "Make the dashboard faster"

REFRAMED SUCCESS CRITERIA:
- Dashboard LCP < 2.5s on 4G connection
- Initial data load completes in < 500ms
- No layout shift during load (CLS < 0.1)
→ Are these the right targets?
```

This lets you loop, retry, and problem-solve toward a clear goal rather than guessing what "faster" means.

### Phase 2: Plan

With the validated spec, generate a technical implementation plan:

1. Identify the major components and their dependencies
2. Determine the implementation order (what must be built first)
3. Note risks and mitigation strategies
4. Identify what can be built in parallel vs. what must be sequential
5. Define verification checkpoints between phases

The plan should be reviewable: the human should be able to read it and say "yes, that's the right approach" or "no, change X."

### Phase 3: Tasks

Break the plan into discrete, implementable tasks:

- Each task should be completable in a single focused session
- Each task has explicit acceptance criteria
- Each task includes a verification step (test, build, manual check)
- Tasks are ordered by dependency, not by perceived importance
- No task should require changing more than ~5 files

**Task template:**
```markdown
- [ ] Task: [Description]
  - Acceptance: [What must be true when done]
  - Verify: [How to confirm — test command, build, manual check]
  - Files: [Which files will be touched]
```

### Phase 4: Implement

Execute tasks one at a time following `incremental-implementation` and `test-driven-development` skills. Use `context-engineering` to load the right spec sections and source files at each step rather than flooding the agent with the entire spec.

## Keeping the Spec Alive

The spec is a living document, not a one-time artifact:

- **Update when decisions change** — If you discover the data model needs to change, update the spec first, then implement.
- **Update when scope changes** — Features added or cut should be reflected in the spec.
- **Commit the spec** — The spec belongs in version control alongside the code.
- **Reference the spec in PRs** — Link back to the spec section that each PR implements.
## Red Flags

- Starting to write code without any written requirements
- Asking "should I just start building?" before clarifying what "done" means
- Implementing features not mentioned in any spec or task list
- Making architectural decisions without documenting them
- Skipping the spec because "it's obvious what to build"

## Verification

Before proceeding to implementation, confirm:

- [ ] The spec covers all six core areas
- [ ] The human has reviewed and approved the spec
- [ ] Success criteria are specific and testable
- [ ] Boundaries (Always/Ask First/Never) are defined
- [ ] The spec is saved to a file in the repository

## Next Step

When this skill completes, suggest to the user:
> "Spec ready. When you're ready, run `/plan` to break this into tasks (`dev-planning-and-task-breakdown`)."

Do not invoke `/plan` automatically.

---

## Story-Driven Mode (Avila Tek)

Use this mode when the tech lead has already run `planning-5-story-generator` and the story file exists at:

```
docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/E-XXX_S-YYY_slug.md
```

The story is your **source of truth**. Do not ask clarifying questions that the story already answers.

### Mapping: Story → Spec

| Story section | Maps to spec section |
|---|---|
| Section 1 — User Story ("As a / I want / So that") | **Objective** |
| Section 2 — Acceptance Criteria | **Success Criteria** |
| Section 3 — Ranked Tasks (Must/Important/Optional) | Base for **Tasks** |
| Section 4 — Technical Scope (API, DB, auth, config) | **Tech Stack** + **Boundaries** |
| Section 5 — Business Rules | **Boundaries** constraints |
| Section 6 — Data Model Impact | **Project Structure** (if schema changes) |

### Story-Driven Workflow

1. **Load all planning context** (in this order):
   - Read the story file completely (Block A + Block B): `docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/E-XXX_S-YYY_slug.md`
   - Read the parent epic file: `docs/epics/E-XXX_slug/epic.md` — extract scope, background, constraints, and non-goals
   - Read the TDD if present: `docs/epics/E-XXX_slug/tdd.md` — extract architecture decisions, tech stack, and integration constraints. If absent, skip silently.
   - Read the domain model: `docs/domain_model.md` — use it to resolve entity names, relationships, and data boundaries. If absent, skip silently.
   - Read `docs/project_context.md` if any of the following are true: the story touches cross-cutting concerns, the tech stack is not explicit in the story, or the epic scope references project-level constraints. If absent or not needed, skip silently.
2. Identify gaps not covered by any of the loaded documents (e.g. build commands, code style, test framework)
3. Ask the developer only about those gaps — do not ask about anything already answered in the story, epic, TDD, domain model, or project context
4. Generate a complete `spec.md` using the standard spec template, with the loaded documents as source of truth
5. **Write to:** `docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/spec.md`

The resulting `spec.md` is the source of truth for the development session. Subsequent `/plan` and `/build` commands use the spec, not the planning documents directly.
