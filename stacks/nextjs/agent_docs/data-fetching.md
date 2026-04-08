---
description: Frontend data fetching patterns — RSC, React Query, prefetch+hydration, mutations, Server Actions
globs: "apps/client/src/features/**/application/**/*.ts, apps/admin/src/features/**/application/**/*.ts"
alwaysApply: false
---

# Data Fetching

## Decision matrix

| Scenario | Approach | Why |
|---|---|---|
| Page-level data, no interactivity | Server Component `async` + direct service call | Zero client JS, streams HTML, no loading flash |
| Data that does not change on user interaction | Server Component | Fetched once at render, cached by Next.js |
| Data client widgets consume on first load | RSC prefetch + `HydrationBoundary` + `dehydrate` | Server-rendered initial data, client takes over |
| Real-time data, polling, background refetch | `useQuery` (TanStack React Query) | Automatic refetching, stale-while-revalidate |
| Client-side pagination / filtering / search | `useQuery` with dynamic query keys | Cache per-page/filter, instant UI on key change |
| Mutations (form submit, button click) | `useMutation` (TanStack React Query) | Typed result, cache invalidation, optimistic UI |
| Server-side mutations (progressive enhancement) | Server Actions (`'use server'`) | CSRF protection, `revalidatePath`, works without JS |

---

## Pattern 1: Server Component direct fetch

When the page is fully server-rendered and needs no client interactivity for this data.

```tsx
// app/(main)/habits/page.tsx
import { HabitsService } from '@/features/habits/infrastructure/habits.service';

export default async function HabitsPage() {
  const service = new HabitsService();
  const habits = await service.getAll();

  return <HabitList habits={habits} />;
}
```

Use this when data is static for the page lifecycle. No React Query needed.

---

## Pattern 2: RSC prefetch + HydrationBoundary

The **default pattern** for data that client widgets will consume. Prefetch on the server, hydrate on the client.

```tsx
// app/(main)/habits/page.tsx (Server Component)
import { HydrationBoundary, dehydrate } from '@tanstack/react-query';
import { getQueryClient } from '@/lib/getQueryClient';
import { habitsQueryOptions } from '@/features/habits/application/queries/useHabits.query';
import { HabitsWidget } from '@/features/habits/ui/widgets/habitsWidget';

export default function HabitsPage() {
  const queryClient = getQueryClient();
  void queryClient.prefetchQuery(habitsQueryOptions());

  return (
    <HydrationBoundary state={dehydrate(queryClient)}>
      <HabitsWidget />
    </HydrationBoundary>
  );
}
```

```tsx
// features/habits/application/queries/useHabits.query.ts
import { queryOptions, useQuery } from '@tanstack/react-query';
import { HabitsService } from '../infrastructure/habits.service';

export function habitsQueryOptions() {
  return queryOptions({
    queryKey: ['habits'],
    queryFn: () => new HabitsService().getAll(),
  });
}

export function useHabits() {
  return useQuery(habitsQueryOptions());
}
```

Always use `queryOptions()` factories to share keys and `queryFn` between prefetch and client hooks.

### `useSuspenseQuery` alternative

When using prefetch, `useSuspenseQuery` is an alternative to `useQuery`. It suspends the component until data is available (uses a `<Suspense>` boundary), eliminating the need to handle `isLoading` manually.

```tsx
// Client component using useSuspenseQuery
'use client';

import { useSuspenseQuery } from '@tanstack/react-query';
import { habitsQueryOptions } from '@/features/habits/application/queries/useHabits.query';

export function HabitsWidget() {
  // No isLoading check needed — component suspends until data arrives
  const { data } = useSuspenseQuery(habitsQueryOptions());
  return <HabitList habits={data} />;
}
```

Use `useSuspenseQuery` when the parent provides a `<Suspense>` boundary with a skeleton. Use `useQuery` when the widget handles its own loading state internally.

---

## Pattern 3: Client-only React Query

When data is purely interactive (depends on client state, polling, etc.).

