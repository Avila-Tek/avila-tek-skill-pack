---
description: React component internal structure — import order, naming by layer, max 150-200 lines
globs: "apps/client/src/features/**/ui/**/*.tsx, apps/admin/src/features/**/ui/**/*.tsx, packages/features/src/**/ui/**/*.tsx"
alwaysApply: false
---

# Component Structure

## Internal order

1. **Imports**
2. **Types & interfaces** — props interface named `[ComponentName]Props`
3. **Component function** (function declaration, not arrow)
   1. Hooks — `useState`, `useRef`, custom hooks, `useEffect`
   2. Derived values — computed from props/state, no side effects
   3. Handlers — `handleX` / `onX` functions
   4. JSX return — only markup, no inline logic

```tsx
// features/habits/ui/components/habitCard.tsx
import React from 'react';
import { Badge } from '@repo/ui';
import type { Habit } from '../../domain/habit.model';
import { canAddProgress, habitDetailsLine } from '../../domain/habit.logic';

interface HabitCardProps {
  habit: Habit;
  onLogProgress: (habitId: string) => void;
  onEdit: (habitId: string) => void;
}

export function HabitCard({ habit, onLogProgress, onEdit }: HabitCardProps) {
  // Hooks
  const [expanded, setExpanded] = React.useState(false);

  // Derived values
  const canLog = canAddProgress(habit);
  const details = habitDetailsLine(habit);

  // Handlers
  function handleToggle() {
    setExpanded((prev) => !prev);
  }

  function handleLog() {
    onLogProgress(habit.id);
  }

  // JSX
  return (
    <div className="flex items-center gap-4">
      <div>
        <h3>{habit.name}</h3>
        <p>{details}</p>
      </div>
      {canLog ? <Button onClick={handleLog}>Log</Button> : null}
      <Badge>{habit.status}</Badge>
    </div>
  );
}
```

---

## Naming

- **Component name**: PascalCase, named by intention — `ProductFiltersPanel`, `CartSummaryBar`.
- **File name**: camelCase matching the component — `productFiltersPanel.tsx` exports `ProductFiltersPanel`.
- **Props interface**: `[ComponentName]Props`.

---

## Size & splitting

- **~150-200 lines max** per component. Beyond that, split.
- Split when: JSX reads like a full page, multiple unrelated state variables, multiple unrelated handlers.
- **One exported component per file.** Internal helpers are fine but unexported.

---

## Function declarations

- Use function declarations for components, **not arrow functions**.
- Arrow components can't be hoisted and are harder to identify in stack traces.

---

## Stateful vs Stateless

- **Stateful (Widget/Container)**: fetches data, manages state, calls mutations, handles loading/error/empty states.
- **Stateless (Component)**: receives data via props, renders UI, emits events via callbacks.

```tsx
// Stateful — owns data
export function HabitListWidget({ date }: { date: Date }) {
  const { data, isLoading, isError } = useHabitsForDate(date);
  if (isLoading) return <HabitListSkeleton />;
  if (isError) return <ErrorState message="Failed to load habits" />;
  if (!data?.length) return <EmptyState />;

  return (
    <div>
      {data.map((habit) => <HabitCard key={habit.id} habit={habit} />)}
    </div>
  );
}

// Stateless — pure rendering
export function HabitCard({ habit }: { habit: Habit }) {
  return (
    <div>
      <h3>{habit.name}</h3>
      <p>{habitDetailsLine(habit)}</p>
    </div>
  );
}
```

---

## Props

- Always destructure in the function signature.
- Define defaults in the signature.
- Prefer explicit props over uncontrolled spreading (`{...props}`).

---

## Anti-patterns

- **Arrow function components** — Use function declarations.
- **Inline logic in JSX** — Move complex expressions to derived values or handlers above the return.
- **Multiple exports** — One component per file.
- **God components** — Split into widget (data + states) and components (presentational).
- **Props drilling beyond 3 levels** — Use Context or composition instead.
