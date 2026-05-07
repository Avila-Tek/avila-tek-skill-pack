# Next.js — Testing Reference

## Framework
Vitest + React Testing Library (RTL). Test files co-located as `*.spec.ts` / `*.spec.tsx`.

## Core Principle: DI/IoC for Testability

**Hard rule:** no module should `new` its own external dependencies inside business logic.

- ✅ Pass dependencies via constructor/function params (DI)
- ✅ Depend on interfaces/contracts, not concrete infrastructure
- ✅ Separate pure logic from side effects

This enables unit tests with injected mocks and integration tests without real external systems.

## Test Scope

| Type | What | When |
|---|---|---|
| Unit | domain logic, pure utilities, reducers, validators, formatters, any branching logic | Any function with edge cases |
| Component | UI behavior, user interactions, accessibility affordances | All interactive components |
| Integration | key flows where multiple modules collaborate | Critical paths only |

## Mock Boundaries

**Mock at:** network clients, repositories, storage, time, randomness, analytics/event emitters.

**Don't mock:** your own pure functions, small deterministic utilities, DOM rendering (use RTL to interact like a user).

## Component Tests (RTL)

Test behavior, not implementation details. Interact via user events; assert on visible outcomes. Prefer accessible queries:

```typescript
// ✅ Good — behavior-focused, accessible queries
it('shows error when email is invalid', async () => {
  render(<LoginForm />);
  await userEvent.type(screen.getByLabelText('Email'), 'not-an-email');
  await userEvent.click(screen.getByRole('button', { name: 'Sign in' }));
  expect(screen.getByRole('alert')).toHaveTextContent('Invalid email');
});

// ❌ Bad — tests implementation details
it('calls setError with invalid email message', () => {
  const setError = vi.fn();
  render(<LoginForm setError={setError} />);
  // ...
  expect(setError).toHaveBeenCalledWith('invalid email');
});
```

## TanStack Query in Tests

Wrap components with `QueryClientProvider` with a fresh client per test:

```typescript
const createWrapper = () => {
  const queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  });
  return ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );
};

it('displays tasks on load', async () => {
  server.use(http.get('/api/tasks', () => HttpResponse.json([{ id: 1, title: 'Test' }])));
  const { result } = renderHook(() => useTasksQuery(), { wrapper: createWrapper() });
  await waitFor(() => expect(result.current.isSuccess).toBe(true));
  expect(result.current.data).toHaveLength(1);
});
```

## Server Actions and Server Components

Test Server Actions as plain async functions (they're just TypeScript):

```typescript
import { createTask } from '@/features/tasks/server/task.actions';

it('returns ok with created task', async () => {
  const result = await createTask({ title: 'My task' });
  expect(result.success).toBe(true);
  expect(result.data.title).toBe('My task');
});
```

Server Components: render as async components, assert on the HTML output.

## Safe\<T\> in Tests

When testing functions that return `Safe<T>`, assert on `success` first:

```typescript
it('returns success false on API failure', async () => {
  server.use(http.get('/api/tasks', () => HttpResponse.error()));
  const result = await taskService.fetchTasks();
  expect(result.success).toBe(false);
});
```

## Commands

```bash
npm test                 # run all tests
npm run test:watch       # watch mode
npm run test:coverage    # with coverage report
npm run type-check       # TypeScript check
npm run lint             # ESLint
```

## Done = Verified

Before considering work complete:
- Run the full test suite
- Lint and typecheck pass
- No flaky timeouts; stabilize async tests

## Anti-Patterns

- Testing implementation details (which hooks were called, internal state)
- Not wrapping with `QueryClientProvider` when testing components that use TanStack Query
- `expect(component).toMatchSnapshot()` for large outputs — snapshots become stale quickly
- Mocking your own pure utilities — test them directly
- Using `data-testid` when accessible queries (`role`, `label`, `text`) are available
