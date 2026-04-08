---
description: UI layer — Server/Client Components, widget pattern, Context for feature state, UI-only hooks
globs: "apps/client/src/features/**/ui/**/*.tsx, apps/admin/src/features/**/ui/**/*.tsx, packages/features/src/**/ui/**/*.tsx"
alwaysApply: false
---

# UI Layer

Everything the user sees and interacts with. Server Components for data delivery, Client Components for interactivity, and a clear widget/component hierarchy.

---

## What lives here

```
features/<feature>/ui/
  pages/           # Route-level screens (compose widgets)
  layouts/         # Shared layout wrappers for route groups
  widgets/         # Self-contained sections (own loading/error/empty states)
  components/      # Reusable presentational pieces
  context/         # Feature-scoped React contexts
  hooks/           # Feature UI hooks (visual state only)
```

---

## Server vs Client Components

### Rules of the component tree

- **Server Components (S)** can contain: other Server Components and Client Components.
- **Client Components (C)** can only contain: other Client Components.

The tree starts at the server (layouts, pages) and interactivity is pushed to the leaves.

### When to use each

| Use Server Components when you need | Use Client Components when you need |
|---|---|
| Data fetching | Interactivity (`onClick`, `onChange`) |
| Access to backend resources | State (`useState`, `useReducer`) |
| Sensitive data on server (tokens, keys) | Effects (`useEffect`) |
| Reduce JavaScript sent to client | Browser APIs |
| Heavy dependencies kept server-side | Custom hooks with state |

### Strategy

- Keep layouts and pages as Server Components by default.
- Extract interactive parts into small Client Components at the leaves.
- Don't mark an entire page as `'use client'` — that sends all its code to the browser.

```tsx
// ✅ — Layout stays server, interactive part is a leaf client component
// app/(main)/layout.tsx (Server Component)
import { Navbar } from '@/shared/navbar/navbar';
import { SearchBar } from '@/shared/ui/searchBar'; // 'use client' inside

export default function MainLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <Navbar />
      <SearchBar />
      <main>{children}</main>
    </>
  );
}
```

---

## Server Components

Default for all pages and layouts. They are `async`, can call services directly, and send zero JS to the client.

```tsx
// features/habits/ui/pages/habitsPage.tsx
import { habitsService } from '../../infrastructure';

export async function HabitsPage() {
  const result = await habitsService.getAll();
  if (!result.success) throw new Error(result.error); // caught by error.tsx
  return <HabitListWidget habits={result.data} />;
}
```

### Handling errors in Server Components

Handle expected errors (not found) with `notFound()`. Throw for unexpected errors — `error.tsx` catches them.

```tsx
import { notFound } from 'next/navigation';

export async function HabitDetailPage({ params }: { params: { id: string } }) {
  const result = await habitsService.getById(params.id);
  if (!result.success) throw new Error(result.error);
  if (!result.data) notFound();

  return <HabitDetail habit={result.data} />;
}
```

### Suspense for streaming

Wrap slow Server Components in `<Suspense>` with a skeleton fallback:

```tsx
import { Suspense } from 'react';

export default function DashboardPage() {
  return (
    <div className="grid grid-cols-2 gap-6">
      <Suspense fallback={<HabitStatsSkeleton />}>
        <HabitStats /> {/* async — streams independently */}
      </Suspense>
      <RecentActivity /> {/* fast — no Suspense needed */}
    </div>
  );
}
```

### Metadata

Use `generateMetadata()` for dynamic page titles/descriptions.

```tsx
export async function generateMetadata({ params }: { params: { id: string } }) {
  const result = await habitsService.getById(params.id);
  return { title: result.success ? result.data.name : 'Habit' };
}
```

---

## Client Components

Add `'use client'` only at the leaf where interactivity begins. Keep the client boundary as narrow as possible.

### State management decision

| State type | Tool | Example |
|---|---|---|
| Server state (API data) | React Query | `useHabits()`, `useCreateHabit()` |
| Ephemeral UI state | `useState` | Modal open, hover, accordion |
| URL state (shareable) | `useSearchParams` | Filters, pagination, search |
| Global UI state | React Context | Theme, locale |

**Never use Context for server state.** React Query handles caching, invalidation, and background refetching.

---

## Widget pattern

Widgets are self-contained sections that own their loading, error, and empty states. They compose smaller components.

```
Widget (owns data + states) → Components (presentational, stateless)
```

Rules:
- Each widget must be able to **live independently** — if other widgets fail or are loading, this widget still works.
- Each widget renders its own **skeleton**, **error state**, and **empty state**.
- Widgets fetch their own data via query hooks.
- Components receive data via props — no data fetching.

```tsx
// features/habits/ui/widgets/habitActivityWidget.tsx
'use client';

export function HabitActivityWidget({ habitId }: { habitId: string }) {
  const { data, isLoading, isError } = useHabitActivity(habitId);

  if (isLoading) return <CardSkeleton title="Recent activity" />;
  if (isError) return <Card><InlineError message="Could not load activity" /></Card>;
  if (!data?.length) return <Card><EmptyState message="No activity yet" /></Card>;

  return (
    <Card>
      <CardHeader><CardTitle>Recent activity</CardTitle></CardHeader>
      <CardContent>
        <ul>{data.map((item) => <li key={item.id}>{item.label}</li>)}</ul>
      </CardContent>
    </Card>
  );
}
```