```tsx
'use client';

import { useQuery } from '@tanstack/react-query';

export function useHabitsByDate(date: string) {
  return useQuery({
    queryKey: ['habits', 'by-date', date],
    queryFn: () => new HabitsService().getByDate(date),
    staleTime: 60 * 1000,
  });
}
```

Always configure `staleTime` (at minimum in `QueryClient` defaults) to avoid refetching on every render.

---

## Pattern 4: Mutations + cache invalidation

```tsx
// features/habits/application/mutations/useCreateHabit.mutation.ts
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { HabitsService } from '../infrastructure/habits.service';

export function useCreateHabit() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: CreateHabitInput) => new HabitsService().create(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['habits'] });
    },
    onError: (error) => {
      // Show toast or handle specific error codes
    },
  });
}
```

Prefer `invalidateQueries` over `setQueryData` unless you need optimistic UI. For optimistic updates, use the `onMutate` / `onError` / `onSettled` pattern.

---

## Pattern 5: Server Actions

Use for mutations that benefit from progressive enhancement or when you need `revalidatePath` / `revalidateTag`.

```tsx
// app/(main)/habits/actions.ts
'use server';

import { safe } from '@repo/utils';
import { HabitsService } from '@/features/habits/infrastructure/habits.service';
import { createHabitSchema } from '@/features/habits/domain/habits.form';
import { revalidatePath } from 'next/cache';

export async function createHabitAction(formData: FormData) {
  const parsed = createHabitSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return { success: false, error: 'Validation failed' } as const;
  }

  const result = await safe(new HabitsService().create(parsed.data));
  if (result.success) {
    revalidatePath('/habits');
  }
  return result;
}
```

Rules:
- Always validate input with Zod before processing.
- Return `Safe<T>` shape (never throw from Server Actions).
- Keep thin: delegate to services.
- Use `revalidatePath` / `revalidateTag` for cache invalidation.

---

## Suspense streaming

Use `loading.tsx` for route-level skeletons and `<Suspense>` for granular streaming.

```tsx
// app/(main)/dashboard/page.tsx
import { Suspense } from 'react';
import { HabitStats } from '@/features/habits/ui/widgets/habitStats';
import { RecentActivity } from '@/features/activity/ui/widgets/recentActivity';
import { HabitStatsSkeleton } from '@/features/habits/ui/components/habitStatsSkeleton';

export default function DashboardPage() {
  return (
    <div className="grid grid-cols-2 gap-6">
      <Suspense fallback={<HabitStatsSkeleton />}>
        <HabitStats /> {/* async Server Component — streams independently */}
      </Suspense>
      <RecentActivity /> {/* fast — no Suspense needed */}
    </div>
  );
}
```

---

## Cache invalidation strategy

- **Query key conventions**: Use hierarchical arrays. Example: `['habits']`, `['habits', 'by-date', date]`, `['habits', habitId]`. Invalidating `['habits']` invalidates all nested keys.
- **After mutations**: Use `invalidateQueries({ queryKey: ['habits'] })` to refetch all habit queries.
- **After Server Actions**: Use `revalidatePath('/habits')` or `revalidateTag('habits')`.
- **Prefer invalidation over manual cache updates** unless optimistic UI is required.

---

## Anti-patterns

- **Fetching in `useEffect`** — Use Server Components or React Query instead. `useEffect` fetch creates waterfalls, loading flashes, and no caching.
- **Not prefetching** when data is available at the server — Always prefetch with `HydrationBoundary` when possible.
- **Waterfall fetches** — Parallelize independent data with `Promise.all` in Server Components or multiple `prefetchQuery` calls.
- **No `staleTime`** — Without it, every component mount refetches. Set at minimum in `QueryClient` defaults.
- **Duplicating query keys** — Use `queryOptions()` factories to share keys and `queryFn` between prefetch and hooks.
- **Server Actions for reads** — Server Actions are for mutations. Use Server Components or React Query for reads.
