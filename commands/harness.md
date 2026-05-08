---
name: harness
description: Configure development harness tooling — linters, static analysis, and self-check rules that let the agent catch violations automatically during build
---

## Overview

The `/harness` command sets up or improves the tooling layer that makes the agent self-correcting. Instead of relying on human review to catch mechanical issues (wrong layer imports, naming violations, missing patterns), harness tools catch them automatically during every `/build` cycle.

## Skills

| Sub-command | Skill | When to use |
|-------------|-------|-------------|
| `/harness eslint` | `dev-harness-eslint` | Generate ESLint rules from project architecture |
| `/harness` (no sub-command) | `dev-harness-eslint` | Default — ESLint is the current entry point |

> Additional harness skills will be added here as the system grows (e.g., TypeScript strict mode, architecture fitness functions, dependency audits).

## Usage

```
/harness
/harness eslint
```

## What Claude Does

Invoke `dev-harness-eslint`:

1. Discover the project's architecture layers, naming conventions, and existing lint config
2. Surface assumptions — confirm layer boundaries before generating rules
3. Generate ESLint rules that encode team conventions (layer boundaries, naming, import discipline)
4. Verify rules pass on the current codebase
5. Add `lint` and `lint:fix` scripts to `package.json`
6. Integrate lint into the agent's `/build` verify step

## Integration with `/build`

After `/harness` runs, the agent's verify cycle becomes:

```
Write failing test (RED)
  → Implement minimum code (GREEN)
    → Run tests
      → Run lint (eslint --max-warnings 0)
        → Commit
```

Lint failures are treated as build failures — the agent fixes them before committing.

## Chaining Rules

| Type | Skill | When |
|------|-------|------|
| Optional | `dev-ci-cd-and-automation` | Add lint to CI pipeline after local harness is configured |
