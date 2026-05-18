---
description: Frontend error handling — Safe<T> pattern, service boundaries, error.tsx boundaries
globs: "apps/client/src/features/**/infrastructure/*.service.ts, apps/client/app/**/error.tsx"
alwaysApply: false
---

# Error Handling

## Philosophy

Handle expected errors explicitly. Let unexpected errors bubble to error boundaries. Never swallow errors silently. Services return `Safe<T>` — they never throw.

---

## The `Safe<T>` pattern

We use the `Safe<T>` discriminated union from `@repo/utils` for all fallible operations at system boundaries.

```typescript
// From packages/utils/src/safe-functions.ts
type Safe<T> =
  | { success: true;  data: T;      message?: string }
  | { success: false; error: string; errorCode?: string; errorDetails?: unknown[]; message?: string };
```

`message` carries the human-readable text from the backend (e.g. `"Usuario creado exitosamente"`).
It is optional because `Safe` is also constructed internally (e.g. by `safe()`) where there is no
backend message. Always use it as a toast title with a fallback:

```typescript
deps.showToast({ type: 'success', title: result.message ?? 'Operación exitosa' });
deps.showToast({ type: 'error',   title: result.error }); // error already contains the message
```

The `safe()` utility wraps promises or synchronous functions:

```typescript
import { safe } from '@repo/utils';

// Async
const result = await safe(fetch('/api/habits'));
if (result.success) {
  console.log(result.data);
} else {
  console.error(result.error);
}

// Sync
const parsed = safe(() => JSON.parse(rawString));
```

---

## Error handling by layer

### Infrastructure (`*.service.ts`)

Services return `Safe<T>`. They **never throw**. The API client already returns `Safe<T>`, and services propagate errors or transform the data.

```typescript
// features/habits/infrastructure/habits.service.ts
import type { Safe } from '@repo/utils';
import type { HabitsApi } from './habits.interfaces';
import { toHabitDomain } from './habits.transform';
import type { Habit } from '../domain/habit.model';

export class HabitsService {
  constructor(private api: HabitsApi) {}

  async getAll(): Promise<Safe<Habit[]>> {
    const result = await this.api.getAll();
    if (!result.success) return result; // propagate error as-is
    return { success: true, data: result.data.map(toHabitDomain) };
  }
}
```

Services check `result.success` and return the error unchanged. The application layer decides how to present errors to the user.

### Application (queries / mutations)

Queries follow the **3-layer standard** (see `data-fetching.md`). The `select` in `useQuery` hooks is the throw boundary — not `queryFn`.

**Queries:**

```typescript
// queryOptions: always Safe<T> passthrough
export function getUserQueryOptions(userId: number) {
  return queryOptions({
    queryKey: ['manage-user', userId],
    queryFn: () => ManageUserService.getById(userId),
  });
}

// useQuery hook: select throws → consumer gets T + isError
export function useGetUser(userId: number) {
  return useQuery({
    ...getUserQueryOptions(userId),
    select: (result): ManageUserData => {
      if (!result.success) throw new Error(result.error);
      return result.data;
    },
  });
}

// useSuspenseQuery hook: returns Safe<T> for QueryResultGuard
export function useGetUserSuspense(userId: number) {
  return useSuspenseQuery(getUserQueryOptions(userId));
}
```

- `useQuery` + select throw → React Query captures the error internally, sets `isError: true`. Does **not** trigger `error.tsx`.
- `useSuspenseQuery` → returns `Safe<T>` without select. The loader uses `QueryResultGuard` to decide what to render.

**Mutations:**

Mutations are passthrough — error handling is done by the **use case layer**, not the mutation.

```typescript
// Mutation: passthrough
export function useCreateUserMutation() {
  return useMutation({
    mutationFn: (form: TManageUserForm) => ManageUserService.create(form),
  });
}

// Use case: handles errors with toast + navigation
export async function createUserUseCase(data: TManageUserForm, deps: Deps): Promise<void> {
  const result = await deps.mutate(data).catch(() => null);
  if (!result) {
    deps.showToast({ type: 'error', title: 'Ha ocurrido un error inesperado' });
    return;
  }
  if (!result.success) {
    deps.showToast({ type: 'error', title: result.error });
    return;
  }
  deps.showToast({ type: 'success', title: result.message ?? 'Usuario creado exitosamente' });
  deps.push(routeBuilders.users());
}
```

**Use cases:**

Use cases return typed results — `{ ok: true, data } | { ok: false, error }` — without throwing. The UI checks `result.ok` directly.

```typescript
// In a use case
const result = await createHabitFlowUseCase(input, deps);
if (!result.ok) {
  toast.error(result.error);
  return;
}
```

### UI layer

> `QueryResultGuard` and `ErrorState` are shared UI components. Scan the project for equivalents before generating code — see `references/components.md` for contracts and reference implementations if missing.

- **Route-level**: Use `error.tsx` for unrecoverable errors. These are error boundaries for unexpected failures.
- **Widget-level (useQuery)**: Handle loading/error/empty states via React Query's `isLoading`, `isError`, `data`.
- **Loader-level (useSuspenseQuery)**: Use `QueryResultGuard` to handle `Safe<T>` results declaratively.
- **Never** display raw `error.message` to users. Show safe, user-friendly messages.

