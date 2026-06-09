# Proposal: Dev-Skill Refactor for Reuse, SOLID, and Token Discipline

**Date:** 2026-06-08
**Status:** **Implemented 2026-06-08** — skill edits applied. Per-repo lint dependencies (`eslint-plugin-boundaries`, etc.) and the `shared:inventory` generator script remain project-side setup, performed by `dev-harness-eslint` when run against a repo.

**Decisions taken at implementation (from §12):**
- **Promotion (§4.1):** hybrid — pure technical helpers (formatters/parsers/validators) go to `shared/` on first write; UI/domain code stays colocated until a 2nd feature needs it.
- **Budgets (§5):** proposed defaults adopted as lint defaults (overridable per repo).
- **Lint rollout:** warn-first grace period on existing repos; promote to `error` once clean.
- **Inventory:** format + regeneration wiring specified in the skills; the generator script itself is per-repo setup, not shipped in the pack.
- **Monorepo override:** boundary rules read an override map from `docs/project_context.md` rather than hardcoding `src/features/*`.
**Scope:** Development skills only (`/spec`, `/plan`, `/build`, `/review`, `/ship` and the skills they chain to). Planning skills (0–6) untouched.
**Enforcement stance:** **Lint-first** — machine-enforced rules are the source of truth for the mechanical concerns (file/function size, layer boundaries, cross-feature imports). Skills carry the rituals (reuse scan, promotion decisions) and *reference* lint output; they do not re-state mechanical limits as prose the agent must remember.

---

## 1. Problem statement

Two recurring failures after months of use:

1. **Duplication & misplacement.** Claude concentrates code into one file; writes functions in feature folders that are clearly shared; and re-writes helpers that already exist in `shared/`/`packages/` because each story runs in a fresh session with no memory of the last.
2. **SOLID / clean-code drift.** Files grow unbounded; single-responsibility erodes; size and complexity limits are ignored during the build.

Secondary concerns: **token consumption** and **hallucination** from loading too much documentation during spec/plan/build.

---

## 2. Diagnosis — the rules mostly exist; enforcement and timing don't

The skill pack already encodes the right knowledge. It fails to *fire* at the right moment, or it's advisory prose with no forcing function.

| Pain | Rule already in the pack | Why it doesn't fire |
|---|---|---|
| Reuse across stories | `import-boundaries.md` "Promotion paths" table; `context-engineering` Red Flag "re-implements utilities that already exist" | `/build` has **no search-before-write gate**. It's a Red Flag with no ritual behind it. |
| Files grow / SOLID | `code-simplification` Rule of 500, 50-line function, 3-level nesting, 5-line duplication | These live in a **separate** skill (`/code-simplify`) not in the build loop. The CLEAN step of `incremental-implementation` says "remove duplication" with **no thresholds**. |
| Shared code in feature folders | "Start colocated, promote when 2+ features need it" | Backfires under stateless sessions (see §2.1). |
| Token bloat / hallucination | `context-engineering` "context flooding < 2,000 lines" guidance | Stack standards are **duplicated** across `stacks/*/agent_docs/` and `skills/dev-*/references/*`, and STACK.md "Required Reading" forces heavy reads on *every* implementation. |

### 2.1 The promotion heuristic backfires in stateless sessions

"Promote to `shared/` only when 2+ features need it" assumes one developer who remembers writing the helper. Our sessions are stateless:

```
Story A session:  writes formatCurrency() locally   → 1 use, correctly NOT promoted
Story B session:  fresh context, never greps shared/ → writes formatCurrency() AGAIN
Result: two copies, neither promoted. The rule guaranteed the duplication.
```

A human avoids this through *continuity of memory*. The agent has none, so it needs an explicit, cheap memory surface (a shared-code index) plus a forced search step to substitute for that continuity. This is the conceptual core of Improvement 1.

### 2.2 What the reference packs contribute

