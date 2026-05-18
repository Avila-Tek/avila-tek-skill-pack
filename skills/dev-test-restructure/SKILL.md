---
name: test-restructure
description: Refactors an existing test suite to match behavioral naming, correct folder structure, and internal quality standards — without breaking passing tests. Spanish triggers: "refactoriza las pruebas", "los tests están desorganizados", "arregla la estructura de pruebas".
---

# Test Suite Restructure

## Overview

Existing test suites accumulate structural debt: class-named files that grow without bound, tests scattered at the root of a `test/` folder, setup copied inline across every test. This skill refactors a test suite incrementally and safely — snapshot first, refactor module by module, compare at the end.

**The contract:** any test that was passing before must still be passing after. No regressions allowed.

## When to Use

- A test suite exists but wasn't written following behavioral naming or file organization conventions
- Test files are too large to navigate
- Tests are flat in a `test/` folder with no relation to module structure
- The team has adopted the testing standards in `dev-test-driven-development` and needs to bring existing tests in line

**When NOT to use:** Starting a new feature from scratch — use `dev-test-driven-development` for that.

## Stack Activation Gate

Detect the active stack from the project's package files. State it explicitly: "Active stack: {name}".

| Stack | Detection signal | Test command |
|-------|-----------------|-------------|
| NestJS | `@nestjs/core` in `package.json` | `npx vitest run` |
| Next.js | `next` in `package.json` | `npx vitest run` |
| Go | `go.mod` present | `go test ./...` |
| Spring Boot | `pom.xml` / `build.gradle` with `spring-boot` | `./mvnw test` |
| React Native | `react-native` in `package.json` | `npx jest` |
| Flutter | `pubspec.yaml` with `flutter:` | `flutter test` |

Load the matching reference from `../dev-test-driven-development/references/` before starting. Apply its file co-location convention and mock strategy throughout.

---

## Phase 1: Snapshot

Before touching a single file, capture the full test result state.

```bash
# Vitest
npx vitest run --reporter=json --outputFile=.test-snapshot.json

# Jest
npx jest --json --outputFile=.test-snapshot.json

# Go
go test ./... 2>&1 | tee .test-snapshot.txt

# Flutter
flutter test 2>&1 | tee .test-snapshot.txt
```

Record and display:

```
TEST SNAPSHOT — before restructure
────────────────────────────────────
Total:   142
Passing: 118
Failing:  24
Skipped:   0

Failing tests:
  - auth/login.spec.ts > LoginService > rejects expired tokens
  - users/users.module.spec.ts > should create user
  ...
```

**Do not proceed until the snapshot is captured.** This is your baseline. Every passing test must still pass at the end.

---

## Phase 2: Classify

Walk the test directory. For every test file, assign one of four classifications.

### Folder structure rule

Test files must mirror the source module tree. Two valid layouts:

```
# Layout A — co-located (preferred for NestJS, Next.js)
src/
  modules/
    users/
      application/use-cases/create-user.spec.ts
      domain/entities/user.spec.ts

# Layout B — mirrored test folder (acceptable when the team prefers separation)
test/
  modules/
    users/
      application/use-cases/
        user-creation.spec.ts
        user-authentication.spec.ts
```

A flat `test/` root with no sub-structure is **not** acceptable regardless of file quality.

Detect which layout the project uses and enforce it consistently. If the project is mixed, pick the dominant pattern and migrate stragglers to it.

### How to determine the target location for a file

Every test file is derived from the source file(s) it exercises. Use that relationship to derive the correct path:

**Step 1 — Identify the source file.** Read the test file's imports. The source module under test is the primary non-test, non-fixture import.

```typescript
// From the imports you can read:
import { CreateUserUseCase } from '../../application/use-cases/create-user.use-case';
//                                  ↑ this is the source file path
```

**Step 2 — Derive the target path from the layout.**

```
Layout A (co-located):
  Source: src/modules/users/application/use-cases/create-user.use-case.ts
  Test:   src/modules/users/application/use-cases/user-creation.spec.ts
                                                   ↑ same directory, behavior-based name

Layout B (mirrored folder):
  Source: src/modules/users/application/use-cases/create-user.use-case.ts
  Test:   test/modules/users/application/use-cases/user-creation.spec.ts
               ↑ test/ root replaces src/, everything else mirrors
```

