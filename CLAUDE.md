# avila-tek-skill-pack

This repo contains Claude Code skills, commands, agents, and references for the complete Avila Tek software delivery lifecycle — from Design Doc to production code.

> **TDD = Technical Design Document** throughout this project. Never Test-Driven Development.

---

## Behavior

**Think before coding. Surface assumptions. Push back.**

- State assumptions explicitly before implementing anything non-trivial. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If something is unclear, stop. Name what's confusing. Ask.
- Push back when an approach has clear problems: explain the downside, propose an alternative.

**Minimum code. Nothing speculative.**

- No features beyond what was asked. No abstractions for single-use code.
- No error handling for impossible scenarios.
- If you write 200 lines and 50 would do, rewrite it.

**Surgical changes. Touch only what you must.**

- Don't "improve" adjacent code, comments, or formatting unless asked.
- Match existing style, even if you'd do it differently.
- Remove only imports/variables/functions that YOUR changes made unused.

**Verify. A task is not complete until there is evidence it works.**

- "Seems right" is never sufficient — there must be passing tests, build output, or runtime data.
- For multi-step tasks, state a brief plan with a verify check per step before starting.

---

## Key Documents

| Document | Purpose |
|---|---|
| [README.md](README.md) | Overview of the full system — start here |
| [PLANNING-WORKFLOW.md](PLANNING-WORKFLOW.md) | Step-by-step planning workflow with gates — Tech Lead reference |
| [DEV-WORKFLOW.md](DEV-WORKFLOW.md) | Step-by-step dev workflow with gates — Developer reference |
| [PLANNING.md](PLANNING.md) | Complete planning skill reference |
| [DEV.md](DEV.md) | Complete dev skill reference |

---

## Planning Skills

Activate from natural language or slash commands:

| Skill | Command | Trigger phrases |
|---|---|---|
| `planning-0-project-context-generator` | `/project-context-generator` | "generate project context", "create master context", "bootstrap the project" |
| `planning-1-domain-model-generator` | `/domain-model-generator` | "domain model", "modelo de dominio", "update the domain model" |
| `planning-2-functional-spec-generator` | `/functional-spec-generator` | "functional spec", "spec funcional", "generate the spec" |
| `planning-3-technical-design-document` | `/technical-design-document` | "TDD", "technical design", "diseño técnico", "create a TDD" |
| `planning-4-epic-generator` | `/epic-generator` | "generate epics", "genera las épicas", "break this spec into epics" |
| `planning-5-story-generator` | `/story-generator` | "generate stories for E-XXX", "expand this epic into stories" |
| `planning-6-write-epics-and-hu-in-base` | `/write-epics-and-hu-in-base` | "sync to Lark", "push E-XXX to Lark", "sincroniza el backlog" |

### Key rules per planning skill

- **skill-0:** Create or Update mode. Ask questions one at a time. English. Max 500 lines.
- **skill-1:** Living doc. Use exact Domain Glossary terms. `[PENDING]` for gaps. Additive — never rewrite history.
- **skill-2:** Output always in Spanish. One per epic. Lark Wiki only — do not write to repo.
- **skill-3:** Ask "TDD before or after epics?" first. English. ASCII diagrams only. Output → `docs/epics/E-XXX_slug/tdd.md`.
- **skill-4:** Primary source is Spec Funcional. Max 150–200 lines per epic.
- **skill-5:** Resolve all open questions before generating. Output → `docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/E-XXX_S-YYY_slug.md`.
- **skill-6:** Requires Epic IDs + API Key + Base ID. Show preview, wait for confirmation before POST.

---

## Dev Skills

### Commands → Skills

| Command | Primary skill | Chains |
|---|---|---|
| `/spec` | `dev-spec-driven-development` | Story-Driven Mode if story file exists |
| `/plan` | `dev-planning-and-task-breakdown` | — |
| `/build` | `dev-incremental-implementation` + `dev-test-driven-development` | On failure → `dev-debugging-and-error-recovery`; on commit → `dev-git-workflow-and-versioning` |
| `/harness` | `dev-harness-eslint` | On success → integrate lint into `/build` verify step |
| `/review` | `dev-code-review-and-quality` | Security findings → `dev-security-and-hardening`; perf findings → `dev-performance-optimization`; always → writes `summary.md` |
| `/test` | `dev-test-driven-development` | — |
| `/test-restructure` | `dev-test-restructure` | — |
| `/ship` | `dev-shipping-and-launch` | — |
| `/code-simplify` | `dev-code-simplification` | — |

### Natural Language Triggers

