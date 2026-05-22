---
description: Frontend testing — DI/IoC, unit tests for domain, component tests with RTL, mock at boundaries, E2E with Cypress
globs: "apps/client/**/*.spec.ts, apps/client/**/*.spec.tsx, apps/admin/**/*.spec.ts, apps/**/*.cy.ts"
alwaysApply: false
---

## WHY (quality intent)

We optimize for **tests that are fast, isolated, and maintainable** by designing code with:

- **Dependency Injection (DI)**: dependencies are passed in, not constructed inside modules.
- **Inversion of Control (IoC)**: domain/application depend on **interfaces/contracts**, not concrete infrastructure details.

This enables reliable unit tests (pure logic) and focused integration tests (wiring + boundaries).

---

## WHAT (testing scope we expect)

When implementing or modifying code, assume we need:

1. **Unit tests** for:

- domain logic, pure utilities, reducers/selectors, validators, formatters
- anything with branching logic and edge cases

2. **Component tests** for:

- UI behavior (render states, user interactions, accessibility affordances)

3. **Integration tests** for:

- key flows where multiple modules collaborate (but still avoid real external systems)

---

## HOW (workflow Claude should follow)

### Default workflow = TDD-friendly

Tests give the agent a “verifiable target”; prefer test-first or test-immediately-after.
If doing strict TDD:

1. write tests from expected I/O
2. run tests and confirm they fail
3. implement until tests pass
4. avoid “overfitting” to tests (sanity-check behaviors)

### Progressive Disclosure (don’t bloat this file)

If task needs specifics, **read the relevant doc** instead of expanding CLAUDE.md.
Suggested docs (keep these in-repo):

- `docs/testing/fundamentals.md` → DI/IoC rules + examples (this is your “Fundamentos” article)
- `docs/testing/unit.md` → unit test patterns & boundaries
- `docs/testing/components.md` → RTL patterns, anti-patterns
- `docs/testing/integration.md` → app wiring + contract tests
- `docs/testing/mocking.md` → what to mock vs what not to mock
  (Prefer pointers to authoritative files instead of duplicating long snippets.)

---

## Command Center (don’t guess commands)

Keep a small “cheat sheet” of how to run tests/lint/build so the agent doesn’t guess.

- Install: `npm install`
- Unit tests: `npm run test`
- Watch tests: `npm run test:watch`
- Coverage: `npm run test:coverage`
- Lint: `npm run lint`
- Typecheck: `npm run type-check`
- Build: `npm run build`

(Replace scripts with your real ones; the point is “always use the right incantation”.)

---

## Testing Instructions (our “standard”)

### 1) DI/IoC rules for testability

**Hard rule:** no module should “new” its own external dependencies inside business logic.

- ✅ pass dependencies via constructor/function params (DI)
- ✅ depend on interfaces/contracts (IoC)
- ✅ separate pure logic from side effects

**Practical outcome:**

- Unit tests can inject mocks/stubs without touching real APIs.
- Integration tests validate wiring without relying on external systems.

### 2) What to mock vs what to test “for real”

Mock at **boundaries**:

- network clients, repositories, storage, time, randomness, analytics/event emitters

Don’t mock:

- your own pure functions
- your own small deterministic utilities
- DOM rendering (use RTL to interact like a user)

### 3) Test naming + structure

- Prefer `describe("<module>")` + `it("should <behavior>")`
- One behavior per test
- Include edge cases (invalid input, error states)

(You can keep naming guidance small; don’t turn this into a style guide.)

### 4) Component tests (React Testing Library mindset)

- Test behavior, not implementation details
- Interact via user events; assert on visible outcomes
- Prefer accessible queries (role/label/text)

### 5) Done = verified

Before considering work complete:

- run test suite
- ensure lint + typecheck pass
- no flaky timeouts; stabilize async tests

(If test suite is slow, isolate with targeted runs first, then full run.)

---

## Maintenance rules 

