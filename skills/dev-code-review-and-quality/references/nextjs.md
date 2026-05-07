# Next.js — Code Review Reference

## File Naming Conventions (by layer)

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
| Server Action file | `*.actions.ts` | `user.actions.ts` |

Component name must be PascalCase and match the file purpose. One exported component per file.

## Architecture Red Flags

- Business logic inside `app/` route files (`page.tsx`, `layout.tsx`) — pages and layouts must be thin; logic belongs in features
- `useEffect` for data fetching — use TanStack Query (`useQuery`, `useMutation`) for all server state
- Direct `fetch()` inside a component without TanStack Query — no cache, no deduplication, no loading/error states
- Prop drilling deeper than ~3 levels — introduce context or restructure
- Mixing `'use client'` into what could be a Server Component — `'use client'` should be a leaf in the tree, not a container
- Infrastructure imports (`*.service.ts`, HTTP clients) directly inside domain or application layers

## Code Standards

**TypeScript:**
- No `any`, no `as any`, no unsafe coercions
- Explicit return types on exported/public functions
- `import type` for type-only imports
- Validate all external data (API responses, form input, env) with Zod

**React / Next.js:**
- Prefer Server Components; minimize `'use client'`
- Components must be function declarations — no arrow component exports (`export const MyComponent = () =>`)
- Prefer ternary (`condition ? <X /> : null`) over `&&` for conditional rendering — `&&` renders `0` and `""` as text
- Avoid nested ternaries; move branching outside JSX
- No prop spreading (`{...props}`) without explicit typing

**Async:**
- `async/await` over `.then()`
- `Promise.all` for independent parallel operations
- No `await` inside a loop for independent operations

## Error Handling

`Safe<T>` pattern from `@repo/utils` at system boundaries:

- **Infrastructure services** → return `Safe<T>`, never throw
- **Application query/mutation hooks** → unwrap `Safe<T>` in `queryFn`/`mutationFn`, throw only at the React Query boundary
- **Application use cases** → return `{ ok: true, data } | { ok: false, error }`, never throw
- **Server Actions** → return `Safe<T>`, never throw
- **UI** → route-level `error.tsx` for unexpected failures; widgets handle their own error states via React Query `isError`

## TanStack Query Conventions

- All server state via React Query — no manual `useState` + `useEffect` for remote data
- `queryKey` must be deterministic and include all variables the query depends on
- Invalidate queries after mutations — don't manually update cache unless necessary
- Loading/error/empty states all handled; no component that only handles the success case

## Verification Checklist

- [ ] `npm run build` — no TypeScript errors
- [ ] `npm test` — all tests pass
- [ ] `npm run lint` — no ESLint/Biome errors
- [ ] `npm run type-check` — strict TypeScript passes
- [ ] No logic in `app/` route files — pages/layouts are thin
- [ ] No `useEffect` for data fetching — TanStack Query used instead
- [ ] No `any` in changed files
- [ ] External data validated with Zod (API responses, form inputs)
- [ ] All async boundaries have loading, error, and empty states
- [ ] No `console.log` in changed files
- [ ] New API routes have authentication checks (middleware or Server Action auth guard)