**Step 3 — For RESTRUCTURE: map each behavior group to its source layer.**

When splitting a file, each behavior group tests a specific class or layer. Identify which source file each group belongs to, then place the new spec file next to that source file.

```
users.module.spec.ts contains tests for:
  → CreateUserUseCase   → src/modules/users/application/use-cases/user-creation.spec.ts
  → User entity         → src/modules/users/domain/entities/user.spec.ts
  → UserRepository      → src/modules/users/infrastructure/persistence/user-repository.spec.ts
```

For NestJS specifically, respect the layer hierarchy defined in `../dev-test-driven-development/references/nestjs.md`:

```
domain/entities/        ← unit tests for domain objects (no mocks)
application/use-cases/  ← unit tests for use-cases (mocked repos)
infrastructure/         ← integration tests (real DB or HTTP)
```

If a behavior group doesn't map cleanly to a single source file (e.g., it tests a collaboration between two layers), place it at the closest common ancestor directory and name it after the scenario: `user-registration-flow.spec.ts`.

### Classification decision tree

For each file, answer in order:

```
1. Is the file in the right location?
   (co-located OR correctly mirrored under the matching module path)
   → No  → add RELOCATE to this file's actions

2. Is the filename behavior-based?
   Behavior-based:  user-creation.spec.ts, password-reset.spec.ts
   Class-based:     user.service.spec.ts, users.module.spec.ts, UserService.test.ts
   → Class-based AND (file > 150 lines OR multiple top-level describe blocks)
     → add RESTRUCTURE to this file's actions
   → Class-based but small (< 150 lines, single describe)
     → treat as REFACTOR (rename + internal cleanup)

3. Does the internal structure follow the standards?
   Check: describe depth ≤ 2, factory helpers used, behavioral assertions
   → No  → add REFACTOR to this file's actions

4. No actions assigned → SKIP (already correct)
```

Actions are additive — a file can require both RESTRUCTURE and RELOCATE.

### Classification report

Present the full plan before touching any file:

```
CLASSIFICATION REPORT
──────────────────────────────────────────────────────
Module: users
  users.module.spec.ts       → RESTRUCTURE + RELOCATE
    Split into:
      user-creation.spec.ts
      user-authentication.spec.ts
      user-profile.spec.ts
    Move to: src/modules/users/application/use-cases/

Module: auth
  sign-in.spec.ts            → REFACTOR
    Issues: inline setup repeated 8×, describe depth 3
  sign-up.spec.ts            → SKIP

Module: tasks
  task.service.spec.ts       → RESTRUCTURE
    Split into:
      task-creation.spec.ts
      task-assignment.spec.ts
      task-completion.spec.ts

Total: 3 files to restructure, 1 to refactor, 1 to relocate, 1 skipped
──────────────────────────────────────────────────────
Proceed? (y/n)
```

**Wait for confirmation before starting Phase 3.**

---

## Phase 3: Refactor — module by module

Process one module at a time. Run the full test suite after completing each module.

### RESTRUCTURE

A file that covers multiple behaviors gets split into one file per behavior group.

1. Read the file completely. Identify distinct behavior groups (top-level `describe` blocks or logical clusters of related tests).
2. For each behavior group:
   a. Create a new `{behavior}.spec.ts` file in the correct location.
   b. Copy the relevant tests into it.
   c. Extract any shared setup into a `{module}.fixtures.ts` factory file co-located with the new specs.
   d. Run tests — the new file must pass before continuing.
3. Once all new files are created and passing, delete the original file.
4. Run the module's tests again to confirm the delete didn't break anything.

```
RESTRUCTURE: users.module.spec.ts
  ✓ Created user-creation.spec.ts (12 tests passing)
  ✓ Created user-authentication.spec.ts (8 tests passing)
  ✓ Created user-profile.spec.ts (6 tests passing)
  ✓ Extracted makeUser() → user.fixtures.ts
  ✓ Deleted users.module.spec.ts
  ✓ Module tests: 26/26 passing
```

