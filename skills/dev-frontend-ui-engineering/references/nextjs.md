# Next.js + React Query — Frontend Standards

## Shared Components Scan

Before applying any pattern in this file, scan the project for these shared components and use the names you find — not the names in the examples below.

| Component | Fallback search terms |
|---|---|
| SSR prefetch wrapper | `PrefetchBoundary`, `HydrationBoundary` |
| Safe result guard | `QueryResultGuard`, `ResultGuard` |
| Loading skeleton | `FormSkeleton`, `Skeleton` |

If any are not found, show the reference implementation from `stacks/nextjs/agent_docs/references/components.md` and ask the user before proceeding.

---

## Architecture

Feature-driven Clean Architecture. A feature is a complete user-facing capability — delete the folder, that capability disappears.

```
src/
  app/                  ← App Router (thin wrappers only — no logic)
  context/              ← Client-side React context providers
  features/
    <feature>/
      ui/
        pages/*.tsx       ← route-level screens (imported from app/)
        layouts/*.tsx     ← shared layout wrappers
        widgets/*.tsx     ← self-contained sections (own loading/error/empty)
        components/*.tsx  ← reusable presentational pieces
        context/*.tsx     ← feature-scoped context
        hooks/*.ts        ← custom hooks for this feature's UI
      application/
        queries/use*.query.ts       ← React Query reads
        mutations/use*.mutation.ts  ← React Query writes
        useCases/*.useCase.ts       ← flow orchestration
      domain/
        *.model.ts        ← domain entities/value objects (frontend-friendly shapes)
        *.logic.ts        ← pure rules, no side effects
        *.constants.ts    ← enums, query keys, domain constants
        *.form.ts         ← Zod form schemas, default value factories
      infrastructure/
        *.interfaces.ts   ← DTO aliases from @repo/schemas, response wrappers, service contracts
        *.transform.ts    ← DTO ↔ Domain mapping
        *.service.ts      ← data-access logic (implements contracts from interfaces)
  shared/               ← Cross-cutting UI + utilities
  lib/                  ← App-level helpers (query client, env, config)
```

**Dependency rule:** `UI → Application → Infrastructure → Domain`. Domain knows nothing. No feature imports from another feature (shared belongs in `shared/` or `packages/`).

> **DTOs:** API input/output types are defined in `@repo/schemas`. `*.interfaces.ts` files create local aliases, response wrapper types, and service contracts — not raw DTO definitions.

## Key Patterns

- **`@repo/ui` only** — no raw HTML elements with inline styles; use design system tokens
- **Zod schemas from `packages/schemas/`** — never hand-write type interfaces shared with backend
- **React Query for all server state** — no `useEffect` + `fetch`; no `useState` for async data
- **No logic in `app/`** — route files import feature pages; zero business logic in route files
- **Server Components by default** — opt into `'use client'` only for interactivity/hooks
- **Layer boundaries strict** — UI calls Application; Application calls Domain + Infra; never reverse

## Component Structure

Internal file order:
1. Imports
2. Props interface (`[ComponentName]Props`)
3. Component function (function **declaration**, not arrow)
   - Hooks
   - Derived values (computed — no side effects)
   - Handlers (`handleX`)
   - JSX return (markup only, no inline logic)

```tsx
// features/habits/ui/components/habitCard.tsx
export function HabitCard({ habit, onLogProgress }: HabitCardProps) {
  const [expanded, setExpanded] = React.useState(false);
  const canLog = canAddProgress(habit);
  function handleLog() { onLogProgress(habit.id); }
  return (
    <div className="flex items-center gap-4">
      <h3>{habit.name}</h3>
      {canLog ? <Button onClick={handleLog}>Log</Button> : null}
    </div>
  );
}
```

**Rules:**
- Function declarations only (not arrow functions)
- ~150–200 lines max — split when JSX fills a page or state diverges
- One exported component per file
- **Stateful (Widget):** owns data, manages loading/error/empty states
- **Stateless (Component):** receives props, renders, emits events

```tsx
// Stateful — Widget
export function HabitListWidget({ date }: { date: Date }) {
  const { data, isLoading, isError } = useHabitsForDate(date);
  if (isLoading) return <HabitListSkeleton />;
  if (isError) return <ErrorState message="Failed to load habits" />;
  if (!data?.length) return <EmptyState />;
  return <div>{data.map(h => <HabitCard key={h.id} habit={h} />)}</div>;
}
```