- **affaan-m/ECC `search-first`** — a *mandatory* search order (repo → registries → existing skills) with an **adopt / extend / compose / build** decision matrix and a "show search evidence" rule before any net-new code. We have nothing equivalent. → Improvement 1.
- **addyosmani Rule-of-500 cluster** — hard numeric triggers (500-line refactor → automate; 50-line function → split; 3-level nesting → guard clauses; 5-line dup → extract). We already copied these into `code-simplification`; we need them *in the build loop* and *in lint*. → Improvements 2 & 3.
- **github/spec-kit `/analyze`** — severity-labeled cross-artifact consistency check. Useful but **out of scope** for the four pains; noted as a future addition.

---

## 3. Design principles for this refactor

1. **Lint is the source of truth for mechanical limits.** Sizes, nesting depth, layer/feature import boundaries → ESLint / golangci-lint / `analysis_options.yaml`. Skills point at lint output instead of repeating numbers. A lint rule catches *every* violation; a prompt catches *some*.
2. **Skills own judgment, not mechanics.** "Should this be promoted to shared?" and "is this helper generic?" are judgment calls — they stay in skills. "Is this file > 300 lines?" is mechanical — it goes to lint.
3. **One home per fact.** Eliminate the `agent_docs` ↔ `references` duplication. Cross-reference, never copy.
4. **Progressive disclosure.** Load the heavy standards file only for the task type that needs it, not on every implementation.
5. **No new numbers invented.** Reuse the thresholds already in `code-simplification`; thread them through, don't fork them.

---

## 4. Improvement 1 — Reuse Scan gate + `shared-inventory.md`

**Targets:** pain #1. **Files:** `dev-incremental-implementation`, `dev-context-engineering`, new generator script, stack STACK.md.

### 4.1 The Reuse Scan gate (in `/build`)

Add a mandatory step to the Increment Cycle, *before* GREEN, whenever the slice introduces a helper, util, mapper, validator, or domain function. The agent must emit evidence:

```
REUSE SCAN — before writing `formatCurrency`:
  rg -i "formatcurrency|formatmoney|currency" shared/ packages/ src/lib/
  → packages/utils/money.ts: formatMoney(cents: number): string
DECISION: reuse formatMoney. Not writing a new helper.
```

Decision matrix (adapted from ECC, aligned with our `import-boundaries.md`):

| Search result | Action |
|---|---|
| Exact match exists | Import it. Do not re-implement. |
| Close match (needs a tweak) | Extend in place / add a parameter — don't fork. |
| No match, **generic** (no feature-specific logic) | Write it **directly in `shared/`** (or `packages/*`), not in the feature folder. |
| No match, **feature-specific** | Keep it colocated in the feature. |

This deliberately **overrides the "wait for 2 uses" rule for provably-generic code** (§2.1): if a helper has zero feature coupling, it goes to `shared/` on first write, because the next session won't remember to promote it. Premature *abstraction* is still discouraged; premature *placement* of obviously-shared code is now encouraged.

> Cost note: the scan is scoped to `shared/`, `packages/`, `lib/` and reads filenames + signatures via `rg`, not file bodies. ~hundreds of tokens, not a repo scan.

### 4.2 `docs/shared-inventory.md` — the agent's memory surface

A generated, one-line-per-export index loaded at the start of `/build` and `/plan`:

```markdown
# Shared Inventory (generated — do not edit by hand)
> Regenerate: `npm run shared:inventory`

## packages/utils
- formatMoney(cents: number): string — "$1.00" formatting
- slugify(input: string): string — URL-safe slug

## shared/ui/components
- <DataTable> — paginated, sortable table (server-driven)
- <ConfirmModal> — destructive-action confirmation
```

This is exactly the "Hierarchical Summary / Project Map" that `context-engineering` already describes (lines 158–179) — we make it **concrete, generated, and wired in**. The generator is a small script (e.g. `ts-morph`/`tsc` export walk for TS; per-stack equivalents) added to the project, invoked by the harness skill. The inventory is the cheap substitute for cross-session memory: the agent reads ~50 lines instead of grepping the repo.

### 4.3 Doc-comment requirement on shared exports (ties into the comments debate, §8)

