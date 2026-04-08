---
description: Application layer — React Query hooks, queryOptions factories, use cases, Safe<T> unwrapping
globs: "apps/client/src/features/**/application/**/*.ts, apps/admin/src/features/**/application/**/*.ts, packages/features/src/**/application/**/*.ts"
alwaysApply: false
---

# Application Layer

The orchestration layer. Defines _what the system can do_ — queries, mutations, and use cases that coordinate infrastructure and domain.

---

## What lives here

```
features/<feature>/application/
  queries/
    use*.query.ts          # React Query reads
  mutations/
    use*.mutation.ts       # React Query writes
  useCases/
    *.useCase.ts           # Complex flow orchestration (pure function + hook)
```

---

## Queries (`use*.query.ts`)

React Query reads. Use `queryOptions()` factories to share cache keys and `queryFn` between server prefetch and client hooks.

```typescript
// features/habits/application/queries/useHabits.query.ts
import { queryOptions, useQuery } from '@tanstack/react-query';
import { habitsService } from '../../infrastructure';
import { habitQueryKeys } from '../../domain/habit.constants';

export function habitsQueryOptions() {
  return queryOptions({
    queryKey: habitQueryKeys.all,
    queryFn: async () => {
      const result = await habitsService.getAll();
      if (!result.success) throw new Error(result.error);
      return result.data;
    },
    staleTime: 60 * 1000,
  });
}

export function useHabits() {
  return useQuery(habitsQueryOptions());
}
```

The `queryFn` calls the service (which returns `Safe<T>`), checks `result.success`, and throws only here — at the React Query boundary — so React Query can capture the error and expose it via `isError` / `error`.

Rules:
- Always use `queryOptions()` factory — avoids duplicating keys between prefetch and client hooks.
- Define query keys in `domain/*.constants.ts`, not inline.
- Set `staleTime` to avoid refetching on every render (at minimum in `QueryClient` defaults).
- Use `enabled` option for conditional fetching (e.g., only when userId is available).
- The throw happens in `queryFn`, not in the service.

---

## Mutations (`use*.mutation.ts`)

React Query writes with cache invalidation. Mutations receive `Safe<T>` from services and handle success/error.

```typescript
// features/habits/application/mutations/useCreateHabit.mutation.ts
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { habitsService } from '../../infrastructure';
import { habitQueryKeys } from '../../domain/habit.constants';
import type { TCreateHabitForm } from '../../domain/habits.form';

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

Rules:
- Invalidate related queries in `onSuccess`.
- Use `onError` for user-facing feedback (toast, form error).
- Prefer `invalidateQueries` over `setQueryData` unless optimistic UI is needed.
- For optimistic updates, use `onMutate` / `onError` / `onSettled` pattern.
- The `mutationFn` unwraps `Safe<T>` and throws — React Query expects thrown errors.

---

## Use cases (`*.useCase.ts`)

For complex flows that orchestrate multiple services, combine multiple queries/mutations, or have business logic beyond simple CRUD.

Use cases follow the **pure function + hook** pattern:

1. **Pure function** — `xxxUseCase(input, deps)` — no React imports, no infrastructure imports. Receives dependencies as a parameter. Returns a typed result (`{ ok: true } | { ok: false, error }`).
2. **Hook** — `useXxx()` — wires real dependencies (from queries/mutations) and exposes a simple API to the UI.

```typescript
// features/habits/application/useCases/createHabitFlow.useCase.ts
import type { Habit } from '../../domain/habit.model';
import type { TCreateHabitForm } from '../../domain/habits.form';
import { canCreateMoreHabits } from '../../domain/habit.logic';

// Error constants
export const CreateHabitFlowErrors = {
  LimitExceeded: 'You have reached the maximum number of habits for your plan.',
  CreationFailed: 'Failed to create habit. Please try again.',
} as const;

// Result type
export type CreateHabitFlowResult =
  | { ok: true; data: Habit }
  | { ok: false; error: (typeof CreateHabitFlowErrors)[keyof typeof CreateHabitFlowErrors] };

