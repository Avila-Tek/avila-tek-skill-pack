# avila-tek-skill-pack

This repo contains Claude Code skills, commands, agents, and references for the complete Avila Tek software delivery lifecycle — from Design Doc to production code. Read this file to understand how to activate and chain every skill correctly.

> **TDD = Technical Design Document** throughout this project. Never Test-Driven Development.

---

## Key Documents

| Document | Purpose |
|---|---|
| [README.md](README.md) | Overview of the full system — start here |
| [PLANNING-WORKFLOW.md](PLANNING-WORKFLOW.md) | Step-by-step planning workflow with gates — Tech Lead reference |
| [DEV-WORKFLOW.md](DEV-WORKFLOW.md) | Step-by-step dev workflow with gates — Developer reference |
| [PLANNING.md](PLANNING.md) | Complete planning skill reference (every skill detailed) |
| [DEV.md](DEV.md) | Complete dev skill reference (every skill detailed) |

---

## Project Structure

```
avila-tek-skill-pack/
├── CLAUDE.md                              ← This file (instructions for Claude)
├── README.md                              ← Human-readable overview
├── PLANNING-WORKFLOW.md                   ← Planning workflow with gates
├── DEV-WORKFLOW.md                        ← Dev workflow with gates
├── PLANNING.md                            ← Full planning skill reference
├── DEV.md                                 ← Full dev skill reference
├── agents/                                ← Specialized sub-agents
│   ├── code-reviewer.md
│   ├── security-auditor.md
│   └── test-engineer.md
├── commands/                              ← Slash commands
│   ├── project-context-generator.md      ← /project-context-generator
│   ├── domain-model-generator.md         ← /domain-model-generator
│   ├── functional-spec-generator.md      ← /functional-spec-generator
│   ├── technical-design-document.md      ← /technical-design-document
│   ├── epic-generator.md                 ← /epic-generator
│   ├── story-generator.md                ← /story-generator
│   ├── write-epics-and-hu-in-base.md     ← /write-epics-and-hu-in-base
│   ├── spec.md                           ← /spec
│   ├── plan.md                           ← /plan
│   ├── build.md                          ← /build
│   ├── review.md                         ← /review
│   ├── test.md                           ← /test
│   ├── ship.md                           ← /ship
│   └── code-simplify.md                  ← /code-simplify
├── hooks/                                 ← Session hooks (auto-detects stack on start)
├── references/                            ← Shared checklists
├── stacks/                                ← Stack-specific standards (auto-loaded by hook)
│   ├── nestjs/
│   │   ├── STACK.md                       ← NestJS profile (Key Patterns, Red Flags, Checklist)
│   │   └── agent_docs/                    ← Full NestJS standards (architecture, auth, testing…)
│   ├── nextjs/
│   │   ├── STACK.md                       ← Next.js profile
│   │   └── agent_docs/                    ← Full Next.js standards (layers, data-fetching…)
│   ├── spring-boot/
│   │   ├── STACK.md
│   │   └── agent_docs/                    ← Full Spring Boot standards (15 files)
│   ├── go/
│   │   ├── STACK.md
│   │   └── agent_docs/                    ← Full Go standards (13 files)
│   ├── flutter/
│   │   ├── STACK.md
│   │   └── agent_docs/                    ← Full Flutter standards (16 files)
│   ├── react-native/
│   │   ├── STACK.md
│   │   └── agent_docs/                    ← Full React Native standards (11 files)
│   └── angular/STACK.md                   ← In progress
└── skills/
    ├── planning-0-project-context-generator/
    ├── planning-1-domain-model-generator/
    ├── planning-2-functional-spec-generator/
    ├── planning-3-technical-design-document/
    ├── planning-4-epic-generator/
    ├── planning-5-story-generator/
    ├── planning-6-write-epics-and-hu-in-base/
    ├── dev-spec-driven-development/
    ├── dev-planning-and-task-breakdown/
    ├── dev-incremental-implementation/
    ├── dev-test-driven-development/
    ├── dev-code-review-and-quality/
    ├── dev-code-simplification/
    ├── dev-shipping-and-launch/
    ├── dev-debugging-and-error-recovery/
    ├── dev-security-and-hardening/
    ├── dev-performance-optimization/
    ├── dev-api-and-interface-design/
    ├── dev-frontend-ui-engineering/
    ├── dev-documentation-and-adrs/
    ├── dev-git-workflow-and-versioning/
    ├── dev-ci-cd-and-automation/
    ├── dev-browser-testing-with-devtools/
    ├── dev-context-engineering/
    ├── dev-deprecation-and-migration/
    ├── dev-using-agent-skills/
    └── dev-idea-refine/
```

---

## Docs Structure (in target project repos)

When skills generate artifacts, they write to this layout inside the target project:

```
docs/
├── inputs/                                ← Source documents (Design Doc, Intake Brief)
├── project_context.md                     ← skill-0 output
├── domain_model.md                        ← skill-1 output (living doc)
├── epics/
│   └── E-XXX_slug/
│       ├── epic.md                        ← skill-4 output
│       ├── tdd.md                         ← skill-3 output (optional)
│       └── stories/
│           └── E-XXX_S-YYY_slug/          ← one folder per story
│               ├── E-XXX_S-YYY_slug.md    ← skill-5 output (story file)
│               ├── spec.md                ← /spec output
│               ├── plan.md                ← /plan output
│               └── todo.md                ← /plan output
└── adrs/                                  ← dev-documentation-and-adrs output
```

Naming rules:
- Epic folder: `E-{3-digit-number}_{lowercase_slug}`
- Story folder: `E-{epic}_S-{3-digit-number}_{lowercase_slug}`
- Story file: same as folder + `.md`

---

## Planning Skills — How to Activate

Planning skills activate from **natural language phrases**. Match the user's intent to the correct skill using the trigger patterns below. Also activate when the corresponding slash command is used.

| Skill | Command | Trigger phrases |
|---|---|---|
| `planning-0-project-context-generator` | `/project-context-generator` | "generate project context", "create master context", "update the project context", "process this design doc", "bootstrap the project" |
| `planning-1-domain-model-generator` | `/domain-model-generator` | "domain model", "generate domain model", "modelo de dominio", "update the domain model" — also trigger after any spec/TDD/epic reveals new entities |
| `planning-2-functional-spec-generator` | `/functional-spec-generator` | "functional spec", "spec funcional", "generate the spec", "generate a spec for this epic" |
| `planning-3-technical-design-document` | `/technical-design-document` | "technical design", "TDD", "design doc", "diseño técnico", "create a TDD" |
| `planning-4-epic-generator` | `/epic-generator` | "generate epics", "genera las épicas", "break this spec into epics" |
| `planning-5-story-generator` | `/story-generator` | "generate stories for E-XXX", "write the stories", "expand this epic into stories" |
| `planning-6-write-epics-and-hu-in-base` | `/write-epics-and-hu-in-base` | "sync to Lark", "push E-XXX to Lark", "sincroniza el backlog" |

### Planning Skill Rules

- **skill-0 (project context):** Two modes — Create (new `project_context.md`) and Update (iterate existing, append Change Log). Never rewrite history. Ask questions one at a time before drafting. Confirm before generating. English only. No implementation details. Max 500 lines.

- **skill-1 (domain model):** Living document. Ask one question at a time. Use exact Domain Glossary terms — no synonyms. Never invent facts — use `[PENDING]` for gaps. Confirm before generating. English only. Each run is additive — append to logs, never rewrite.

- **skill-2 (functional spec):** Output always in Spanish. One per epic. Lives in Lark Wiki — present for user to copy/export, do not write to repo.

- **skill-3 (TDD):** First ask: "TDD before or after epics?" — this changes how section 4.3 is populated. English. ASCII diagrams only (no Mermaid). Output to `docs/epics/E-XXX_slug/tdd.md`.

- **skill-4 (epics):** Primary source is the Spec Funcional. TDD enriches if available. Present discovered epics, ask which to generate. Max 150–200 lines per epic. Use `[TO BE DEFINED]` for gaps.

- **skill-5 (stories):** Resolve all open questions before generating — no ambiguities in the final document. Each story gets its own folder. Output: `docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/E-XXX_S-YYY_slug.md`.

- **skill-6 (lark sync):** Requires Epic IDs + API Key + Base ID before starting. Show preview, wait for confirmation before the POST. Never clone the repo. Never invent field values.

---

## Dev Skills — How to Activate

### Commands → Skills Mapping

When a slash command is used, invoke the corresponding skill(s):

| Command | Primary skill | Always chains | Conditionally chains |
|---|---|---|---|
| `/spec` | `dev-spec-driven-development` | — | If story file exists → Story-Driven Mode; if not → standard clarifying Q&A |
| `/plan` | `dev-planning-and-task-breakdown` | — | — |
| `/build` | `dev-incremental-implementation` | `dev-test-driven-development` | On failure → `dev-debugging-and-error-recovery`; on commit → `dev-git-workflow-and-versioning`; browser features → `dev-browser-testing-with-devtools` |
| `/review` | `dev-code-review-and-quality` | — | Security findings → `dev-security-and-hardening`; performance findings → `dev-performance-optimization` |
| `/test` | `dev-test-driven-development` | — | Browser issues → `dev-browser-testing-with-devtools` |
| `/ship` | `dev-shipping-and-launch` | — | — |
| `/code-simplify` | `dev-code-simplification` | — | — |

### Natural Language Triggers for Dev Skills

Activate these skills when the user's message matches the trigger. No command needed.

