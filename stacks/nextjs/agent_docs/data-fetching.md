---
description: Frontend data fetching patterns — React Query, prefetch+hydration, mutations, use cases, Server Actions
globs: "apps/client/src/features/**/application/**/*.ts, apps/admin/src/features/**/application/**/*.ts"
alwaysApply: false
---

# Data Fetching

## Decision matrix

| Scenario | Approach | Why |
|---|---|---|
| Data client widgets consume on first load | RSC prefetch (`PrefetchBoundary`) + client hook | Server-rendered initial data, client takes over |
| Client-side pagination / filtering / search | `useQuery` with dynamic query keys | Cache per-page/filter, instant UI on key change |
| Detail/edit pages with Suspense | `useSuspenseQuery` + `QueryResultGuard` | No loading state handling, error page inline |
| Mutations (form submit, button click) | `useMutation` + use case | Typed result, use case handles toast + navigation |
| Server-side mutations (progressive enhancement) | Server Actions (`'use server'`) | CSRF protection, `revalidatePath`, works without JS |

---

## Query standard — 3 layers

Every query file follows a **three-layer** structure.

```
┌─────────────────────────────────────────────────┐
│  queryOptions (source of truth)                 │
│  queryFn: () => Service.method()  →  Safe<T>    │
│  Always passthrough. Never throw. Never select. │
└──────────────┬──────────────────┬───────────────┘
               │                  │
    ┌──────────▼──────┐  ┌───────▼────────────────┐
    │  useXxx()       │  │  useXxxSuspense()       │
    │  useQuery       │  │  useSuspenseQuery        │
    │  + select throw │  │  returns Safe<T> direct  │
    │  → T + isError  │  │  → for QueryResultGuard  │
    └─────────────────┘  └─────────────────────────┘
```

### Layer 1 — `queryOptions` (source of truth)

- `queryFn` is always a **passthrough** of the service call → returns `Safe<T>`.
- Never throw, never select.
- Can include `staleTime`, `enabled`, etc.
- Used by `PrefetchBoundary` (server) and as the base for both hooks.
- Services are singletons: `ManageUserService.getById()`, not `new Service()`.

### Layer 2a — `useXxx` hook (client, `useQuery`)

- Spreads `queryOptions` + adds `select` that throws on `!result.success` and returns `T`.
- Consumer receives `{ data: T | undefined, isLoading, isError, error }`.
- The throw in `select` does **not** trigger `error.tsx` — React Query catches it internally and sets `isError: true`.

### Layer 2b — `useXxxSuspense` hook (`useSuspenseQuery`)

- Spreads `queryOptions` without select or throw.
- Returns `Safe<T>` directly.
- Consumer uses `QueryResultGuard` to decide what to render.
- Only export this hook if the query has consumers that use `useSuspenseQuery`.

### Naming convention

- `useGetUser` → `useQuery` hook
- `useGetUserSuspense` → `useSuspenseQuery` hook

### Complete example

```tsx
import { queryOptions, useQuery, useSuspenseQuery } from '@tanstack/react-query';
import { ManageUserService } from '../../infrastructure';

// Layer 1: queryOptions — always Safe<T>
export function getUserQueryOptions(userId: number) {
  return queryOptions({
    queryKey: ['manage-user', userId],
    queryFn: () => ManageUserService.getById(userId),
    enabled: userId > 0,
  });
}

// Layer 2a: client hook — select throw → T + isError
export function useGetUser(userId: number) {
  return useQuery({
    ...getUserQueryOptions(userId),
    select: (result) => {
      if (!result.success) throw new Error(result.error);
      return result.data;
    },
  });
}

// Layer 2b: suspense hook — Safe<T> for QueryResultGuard
export function useGetUserSuspense(userId: number) {
  return useSuspenseQuery(getUserQueryOptions(userId));
}
```

### Exception: `T | null` select

When `null` represents a **valid business state** (not an error), the `useQuery` hook may use `select: (result) => result.success ? result.data : null` instead of throwing. Example: `useTableConfigurationQuery` where `null` means "no saved config yet". Document why in a comment.

---

## RSC prefetch + PrefetchBoundary

> `PrefetchBoundary` and `QueryResultGuard` are shared UI components. Scan the project for equivalents before generating code — see `references/components.md` for contracts and reference implementations if missing.

The **default pattern** for server-prefetched data. `PrefetchBoundary` abstracts `HydrationBoundary` + `dehydrate` + `getQueryClient`.

```tsx
// app/(main)/users/page.tsx (Server Component)
import { PrefetchBoundary } from '@/src/shared/ui/components/PrefetchBoundary';
import { viewUsersListQueryOptions } from '@/features/users/viewUsers/application/queries/useViewUsers.query';
import ViewUsersTableWidget from '@/features/users/viewUsers/ui/widgets/ViewUsersTableWidget';

export default function UsersPage() {
  return (
    <PrefetchBoundary queries={[viewUsersListQueryOptions(defaultParams)]}>
      <ViewUsersTableWidget />
    </PrefetchBoundary>
  );
}
```

```tsx
// Client widget — uses the useQuery hook, data arrives pre-hydrated
'use client';

export function ViewUsersTableWidget() {
  const { data, isLoading, isError } = useViewUsers(params);
  // data is T (not Safe<T>) thanks to the select throw in the hook
  if (isLoading) return <Skeleton />;
  if (isError) return <ErrorState />;
  return <Table data={data} />;
}
```

