---
name: test-driven-development
description: Drives development with tests. Use when implementing any logic, fixing any bug, or changing any behavior. Use when you need to prove that code works, when a bug report arrives, or when you're about to modify existing functionality. Spanish triggers: "escribe las pruebas", "crea los tests", "prueba esto con TDD".
---

# Test-Driven Development

## Stack Activation Gate

Detect the active stack from the project's package files. State it explicitly: "Active stack: {name}".

| Stack | Detection signal |
|-------|-----------------|
| NestJS | `@nestjs/core` in `package.json` |
| Next.js | `next` in `package.json` (not Angular, not React Native) |
| Go | `go.mod` present |
| Spring Boot | `pom.xml` or `build.gradle` containing `spring-boot` |
| React Native | `react-native` in `package.json` |
| Flutter | `pubspec.yaml` containing `flutter:` |

**Required before any code output — do not skip:**
1. Derive the skill directory from the path this SKILL.md was loaded from.
2. Read the matching reference file from that directory:
   - NestJS → `references/nestjs.md`
   - Next.js → `references/nextjs.md`
   - Go → `references/go.md`
   - Spring Boot → `references/spring-boot.md`
   - React Native → `references/react-native.md`
   - Flutter → `references/flutter.md`
3. Apply the testing patterns from that file and run its Verification Checklist before completing any output.

> The loaded reference defines the test framework, file co-location convention, mock strategy, and commands for the active stack. Follow them exactly.

## Overview

Write a failing test before writing the code that makes it pass. For bug fixes, reproduce the bug with a test before attempting a fix. Tests are proof — "seems right" is not done. A codebase with good tests is an AI agent's superpower; a codebase without tests is a liability.

## When to Use

- Implementing any new logic or behavior
- Fixing any bug (the Prove-It Pattern)
- Modifying existing functionality
- Adding edge case handling
- Any change that could break existing behavior

**When NOT to use:** Pure configuration changes, documentation updates, or static content changes that have no behavioral impact.

**Related:** For browser-based changes, combine TDD with runtime verification using Chrome DevTools MCP — see the `dev-browser-testing-with-devtools` skill.

## The TDD Cycle

```
    RED                GREEN              REFACTOR
 Write a test    Write minimal code    Clean up the
 that fails  ──→  to make it pass  ──→  implementation  ──→  (repeat)
      │                  │                    │
      ▼                  ▼                    ▼
   Test FAILS        Test PASSES         Tests still PASS
```

### Step 1: RED — Write a Failing Test

Write the test first. It must fail. A test that passes immediately proves nothing.

```typescript
// RED: This test fails because createTask doesn't exist yet
describe('TaskService', () => {
  it('creates a task with title and default status', async () => {
    const task = await taskService.createTask({ title: 'Buy groceries' });

    expect(task.id).toBeDefined();
    expect(task.title).toBe('Buy groceries');
    expect(task.status).toBe('pending');
    expect(task.createdAt).toBeInstanceOf(Date);
  });
});
```

### Step 2: GREEN — Make It Pass

Write the minimum code to make the test pass. Don't over-engineer:

```typescript
// GREEN: Minimal implementation
export async function createTask(input: { title: string }): Promise<Task> {
  const task = {
    id: generateId(),
    title: input.title,
    status: 'pending' as const,
    createdAt: new Date(),
  };
  await db.tasks.insert(task);
  return task;
}
```

### Step 3: REFACTOR — Clean Up

With tests green, improve the code without changing behavior:

- Extract shared logic
- Improve naming
- Remove duplication
- Optimize if necessary

Run tests after every refactor step to confirm nothing broke.

## The Prove-It Pattern (Bug Fixes)

When a bug is reported, **do not start by trying to fix it.** Start by writing a test that reproduces it.

```
Bug report arrives
       │
       ▼
  Write a test that demonstrates the bug
       │
       ▼
  Test FAILS (confirming the bug exists)
       │
       ▼
  Implement the fix
       │
       ▼
  Test PASSES (proving the fix works)
       │
       ▼
  Run full test suite (no regressions)
```

**Example:**

```typescript
// Bug: "Completing a task doesn't update the completedAt timestamp"

// Step 1: Write the reproduction test (it should FAIL)
it('sets completedAt when task is completed', async () => {
  const task = await taskService.createTask({ title: 'Test' });
  const completed = await taskService.completeTask(task.id);

  expect(completed.status).toBe('completed');
  expect(completed.completedAt).toBeInstanceOf(Date);  // This fails → bug confirmed
});

// Step 2: Fix the bug
export async function completeTask(id: string): Promise<Task> {
  return db.tasks.update(id, {
    status: 'completed',
    completedAt: new Date(),  // This was missing
  });
}

// Step 3: Test passes → bug fixed, regression guarded
```

## Test File Organization

Test files should be as easy to read as production code. A test file that grows without bounds defeats readability, specificity, and maintainability.

### One file = one concern

Map test files to units of behavior, not units of code:

```
✅ user-registration.spec.ts       ← behavior
✅ password-reset.spec.ts          ← behavior
❌ user.service.spec.ts            ← class — becomes a dumping ground
```

When a class or module has multiple distinct behaviors, split them into separate spec files from the start.

### Size threshold

A test file over **150 lines** (excluding shared fixtures) is a signal to split. Over **250 lines** is a hard limit — split before adding more tests.

When a file hits the threshold, split by behavior group:

