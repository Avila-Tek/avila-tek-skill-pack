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
  | { success: true; data: T }
  | { success: false; error: string };
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

The application layer is the **throw boundary** — the only place where `Safe<T>` errors are converted to thrown errors for React Query to capture.

**Queries:**

```typescript
// features/habits/application/queries/useHabits.query.ts
export function habitsQueryOptions() {
  return queryOptions({
    queryKey: habitQueryKeys.all,
    queryFn: async () => {
      const result = await habitsService.getAll();
      if (!result.success) throw new Error(result.error); // throw HERE for React Query
      return result.data;
    },
  });
}
```

React Query captures the thrown error and exposes it via `isError` and `error`. Widgets render error states accordingly.

**Mutations:**

```typescript
// features/habits/application/mutations/useCreateHabit.mutation.ts
export function useCreateHabit() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (data: TCreateHabitForm) => {
      const result = await habitsService.create(data);
      if (!result.success) throw new Error(result.error);
      return result.data;
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: habitQueryKeys.all });
    },
    onError: (error) => {
      toast.error('Failed to create habit');
    },
  });
}
```

For mutations, use `onError` for user-facing feedback. Check for specific error codes if needed.

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

- **Route-level**: Use `error.tsx` for unrecoverable errors. These are error boundaries for unexpected failures.
- **Widget-level**: Handle loading/error/empty states via React Query's `isLoading`, `isError`, `data`.
- **Never** display raw `error.message` to users. Show safe, user-friendly messages.

```tsx
// app/(main)/habits/error.tsx
'use client';

export default function HabitsError({ error, reset }: { error: Error; reset: () => void }) {
  return (
    <div>
      <p>Something went wrong loading habits.</p>
      <Button onClick={reset}>Try again</Button>
    </div>
  );
}
```

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

Match on these in the application layer:

```typescript
onError: (error) => {
  if (error.message === HABIT_LIMIT_EXCEEDED) {
    toast.error('You have reached the maximum number of habits.');
    return;
  }
  toast.error('Something went wrong.');
},
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
| Application (queryFn / mutationFn) | Unwrap `Safe<T>`, throw on `!success` | Yes — for React Query |
| Application (use cases) | Return `{ ok, data/error }` | Never |
| Server Actions | Return `Safe<T>` | Never |
| UI (widgets) | Check `isError` / `result.ok` | Never |
| UI (error.tsx) | Catches thrown errors from React Query | Catches |

---

## Anti-patterns

- **Services that throw** — Services return `Safe<T>`. Only the application layer throws (at the React Query boundary).
- **Empty catch blocks** — `catch (e) {}` hides bugs. Always log, re-throw, or return an error.
- **`catch (e) { console.log(e) }` without handling** — Logging is not handling. Decide what the user sees.
- **Raw `error.message` in UI** — Error messages may contain stack traces or internal details. Show safe messages.
- **try/catch "just in case"** — Don't wrap code that cannot fail. Handle errors at the right boundary.
- **Catching at every layer** — Catch at the boundary (application layer), not at every call site. Let `Safe<T>` propagate through infrastructure.
- **Throwing from Server Actions** — Server Actions return `Safe<T>`. Thrown errors lose type information.