Every exported symbol in `shared/`/`packages/` carries a one-line doc comment. This feeds the inventory generator (the description column) and makes the reuse scan richer. Enforced by lint (`require-jsdoc`-style, scoped to those paths) — see §6.

---

## 5. Improvement 2 — Size & complexity thresholds in the build loop

**Targets:** pain #2. **Files:** `dev-incremental-implementation` (CLEAN step), `dev-code-simplification` (becomes the single threshold home that build references).

The CLEAN step currently says "improve names, remove duplication, flatten nesting" with no thresholds. Rewrite it to run an explicit check that **references** (not duplicates) the `code-simplification` thresholds, and notes that lint will hard-fail the mechanical ones:

```
CLEAN — after GREEN, before Verify:
  □ Any function > 50 lines?      → split (lint: max-lines-per-function)
  □ Any file over budget?         → extract a module (lint: max-lines)
  □ Nesting > 3 levels?           → guard clauses (lint: max-depth)
  □ 5+ duplicated lines?          → extract; run Reuse Scan on the target location
  □ New shared export?            → add doc comment, regenerate inventory
```

`code-simplification` stays the canonical definition of the thresholds; `incremental-implementation` links to it rather than restating the numbers (principle 5). The build loop is where they now actually fire.

**File-size budgets** (the one number we must pick) — proposed defaults, overridable per stack:

| Artifact | Soft budget (lint warns) | Hard cap (lint errors) |
|---|---|---|
| Component / widget (`.tsx`) | 150 | 250 |
| Hook / service / use-case | 120 | 200 |
| Util module | 150 | 250 |
| Controller / route | 100 | 200 |

These are starting points for discussion, not final — see Open Questions.

---

## 6. Improvement 3 — ESLint harness rule recipes (lint-first centerpiece)

**Targets:** pain #2 (durably) and pain #1's mechanical half (cross-feature imports). **Files:** `dev-harness-eslint` (add a "Rule Recipes" reference), `/build` verify step already runs `eslint --max-warnings 0`.

The harness skill already wires lint into `/build` verify. It needs concrete, copy-ready recipes per concern. Proposed additions:

### 6.1 Size & complexity (JS/TS)

```js
{
  rules: {
    'max-lines': ['error', { max: 250, skipBlankLines: true, skipComments: true }],
    'max-lines-per-function': ['warn', { max: 50, skipComments: true }],
    'max-depth': ['error', 3],
    'complexity': ['warn', 10],
  },
}
```

### 6.2 Layer + cross-feature boundaries (the durable fix for misplacement)

Use `eslint-plugin-boundaries` to encode the `import-boundaries.md` matrix as machine rules:

```js
// boundaries: domain ← infrastructure ← application ← ui ; features cannot import each other
settings: {
  'boundaries/elements': [
    { type: 'domain',         pattern: 'src/features/*/domain/*' },
    { type: 'infrastructure', pattern: 'src/features/*/infrastructure/*' },
    { type: 'application',    pattern: 'src/features/*/application/*' },
    { type: 'ui',             pattern: 'src/features/*/ui/*' },
    { type: 'shared',         pattern: 'src/shared/*' },
  ],
},
rules: {
  'boundaries/element-types': ['error', {
    default: 'disallow',
    rules: [
      { from: 'ui',             allow: ['application', 'domain', 'shared'] },
      { from: 'application',    allow: ['domain', 'infrastructure'] },
      { from: 'infrastructure', allow: ['domain'] },
      { from: 'domain',         allow: [] },
    ],
  }],
  // no cross-feature imports — forces promotion to shared/
  'boundaries/no-private': ['error', { allowUncles: false }],
}
```

This is what actually stops "function in the wrong folder": an `import` from another feature, or from `ui/` into `infrastructure/`, becomes a build-breaking lint error — caught in `/build` verify, every time, regardless of session memory.

### 6.3 Doc comments on shared exports

```js
{
  files: ['src/shared/**', 'packages/**'],
  rules: {
    'jsdoc/require-jsdoc': ['warn', { publicOnly: true, require: { FunctionDeclaration: true } }],
  },
}
```