```
// Before: user.spec.ts (300 lines)
describe('User')
  describe('creation') ...
  describe('authentication') ...
  describe('password reset') ...

// After
user-creation.spec.ts       ← describe('User creation')
user-authentication.spec.ts ← describe('User authentication')
user-password-reset.spec.ts ← describe('User password reset')
```

### Use factory helpers for fixtures

Never repeat setup inline. Extract a factory or builder next to the spec file:

```typescript
// user.factory.ts — co-located with the spec
export function makeUser(overrides?: Partial<UserProps>): User {
  return User.create({
    id: 'user-1',
    email: 'test@example.com',
    name: 'Test User',
    ...overrides,
  });
}

// user-creation.spec.ts — clean, intent-revealing
it('rejects a duplicate email', async () => {
  const existing = makeUser({ email: 'taken@example.com' });
  await repo.save(existing);

  await expect(useCase.execute({ email: 'taken@example.com' }))
    .rejects.toThrow(DuplicateEmailError);
});
```

Factory helpers belong in a `*.factory.ts` or `*.fixtures.ts` file co-located with the spec. Never import fixtures from unrelated modules.

### Describe block depth

Maximum two levels: one for the unit under test, one for the scenario group. Deeper nesting is a sign the behavior group should become its own file.

```typescript
// ✅ Two levels — readable
describe('TaskService', () => {
  describe('when task is overdue', () => {
    it('sends a reminder notification', ...);
    it('marks task as at-risk', ...);
  });
});

// ❌ Three levels — split the file instead
describe('TaskService', () => {
  describe('notifications', () => {
    describe('when overdue', () => { ... });
  });
});
```

## See Also

For detailed testing patterns, examples, and anti-patterns across frameworks, see `../../references/testing-patterns.md`.

## Test Properties

Not all tests need every property, but no property should be sacrificed without a deliberate tradeoff.

| Property | Definition | Tradeoff |
|---|---|---|
| **Isolated** | Same result regardless of test execution order | |
| **Deterministic** | Same result if nothing changes | Avoid time, random, or network dependencies |
| **Fast** | Runs in milliseconds, not seconds | Slow tests don't get run |
| **Behavioral** | Sensitive to changes in *what* the code does | If behavior changes, the test must fail |
| **Structure-insensitive** | Insensitive to changes in *how* the code does it | Refactoring should never break tests |
| **Readable** | A reader can infer the motivation without reading the source | |
| **Specific** | A failure points directly to the cause | |
| **Automated** | Runs without human intervention | |

**Behavioral and Structure-insensitive are the most commonly violated pair.** A test that duplicates the implementation's structure will pass when behavior is broken and fail when behavior is intact — the worst of both worlds. Test the *contract*, not the *implementation*.

### Test Category Tradeoffs

| Category | Keeps | Gives up |
|---|---|---|
| Unit / Programmer | Fast, Specific, Writable | Predictive (narrow scope) |
| Integration | Behavioral, Predictive | Speed, Specificity |
| Acceptance | Readable by non-programmers | Speed, Specificity |
| Monitoring | Real-world signal | Predictive, Automated alerting |

## Red Flags

- Writing code without any corresponding tests
- Tests that pass on the first run (they may not be testing what you think)
- "All tests pass" but no tests were actually run
- Bug fixes without reproduction tests
- Tests that mirror code structure — they will break on every refactor even when behavior is unchanged
- Tests that assert on internal implementation details (private methods, internal state, call counts on collaborators)
- Tests that test framework behavior instead of application behavior
- Test names that don't describe the expected behavior
- Skipping tests to make the suite pass
- Non-deterministic tests (flaky due to time, randomness, or network)
- Test files organized by class/method instead of behavior — they grow without bound
- Test files over 250 lines — split by behavior group before adding more tests
- Fixture setup repeated inline across multiple tests instead of extracted to a factory

## Verification

After completing any implementation:

- [ ] Every new behavior has a corresponding test
- [ ] All tests pass: `npm test`
- [ ] Bug fixes include a reproduction test that failed before the fix
- [ ] Test names describe the behavior being verified, not the implementation
- [ ] Tests assert on observable outputs and side effects, not internal structure
- [ ] Tests produce the same result regardless of execution order (isolated)
- [ ] Tests produce the same result on repeated runs with no changes (deterministic)
- [ ] No tests were skipped or disabled
- [ ] Coverage hasn't decreased (if tracked)
- [ ] No test file exceeds 250 lines — split by behavior group if over the threshold
- [ ] Repeated fixture setup is extracted to a factory helper

## Output Artifact

### Where to place the test file

Before creating a new test file, detect the project's layout from existing test files:

```
Layout A — co-located (spec file sits next to its source file):
  src/modules/users/application/use-cases/create-user.use-case.ts
  src/modules/users/application/use-cases/user-creation.spec.ts   ← same directory

Layout B — mirrored test folder (test/ mirrors src/ structure):
  src/modules/users/application/use-cases/create-user.use-case.ts
  test/modules/users/application/use-cases/user-creation.spec.ts  ← test/ replaces src/
```

Pick the layout that already exists in the project and follow it consistently. Never mix layouts in the same project.

For layer-specific placement within a module (e.g., domain vs. use-case vs. infrastructure), follow the pyramid defined in the loaded stack reference file.

If the test file you're about to create would end up in a flat `test/` root with no sub-structure, stop — derive the correct path from the source file's location using the rules above.

Coverage report is generated at the project root after running the test command.