- Keep contents **short and universally applicable**; irrelevant rules get ignored.
- Prefer **separate docs** + “read when needed” (progressive disclosure).
- Avoid auto-generating CLAUDE.md; craft intentionally because it affects every session.

---

## E2E Testing (Cypress)

E2E tests live in `apps/<app>/cypress/e2e/` and cover **critical user flows** end-to-end in a real browser. Each frontend app (`admin`, `client`) has its own Cypress setup.

### When to write E2E vs unit/component

| Scenario | Layer |
|----------|-------|
| Business logic, pure functions | Unit |
| Component render states, interactions | Component (RTL) |
| Full user flows (auth, multi-step forms, navigation) | E2E (Cypress) |

### Skills

Use these slash commands instead of writing Cypress tests by hand:

- **`/cypress-author`** — create, update, or fix a spec
- **`/cypress-explain`** — explain a test or a Cypress API

### Project conventions

**Selectors:** Always use `data-cy` attributes. Never use class names or tag selectors.

```html
<!-- Component -->
<button data-cy=”submit-btn”>Submit</button>
```
```ts
// Test
cy.get('[data-cy=”submit-btn”]').click();
```

**Page Object pattern:** Each page has a class in `apps/<app>/cypress/support/pageObjects/`. Methods encapsulate interactions; tests orchestrate flows.

```ts
// apps/<app>/cypress/support/pageObjects/SignInPage.ts
export default class SignInPage {
  signIn(email: string, password: string) {
    cy.get('[data-cy=”email-input”]').type(email);
    cy.get('[data-cy=”password-input”]').type(password);
    cy.get('[data-cy=”submit-btn”]').click();
  }
}
```

**Fixtures:** Credentials and test data in `cypress/fixtures/`. Never hardcode credentials in test files.

```ts
before(() => {
  cy.fixture('auth/credentials').then((data) => { ... });
});
```

**Network:** The app uses `MockHttpClient` — an in-process JS interceptor that handles API calls before they reach the network. `cy.intercept()` alone never fires in mock mode.

> If the project does not have `MockHttpClient`, see `references/testing-utilities.md` for the reference implementation and Cypress command setup.

Use the environment-aware custom commands for all stubs:

| Command | Purpose |
|---|---|
| `cy.apiError(method, path, statusCode, error)` | Stub a failing API response |
| `cy.apiResponse(method, path, data)` | Override a default mock response |

In mock mode (`NEXT_PUBLIC_API_MOCKING=enabled`) these route to `MockHttpClient`. In real-API mode (variable unset) they fall back to `cy.intercept()`. Never call `cy.intercept()` directly for response stubs — it will be silently ignored in mock mode.

Low-level commands (`cy.setMockError`, `cy.setMockResponse`) program `MockHttpClient` directly and must be called **after** `cy.visit()` (they need `window.__mockClient__`). Prefer `cy.apiError` / `cy.apiResponse` instead.

**Switching modes:** edit `apps/admin/.env.local`:
- `NEXT_PUBLIC_API_MOCKING=enabled` → MockHttpClient, no backend needed
- variable unset → real HTTP, backend required

Default mock responses live in `packages/features/src/mocks/` and `apps/admin/src/mocks/`. Each full page load resets them — no manual cleanup needed between tests.

Never use arbitrary `cy.wait(ms)`.

**State setup:** Use `before`/`beforeEach` to isolate state. Use `cy.session()` for flows that require login.

**Naming:** `”[action] → [expected result]”`
```ts
it('sign in with valid credentials → redirects to dashboard', () => { ... });
```

**Structure:** (same layout for every frontend app)
```
apps/<app>/cypress/
  e2e/
    auth/         ← one folder per feature area
      signIn.cy.ts
      forgotPassword.cy.ts
  fixtures/
    auth/
      credentials.json
  support/
    pageObjects/  ← one class per page
    commands.ts
    e2e.ts
```

### Commands

```bash
# Run all E2E tests (headless)
npx cypress run --project apps/<admin|client>

# Open Cypress UI
npx cypress open --project apps/<admin|client>
```
