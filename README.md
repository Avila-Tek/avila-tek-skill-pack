# Avila Tek Skill Pack

Claude Code skills for the complete Avila Tek software delivery lifecycle — from product doc to production code.

> **TDD in this project = Technical Design Document.** Never Test-Driven Development.

---

## How It Works

Two tracks. One system.

The **Planning Track** (Tech Lead) transforms a Design Doc into structured story files: context, domain model, functional spec, epics, and user stories — each with acceptance criteria and full technical scope. The **Dev Track** (Developer) picks up those story files and delivers production code using 8 slash commands that auto-chain secondary skills on failure, security findings, and browser issues — no manual intervention needed.

The **story file** is the bridge. When the planning track is done, the developer reads the story and runs `/spec` → `/plan` → `/build` → `/review` → `/ship`.

---

## The Full Pipeline

```
PLANNING TRACK (Tech Lead)                           DEV TRACK (Developer)
══════════════════════════                           ══════════════════════

[Design Doc in Lark Wiki]
          │
          ▼
/project-context-generator ───► docs/project_context.md
          │
          ▼
/domain-model-generator ───────► docs/domain_model.md
          │
          ▼
/functional-spec-generator ────► Spec Funcional (Lark Wiki)
          │
          ▼
/technical-design-document ────► docs/epics/E-XXX/tdd.md  (optional)
          │
          ▼
/epic-generator ───────────────► docs/epics/E-XXX/epic.md
          │
          ▼
/story-generator ──────────────► ┌─────────────────────────────────┐
          │                       │  docs/epics/E-XXX/stories/       │
          │                       │    E-XXX_S-YYY_slug/             │◄── HANDOFF
          │                       │      E-XXX_S-YYY_slug.md         │
          │                       └─────────────────────────────────┘
          │                                         │
/write-epics-and-hu-in-base ──► Lark Base           │
                                                     ▼
                                              /spec ─────► spec.md
                                                     │
                                                     ▼
                                              /plan ─────► plan.md + todo.md
                                                     │
                                                     ▼
                                              /build ────► code + tests
                                                     │
                                                     ▼
                                              /review ───► code review
                                                     │
                                                     ▼
                                              /ship ─────► production
```

---

## Planning Track

Seven sequential skills that move a Design Doc through context, domain model, spec, TDD, epics, and stories. Each skill asks clarifying questions before generating — never invents business rules.

| Command | Output artifact | Where it lives |
|---------|----------------|----------------|
| `/project-context-generator` | `project_context.md` | `docs/` |
| `/domain-model-generator` | `domain_model.md` | `docs/` |
| `/functional-spec-generator` | Spec Funcional | Lark Wiki (copy/export) |
| `/technical-design-document` | `tdd.md` | `docs/epics/E-XXX/` |
| `/epic-generator` | `epic.md` | `docs/epics/E-XXX/` |
| `/story-generator` | `E-XXX_S-YYY_slug.md` | `docs/epics/E-XXX/stories/E-XXX_S-YYY/` |
| `/write-epics-and-hu-in-base` | Epics + stories synced | Lark Base |

> **To use the Planning Track effectively, read [PLANNING.md](PLANNING.md) first.** It covers every skill in detail: what each one asks before generating, what each artifact contains, the rules that govern the process, and how the skills connect. The table above is a summary — the full picture is in that document.

---

## Dev Track

Eight slash commands. Each one chains secondary skills automatically — you never need to invoke them manually.

### The Developer Loop

```
story.md
    │
    ▼
  /spec ─────────────────────────────────────────────► spec.md
    │   (Story-Driven Mode: reads story file,           (story folder)
    │    only asks about gaps)
    ▼
  /plan ─────────────────────────────────────────────► plan.md + todo.md
    │   (ordered tasks with acceptance criteria)         (story folder)
    ▼
  /build ────────────────────────────────────────────► code + tests committed
    │   (one increment at a time, RED → GREEN → commit)
    │
    │   FAILED? ────────────────── auto ─────────────► /review
    ▼
  /review ───────────────────────────────────────────► structured findings
    │   (5-axis: correctness, readability,
    │    architecture, security, performance)
    ▼
  /ship ─────────────────────────────────────────────► production
        (pre-launch checklist + rollback plan)
```

