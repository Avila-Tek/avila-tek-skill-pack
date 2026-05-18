---
name: dev-harness-eslint
description: Analyzes project architecture and generates ESLint rules that encode team conventions — giving the agent and developers immediate feedback when code drifts from established patterns. Spanish triggers: "configura eslint", "añade reglas de lint", "el agente sigue cometiendo el mismo error de arquitectura".
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

> **Non-JS stacks:** For Go, use `golangci-lint` with a `.golangci.yml`. For Flutter/Dart, use `analysis_options.yaml`. This skill generates the appropriate config file — not ESLint — when a non-JS stack is detected.

### Phase 4: Verify

Run the linter on the current codebase after applying the new rules:

```bash
npx eslint . --max-warnings 0
```

New rules must produce one of two clean outcomes:

| Outcome | Action |
|---------|--------|
| Zero violations | Done — rules are ready |
| Existing violations found | Document them as known debt; add `// eslint-disable-next-line` with a TODO comment at each site; open a tracking item |

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

## Output

At the end of this skill, the following must exist:

- [ ] ESLint config written or updated (no merge conflicts with existing rules)
- [ ] `package.json` has `lint` and `lint:fix` scripts
- [ ] Lint passes on current codebase (`npm run lint` exits 0, or known debt is documented inline)
- [ ] Layer boundaries are documented as a comment block at the top of the ESLint config

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