### 6.4 Non-JS stacks (the harness skill already branches here)

| Stack | Tool | Size/complexity | Boundaries |
|---|---|---|---|
| Go | `golangci-lint` (`.golangci.yml`) | `funlen`, `gocyclo`, `cyclop`, `nestif` | `depguard` for import direction |
| Flutter/Dart | `analysis_options.yaml` | `lines_of_executable_code`, `cyclomatic_complexity` (dart_code_metrics) | `avoid-importing-entrypoint-exports`, custom |
| Spring Boot | Checkstyle / ArchUnit | `MethodLength`, `FileLength` | ArchUnit layered-architecture tests |

The harness skill should ship one recipe block per stack, generated into the right config file.

> **Migration discipline (already in the harness skill):** when enabling these rules on an existing repo, existing violations become documented debt with targeted inline suppressions + a tracking item — *not* wholesale rule-disabling.

---

## 7. Improvement 4 — Token / standards consolidation

**Targets:** token bloat + hallucination. **Files:** `CLAUDE.md`, `stacks/*/STACK.md`, `skills/dev-*/references/*`, `dev-context-engineering`.

### 7.1 Resolve the `agent_docs` ↔ `references` contradiction

**Correction (post-implementation):** the original draft assumed `skills/dev-*/references/{stack}.md` *duplicated* `stacks/*/agent_docs/`. Inspection disproved this — the skill `references/` files are **condensed, skill-scoped checklists** (e.g. `dev-code-review-and-quality/references/nestjs.md` is 96 lines of review-specific naming rules + red flags) versus the 746-line deep `agent_docs/architecture.md`. They are *not* redundant; they are good progressive disclosure and were **kept untouched**.

The real problem was a **documentation contradiction**, not duplication:

- `skills/dev-using-agent-skills/SKILL.md`: *"agent_docs contain general reference only — skills do not defer to them at runtime."*
- every `stacks/*/STACK.md` "Required Reading": *"Read the agent_docs files listed for your task type."*

These directly contradict — skills *do* read `agent_docs` at runtime.

**What was implemented:**
- Rewrote the `using-agent-skills` "Where Standards Live" section to describe the real model: `STACK.md` (entry point/index) → `agent_docs/*` (deep standards, loaded on demand) → `references/{stack}.md` (condensed per-skill checklist). Added the three-layer "further from universal → closer to the project" rule of thumb (see the companion three-layer-model proposal).
- The skill `references/` files were **not** collapsed or deleted.

### 7.2 Make "Required Reading" progressive

`STACK.md` currently forces `architecture.md` + `code-standard.md` + `import-boundaries.md` for **any** implementation. Re-tier so a one-line change doesn't drag in three docs:

| Trigger | Load |
|---|---|
| Editing within an existing file, no new module/export | `code-standard.md` only |
| Creating a new module / crossing a layer | + `architecture.md`, `import-boundaries.md` |
| Data fetching / forms / routing / auth | + the one matching doc |

### 7.3 Spec/plan context budget

