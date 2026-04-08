---
description: Frontend testing — DI/IoC, unit tests for domain, component tests with RTL, mock at boundaries
globs: "apps/client/**/*.spec.ts, apps/client/**/*.spec.tsx, apps/admin/**/*.spec.ts"
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

Tests give the agent a “verifiable target”; prefer test-first or test-immediately-after. :contentReference[oaicite:2]{index=2}  
If doing strict TDD:

1. write tests from expected I/O
2. run tests and confirm they fail
3. implement until tests pass
4. avoid “overfitting” to tests (sanity-check behaviors) :contentReference[oaicite:3]{index=3}

### Progressive Disclosure (don’t bloat this file)

If task needs specifics, **read the relevant doc** instead of expanding CLAUDE.md. :contentReference[oaicite:4]{index=4}  
Suggested docs (keep these in-repo):

- `docs/testing/fundamentals.md` → DI/IoC rules + examples (this is your “Fundamentos” article)
- `docs/testing/unit.md` → unit test patterns & boundaries
- `docs/testing/components.md` → RTL patterns, anti-patterns
- `docs/testing/integration.md` → app wiring + contract tests
- `docs/testing/mocking.md` → what to mock vs what not to mock
  (Prefer pointers to authoritative files instead of duplicating long snippets.) :contentReference[oaicite:5]{index=5}

---

## Command Center (don’t guess commands)

Keep a small “cheat sheet” of how to run tests/lint/build so the agent doesn’t guess. :contentReference[oaicite:6]{index=6}

- Install: `npm install`
- Unit tests: `npm run test`
- Watch tests: `npm run test:watch`
- Coverage: `npm run test:coverage`
- Lint: `npm run lint`
- Typecheck: `npm run type-check`
- Build: `npm run build`

(Replace scripts with your real ones; the point is “always use the right incantation”.) :contentReference[oaicite:7]{index=7}

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

- Keep contents **short and universally applicable**; irrelevant rules get ignored. :contentReference[oaicite:8]{index=8}
- Prefer **separate docs** + “read when needed” (progressive disclosure). :contentReference[oaicite:9]{index=9}
- Avoid auto-generating CLAUDE.md; craft intentionally because it affects every session. :contentReference[oaicite:10]{index=10}

---