## Data Fetching

| Scenario | Pattern |
|---|---|
| Page-level, no interactivity | Server Component + direct service call |
| Client widget, initial data from server | `PrefetchBoundary` + client hook |
| Client-side pagination / filtering / search | `useQuery` with dynamic query keys |
| Detail/edit pages with Suspense | `useSuspenseQuery` + `QueryResultGuard` |
| Mutations | `useMutation` passthrough → use case handles errors |
| Server-side mutations (progressive) | Server Actions (`'use server'`) |

**Pattern 1 — Server Component:**
```tsx
export default async function HabitsPage() {
  const habits = await habitsService.getAll();
  return <HabitList habits={habits} />;
}
```

**Pattern 2 — PrefetchBoundary + three-layer query (default for client widgets):**

Every query file follows a three-layer structure:

- **`queryOptions`** — always a `Safe<T>` passthrough. Never throws, never selects. Used by `PrefetchBoundary` (server) and as base for both hooks.
- **`useXxx()`** — `useQuery` + `select` that throws on `!result.success`. Consumer receives `T + isError`.
- **`useXxxSuspense()`** — `useSuspenseQuery`, returns `Safe<T>` directly for `QueryResultGuard`.

```tsx
// Layer 1: queryOptions — always Safe<T>
export function habitsQueryOptions() {
  return queryOptions({
    queryKey: ['habits'],
    queryFn: () => habitsService.getAll(),  // service is a singleton
  });
}

// Layer 2a: client hook — select throw → T + isError
export function useHabits() {
  return useQuery({
    ...habitsQueryOptions(),
    select: (result) => {
      if (!result.success) throw new Error(result.error);
      return result.data;
    },
  });
}

// Layer 2b: suspense hook — Safe<T> for QueryResultGuard
export function useHabitsSuspense() {
  return useSuspenseQuery(habitsQueryOptions());
}
```

Page-level prefetch with `PrefetchBoundary`:

```tsx
// page.tsx (Server Component)
export default function HabitsPage() {
  return (
    <PrefetchBoundary queries={[habitsQueryOptions()]}>
      <HabitsWidget />
    </PrefetchBoundary>
  );
}
```

For detail/edit pages — use `useSuspenseQuery` + `QueryResultGuard`:

```tsx
// page.tsx (Server Component)
export default async function HabitDetailRoute({ params }: Props) {
  const habitId = parseIdParam((await params).id);
  return (
    <PrefetchBoundary queries={[habitQueryOptions(habitId)]}>
      <Suspense fallback={<FormSkeleton />}>
        <HabitDetailLoader habitId={habitId} />
      </Suspense>
    </PrefetchBoundary>
  );
}

// Client loader — 'use client'
export function HabitDetailLoader({ habitId }: Props) {
  const { data: result } = useHabitSuspense(habitId);
  return (
    <QueryResultGuard result={result} title="Habit not found" redirectTo={routeBuilders.habits()}>
      {(habit) => <HabitDetailContent habit={habit} />}
    </QueryResultGuard>
  );
}
```

Use `useSuspenseQuery` when the parent provides a `<Suspense>` boundary with a skeleton. Use `useQuery` when the widget handles its own loading state.

**Pattern 3 — Mutations:**

Mutations are passthroughs — never put error handling in the mutation hook. A **use case** wraps the mutation and handles `Safe<T>` results with toast + navigation:

```tsx
// Mutation: passthrough only
export function useCreateHabitMutation() {
  return useMutation({
    mutationFn: (data: TCreateHabitForm) => habitsService.create(data),
  });
}

// Use case: handles Safe<T> with toast + navigation
export function useCreateHabit() {
  const createMutation = useCreateHabitMutation();
  const router = useRouter();
  const { showToast } = useToast();
  return {
    createHabit: (data: TCreateHabitForm) =>
      createHabitUseCase(data, { mutate: createMutation.mutateAsync, showToast, push: router.push }),
    isPending: createMutation.isPending,
  };
}

async function createHabitUseCase(data: TCreateHabitForm, deps: CreateHabitDeps) {
  const result = await deps.mutate(data).catch(() => null);
  if (!result) {
    deps.showToast({ type: 'error', title: 'Ha ocurrido un error inesperado' });
    return;
  }
  if (!result.success) {
    deps.showToast({ type: 'error', title: result.error });
    return;
  }
  deps.showToast({ type: 'success', title: result.message ?? 'Hábito creado exitosamente' });
  deps.push(routeBuilders.habits());
}
```

