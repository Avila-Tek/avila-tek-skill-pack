---
description: Backend test commands cheat sheet — npm run test, vitest, verification checklist
globs: "apps/api/src/**/*.spec.ts, apps/api/vitest.config.ts"
alwaysApply: false
---

# Test Cheat Sheet — apps/api

Quick reference. For patterns and examples see `testing.md`.

---

## Commands

```bash
# Run all tests
npm run test

# Watch mode
npm run test:watch

# Coverage report
npm run test:coverage

# E2E tests
npm run test:e2e

# Typecheck
npx turbo typecheck --filter @app/api

# Lint
npx turbo lint --filter @app/api
```

---

## Scope at a glance

| Layer | What to test | Tool |
|---|---|---|
| Domain (entities, value objects, policies) | Business rules, validation, invariants | Vitest — pure unit |
| Application (use-cases) | Orchestration logic, port interactions | Vitest — unit with mocked ports |
| Infrastructure (repository adapters) | DB queries, row mapping | Vitest — integration with test DB |
| Presentation (controllers) | HTTP wiring, status codes, response shape | NestJS `Test.createTestingModule` |

---

## File placement

Test files live **next to the file they test**, using the `.spec.ts` suffix:

```
src/modules/office/
├── domain/entities/Office.spec.ts
├── application/use-cases/CreateOfficeUseCase.spec.ts
└── infrastructure/persistence/OfficeRepositoryAdapter.spec.ts
```

---

## Done = verified

Before considering any task complete:

1. Run `npm run test` — all tests pass.
2. Run `npx turbo typecheck` — zero errors.
3. Run `npx turbo lint` — zero warnings.
4. No flaky async tests — stabilize with `vi.useFakeTimers()` or proper `await` if needed.
