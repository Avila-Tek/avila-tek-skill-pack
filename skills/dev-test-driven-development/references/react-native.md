# React Native — Testing Reference

## Framework
Vitest + React Testing Library (RTL) for unit/component tests. `integration_test` for critical E2E flows.

## Test Scope

| Type | What | Tools |
|---|---|---|
| Unit | domain logic, use cases, pure utilities, validators | Vitest |
| Component | UI behavior, user interactions, navigation | RTL + Expo Router test utils |
| Integration | key flows (auth, checkout, onboarding) | Expo `integration_test` |

## Core Principle: DI/IoC

Dependencies are passed in — never `new`-ed inside business logic. Domain and Application layers depend on interfaces, not concrete infrastructure.

This means:
- Unit tests inject mocks/stubs without touching real APIs
- Component tests inject mock repositories/use cases
- Real HTTP only at the integration level

## Unit Tests: Domain and Use Cases

Domain logic is pure TypeScript — test with no mocks:

```typescript
// domain/validators/email.validator.test.ts
describe('EmailValidator', () => {
  it('returns true for valid email', () => {
    expect(isValidEmail('user@example.com')).toBe(true);
  });
  it('returns false for missing @', () => {
    expect(isValidEmail('userexample.com')).toBe(false);
  });
});
```

Use cases receive repository interfaces — inject fakes in tests:

```typescript
// application/use-cases/get-orders.usecase.test.ts
const fakeRepo: OrderRepository = {
  findAll: vi.fn().mockResolvedValue([{ id: '1', total: 50 }]),
};

describe('GetOrdersUseCase', () => {
  it('returns orders from repository', async () => {
    const useCase = new GetOrdersUseCase(fakeRepo);
    const result = await useCase.execute();
    expect(result).toHaveLength(1);
  });
});
```

## Component Tests (RTL)

Test behavior and interactions, not implementation. Prefer accessible queries:

```tsx
// presentation/features/auth/SignInScreen.test.tsx
import { render, fireEvent, waitFor } from '@testing-library/react-native';

describe('SignInScreen', () => {
  it('shows error when credentials are invalid', async () => {
    const { getByLabelText, getByRole, getByText } = render(
      <SignInScreen signIn={vi.fn().mockRejectedValue(new Error('Invalid credentials'))} />
    );
    fireEvent.changeText(getByLabelText('Email'), 'a@b.com');
    fireEvent.changeText(getByLabelText('Password'), 'wrong');
    fireEvent.press(getByRole('button', { name: 'Sign in' }));
    await waitFor(() => expect(getByText('Invalid credentials')).toBeTruthy());
  });
});
```

## TanStack Query in Tests

Wrap with `QueryClientProvider` with a fresh client per test:

```tsx
const createWrapper = () => {
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  return ({ children }: { children: ReactNode }) => (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );
};

it('displays orders after load', async () => {
  server.use(http.get('/orders', () => HttpResponse.json([{ id: '1' }])));
  const { result } = renderHook(() => useOrdersQuery(), { wrapper: createWrapper() });
  await waitFor(() => expect(result.current.isSuccess).toBe(true));
  expect(result.current.data).toHaveLength(1);
});
```

## Auth in Tests

Use `authClient.useSession()` — mock the session state in components:

```typescript
// Mock better-auth session
vi.mock('@/infrastructure/auth/auth-client', () => ({
  authClient: {
    useSession: vi.fn().mockReturnValue({
      data: { user: { id: '1', name: 'Alice', email: 'a@b.com' } },
      isPending: false,
    }),
  },
}));
```

## Mock Boundaries

**Mock:** network clients, repositories, storage (`expo-secure-store`), time, randomness.

**Don't mock:** pure domain functions, small utilities, React Native component rendering.

## Commands

```bash
npm test                  # run all tests
npm run test:watch        # watch mode
npm run test:coverage     # with coverage
npm run typecheck         # TypeScript check
npm run lint              # ESLint
```

## Anti-Patterns

- Calling real APIs in unit tests — inject fake repositories
- Not wrapping with `QueryClientProvider` when testing TanStack Query hooks
- Checking auth state in every screen — auth routing happens in `_layout.tsx`
- Testing implementation details (internal state, which hooks were called)
- Using `testID` when accessible queries (role/label/text) are available