`/spec` and `/plan` can load project_context + domain_model + story + epic + TDD simultaneously. Add an explicit instruction (leaning on `context-engineering`'s existing "< 2,000 lines focused" rule): **load the section, not the document** — e.g. read only the relevant epic scope and the domain entities named in the story, not every doc end-to-end. This is the main hallucination lever for the planning-heavy phases.

---

## 8. Comments policy change

The team's argument — AI can keep comments fresh better than humans — is accepted **narrowly**:

- **Keep** "comment the *why*, not the *what*" as the default for private / feature-local code (rot risk still outweighs benefit there).
- **Add** a *requirement* for a one-line doc comment on every **exported `shared/`/`packages/` symbol** (§4.3, enforced §6.3). Rationale: a documented shared function is a *discoverable* one — this directly strengthens the reuse scan and the inventory, so the comment rule and the duplication fix reinforce each other.
- **No** blanket relaxation toward "comment everything" — that reintroduces rot for marginal gain.

Update sites: `code-simplification` (the "comments explaining what → delete" table gets the shared-export exception), `code-review-and-quality` axis 2.

---

## 9. How `/build` ties it all together (target flow)

```
/build  (incremental-implementation)
  └─ For each slice:
       RED   — failing test
       ├─ REUSE SCAN (Imp.1) ── evidence + adopt/extend/promote/build decision
       GREEN — minimum code, placed per the decision matrix
       CLEAN — size/complexity checklist (Imp.2), referencing code-simplification
       VERIFY — npm test && npm run build && npm run lint  ← lint enforces Imp.3
                (max-lines, boundaries, no cross-feature, jsdoc on shared)
                regenerate shared-inventory if a shared export changed
       COMMIT
```

Lint failure = build not done. The mechanical rules can't be forgotten because they're not in the prompt — they're in the verify command.

---

## 10. Per-file change list (summary)

| File | Change | Improvement |
|---|---|---|
| `skills/dev-incremental-implementation/SKILL.md` | Add Reuse Scan step before GREEN; rewrite CLEAN with threshold checklist (refs code-simplification); load shared-inventory at start | 1, 2 |
| `skills/dev-context-engineering/SKILL.md` | Promote "Hierarchical Summary" → concrete `shared-inventory.md`; add reuse-scan as anti-starvation tactic | 1 |
| `skills/dev-harness-eslint/SKILL.md` | Add "Rule Recipes" reference (size, boundaries, jsdoc) per stack; generate shared-inventory script | 1, 3 |
| `skills/dev-code-simplification/SKILL.md` | Becomes canonical threshold home; add shared-export comment exception | 2, 8 |
| `skills/dev-code-review-and-quality/SKILL.md` | Axis 3: cite boundary lint; axis 2: shared-export doc-comment exception | 3, 8 |
| `stacks/{nextjs,nestjs,go,react-native,spring-boot,flutter}/STACK.md` | Made "Required Reading" progressive (small-edit vs new-module tiers) | 4 |
| `stacks/{express,fastify}/STACK.md` | Added progressive-reading note (no prior intro line) | 4 |
| `skills/dev-*/references/{stack}.md` | **Kept** — condensed skill-scoped checklists, not duplicates (claim corrected, see §7.1) | 4 |
| `skills/dev-using-agent-skills/SKILL.md` | Fixed the "skills do not defer to agent_docs" contradiction; documented the real STACK.md → agent_docs → references model + three-layer rule of thumb | 4 |
| (project repos) `npm run shared:inventory` script + lint deps | Generator + `eslint-plugin-boundaries` etc. — performed per-repo by `dev-harness-eslint` (spec'd, not shipped) | 1, 3 |

---

## 11. Rollout sequence

1. **Imp.3 (lint recipes)** first — it's the foundation everything else references. Pilot on one repo per stack.
2. **Imp.1 (reuse scan + inventory)** — depends on the inventory generator shipping with the harness.
3. **Imp.2 (build CLEAN thresholds)** — trivial once lint owns the numbers.
4. **Imp.4 (consolidation)** — can proceed in parallel; lowest risk, pure token savings.
5. Comments policy (§8) folded into whichever of Imp.1/Imp.3 lands first.

Each skill edit is independently revertable; pilot on one active project before pack-wide rollout.

---

## 12. Open questions / risks

1. **File-size budgets (§5):** are the proposed numbers right for our codebases? Need 2–3 sample repos checked against them before locking in.
2. **`eslint-plugin-boundaries` adoption:** existing repos will surface many violations on day one. Acceptable as tracked debt, or do we want a grace-period `warn` phase first?
3. **Inventory generator maintenance:** who owns the per-stack generator scripts? Risk of the inventory going stale if regeneration isn't wired into a pre-commit hook / CI.
4. **Monorepo nuance:** the boundary rules assume the feature-sliced layout. Repos that predate it need a per-repo override map.
5. **Promotion override (§4.1):** moving provably-generic code to `shared/` on first write is a real departure from the current rule. Confirm the team agrees before encoding it — it's the highest-judgment change here.