#### `QueryResultGuard` — for detail/edit loaders with `useSuspenseQuery`

`QueryResultGuard<T>` is a declarative wrapper that inspects a `Safe<T>` result and renders either the children (with data) or an `ErrorState` error page inline.

```tsx
import { QueryResultGuard } from '@repo/ui/components/QueryResultGuard';

export function UpdateUserFormLoader({ id }: { id: number }) {
  const { data: result } = useGetUserSuspense(id);

  return (
    <QueryResultGuard
      result={result}
      title="Usuario no encontrado"
      redirectTo={routeBuilders.users()}
    >
      {(userData) => (
        <ManageUserForm formType={formTypeEnumObject.update} userData={userData} />
      )}
    </QueryResultGuard>
  );
}
```

**How it works:**
- `result.success === true` → calls `children(result.data)`
- `result.success === false` → renders `ErrorState` with `result.error` as description (fallback)
- If `description` is passed explicitly, it takes priority over `result.error`
- No `useEffect`, no `useRouter`, no side effects — purely declarative
- Preserves `AdminPageLayout` context (breadcrumbs, title, back button)

#### `ErrorState` — standalone error page

`ErrorState` is a presentational component for inline error states. Can be used independently of `QueryResultGuard`.

```tsx
import { ErrorState } from '@repo/ui/components/ErrorState';

<ErrorState
  title="Proveedor no encontrado"
  description="El proveedor que buscas no existe o fue eliminado."
  redirectTo="/providers"
  redirectLabel="Volver a proveedores"
/>
```

**Props:** `redirectTo` (required), `title?`, `description?`, `redirectLabel?`, `icon?` (ReactNode, defaults to Lucide `SearchX`).

---

## Server Action error handling

Server Actions should return `Safe<T>` shape — never throw. Thrown errors in Server Actions surface as generic messages with no type information.

```typescript
// app/(main)/habits/actions.ts
'use server';

import { habitsService } from '@/features/habits/infrastructure';
import { createHabitSchema } from '@/features/habits/domain/habits.form';
import { revalidatePath } from 'next/cache';

export async function createHabitAction(formData: FormData) {
  const parsed = createHabitSchema.safeParse(Object.fromEntries(formData));
  if (!parsed.success) {
    return { success: false, error: 'Validation failed' } as const;
  }

  const result = await habitsService.create(parsed.data);
  if (result.success) {
    revalidatePath('/habits');
  }
  return result;
}
```

The calling component checks `result.success`:

```tsx
const result = await createHabitAction(formData);
if (!result.success) {
  toast.error(result.error);
  return;
}
// success path
```

---

## Error codes for domain errors

When specific error types need to be matched, use string constants in `domain/*.constants.ts`:

```typescript
// features/habits/domain/habit.constants.ts
export const HABIT_LIMIT_EXCEEDED = 'HABIT_LIMIT_EXCEEDED';
export const HABIT_DUPLICATE_NAME = 'HABIT_DUPLICATE_NAME';
```

For use cases, define error constants as objects:

```typescript
export const CreateHabitErrors = {
  LimitExceeded: 'You have reached the maximum number of habits.',
  DuplicateName: 'A habit with this name already exists.',
} as const;
```

---

## Summary: where errors are handled

| Layer | Pattern | Throws? |
|---|---|---|
| Infrastructure (services) | Return `Safe<T>` | Never |
| Application (queryOptions) | Passthrough `Safe<T>` from service | Never |
| Application (useQuery hook select) | Throw on `!success` → `isError: true` | Yes — caught by React Query |
| Application (useSuspenseQuery hook) | Return `Safe<T>` for `QueryResultGuard` | Never |
| Application (mutations) | Passthrough `Safe<T>` | Never |
| Application (use cases) | Check `result.success`, toast + navigate | Never |
| Server Actions | Return `Safe<T>` | Never |
| UI (useQuery widgets) | Check `isError` / `data` | Never |
| UI (useSuspenseQuery loaders) | `QueryResultGuard` → children or `ErrorState` | Never |

---

## Anti-patterns

- **Services that throw** — Services return `Safe<T>`. Only the application layer throws (at the React Query boundary).
- **Empty catch blocks** — `catch (e) {}` hides bugs. Always log, re-throw, or return an error.
- **`catch (e) { console.log(e) }` without handling** — Logging is not handling. Decide what the user sees.
- **Raw `error.message` in UI** — Error messages may contain stack traces or internal details. Show safe messages.
- **try/catch "just in case"** — Don't wrap code that cannot fail. Handle errors at the right boundary.
- **Catching at every layer** — Catch at the boundary (application layer), not at every call site. Let `Safe<T>` propagate through infrastructure.
- **Throwing from Server Actions** — Server Actions return `Safe<T>`. Thrown errors lose type information.
- **`React.useEffect` + `router.replace` for error handling** — Use `QueryResultGuard` (for suspense loaders) or `isError` (for `useQuery` consumers). Never redirect silently on error.
- **Throwing in `queryOptions.queryFn`** — The throw belongs in the hook's `select`, not in `queryFn`. See `data-fetching.md` for the 3-layer query standard.
- **Error handling in mutation hooks** — Never put `onError` or toast logic in the mutation. Use the use case layer for all error handling.