### Auto-Chaining — How Secondary Skills Activate

Skills chain automatically. You never invoke these manually.

```
/build ─────── always chains ────────────────────────► dev-test-driven-development
   │                                                    (write failing test first)
   │
   ├── test or build fails ─── auto-chains ───────────► dev-debugging-and-error-recovery
   │
   ├── browser/UI code touched ─── auto-chains ────────► dev-browser-testing-with-devtools
   │
   └── increment complete ──── suggests to user ────────► /review


/review ─────── always chains ───────────────────────► dev-code-review-and-quality
   │
   ├── security finding ─────── auto-chains ───────────► dev-security-and-hardening
   │
   └── performance finding ──── auto-chains ───────────► dev-performance-optimization
```

### Commands Reference

| Command | What it does | Chains |
|---------|-------------|--------|
| `/spec` | Write spec from story file (Story-Driven Mode) or from scratch | — |
| `/plan` | Break spec into ordered tasks with ACs and checkpoints | — |
| `/build` | Implement one task increment (RED → GREEN → commit) | TDD always; debugging on failure; browser-testing on UI |
| `/test` | Run TDD workflow or Prove-It pattern for bug fixes | browser-testing on browser issues |
| `/review` | Five-axis code review with severity labels | security on auth/input findings; performance on N+1/bundle findings |
| `/ship` | Pre-launch checklist + rollback plan | — |
| `/code-simplify` | Reduce complexity without changing behavior | — |

### Natural Language Triggers

These skills activate without a slash command — just describe what you need:

| Say something like... | Skill activated |
|-----------------------|----------------|
| "this test is failing", "build broke", "fix this error" | `dev-debugging-and-error-recovery` |
| "security review", "is this safe", "harden this", anything touching auth | `dev-security-and-hardening` |
| "this is slow", "N+1 query", "optimize this", "Core Web Vitals" | `dev-performance-optimization` |
| "design this API", "define the contract", "REST endpoint design" | `dev-api-and-interface-design` |
| "build this UI", "this component", "state management" | `dev-frontend-ui-engineering` |
| "write an ADR", "document this decision", "why did we choose X" | `dev-documentation-and-adrs` |
| "how should I commit this", "branch naming", "resolve this conflict" | `dev-git-workflow-and-versioning` |
| "set up CI", "configure the pipeline", "automate the build" | `dev-ci-cd-and-automation` |
| "deprecate this", "migrate from X to Y", "sunset this feature" | `dev-deprecation-and-migration` |

> **To use the Dev Track effectively, read [DEV.md](DEV.md) first.** It covers every skill in detail: how Story-Driven Mode works, how auto-chaining activates secondary skills, what each command does step by step, and all 20 dev skills with their activation patterns and rules. The tables above are a summary — the full picture is in that document.

---

## Stack System

When you open Claude Code inside a project, the session-start hook automatically detects the tech stack and injects the matching standards. No setup needed — just open Claude from within your project directory.

When a stack is detected, Claude loads `stacks/{name}/STACK.md` (key patterns, red flags, verification checklist) and all docs from `stacks/{name}/agent_docs/` (architecture, auth, testing, error handling, and more). These become mandatory quality gates for every code task in the session.

| Stack | Detection signal | Standards docs | Status |
|-------|-----------------|----------------|--------|
| **NestJS** | `@nestjs/core` in `package.json` | 12 files | Ready |
| **Next.js** | `next` in `package.json` | 17 files | Ready |
| **Go** | `go.mod` present | 13 files | Ready |
| **Spring Boot** | `pom.xml` or `build.gradle` containing `spring-boot` | 15 files | Ready |
| **Flutter** | `pubspec.yaml` containing `flutter:` | 16 files | Ready |
| **React Native** | `react-native` in `package.json` | 11 files | Ready |
| **Fastify** | `fastify` in `package.json` | 8 files | Ready |
| **Express** | `express` in `package.json` (excludes NestJS/Angular/React Native) | 7 files | Ready |
| **Angular** | `angular.json` or `@angular/core` in `package.json` | — | In progress |