### useSuspenseQuery + PrefetchBoundary

For detail/edit pages with `<Suspense>` boundaries:

```tsx
// app/(main)/users/[id]/page.tsx (Server Component)
import { parseIdParam } from '@repo/utils';

export default async function UserDetailRoute({ params }: Props) {
  const { id } = await params;
  const userId = parseIdParam(id); // returns 0 for invalid — QueryResultGuard handles "not found"
  return (
    <PrefetchBoundary queries={[getUserDetailQueryOptions(userId)]}>
      <Suspense fallback={<FormSkeleton />}>
        <ViewUserDetailLoader userId={userId} />
      </Suspense>
    </PrefetchBoundary>
  );
}
```

```tsx
// Client loader — uses the suspense hook + QueryResultGuard
'use client';

export function ViewUserDetailLoader({ userId }: Props) {
  const { data: result } = useGetUserDetailSuspense(userId);
  return (
    <QueryResultGuard
      result={result}
      title="Usuario no encontrado"
      redirectTo={routeBuilders.users()}
    >
      {(detail) => <ViewUserDetailContent detail={detail} />}
    </QueryResultGuard>
  );
}
```

Use `useSuspenseQuery` when the parent provides a `<Suspense>` boundary with a skeleton. Use `useQuery` when the widget handles its own loading state internally.

---

## Mutation standard

Mutations are always a **passthrough** of the service call → returns `Safe<T>`. Error handling is done by the **use case layer** (toast + navigation), never in the mutation itself.

### Mutation hook

```tsx
// Simple mutation — passthrough, no error handling
export function useCreateUserMutation() {
  return useMutation({
    mutationFn: (form: TManageUserForm) => ManageUserService.create(form),
  });
}

// Mutation with cache invalidation — onSuccess only for invalidation
export function useToggleUserStatus(userId: number) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (newStatus: UserDetailStatus) =>
      ViewUserDetailService.updateStatus(userId, newStatus),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [viewUserDetailQueryKey, userId] });
    },
  });
}
```

### Use case (error handling layer)

Use cases wrap mutations and handle `Safe<T>` results with toast + navigation:

```tsx
type CreateUserDeps = {
  mutate: (data: TManageUserForm) => Promise<Safe<ManageUserData>>;
  showToast: (options: ToastOptions) => void;
  push: (url: string) => void;
};

export async function createUserUseCase(
  data: TManageUserForm,
  deps: CreateUserDeps
): Promise<void> {
  const result = await deps.mutate(data).catch(() => null);
  if (!result) {
    deps.showToast({ type: 'error', title: 'Ha ocurrido un error inesperado' });
    return;
  }
  if (!result.success) {
    deps.showToast({ type: 'error', title: 'Error al crear el usuario', description: result.error });
    return;
  }
  deps.showToast({ type: 'success', title: result.message ?? 'Usuario creado exitosamente' });
  deps.push(routeBuilders.users());
}

export function useCreateUser() {
  const createMutation = useCreateUserMutation();
  const router = useRouter();
  const { showToast } = useToast();

  return {
    createUser: (data: TManageUserForm) =>
      createUserUseCase(data, {
        mutate: createMutation.mutateAsync,
        showToast,
        push: router.push,
      }),
    isPending: createMutation.isPending,
  };
}
```

---

## Server Actions

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

## Cache invalidation strategy

- **Query key conventions**: Use hierarchical arrays. Example: `['users']`, `['users', 'list', params]`, `['manage-user', userId]`. Invalidating `['users']` invalidates all nested keys.
- **After mutations**: Use `invalidateQueries({ queryKey: [...] })` in mutation's `onSuccess`. Error handling goes in the use case, not here.
- **After Server Actions**: Use `revalidatePath('/path')` or `revalidateTag('tag')`.
- **Prefer invalidation over manual cache updates** unless optimistic UI is required.

---

## Anti-patterns

- **Throwing in `queryFn`** — Never throw inside `queryOptions.queryFn`. The throw belongs in the hook's `select`. This keeps `queryOptions` as a pure `Safe<T>` source usable by both `useQuery` and `useSuspenseQuery`.
- **Handling errors with `useEffect` + `router.replace`** — Use `QueryResultGuard` (for suspense loaders) or `isError` (for `useQuery` consumers) instead of side effects.
- **Error handling in mutations** — Never put `onError` or toast logic in the mutation hook. Use the use case layer for all error handling.
- **Fetching in `useEffect`** — Use `PrefetchBoundary` + React Query instead. `useEffect` fetch creates waterfalls, loading flashes, and no caching.
- **Not prefetching** when data is available at the server — Always prefetch with `PrefetchBoundary` when possible.
- **Waterfall fetches** — Parallelize independent data with multiple queries in `PrefetchBoundary`'s `queries` array.
- **No `staleTime`** — Without it, every component mount refetches. Set at minimum in `QueryClient` defaults.
- **Duplicating query keys** — Use `queryOptions()` factories to share keys and `queryFn` between prefetch and hooks.
- **`new Service()` in queryFn** — Services are singletons exported from `infrastructure/index.ts`. Use `ManageUserService.getById()`, not `new ManageUserServiceClass().getById()`.
- **Using `HydrationBoundary` + `dehydrate` directly** — Use `PrefetchBoundary` instead; it abstracts the boilerplate.
- **Server Actions for reads** — Server Actions are for mutations. Use `PrefetchBoundary` + React Query for reads.