### REFACTOR

A file with the right name but internal issues gets fixed in place.

Address issues in this order — run tests after each step:

1. **Describe depth** — if nesting exceeds 2 levels, either flatten or extract the inner group to its own file.
2. **Repeated inline setup** — extract to a `make{Entity}()` factory in a co-located `.fixtures.ts` file.
3. **Implementation assertions** — replace assertions on internal state, call counts, or method names with assertions on observable outputs and side effects.
4. **Test names** — rename any test that describes the implementation (`calls repository.save`) to describe the behavior (`persists the new task`).

```
REFACTOR: sign-in.spec.ts
  ✓ Flattened describe nesting (3 → 2 levels)
  ✓ Extracted makeCredentials() → auth.fixtures.ts (removed 8× inline setup)
  ✓ Replaced 3 call-count assertions with state assertions
  ✓ Renamed 2 tests to describe behavior
  ✓ 14/14 passing
```

### RELOCATE

A well-structured file in the wrong place gets moved without content changes.

1. Derive the target path using the mapping rule in the **Folder structure rule** section above: read the file's imports, find the source module, apply the project layout.
2. Move the file to the derived target path.
3. Update any import paths inside the file that break due to the new location.
4. Run tests immediately — a failing test here is always an import path issue.

```
RELOCATE: test/sign-out.spec.ts
  → src/modules/auth/application/use-cases/sign-out.spec.ts
  ✓ Updated 0 import paths
  ✓ 5/5 passing
```

### SKIP

Log it and move on:

```
SKIP: sign-up.spec.ts — already correct
```

---

## Phase 4: Compare snapshots

Once every module is processed, run the full suite and compare against the Phase 1 snapshot.

```bash
npx vitest run --reporter=json --outputFile=.test-snapshot-after.json
```

Display a diff:

```
SNAPSHOT COMPARISON
──────────────────────────────────────────────────────────
                Before    After
  Total           142      168   (+26 new tests written during refactor)
  Passing         118      141   (+23)
  Failing          24        3   (-21)
  Skipped           0        0

Previously passing, now FAILING (regressions — must fix before done):
  ✗ auth/sign-in.spec.ts > when credentials are valid > returns a token
    → Import error: makeCredentials not found

Previously failing, now PASSING (bonus — bad structure was the cause):
  ✓ users > user-creation > rejects duplicate email (x18 tests)
  ✓ tasks > task-completion > marks task as completed

Remaining failures (were failing before, still failing):
  ✗ tasks > task-archival > archives after 30 days
    → Likely a real bug. Do not fix here — create a task.
──────────────────────────────────────────────────────────
```

**Regressions are blockers.** Fix every regression before considering the work done. Regressions introduced by this refactor are always structural errors (import paths, missing factories, misplaced tests) — not logic bugs.

Remaining failures that existed before the restructure are out of scope. Note them, create a task for each, and do not fix them here.

---

## Red Flags

- Deleting an original file before all its replacement files are passing
- Fixing a logic bug during a structural refactor — that is scope creep; note it and move on
- Creating a `fixtures.ts` that imports from another module's fixtures — fixtures are local
- A file that passes in isolation but fails in the full suite — test isolation problem, fix before continuing
- Merging RESTRUCTURE and unrelated REFACTOR changes in the same step
- Skipping the snapshot — proceeding without a baseline is not allowed

## Verification

- [ ] Phase 1 snapshot was captured before any changes
- [ ] Classification report was reviewed and confirmed before Phase 3 began
- [ ] Tests were run after each module was completed
- [ ] No regressions remain (every test passing before is passing now)
- [ ] All test files are in the correct location (co-located or mirrored module tree)
- [ ] No test file exceeds 250 lines
- [ ] Shared fixtures are in co-located `.fixtures.ts` files
- [ ] Class-based filenames have been eliminated
- [ ] Remaining pre-existing failures are documented as tasks
- [ ] Snapshot comparison has been shown to the user