For mutations that only need cache invalidation (no navigation or complex error flow), `onSuccess` is sufficient:

```tsx
export function useToggleHabitStatus() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (habitId: string) => habitsService.toggleStatus(habitId),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['habits'] }),
  });
}
```

**Query key conventions:** hierarchical arrays — `['habits']`, `['habits', 'by-date', date]`, `['habits', id]`. Invalidating `['habits']` cascades to all nested keys.

**Service singletons:** Services are exported as singletons from `infrastructure/index.ts`. Use `habitsService.getAll()`, not `new HabitsService().getAll()`.

**Anti-patterns:** `useEffect` for fetching, throwing in `queryFn` (throw belongs in `select`), `new Service()` in `queryFn`, `HydrationBoundary`+`dehydrate` directly (use `PrefetchBoundary`), error handling in mutation hooks (use the use case layer), no `staleTime` set, Server Actions for reads.

## Forms

Three-piece pattern — always split this way:

| File | Layer | Responsibility |
|---|---|---|
| `*.form.ts` | Domain | Zod schema, inferred type, default values factory |
| `*Form.tsx` | UI/widgets | `useForm` + `zodResolver` + `FormProvider` + mutation |
| `*FormContent.tsx` | UI/widgets | Fields via `useFormContext` |

```typescript
// features/habits/domain/habits.form.ts
export const createHabitFormDefinition = z.object({
  name: z.string().min(1, 'Name is required').max(100),
  frequency: z.enum(['daily', 'weekly']),
});
export type TCreateHabitForm = z.infer<typeof createHabitFormDefinition>;
export function createHabitDefaultValues(): TCreateHabitForm {
  return { name: '', frequency: 'daily' };
}
```

```tsx
// CreateHabitForm.tsx — container
const mutation = useCreateHabit();
const methods = useForm<TCreateHabitForm>({
  defaultValues: createHabitDefaultValues(),
  resolver: zodResolver(createHabitFormDefinition),
});
return (
  <FormProvider {...methods}>
    <form onSubmit={methods.handleSubmit(d => mutation.mutateAsync(d))}>
      <CreateHabitFormContent disabled={mutation.isPending} error={mutation.error?.message} />
    </form>
  </FormProvider>
);
```

**Rules:** `mutation.isPending` for disabled state (no manual `useState`). `.safeParse()` not `.parse()`. Schemas in `domain/*.form.ts` — never inside components.

### Cross-field validation (`superRefine`)

When one field's validity depends on another, use `superRefine` on the relevant sub-schema:

```typescript
const transactionDefinition = z.object({
  amount: z.number().positive(),
  isNational: z.boolean(),
  routingNumberCode: z.string().optional(),
  routingNumberType: z.enum(['aba', 'swift']).optional(),
});

function refineRoutingNumber(value: z.infer<typeof transactionDefinition>, ctx: z.RefinementCtx) {
  if (value.isNational) return;
  if (!value.routingNumberCode) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'Routing number required for international transactions',
      path: ['routingNumberCode'],
    });
  }
}

export const payOrderFormDefinition = z.object({
  transactions: z.array(transactionDefinition.superRefine(refineRoutingNumber)).min(1),
});
```

State-dependent validation (e.g. "name not taken") belongs in a use case, not the schema.

## Routing

All navigation uses `routeBuilders` — no magic strings.

```typescript
// shared/routes/routes.ts
const ROUTE_PATHS = { LOGIN: '/login', DASHBOARD: '/all-habits' } as const;
export const routeBuilders = {
  login: (params?: { callbackUrl?: string }) => {
    if (!params?.callbackUrl) return ROUTE_PATHS.LOGIN;
    return `${ROUTE_PATHS.LOGIN}?callbackUrl=${params.callbackUrl}`;
  },
  dashboard: () => ROUTE_PATHS.DASHBOARD,
} as const;
export const ROUTES = ROUTE_PATHS;
```

Routes classified in `shared/routes/routesConfig.ts`:
- `PUBLIC_ROUTES` — anyone
- `AUTH_ROUTES` — unauthenticated only (redirects logged-in users)
- `PROTECTED_ROUTES` — requires authentication

