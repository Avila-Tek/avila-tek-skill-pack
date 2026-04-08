---
description: Frontend TypeScript/React code conventions — naming, exports, Safe<T>, Tailwind/shadcn stack
globs: "apps/client/src/**/*.tsx, apps/client/src/**/*.ts, apps/admin/src/**/*.tsx, apps/admin/src/**/*.ts"
alwaysApply: false
---

# Code Standards (Frontend)

Keep changes consistent with this repo. Prefer clarity, small diffs, and predictable patterns.

## File & export conventions

- Use **camel-case** for files and folders.
- **One React component per file** (1 exported component).
- Prefer **named exports** (`export function X()`); Next.js **route files** (`page.tsx`, `layout.tsx`, `error.tsx`, `loading.tsx`) may use **default exports**.
- Avoid **barrel exports** (`index.ts`) unless a package already depends on them.
- Co-locate files by feature; don't move code to `shared/` “just in case”.

## Naming conventions (file suffixes by layer)

| Layer / Artifact | Suffix | Example |
|---|---|---|
| Domain model | `*.model.ts` | `habit.model.ts` |
| Domain logic | `*.logic.ts` | `habit.logic.ts` |
| Domain constants | `*.constants.ts` | `habit.constants.ts` |
| Form schema | `*.form.ts` | `habits.form.ts` |
| Infrastructure interface | `*.interfaces.ts` | `habits.interfaces.ts` |
| Infrastructure transform | `*.transform.ts` | `habits.transform.ts` |
| Infrastructure service | `*.service.ts` | `habits.service.ts` |
| Application query hook | `use*.query.ts` | `useHabits.query.ts` |
| Application mutation hook | `use*.mutation.ts` | `useCreateHabit.mutation.ts` |
| Application use case | `*.useCase.ts` | `createHabitFlow.useCase.ts` |
| UI page | in `pages/` folder | `habitsPage.tsx` |
| UI widget | in `widgets/` folder | `habitCardWidget.tsx` |
| UI component | descriptive camelCase | `habitProgressBar.tsx` |
| Server Action file | `*.actions.ts` | `user.actions.ts` |

Component name must be PascalCase and match the file purpose: `habitCard.tsx` exports `function HabitCard()`.

## Import order

Biome enforces import sorting automatically. The expected order:

1. External packages (`react`, `@tanstack/react-query`, `zod`)
2. Monorepo packages (`@repo/schemas`, `@repo/utils`, `@repo/services`, `@repo/ui`)
3. Absolute app imports (`@/features/...`, `@/shared/...`, `@/lib/...`)
4. Relative imports (`./habitCard`, `../shared/avatar`)

Use `import type` for type-only imports.

## TypeScript

- **Strict**: no `any`, no `as any`, no unsafe coercion.
- Prefer **interfaces** for object shapes; use **type** for unions/mapped types.
- Add **explicit return types** for exported/public functions.
- Keep types close to usage; use `types.ts` only when shared inside a module.
- Validate **external data** (API, forms, env) with **Zod**.

## React & Next.js

- Prefer **Server Components**; minimize **`use client`**, `useEffect`, and local `setState`.
- Client components only for **browser APIs / interactivity**; keep them small.
- Use React APIs via **`React.*`** (import React, avoid importing hooks directly).
- Components must be **function declarations** (no React arrow components).
- Prefer composition over prop drilling; avoid passing props more than ~3 levels.

## UI / Styling

- Use **Tailwind CSS** + **shadcn/ui** (from `packages/ui`) + **Radix** + **Lucide**.
- Check `packages/ui` before installing new shadcn components.
- Build **responsive** UI (mobile-first); avoid bespoke styling patterns.

## Async & data work

- Prefer **async/await** over `.then()`.
- Parallelize independent work with **`Promise.all`**.
- Avoid `await` inside loops for independent operations.
- Use **TanStack React Query** for server-state (queries/mutations/cache/invalidation).
- Keep backend shapes (DTOs) out of UI; return **Domain-friendly** data from hooks/services.

## Rendering & readability

- Prefer **ternaries** (`condition ? <X /> : null`) over `&&` for conditional rendering — avoids rendering `0`, `""`, or `NaN` when the condition is not strictly boolean.
- Avoid nested ternaries; move branching outside JSX.
- Destructure props in the function signature; define defaults there.
- Avoid uncontrolled prop spreading (`{...props}`) unless intentional and typed.

## Error handling

- Use `Safe<T>` and `safe()` from `@repo/utils` at system boundaries (API calls, I/O).
- Infrastructure services: return `Safe<T>` — **never throw**. Propagate `{ success: false, error }` from the API.
- Application queries/mutations: unwrap `Safe<T>` in `queryFn`/`mutationFn` — throw only at the React Query boundary so React Query captures it.
- Application use cases: return `{ ok: true, data } | { ok: false, error }` — never throw.
- Server Actions: return `Safe<T>` — never throw.
- UI: route-level `error.tsx` for unexpected failures. Widgets handle their own error states via React Query’s `isError`.
- Don’t add error handling “just in case”.
- When needed: handle expected errors explicitly; keep user-facing messages safe.
- Unexpected errors should be logged/observed, not leaked to UI verbatim.
- See `agent_docs/frontend/error-handling.md` for full patterns.
