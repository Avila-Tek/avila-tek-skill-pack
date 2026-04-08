---
description: Frontend Clean Architecture — feature-driven layers (UI, Application, Domain, Infrastructure)
globs: "apps/client/src/features/**/*.ts, apps/client/src/features/**/*.tsx, apps/admin/src/features/**/*.ts, apps/admin/src/features/**/*.tsx, packages/features/src/**/*.ts, packages/features/src/**/*.tsx"
alwaysApply: false
---

# Frontend Architecture

## Repo Mental Model

We use a **Clean Architecture-inspired** model adapted to React and a **feature-driven** organization.

### Layers (outside → inside)

- **UI**: screens/components (rendering and visual state)
- **Application**: orchestration (use-cases, React Query hooks)
- **Domain**: business language (models + pure domain rules)
- **Infrastructure**: API/services, DTO transforms, technical concerns

**Dependency direction** (allowed):

```
UI → Application → Infrastructure → Domain
```

Domain is the innermost layer — every other layer can import from it. **Never** import in the opposite direction of the arrows above.

### Feature-driven organization

We group code by product functionality (a "feature"), not by technical type.

A feature is a complete user-facing capability.

**Promise:** If you delete `features/<feature>`, the rest of the app should still compile (that capability simply disappears).

### Suggested structure

```
src/
  app/                # Next.js routes (thin composition layer)
  context/            # React context providers (client providers, themes, query client)
  features/           # Product features (vertical slices)
  shared/             # Cross-cutting UI + utilities
  lib/                # App-level helpers (query client, env, config)
```

> If your repo differs, follow the _intent_ above: routes are thin; features own their flows; shared is for reusable primitives.

See `agent_docs/frontend/routing.md` for route organization, route builders, and navigation patterns.

## How to slice a feature

A feature should be removable without breaking the rest of the app.

```
[feature-name]/
  ui/
    pages/*.tsx        // — route-level screens (compose widgets; minimal logic)
    layouts/*.tsx      // — shared layout wrappers for route groups
    widgets/*.tsx      // — self-contained sections (own loading/error/empty states)
    components/*.tsx   // — reusable presentational pieces (small interactions only)
    context/*.tsx      // — React context providers scoped to this feature
    hooks/*.ts         // — custom hooks for this feature's UI
  application/
    queries/use*.query.ts       // — React Query reads (cache keys, enabled, retries)
    mutations/use*.mutation.ts  // — React Query writes
    useCases/*.useCase.ts       // — flow orchestration (simple API for UI)
  domain/
    *.model.ts         // — domain entities/value objects (frontend-friendly shapes)
    *.logic.ts         // — pure rules/invariants (no side effects)
    *.constants.ts     // — enums, query keys, domain constants
    *.form.ts          // — Zod form schemas, form types, default value factories
  infrastructure/
    *.interfaces.ts    // — DTO aliases from @repo/schemas, response wrappers, API contracts
    *.transform.ts     // — DTO ↔ Domain mapping
    *.service.ts       // — data-access logic (implements contracts from interfaces)
```

> **Note on DTOs:** API input/output types (DTOs) are defined in `@repo/schemas`. Infrastructure `*.interfaces.ts` files create local aliases, response wrapper types, and service contracts — not raw DTO definitions.

## Boundaries (avoid spaghetti)

### 1) No feature-to-feature imports

- ✅ `features/<x>` may import from `shared/*`, `lib/*`, and packages (e.g. `@repo/services`).
- ❌ `features/<x>` importing `features/<y>/*` is not allowed.

If two features need the same thing:

- Promote to `shared/` if it's generic UI/capability.
- Promote to `packages/*` if it's truly cross-app and stable.