Route files are thin wrappers:
```tsx
// app/(auth)/login/page.tsx
import { LoginPage } from '@repo/features/auth/ui/pages/LoginPage';
export const metadata: Metadata = { title: 'Sign In' };
export default function LoginRoute() { return <LoginPage />; }
```

Adding a new route: add to `ROUTE_PATHS` → add builder → classify in `routesConfig.ts` → create `page.tsx` → delegate to feature page.

## Authentication

Uses **better-auth** with cookie-based sessions (no JWTs).

```tsx
// Client Components
const { data: session, isPending } = authClient.useSession();
```

Route protection in `middleware.ts` — not in components:
```typescript
export function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const authenticated = isAuthenticated(request);
  if (isAuthRoute(pathname) && authenticated)
    return NextResponse.redirect(new URL(routeBuilders.dashboard(), request.url));
  if (isProtectedRoute(pathname) && !authenticated)
    return NextResponse.redirect(new URL(routeBuilders.login({ callbackUrl: pathname }), request.url));
  return NextResponse.next();
}
```

**Anti-patterns:** Calling `auth.api` from Client Components, session checks in every component, manual cookie reads.

## Styling

Never use primitive Tailwind color classes. Always use semantic tokens:

| File | Examples |
|---|---|
| `bg-variables.css` | `bg-brand-solid`, `bg-surface`, `bg-error-solid` |
| `text-variables.css` | `txt-primary-900`, `txt-secondary-700`, `txt-brand-secondary-700` |
| `border-variables.css` | `border-primary`, `border-brand`, `border-error` |
| `fg-variables.css` | `fg-brand-primary`, `fg-secondary` |

```tsx
// ✗ Bad — primitive Tailwind
<div className="bg-brand-600 text-white border-brand-500" />
// ✓ Good — semantic tokens
<div className="bg-brand-solid txt-primary_on-brand border-brand" />
```

For shadcn: check `packages/ui` before installing. Use `npx shadcn@canary add <component>` (not `shadcn-ui`).

## Code Standards

**File naming by layer suffix:**

| Layer | Suffix | Example |
|---|---|---|
| Domain model | `*.model.ts` | `habit.model.ts` |
| Domain logic | `*.logic.ts` | `habit.logic.ts` |
| Domain constants | `*.constants.ts` | `habit.constants.ts` |
| Form schema | `*.form.ts` | `habits.form.ts` |
| Infra interface | `*.interfaces.ts` | `habits.interfaces.ts` |
| Infra transform | `*.transform.ts` | `habits.transform.ts` |
| Infra service | `*.service.ts` | `habits.service.ts` |
| Query hook | `use*.query.ts` | `useHabits.query.ts` |
| Mutation hook | `use*.mutation.ts` | `useCreateHabit.mutation.ts` |
| Use case | `*.useCase.ts` | `createHabitFlow.useCase.ts` |
| Server Action | `*.actions.ts` | `user.actions.ts` |

**TypeScript:** No `any` without comment. `import type` for type-only imports. Explicit return types on exported functions. Validate external data with Zod.

**React:** Function declarations (not arrow functions). Server Components by default; `'use client'` only for browser APIs/interactivity. Prefer ternaries over `&&`:

```tsx
// ✗ avoid — renders "0" when empty
return items.length && <List items={items} />;
// ✓ preferred
return items.length > 0 ? <List items={items} /> : <EmptyState />;
```

**Error handling:** Infrastructure services return `Safe<T>` — never throw. `queryFn` is always a passthrough — never throw there. The throw belongs in the hook's `select` (React Query catches it, sets `isError: true`). Mutations are passthroughs — use case layer handles errors with toast + navigation. Server Actions return `Safe<T>`.

## shadcn Component Library

When the project uses shadcn/ui, use the MCP before writing custom components:

1. Query the shadcn MCP for a component matching the UI need.
2. Review its API, variants, and built-in accessibility behavior.
3. If not yet in the project, install via CLI: `npx shadcn@canary add <component>` (not `shadcn-ui`).
4. Compose from shadcn primitives — never re-implement what it already provides.

**Prefer shadcn primitives** for: Button, Dialog, Dropdown, Form, Input, Select, Sheet, Toast, Tooltip, Table, Tabs, Command.

Check `packages/ui` before installing — the component may already be available project-wide.

## State Management Decision Matrix

