# React Native — Code Review Reference

## Architecture Red Flags

These are blocking findings in a code review:

- Infrastructure imports (`*.service.ts`, HTTP clients, `authClient`) directly inside domain or application layers — dependency direction must point inward only
- Direct `fetch()` or API calls inside a screen component — all server state goes through TanStack Query hooks
- Business logic inside a screen component — screens are thin; logic belongs in use cases or query/mutation hooks
- Manual Zustand auth store managing session state — `authClient.useSession()` is the session source of truth
- Storing auth tokens in `AsyncStorage` — use `expo-secure-store` via better-auth `expoClient()`
- Auth checks duplicated across individual screens — auth routing belongs in root `_layout.tsx`
- `useEffect` for data fetching — TanStack Query handles all data synchronization

## Layer Boundaries

```
Presentation (Screens, Components, Navigation)
      ↓ depends on
Application (use*.query.ts, use*.mutation.ts, *.useCase.ts)
      ↓ depends on
Domain (*.model.ts, *.logic.ts, validators)
      ↑ implements
Infrastructure (*.service.ts, auth-client, api adapters)
```

Screens depend on application hooks. Application hooks call infrastructure services. Domain is pure TypeScript with no infrastructure imports.

## File Naming Conventions

| Artifact | Suffix | Example |
|---|---|---|
| Domain model | `*.model.ts` | `order.model.ts` |
| Domain logic | `*.logic.ts` | `order.logic.ts` |
| Infrastructure service | `*.service.ts` | `orders.service.ts` |
| Infrastructure transform | `*.transform.ts` | `orders.transform.ts` |
| Application query hook | `use*.query.ts` | `useOrders.query.ts` |
| Application mutation hook | `use*.mutation.ts` | `useCreateOrder.mutation.ts` |
| Application use case | `*.useCase.ts` | `checkoutFlow.useCase.ts` |
| Form schema | `*.form.ts` | `order.form.ts` |

## Code Standards

**TypeScript:**
- No `any`, no `as any`, no unsafe coercions
- Explicit return types on exported functions
- Validate all external data (API responses, form inputs) with Zod

**React Native:**
- Components must be function declarations
- `'use client'` is not applicable — all RN components are client-side; mark server logic explicitly
- Prefer ternary over `&&` for conditional rendering — avoids rendering `0`/`""` as text
- No prop drilling deeper than ~3 levels

**Async:**
- All server state via TanStack Query
- `Promise.all` for independent parallel operations
- No `await` inside a loop for independent operations

## Error Handling

Infrastructure services return `Safe<T>` or `Result<T, E>` — never throw:

```typescript
// ✅ Infrastructure service — never throw
async getOrders(): Promise<Safe<Order[]>> {
  try {
    const response = await fetch(`${API_URL}/orders`, { credentials: 'include' });
    if (!response.ok) return { success: false, error: response.statusText };
    return { success: true, data: await response.json() };
  } catch (e) {
    return { success: false, error: 'Network error' };
  }
}

// Application hook — throw at React Query boundary so RQ captures it
const queryFn = async () => {
  const result = await ordersService.getOrders();
  if (!result.success) throw new Error(result.error);
  return result.data;
};
```

## Navigation

Auth routing in root `_layout.tsx`. No auth checks in individual screens — screens assume authentication is verified by the layout.

Named routes via type-safe route builders — no raw string paths scattered across components.

## Verification Checklist

- [ ] `npm run build` — no TypeScript errors
- [ ] `npm test` — all tests pass
- [ ] `npm run lint` — no ESLint errors
- [ ] `npm run typecheck` — strict TypeScript passes
- [ ] No infrastructure imports in domain or application layers
- [ ] No `useEffect` for data fetching — TanStack Query used instead
- [ ] No manual auth store — `authClient.useSession()` used
- [ ] Auth tokens in `expo-secure-store`, not `AsyncStorage`
- [ ] Auth routing in root `_layout.tsx` only
- [ ] External data validated with Zod
- [ ] No `console.log` in changed files
- [ ] New API calls include authentication (`credentials: 'include'` or Bearer token)