// Dependencies type
type Dependencies = {
  currentHabitCount: number;
  createHabit: (data: TCreateHabitForm) => Promise<Habit>;
};

// 1. Pure function — no React, no infrastructure imports
export async function createHabitFlowUseCase(
  input: TCreateHabitForm,
  deps: Dependencies
): Promise<CreateHabitFlowResult> {
  if (!canCreateMoreHabits(deps.currentHabitCount)) {
    return { ok: false, error: CreateHabitFlowErrors.LimitExceeded };
  }

  try {
    const habit = await deps.createHabit(input);
    return { ok: true, data: habit };
  } catch {
    return { ok: false, error: CreateHabitFlowErrors.CreationFailed };
  }
}
```

```typescript
// features/habits/application/useCases/useCreateHabitFlow.ts
import React from 'react';
import { useHabits } from '../queries/useHabits.query';
import { useCreateHabit } from '../mutations/useCreateHabit.mutation';
import { createHabitFlowUseCase, type CreateHabitFlowResult } from './createHabitFlow.useCase';
import type { TCreateHabitForm } from '../../domain/habits.form';

// 2. Hook — wires real dependencies
export function useCreateHabitFlow() {
  const habits = useHabits();
  const createMutation = useCreateHabit();

  const execute = React.useCallback(
    async (input: TCreateHabitForm): Promise<CreateHabitFlowResult> => {
      return createHabitFlowUseCase(input, {
        currentHabitCount: habits.data?.length ?? 0,
        createHabit: createMutation.mutateAsync,
      });
    },
    [habits.data, createMutation]
  );

  return {
    execute,
    isLoading: habits.isLoading || createMutation.isPending,
    isError: habits.isError,
  };
}
```

**Usage in UI:**

```tsx
// features/habits/ui/widgets/createHabitWidget.tsx
export function CreateHabitWidget() {
  const flow = useCreateHabitFlow();

  async function handleSubmit(data: TCreateHabitForm) {
    const result = await flow.execute(data);
    if (!result.ok) {
      toast.error(result.error);
      return;
    }
    toast.success('Habit created');
  }

  return <CreateHabitForm onSubmit={handleSubmit} disabled={flow.isLoading} />;
}
```

**When to use a use case vs a simple mutation:**

Use cases are **optional** — not every mutation needs one. Use them when:
- The flow involves multiple service calls or queries
- There's business logic beyond CRUD (validation, conditional flows)
- You need unified loading/error state across multiple operations
- The logic is complex enough to warrant isolation and testing

For simple CRUD, a mutation hook calling a service directly is fine.

---

## Rules

- **Pure use case functions have no React or infrastructure imports.** They receive everything via the `deps` parameter.
- **Use case hooks wire dependencies.** They import queries, mutations, and pass `.mutateAsync` / `.data` to the pure function.
- **No direct database access.** Always go through services.
- **Return typed results from use cases.** Use `{ ok: true, data } | { ok: false, error }` instead of throwing.
- **Error constants as objects.** Define error messages as `const Errors = { ... } as const` for type safety and reuse.

---

## Anti-patterns

- **Business logic in mutation hooks** — If `onSuccess` contains business rules (not just cache invalidation), extract to a use case.
- **Use case calling another use case** — Use cases are entry points, not composable building blocks. Compose at the service level.
- **Cache operations in use cases** — `invalidateQueries`, `revalidatePath` belong in the mutation hook or Server Action, not use cases.
- **Duplicating query keys** — Define once in `domain/*.constants.ts`, import everywhere.
- **Skipping `queryOptions()` factory** — Leads to key/function mismatches between prefetch and client hook.
- **Use cases that import infrastructure directly** — The pure function receives deps. Only the hook wires real implementations.
- **Class-based use cases** — Use the function + hook pattern. It's more testable (mock individual deps) and more composable (unified loading state).
