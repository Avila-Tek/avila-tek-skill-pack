---
description: Server layer — Server Actions, Route Handlers, Next.js caching layers (memoization, data cache)
globs: "apps/client/app/**/*.ts, apps/client/app/api/**/*.ts, apps/client/next.config.ts"
alwaysApply: false
---

# Server Layer

Everything that runs exclusively on the server: Server Actions, Route Handlers, and caching strategies.

---

## Server Actions

Async functions marked with `'use server'` that handle mutations from Client Components. The four-step pattern:

1. **Validate** input with Zod
2. **Call** service/use case
3. **Invalidate** cache on success
4. **Return** typed `Safe<T>` result

```typescript
// app/(main)/habits/actions.ts
'use server';

import { safe } from '@repo/utils';
import { HabitsService } from '@/features/habits/infrastructure/habits.service';
import { createHabitSchema } from '@/features/habits/domain/habits.form';
import { revalidatePath } from 'next/cache';

export async function createHabitAction(formData: FormData) {
  // 1. Validate
  const parsed = createHabitSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return { success: false, error: 'Validation failed' } as const;
  }

  // 2. Call service
  const result = await safe(new HabitsService().create(parsed.data));

  // 3. Invalidate on success
  if (result.success) {
    revalidatePath('/habits');
  }

  // 4. Return typed result
  return result;
}
```

Rules:
- **Never throw** from Server Actions — return `Safe<T>` shape. Thrown errors surface as generic messages.
- **Only for mutations** — Don't use Server Actions for reads. Use Server Components or React Query.
- **Keep thin** — Validate, delegate to service, invalidate cache. No business logic.
- **Co-locate near routes** — Place `actions.ts` near the route that uses it.

---

## Route Handlers

HTTP endpoints for external callers: webhooks, mobile apps, third-party integrations. For internal UI mutations, prefer Server Actions.

```typescript
// app/api/webhooks/stripe/route.ts
import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  // 1. Authenticate
  const signature = request.headers.get('stripe-signature');
  if (!signature) {
    return NextResponse.json({ error: 'Missing signature' }, { status: 401 });
  }

  // 2. Parse and validate
  const body = await request.json();
  const parsed = webhookSchema.safeParse(body);
  if (!parsed.success) {
    return NextResponse.json({ error: 'Invalid payload' }, { status: 400 });
  }

  // 3. Call service
  const result = await safe(webhookService.process(parsed.data));

  // 4. Respond
  if (!result.success) {
    return NextResponse.json({ error: 'Processing failed' }, { status: 500 });
  }

  return NextResponse.json({ data: result.data }, { status: 200 });
}
```

### When to use which

| Scenario | Use |
|---|---|
| UI form submission | Server Action |
| UI button action | Server Action |
| External API consumer | Route Handler |
| Webhook receiver | Route Handler |
| File download / streaming | Route Handler |
| OAuth callback | Route Handler |

---

## Caching

Next.js has four caching layers. Understanding them prevents over-fetching and stale data.

### 1. Request Memoization — `cache()`

Deduplicates identical function calls within a single request. Use when the same data is needed by both `generateMetadata` and the page component.

```typescript
import { cache } from 'react';

export const getHabit = cache(async (id: string) => {
  return new HabitsService().getById(id);
});
```

### 2. Data Cache — `fetch` with `next` options

For `fetch` calls with time-based or tag-based revalidation:

```typescript
const response = await fetch(`${API_URL}/habits`, {
  next: { revalidate: 60, tags: ['habits'] }, // Cache 60s, tag-based invalidation
});
```

### 3. `unstable_cache` — for non-fetch data

Caches use case / service results (ORM queries, computed data):

```typescript
import { unstable_cache } from 'next/cache';

export const getCachedHabits = unstable_cache(
  async (userId: string) => {
    return new HabitsService().getByUser(userId);
  },
  ['habits-by-user'],
  { revalidate: 60, tags: ['habits'] }
);
```

### 4. Full Route Cache

Next.js automatically caches static routes at build time. Dynamic routes opt out with `export const dynamic = 'force-dynamic'` or by using dynamic functions (`cookies()`, `headers()`, `searchParams`).

### Cache invalidation

After mutations, invalidate the relevant caches:

```typescript
// In Server Actions:
revalidateTag('habits');    // Preferred — invalidates all caches tagged with 'habits'
revalidatePath('/habits');  // Alternative — invalidates the specific path

// In React Query mutations:
queryClient.invalidateQueries({ queryKey: ['habits'] });
```

### Caching strategy by data type

| Data type | Strategy |
|---|---|
| Public, rarely changes | Long `revalidate` (3600+) |
| Public, periodic updates | Short `revalidate` (60-300) |
| User-specific | Per-request memoization (`cache()`) — never cache globally |
| Real-time | No cache (`cache: 'no-store'` or `noStore()`) |
| After mutation | Invalidate immediately via `revalidateTag` |

---

## Anti-patterns

- **Server Actions for reads** — Server Actions are for mutations. Use Server Components or React Query for reads.
- **Business logic in Route Handlers** — Route Handlers authenticate, validate, delegate, and respond. Business rules belong in services or use cases.
- **Caching user-specific data globally** — Global `unstable_cache` with user data serves wrong data to wrong users. Use `cache()` for per-request memoization.
- **No cache invalidation after mutations** — Always invalidate relevant tags/paths/queries after successful writes.
- **`redirect()` inside try/catch** — `redirect()` throws internally (it's a Next.js convention). Calling it inside try/catch will catch the redirect. Call `redirect()` outside try/catch blocks.