### When to fetch in Page vs Widget

By default, each widget fetches its own data. Only fetch in the Page when:
- **2+ widgets share the same query** — the Page fetches once and passes down.
- **A root resource is needed** to decide if the page should render at all (e.g., user not found).

```tsx
export function UserDashboardPage({ userId }: { userId: string }) {
  const { data: user, isLoading, isError } = useUser(userId);

  if (isLoading) return <PageSkeleton />;
  if (isError) return <ErrorState message="Could not load user" />;
  if (!user) return <EmptyState message="User not found" />;

  return (
    <div>
      <UserHeaderWidget user={user} />
      <UserProfileWidget user={user} />
      {/* These widgets fetch their own data */}
      <UserActivityWidget userId={userId} />
      <UserPermissionsWidget userId={userId} />
    </div>
  );
}
```

---

## Context pattern

Use React Context when a piece of state is shared by **2+ widgets** within a feature, or to avoid prop drilling beyond 3 levels.

Structure: **Type → Provider with `useMemo` → Hook consumer**.

```tsx
// features/onboarding/ui/context/stepperContext.tsx
import React from 'react';

// 1. Type: state + actions
interface StepperContextValue {
  currentStep: number;
  totalSteps: number;
  isFirstStep: boolean;
  isLastStep: boolean;
  next: () => void;
  back: () => void;
  goTo: (step: number) => void;
}

const StepperContext = React.createContext<StepperContextValue | null>(null);

// 2. Provider
export function StepperProvider({
  totalSteps,
  children,
}: {
  totalSteps: number;
  children: React.ReactNode;
}) {
  const [currentStep, setCurrentStep] = React.useState(0);

  const value = React.useMemo<StepperContextValue>(
    () => ({
      currentStep,
      totalSteps,
      isFirstStep: currentStep === 0,
      isLastStep: currentStep === totalSteps - 1,
      next: () => setCurrentStep((s) => Math.min(s + 1, totalSteps - 1)),
      back: () => setCurrentStep((s) => Math.max(s - 1, 0)),
      goTo: (step) => setCurrentStep(step),
    }),
    [currentStep, totalSteps]
  );

  return (
    <StepperContext.Provider value={value}>{children}</StepperContext.Provider>
  );
}

// 3. Hook
export function useStepper() {
  const ctx = React.useContext(StepperContext);
  if (!ctx) throw new Error('useStepper must be used within a StepperProvider');
  return ctx;
}
```

Rules:
- Context local to a feature → `features/<feature>/ui/context/`.
- Context shared across features → `shared/`.
- Always wrap the value in `useMemo` to prevent unnecessary re-renders.
- Always provide a hook that validates the context exists.

---

## UI Hooks

Custom hooks that encapsulate **visual state only** — no queries, no mutations, no business logic.

```typescript
// features/habits/ui/hooks/useDisclosure.ts
import React from 'react';

export function useDisclosure(initialState = false) {
  const [isOpen, setIsOpen] = React.useState(initialState);

  return {
    isOpen,
    open: () => setIsOpen(true),
    close: () => setIsOpen(false),
    toggle: () => setIsOpen((v) => !v),
  };
}
```

Usage:

```tsx
export function DeleteHabitWidget({ habitId }: { habitId: string }) {
  const dialog = useDisclosure();
  const deleteHabit = useDeleteHabit();

  return (
    <>
      <Button variant="destructive" onClick={dialog.open}>Delete</Button>
      <ConfirmDialog
        open={dialog.isOpen}
        onConfirm={() => deleteHabit.mutateAsync(habitId)}
        onCancel={dialog.close}
      />
    </>
  );
}
```

What belongs in UI hooks:
- Open/close/toggle state
- Scroll position tracking
- Debounced input values
- Tab selection logic

What does NOT belong:
- Queries or mutations (Application layer)
- Business logic (Domain layer)
- State shared across components (Context)

---

## Forms

Use `react-hook-form` + `zodResolver` for all forms. Split into container (form setup + mutation) and content (UI fields). See `agent_docs/frontend/forms.md` for the full pattern.

---

## Anti-patterns

- **`'use client'` at page level** — Pages are Server Components by default. Push `'use client'` to the widget/component that needs it.
- **Fetching in `useEffect`** — Use React Query or Server Components. `useEffect` fetch creates waterfalls and no caching.
- **Context for server state** — Don't create React Context for API data. React Query handles this.
- **Business logic in event handlers** — Extract to `domain/*.logic.ts` or use cases. Event handlers call hooks/mutations.
- **Forms without Zod** — Always validate with Zod. It ensures consistency between client and server validation.
- **Monolithic components** — Split into widget (data + states) and components (presentational). One React component per file.
- **Widgets without own states** — Every widget must handle loading, error, and empty states independently.
- **Large Client Components** — Keep `'use client'` boundaries narrow. Extract server-renderable parts out.
