---
description: Import boundary rules — dependency direction (UI→App→Infra→Domain), no cross-feature imports
globs: "apps/client/src/features/**/*.ts, apps/client/src/features/**/*.tsx, apps/admin/src/features/**/*.ts, apps/admin/src/features/**/*.tsx"
alwaysApply: false
---

# Import Boundaries

Import boundaries enforce the architecture. Without them, layers and features exist only in documentation.

---

## Dependency direction

```
UI → Application → Infrastructure → Domain
```

Domain is the innermost layer. Every other layer can import from it. Never import in the opposite direction.

### What can import what

| From \ To | Domain | Infrastructure | Application | UI | shared/ |
|---|---|---|---|---|---|
| **Domain** | self | NO | NO | NO | NO |
| **Infrastructure** | YES | self | NO | NO | NO |
| **Application** | YES | YES | self | NO | NO |
| **UI** | YES | NO (go through Application) | YES | self | YES |
| **shared/** | YES | NO | NO | self | self |

---

## Cross-feature rules

Features are vertical slices. No feature may import from another feature.

```typescript
// BAD — cross-feature import creates hidden coupling
import { UserAvatar } from '@/features/users/ui/components/userAvatar';

// GOOD — promote to shared, both features import from there
import { UserAvatar } from '@/shared/ui/components/userAvatar';
```

### Promotion paths

When two features need the same thing:

| Question | Location |
|---|---|
| Generic UI component, no business logic? | `shared/ui/components/` |
| Composed UI used by multiple features? | `shared/ui/components/` |
| Technical helper (formatting, parsing, HTTP)? | `shared/utils/` |
| Cross-cutting capability (upload, notifications)? | `shared/` (dedicated subfolder) |
| Business rule or domain constraint? | `shared/domain/` |
| Truly cross-app and stable? | `packages/*` |
| Specific to one feature? | Stays in that feature |

Start colocated in the feature. Promote only when reuse is proven (2+ features need it).

---

## Package boundary rules

| Package | Imported by | Notes |
|---|---|---|
| `@repo/schemas` | Infrastructure layer (DTO types), Domain layer (shared Zod schemas for forms) | Never import in UI directly |
| `@repo/services` | Infrastructure layer only (API client) | Never call from UI components |
| `@repo/utils` | Any layer | Pure utilities, no framework coupling |
| `@repo/ui` | UI layer only | shadcn/ui components, Tailwind tokens |
| `@repo/feature-flags` | UI layer (providers, wrappers) | Feature flag checks |

Never import app code from packages.

---

## Route layer (`app/`)

Routes are a thin composition layer. They wire features together but contain no business logic.

```typescript
// GOOD — route delegates to feature page
// app/(main)/habits/page.tsx
import { HabitsPage } from '@/features/habits/ui/pages/habitsPage';
export default function Page() {
  return <HabitsPage />;
}

// BAD — route contains business logic
// app/(main)/habits/page.tsx
import { HabitsService } from '@/features/habits/infrastructure/habits.service';
export default async function Page() {
  const service = new HabitsService();
  const habits = await service.getAll();
  const filtered = habits.filter(h => h.status === 'active'); // logic in route
  return <div>{filtered.map(...)}</div>;
}
```

Server Actions can be colocated near routes (e.g., `app/(main)/habits/actions.ts`) but should delegate to services.

See `agent_docs/frontend/routing.md` for route builders and route classification.

---

## Import order

Biome enforces import sorting automatically. The expected order is:

1. External packages (`react`, `@tanstack/react-query`, `zod`)
2. Monorepo packages (`@repo/schemas`, `@repo/utils`, `@repo/services`, `@repo/ui`)
3. Absolute app imports (`@/features/...`, `@/shared/...`, `@/lib/...`)
4. Relative imports (`./habitCard`, `../shared/avatar`)

Use `import type` for type-only imports.

---

## Anti-patterns

- **Service directly in UI** — UI should go through Application (queries/mutations), not call services directly.
- **Importing from another feature** — Promotes to `shared/` or `packages/*` first.
- **Circular dependencies** — If A imports B and B imports A, extract the shared piece to a lower layer or `shared/`.
- **`shared/` as junk drawer** — Every file in `shared/` should be generic. If it contains a feature name or `if (context === 'invoice')` branches, it belongs in the feature.
- **Using `@repo/services` API client directly in UI** — Always go through the feature's infrastructure service.
- **Premature extraction** — Don't move to `shared/` until 2+ features need it. Three similar lines > one premature abstraction.