| Skill | Activate when the user says... |
|---|---|
| `dev-debugging-and-error-recovery` | "this test is failing", "build broke", "fix this error", "debug this", any unexpected error or failing assertion |
| `dev-security-and-hardening` | "security review", "is this safe", "harden this", "validate input", anything touching auth/authz, user input, or secrets |
| `dev-performance-optimization` | "this is slow", "optimize this", "memory leak", "N+1 query", "Core Web Vitals", "bundle size" |
| `dev-api-and-interface-design` | "design this API", "what should this interface look like", "define the contract", "REST endpoint design" |
| `dev-frontend-ui-engineering` | "build this UI", "this component", "frontend patterns", "state management", anything that renders in the browser |
| `dev-documentation-and-adrs` | "write an ADR", "document this decision", "why did we choose X", "record this" |
| `dev-git-workflow-and-versioning` | "how should I commit this", "branch naming", "git workflow", "resolve this conflict" |
| `dev-ci-cd-and-automation` | "set up CI", "configure the pipeline", "automate the build", "deployment strategy" |
| `dev-browser-testing-with-devtools` | "test this in the browser", "inspect the DOM", "check network requests", "DevTools", "Chrome DevTools" |
| `dev-context-engineering` | "what context do I need", "load the right files", "configure context for this session", "agent context" |
| `dev-deprecation-and-migration` | "deprecate this", "migrate from X to Y", "remove this old API", "sunset this feature" |
| `dev-using-agent-skills` | "which skill should I use", "how do I use the skills", "discover skills", "what's the right approach" |
| `dev-idea-refine` | "idea-refine", "ideate on this", "explore this approach", "not sure what to build", "refine this idea" |

### `/spec` — Two Modes

**Without planning artifacts** (no story file in the repo): run the standard clarifying Q&A workflow. Ask about objective, users, features, tech stack, constraints, and boundaries. Generate the spec from scratch. Write to project root as `SPEC.md` or wherever the user specifies.

**With planning artifacts** (story file exists): run Story-Driven Mode instead (see below). The story replaces the Q&A — it already contains the ACs, technical scope, and business rules.

### Story-Driven Mode (activate silently when story file exists)

When `/spec` is invoked and a story file exists at `docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/E-XXX_S-YYY_slug.md`:

1. Read the story file completely (Block A + Block B)
2. Map story sections to spec sections:
   - Section 1 (User Story) → Objective
   - Section 2 (Acceptance Criteria) → Success Criteria
   - Section 3 (Ranked Tasks) → base for Tasks
   - Section 4 (Technical Scope: API, DB, auth, config) → Tech Stack + Boundaries
   - Section 5 (Business Rules) → Boundaries constraints
   - Section 6 (Data Model) → Project Structure (if schema changes)
3. Ask only about gaps the story does not cover (e.g. build commands, test framework, code style)
4. Do NOT ask about scope, ACs, or technical boundaries already in the story
5. Write `spec.md` to `docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/spec.md`

The spec becomes the source of truth for `/plan` and `/build`.

### Output Paths for Dev Artifacts

All dev artifacts go inside the story folder, co-located with the story file:

```
docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/
├── E-XXX_S-YYY_slug.md   ← story (planning output — do not modify)
├── spec.md               ← /spec
├── plan.md               ← /plan
└── todo.md               ← /plan
```

---

## Agents

Three specialized agents available for review and auditing tasks:

| Agent | Use when |
|---|---|
| `code-reviewer` | Need a structured five-axis code review with severity labels |
| `security-auditor` | Need a dedicated security audit of a change or feature |
| `test-engineer` | Need an independent evaluation of test coverage and quality |

Invoke via the agent syntax: `Use the code-reviewer agent to review this change.`

---

## Artifact Ownership

| Artifact | Lives in | Created by |
|---|---|---|
| Design Doc | Lark Wiki | Team (manual) |
| `project_context.md` | `docs/` | skill-0 (`/project-context-generator`) |
| `domain_model.md` | `docs/` | skill-1 (`/domain-model-generator`) |
| Spec Funcional | Lark Wiki | skill-2 (`/functional-spec-generator`) |
| `tdd.md` | `docs/epics/E-XXX/tdd.md` | skill-3 (`/technical-design-document`) |
| `epic.md` | `docs/epics/E-XXX/` | skill-4 (`/epic-generator`) |
| Story folder + `.md` | `docs/epics/E-XXX/stories/E-XXX_S-YYY_slug/` | skill-5 (`/story-generator`) |
| Lark Base records | Lark Base | skill-6 (`/write-epics-and-hu-in-base`) |
| `spec.md` | story folder | dev (`/spec`) |
| `plan.md` + `todo.md` | story folder | dev (`/plan`) |
| ADRs | `docs/adrs/` | dev (`dev-documentation-and-adrs`) |

---