**Monorepo:** When multiple stacks are detected (e.g. NestJS + Next.js), all matching standards are loaded. Each stack's rules apply to its part of the codebase.

---

## Agents & References

Three specialized agents for review and auditing tasks:

| Agent | Use when |
|-------|---------|
| `code-reviewer` | Need a structured five-axis review with severity labels |
| `security-auditor` | Need a dedicated security audit of a change or feature |
| `test-engineer` | Need an independent evaluation of test coverage and quality |

Invoke with: `Use the code-reviewer agent to review this change.`

Four shared reference checklists in `references/`:
- `accessibility-checklist.md` — A11y standards
- `performance-checklist.md` — Performance gates
- `security-checklist.md` — Security verification
- `testing-patterns.md` — Testing best practices

---

## Artifact Map

Every artifact has exactly one home. No duplication.

| Artifact | Location | Created by |
|----------|----------|-----------|
| Design Doc | Lark Wiki | Team (manual) |
| `project_context.md` | `docs/` | `/project-context-generator` |
| `domain_model.md` | `docs/` | `/domain-model-generator` |
| Spec Funcional | Lark Wiki | `/functional-spec-generator` |
| `tdd.md` | `docs/epics/E-XXX/` | `/technical-design-document` |
| `epic.md` | `docs/epics/E-XXX/` | `/epic-generator` |
| Story file + folder | `docs/epics/E-XXX/stories/E-XXX_S-YYY/` | `/story-generator` |
| Lark Base records | Lark Base | `/write-epics-and-hu-in-base` |
| `spec.md` | story folder | `/spec` |
| `plan.md` + `todo.md` | story folder | `/plan` |
| Code + tests | project source | `/build` |
| ADRs | `docs/adrs/` | `dev-documentation-and-adrs` |

### Docs layout in target repos

```
docs/
├── inputs/                              ← Design Doc, Intake Brief
├── project_context.md                   ← /project-context-generator
├── domain_model.md                      ← /domain-model-generator
├── epics/
│   └── E-XXX_slug/
│       ├── epic.md                      ← /epic-generator
│       ├── tdd.md                       ← /technical-design-document (optional)
│       └── stories/
│           └── E-XXX_S-YYY_slug/
│               ├── E-XXX_S-YYY_slug.md  ← /story-generator (do not modify)
│               ├── spec.md              ← /spec
│               ├── plan.md              ← /plan
│               └── todo.md              ← /plan
└── adrs/                                ← dev-documentation-and-adrs
```

---

## Quick Start

**Step 1 — Add the Avila Tek marketplace** (only once per machine):

```bash
claude plugin marketplace add avila-tek github:avila-tek/avila-tek-skill-pack
```

**Step 2 — Install the plugin in your project** (run from inside the project):

```bash
claude plugin install avila-tek-skill-pack@avila-tek --scope project
```

This installs the plugin at project scope — it gets saved to `.claude/settings.json` so the entire team gets it automatically when they clone the repo.

**Step 3 — Activate without restarting:**

```bash
/reload-plugins
```

Stack standards load automatically on every session start. No additional setup needed.

---

## Lark Setup

`/write-epics-and-hu-in-base` requires three inputs before it can run:

| Input | Description |
|-------|-------------|
| **Epic IDs** | Which epics to sync (e.g. `E-002 E-003`) |
| **API Key** | Bearer token — `sk-xxxx...` (get from project lead) |
| **Base ID** | Target Lark Base identifier (visible in the Base URL) |

The default endpoint is the QA environment. Claude will ask you to confirm or override before sending.

---

## Design Principles

**One artifact, one place.** Project context lives in the repo. The Spec Funcional lives in Lark Wiki. Backlog records live in Lark Base. No duplication.

**The repo is the execution layer.** When development starts, everything needed is already in `docs/` — epics with ACs, stories with technical scope and business rules, a project context with glossary and constraints.

**Stories are the handoff point.** The planning track ends when the story file is committed. The dev track starts by reading it. The story's ACs become the spec's success criteria. Nothing is lost in translation.

**AI assists, humans decide.** Every skill asks questions before generating. It never invents business rules or field values. Every artifact is reviewed and committed by the team.