| State type | Solution |
|---|---|
| Component-specific ephemeral UI (toggle, input draft) | `useState` |
| Shared between 2–3 sibling components | Lift to nearest common parent |
| Feature-scoped config (read-heavy, write-rare) | React Context |
| Filters, pagination, tabs — shareable via URL | `useSearchParams` (Next.js) |
| Remote data with caching | TanStack React Query (`useQuery`) |
| User-triggered writes | TanStack React Query (`useMutation`) |
| Complex app-wide client state | Zustand |

**Never** `useEffect` + `fetch` for server data — use React Query.
**Never** lift state to global store before trying local → lifted → context first.

## Optimistic Updates

For frequent, low-risk mutations (toggle, reorder, quick edits), use optimistic updates to make the UI feel instant:

```tsx
export function useToggleTask() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (taskId: string) => tasksService.toggle(taskId),
    onMutate: async (taskId) => {
      await queryClient.cancelQueries({ queryKey: ['tasks'] });
      const previous = queryClient.getQueryData(['tasks']);

      queryClient.setQueryData(['tasks'], (old: Task[]) =>
        old.map(t => t.id === taskId ? { ...t, done: !t.done } : t)
      );

      return { previous };
    },
    onError: (_err, _taskId, context) => {
      queryClient.setQueryData(['tasks'], context?.previous);
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['tasks'] });
    },
  });
}
```

`onMutate` → apply optimistic change. `onError` → revert. `onSettled` → sync with server.

## Accessibility Patterns

### Focus management for dialogs and modals

Move focus to the first interactive element when a dialog opens. Restore it to the trigger when it closes. Trap focus inside while open.

```tsx
function Dialog({ isOpen, onClose }: DialogProps) {
  const closeRef = React.useRef<HTMLButtonElement>(null);

  React.useEffect(() => {
    if (isOpen) closeRef.current?.focus();
  }, [isOpen]);

  return (
    <dialog open={isOpen} onClose={onClose}>
      <button ref={closeRef} onClick={onClose}>Close</button>
      {/* dialog content */}
    </dialog>
  );
}
```

### Skeleton loading (not spinners for content)

```tsx
function TaskListSkeleton() {
  return (
    <div className="space-y-3" aria-busy="true" aria-label="Loading tasks">
      {Array.from({ length: 3 }).map((_, i) => (
        <div key={i} className="h-12 bg-muted animate-pulse rounded" />
      ))}
    </div>
  );
}
```

## Good Practices

- React APIs via `React.*` — `React.useState`, `React.useEffect`, etc.
- Move derived values above the JSX return — never inline complex logic in JSX
- Max 3 levels prop drilling; beyond that use Context or composition
- `Promise.all` for parallel async — never sequential `await` for independent calls

```tsx
// ✗ avoid — sequential
const a = await fetch('/a');
const b = await fetch('/b');
// ✓ preferred — parallel
const [a, b] = await Promise.all([fetch('/a'), fetch('/b')]);
```

Always handle loading + error + empty:
```tsx
if (isLoading) return <Spinner />;
if (isError) return <ErrorState />;
if (!data?.length) return <EmptyState />;
```

## Red Flags

- `useEffect` for data fetching (use React Query)
- Business logic in `app/` route files
- Cross-layer imports in wrong direction (infra importing from UI)
- Raw `fetch()` outside `infrastructure/` adapters
- Inline styles or primitive color values (not semantic tokens)
- Missing loading, error, or empty states in widgets
- `any` type without explanatory comment
- Magic route strings instead of `routeBuilders`
- `HydrationBoundary` + `dehydrate` used directly (use `PrefetchBoundary`)
- Throwing in `queryFn` (throw belongs in the hook's `select`)
- `onError`, toast, or navigation logic in mutation hooks (use the use case layer)
- `new Service()` in `queryFn` (services are singletons)

## Verification Checklist

- [ ] `npm run build` passes with no type errors
- [ ] `npm test` passes, coverage ≥ 80%
- [ ] No ESLint errors (`npm run lint`)
- [ ] New pages have `loading.tsx` and `error.tsx` siblings
- [ ] All interactive elements are keyboard-accessible
- [ ] No raw `fetch()` outside `infrastructure/` layer
- [ ] Semantic color tokens used — no primitive Tailwind color classes
- [ ] Bundle size delta reviewed (`npm run analyze`)
