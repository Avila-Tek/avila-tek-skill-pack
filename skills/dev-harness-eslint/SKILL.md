---
name: dev-harness-eslint
description: >
  Analyzes project architecture and generates ESLint rules that encode team conventions — giving the agent and developers immediate feedback when code drifts from established patterns. Spanish triggers: "configura eslint", "añade reglas de lint", "el agente sigue cometiendo el mismo error de arquitectura".
---

# ESLint Harness

## Overview

Encode architectural decisions as ESLint rules. The goal is not just linting style — it is making the agent's own verify step self-correcting. Once rules exist, the agent runs `eslint --max-warnings 0` during `/build` and catches violations before committing, without needing human review for mechanical issues.

## When to Use

- Setting up a new project for the first time
- After a code review reveals recurring pattern violations
- When `/build` keeps producing similar architecture mistakes
- When onboarding a new stack, layer, or module to an existing project

## Process

### Phase 1: Discover

Read the project without touching any code:

1. Check for existing ESLint config in order: `eslint.config.js`, `eslint.config.mjs`, `.eslintrc.json`, `.eslintrc.js`, `package.json#eslintConfig`
2. Read the folder structure to identify architectural layers (controllers, services, repositories, domain, etc.)
3. Read 3–5 representative files per layer — focus on import statements and exports
4. Check for architecture docs: `docs/domain_model.md`, any TDD (`docs/epics/*/tdd.md`), ADRs
5. Identify naming conventions from existing filenames, class names, and function names

Document findings as a surface-assumptions block before asking anything:

```
FINDINGS:
1. Layers detected: controllers/, services/, repositories/, domain/
2. Existing ESLint config: .eslintrc.json (extends: eslint:recommended)
3. Import pattern: services import repositories directly (no interface layer)
4. Naming: PascalCase classes, camelCase functions, kebab-case files
5. No barrel exports in domain/
→ Confirm these before I generate rules.
```

### Phase 2: Clarify

Ask only about things discovery could not determine. One question at a time.

| Question | Why it matters |
|----------|---------------|
| Can controllers import from repositories directly? | Determines `no-restricted-imports` layer rules |
| Are barrel exports (`index.ts`) allowed in all layers? | Determines `import/no-internal-modules` scope |
| Are there naming conventions not visible in existing files? | Adds `id-match` or `unicorn/filename-case` rules |
| Are there known anti-patterns the team wants to ban? | Adds explicit `no-restricted-syntax` entries |

Do not proceed to Phase 3 until layer boundaries are confirmed.

### Phase 3: Generate

Write or update the ESLint config. Cover these rule categories:

#### Layer Boundary Enforcement

Use `no-restricted-imports` to prevent cross-layer violations:

```js
// Example: controllers must not import from repositories
{
  files: ['src/controllers/**'],
  rules: {
    'no-restricted-imports': ['error', {
      patterns: ['*/repositories/*', '*/repositories'],
    }],
  },
}
```

For feature-sliced architectures, encode the full dependency direction with `eslint-plugin-boundaries` instead of one-off `no-restricted-imports`. This is what mechanically prevents code landing in the wrong layer or leaking across features — a misplaced import becomes a build-breaking error caught in `/build` verify, regardless of session memory:

```js
// Dependency direction: domain ← infrastructure ← application ← ui
// Features are vertical slices and may not import each other.
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
  'boundaries/element-types': ['warn', {  // warn-first; promote to 'error' once the repo is clean
    default: 'disallow',
    rules: [
      { from: 'ui',             allow: ['application', 'domain', 'shared'] },
      { from: 'application',    allow: ['domain', 'infrastructure', 'shared'] },
      { from: 'infrastructure', allow: ['domain', 'shared'] },
      { from: 'domain',         allow: [] },
    ],
  }],
  'boundaries/no-private': ['warn', { allowUncles: false }], // no cross-feature imports → forces promotion to shared/
}
```

Map the `boundaries/elements` patterns to the project's actual layout — confirm the layer folder names in Phase 2 before generating these. For repos that predate the feature-sliced layout, read the override map declared in `docs/project_context.md` rather than assuming `src/features/*`.

#### Size & Complexity Budgets

These are the durable fix for files growing unbounded and single-responsibility drift. The numeric thresholds are the project's source of truth here — skills reference lint, not the reverse.

```js
{
  rules: {
    'max-lines': ['warn', { max: 250, skipBlankLines: true, skipComments: true }],
    'max-lines-per-function': ['warn', { max: 50, skipComments: true }],
    'max-depth': ['error', 3],
    'complexity': ['warn', 10],
  },
}
```

Default file budgets (hard error / soft warn) — override per repo in Phase 2:

| Artifact (file glob) | Warn | Error |
|---|---|---|
| Component / widget (`*.tsx` in `ui/`) | 150 | 250 |
| Hook / service / use-case | 120 | 200 |
| Util module (`shared/`, `packages/`) | 150 | 250 |
| Controller / route | 100 | 200 |

Use per-glob overrides to apply different `max-lines` caps to different artifact types.

#### Doc Comments on Shared Exports

A documented shared export is a discoverable one — this feeds the shared inventory's description column and strengthens the Reuse Scan in `/build`. Require it only on `shared/`/`packages/` public exports, not on feature-local code (where comment rot outweighs the benefit):

```js
{
  files: ['src/shared/**', 'packages/**'],
  rules: {
    'jsdoc/require-jsdoc': ['warn', { publicOnly: true, require: { FunctionDeclaration: true } }],
  },
}
```

#### Naming Conventions

Use `unicorn/filename-case` (if unicorn is available) or document the pattern in a comment if not:

```js
{
  rules: {
    'unicorn/filename-case': ['error', { case: 'kebabCase' }],
  },
}
```

#### Import Discipline

```js
{
  rules: {
    // No wildcard imports — makes dependencies explicit
    'no-restricted-syntax': ['error', {
      selector: 'ImportNamespaceSpecifier',
      message: 'Wildcard imports hide dependencies. Import only what you need.',
    }],
  },
}
```

#### Stack-Specific Rules

| Stack | Key rules to add |
|-------|-----------------|
| NestJS | Ban `new` in controllers (use DI); require `@Injectable()` on services |
| Next.js | Ban `useEffect` for data fetching in favor of Server Components |
| Express | Require error-first callback signatures; ban `req.body` without validation |
| Go | Not applicable (use golangci-lint instead — see note below) |

> **Non-JS stacks:** For Go, use `golangci-lint` with a `.golangci.yml`. For Flutter/Dart, use `analysis_options.yaml`. For Spring Boot, use Checkstyle + ArchUnit. This skill generates the appropriate config file — not ESLint — when a non-JS stack is detected.

The size/complexity and boundary recipes above have direct equivalents in every stack's linter — generate them into the right config, warn-first:

| Stack | Size & complexity | Layer / boundary |
|-------|-------------------|------------------|
| Go | `funlen`, `gocyclo`, `cyclop`, `nestif` (`.golangci.yml`) | `depguard` rules for import direction |
| Flutter / Dart | `lines_of_executable_code`, `cyclomatic_complexity` (dart_code_metrics in `analysis_options.yaml`) | `avoid-importing-entrypoint-exports` + custom rules |
| Spring Boot | Checkstyle `MethodLength`, `FileLength` | ArchUnit layered-architecture tests |

### Phase 4: Verify

Run the linter on the current codebase after applying the new rules:

```bash
npx eslint . --max-warnings 0
```

New rules must produce one of two clean outcomes:

| Outcome | Action |
|---------|--------|
| Zero violations | Done — rules are ready (set the rule to `error`) |
| Existing violations found | See rollout below |

**Warn-first rollout (existing repos).** Bulk structural rules — `max-lines`, `boundaries/*`, `complexity` — will surface many violations on day one. Inline-suppressing hundreds of sites is noise. Instead:

1. Land the rule as `warn` (not `error`). `npm run lint` still exits 0, so it never blocks ongoing work.
2. Record the violation count as tracked debt (a single tracking item per rule, not per site).
3. Burn the count down over time; **promote the rule to `error` once the repo reaches zero.**

Use targeted inline `// eslint-disable-next-line` with a TODO **only** for a small, finite set of intentional exceptions — never to silence a rule wholesale.

For high-value rules with few violations (e.g. cross-feature imports), you may go straight to `error` with inline suppressions for the known debt. Default to warn-first when the violation count is large.

Do not suppress rules wholesale. Inline suppressions must be targeted and explained.

### Phase 5: Integrate Self-Check into Build

After generating rules, update the project's verify step so the agent runs ESLint automatically during `/build`.

**Add to `package.json` scripts (if not present):**

```json
{
  "scripts": {
    "lint": "eslint . --max-warnings 0",
    "lint:fix": "eslint . --fix --max-warnings 0"
  }
}
```

**Update the verify step in CI / pre-commit hook:**

```bash
npm run lint
```

**Agent behavior after this skill runs:** During every `/build` cycle, after tests pass and before committing, run `npm run lint`. If violations appear, fix them in the same commit — do not leave lint failures in commits.

### Phase 6: Shared Inventory

The Reuse Scan in `/build` (`dev-incremental-implementation`) consults `docs/shared-inventory.md` — a generated, one-line-per-export index of `shared/` and `packages/`. Wire its generation here so it stays current:

1. Add a `shared:inventory` script to `package.json` that walks the public exports of `shared/` and `packages/*` and writes `docs/shared-inventory.md` in the format defined in `dev-context-engineering` ("The Shared Inventory"). A TS/JS project can use a `ts-morph` export walk; other stacks use their own AST/reflection tooling.

   > This skill specifies the script and format; it does not ship the generator. The generator is per-repo setup, since the export-walk tooling is stack-specific.

2. Wire regeneration so the inventory cannot silently drift:
   - Add it to the pre-commit hook (regenerate + `git add docs/shared-inventory.md` when files under `shared/`/`packages/` changed), or
   - Add a CI check that fails if `shared:inventory` produces a diff.

3. Until a generator exists, the inventory is maintained by the agent during `/build` (it appends/edits the relevant line whenever it adds a shared export — see the Clean Step Checklist).

## Output

At the end of this skill, the following must exist:

- [ ] ESLint config written or updated (no merge conflicts with existing rules)
- [ ] `package.json` has `lint` and `lint:fix` scripts
- [ ] Lint passes on current codebase (`npm run lint` exits 0, or known debt is documented as warn-first tracked debt)
- [ ] Size/complexity budgets and boundary rules present (warn-first on existing repos)
- [ ] Layer boundaries are documented as a comment block at the top of the ESLint config
- [ ] `shared:inventory` script + regeneration hook wired (or the manual-maintenance fallback noted)

## Red Flags

- Adding rules that suppress entire layers (`eslint-disable` at file level) — defeats the purpose
- Generating rules without verifying they pass on the current codebase
- Skipping Phase 2 — rules based on wrong assumptions create false positives that developers start ignoring
- Adding plugins that aren't installed as dev dependencies

## Verification

Before closing this skill:

- [ ] `npm run lint` exits 0 (or known debt is documented)
- [ ] Layer boundaries are explicit in the config
- [ ] Agent's `/build` flow will run lint as part of verify
- [ ] No dev dependency is missing for the rules generated