## Conventions

- **Planning skills:** `skills/planning-{number}-{name}/SKILL.md` — numbered by process order (0 → 6)
- **Dev skills:** `skills/dev-{name}/SKILL.md` — flat, no number, prefixed with `dev-`
- **Commands:** `commands/{skill-name-without-prefix}.md` — matches skill name without `planning-N-` or `dev-`
- YAML frontmatter with `name` and `description` fields required on every SKILL.md
- Supporting reference files go in `skills/{name}/references/` — only create if content exceeds ~100 lines
- Never duplicate content between skills — cross-reference instead

---

## Stack System

The session-start hook (`hooks/session-start.sh`) automatically detects and loads the correct stack standards every time Claude Code opens in a project directory. No manual action is needed.

### Detection Signals

| Stack | Signal |
|-------|--------|
| nestjs | `@nestjs/core` in any `package.json` (max 3 levels deep) |
| nextjs | `next` in any `package.json` (excludes Angular/React Native projects) |
| angular | `angular.json` present, or `@angular/core` in `package.json` |
| react-native | `react-native` in any `package.json` |
| spring-boot | `pom.xml` or `build.gradle` containing `spring-boot` |
| go | `go.mod` present |
| flutter | `pubspec.yaml` containing `flutter:` |

### Monorepo Behavior

When multiple stacks are detected (e.g. NestJS + Next.js), all matching STACK.md files are loaded and labeled. Apply each stack's standards to its respective part of the codebase.

### Fallback

If no stack is detected, the session continues without stack-specific standards. The meta-skill and all other skills remain available.

### Adding a New Stack

1. Create `stacks/{name}/STACK.md` (frontmatter + Summary + Architecture + Key Patterns + Standards Documents + Testing + Red Flags + Verification Checklist)
2. Add detection logic to `hooks/session-start.sh`
3. Populate `stacks/{name}/agent_docs/` with detailed standards
4. Update the detection table above

---

## Stack Standards Enforcement

The session-start hook loads the active STACK.md(s) at the start of every session. These are not optional guidelines — they are mandatory quality gates. Apply the following rules in every task:

### Active Gates (run before completing any code task)

1. **Before generating code** — identify the active stack. State it explicitly if non-obvious: "Active stack: NestJS". If the session-start hook did not inject a stack, check the project files directly using the detection signals in the Stack System table.

2. **Before submitting output** — run through the active STACK.md Verification Checklist. If any item fails, fix it before delivering the response. Do not skip this step because "it's a small change."

3. **During code review (`/review`)** — run the active STACK.md Red Flags list against every changed file. Flag any hit as a review finding with the same severity system as other findings.

4. **During API and UI work** — apply the Key Patterns from the active STACK.md. For NestJS: repository layer required, no direct Drizzle in services, Zod schemas from `packages/schemas/`. For Next.js: React Query for all server state, no logic in `app/` files, strict layer boundaries.

### Escalation Rule

If the active stack is Angular (in progress, no agent_docs yet): proceed with general best practices and state explicitly "stack standards for Angular are not yet fully defined — applying general conventions."

For all other stacks (NestJS, Next.js, Go, Spring Boot, Flutter, React Native): full agent_docs exist — load them.

---

## Evals

The `evals/` directory contains JSON eval definitions for verifying that Claude applies stack standards correctly.

| File | Purpose |
|------|---------|
| `evals/stack-compliance.json` | Verifies NestJS/Next.js stack standard enforcement — repository layer, Zod DTOs, auth guards, error handling |

Each eval defines a prompt + expected assertions. Run manually by giving Claude the eval file and asking it to grade its own output against the assertions. No automated runner is configured yet — evals serve as a reference for what "correct stack compliance" looks like.

---

## Boundaries

- **Always:** Follow [DEV-WORKFLOW.md](DEV-WORKFLOW.md) gates when executing dev commands — do not advance a phase with a failing gate
- **Always:** Follow [PLANNING-WORKFLOW.md](PLANNING-WORKFLOW.md) gates when executing planning skills — do not advance a phase before it is confirmed
- **Always:** Keep skill numbering aligned with process order (planning track)
- **Always:** Write output paths explicitly in every SKILL.md
- **Always:** Use Story-Driven Mode in `/spec` when a story file exists in the target repo
- **Always:** Chain secondary skills automatically without asking the user (debugging on failure, security on review findings)
- **Always:** Run the active STACK.md Verification Checklist before completing any code task
- **Never:** Add vague advice — every skill must have concrete steps and a clear output artifact
- **Never:** Duplicate business logic between skills — reference the primary one
- **Never:** Invent field values or business rules — use `[PENDING]` for gaps in planning artifacts
- **Never:** Ask the user about Story-Driven Mode — detect the story file and activate it silently
- **Never:** Skip the Stack Conventions axis in code review, even for small changes