| Skill | Activate when |
|---|---|
| `dev-debugging-and-error-recovery` | "test is failing", "build broke", "fix this error", unexpected error or failing assertion |
| `dev-security-and-hardening` | "security review", "harden this", anything touching auth/authz, user input, or secrets |
| `dev-performance-optimization` | "this is slow", "N+1 query", "bundle size", "Core Web Vitals" |
| `dev-api-and-interface-design` | "design this API", "define the contract", "REST endpoint design" |
| `dev-frontend-ui-engineering` | "build this UI", "this component", anything that renders in the browser |
| `dev-documentation-and-adrs` | "write an ADR", "document this decision", "record this" |
| `dev-git-workflow-and-versioning` | "how should I commit this", "branch naming", "resolve this conflict" |
| `dev-ci-cd-and-automation` | "set up CI", "configure the pipeline", "automate the build" |
| `dev-browser-testing-with-devtools` | "test in the browser", "inspect the DOM", "Chrome DevTools" |
| `dev-context-engineering` | "what context do I need", "load the right files", "configure context" |
| `dev-deprecation-and-migration` | "deprecate this", "migrate from X to Y", "sunset this feature" |
| `dev-idea-refine` | "ideate on this", "not sure what to build", "refine this idea" |
| `dev-test-restructure` | "refactor the tests", "fix test structure", "our test suite is a mess", "bring tests in line" |
| `dev-harness-eslint` | "set up eslint", "add lint rules", "the agent keeps making the same architecture mistake", "encode our layer boundaries", "configure the linter", "add harness" |

### `/spec` — Two Modes

**Standard mode** (no story file): clarifying Q&A → objective, users, features, tech stack, constraints, boundaries → write `SPEC.md`.

**Story-Driven Mode** (story file exists — activate silently):
1. Load: story file → parent epic → TDD → domain model → project context (if cross-cutting)
2. Map story sections → spec sections (User Story → Objective, ACs → Success Criteria, Tasks → Tasks, Technical Scope → Boundaries)
3. Ask only about gaps not covered by any loaded document
4. Write `spec.md` to the story folder: `docs/epics/E-XXX_slug/stories/E-XXX_S-YYY_slug/spec.md`

---

## Stack System

The session-start hook auto-detects and loads the active stack standards. Full standards live in `stacks/{name}/agent_docs/` — apply them; don't repeat them here.

| Stack | Detection signal |
|---|---|
| nestjs | `@nestjs/core` in any `package.json` |
| nextjs | `next` in any `package.json` (not Angular/React Native) |
| angular | `angular.json` present, or `@angular/core` in `package.json` |
| react-native | `react-native` in any `package.json` |
| spring-boot | `pom.xml` or `build.gradle` with `spring-boot` |
| go | `go.mod` present |
| flutter | `pubspec.yaml` with `flutter:` |
| fastify | `fastify` in any `package.json` |
| express | `express` in any `package.json` (not NestJS/Angular/RN) |

In a monorepo, all detected STACK.md files are loaded simultaneously. If no stack is detected, continue without stack-specific standards.

---

## Output Paths

Artifacts generated in target project repos:

```
docs/
├── project_context.md              ← skill-0
├── domain_model.md                 ← skill-1
└── epics/
    └── E-XXX_slug/
        ├── epic.md                 ← skill-4
        ├── tdd.md                  ← skill-3
        └── stories/
            └── E-XXX_S-YYY_slug/
                ├── E-XXX_S-YYY_slug.md  ← skill-5
                ├── spec.md              ← /spec
                ├── plan.md              ← /plan
                └── todo.md             ← /plan
```

Naming: `E-{3-digit}_{lowercase_slug}` for epics · `E-{epic}_S-{3-digit}_{lowercase_slug}` for stories.

---

## Agents

| Agent | Use when |
|---|---|
| `code-reviewer` | Structured five-axis code review with severity labels |
| `security-auditor` | Dedicated security audit of a change or feature |
| `test-engineer` | Independent evaluation of test coverage and quality |

---

## Conventions

- Planning skills: `skills/planning-{N}-{name}/SKILL.md` — numbered by process order (0 → 6)
- Dev skills: `skills/dev-{name}/SKILL.md` — prefixed `dev-`, no number
- Commands: `commands/{skill-name-without-prefix}.md`
- YAML frontmatter with `name` + `description` required on every SKILL.md
- Supporting reference files → `skills/{name}/references/` (only if content exceeds ~100 lines)
- Never duplicate content between skills — cross-reference instead

---

## Boundaries

- Follow [DEV-WORKFLOW.md](DEV-WORKFLOW.md) gates — do not advance a phase with a failing gate
- Follow [PLANNING-WORKFLOW.md](PLANNING-WORKFLOW.md) gates — do not advance before confirmation
- Chain secondary skills automatically without asking (debugging on failure, security on review findings)
- Activate Story-Driven Mode silently when a story file exists — do not ask the user
- Use `[PENDING]` for gaps in planning artifacts — never invent field values
- Never duplicate business logic between skills — reference the primary one
