---
description: Backend testing strategy — unit/integration/E2E pyramid, mocked ports, in-memory fakes
globs: "apps/api/src/**/*.spec.ts, apps/api/test/**/*.e2e-spec.ts"
alwaysApply: false
---

# Testing Guide — apps/api

The test pyramid applies directly to the Hexagonal Architecture: most tests are unit tests against pure domain logic, fewer are integration tests that verify NestJS wiring, and fewest are E2E tests that exercise the full HTTP surface. Each level answers a different question.

- **Unit tests** ask: "is the business rule correct?"
- **Integration tests** ask: "does the wiring work?"
- **E2E tests** ask: "does the HTTP API respond correctly end-to-end?"

Because domain and application logic have zero NestJS imports, unit tests require no framework overhead. They are plain `describe`/`it` blocks with `vi.fn()` mocks running in milliseconds. Testing via HTTP when a unit test would suffice is the most common waste of testing effort in NestJS projects — it inflates runtime by orders of magnitude and makes tests sensitive to irrelevant infrastructure concerns.

> **CQRS note:** The codebase currently uses `@nestjs/cqrs` as the cross-module communication mechanism. This affects how use-cases and controllers are tested — see the callouts in each section below. This pattern is provisional and the testing approach will evolve when CQRS is replaced.

---

## Test file co-location

Unit and integration test files live **next to the source file they test**. E2E tests live in `test/` at the project root.

```
src/modules/office/
├── domain/
│   ├── entities/Office.spec.ts               ← unit test
│   └── value-objects/Location.spec.ts        ← unit test
├── application/
│   └── use-cases/CreateOfficeUseCase.spec.ts ← unit test
├── infrastructure/
│   ├── persistence/OfficeRepositoryAdapter.spec.ts ← integration test (DB)
│   └── web/OfficeController.spec.ts          ← integration test (HTTP wiring)
test/
└── offices.e2e-spec.ts                       ← E2E test (full HTTP stack)
```

---

## 1. Unit tests — Domain layer

Entities, value objects, and policies are pure TypeScript. No mocks needed — instantiate directly with `new` or static factories.

```typescript
// ✅ Good — src/modules/office/domain/value-objects/Location.spec.ts
import { describe, expect, it } from 'vitest';
import { Location } from './Location';
import { InvalidLocationError } from './Location';

describe('Location', () => {
  it('should create a valid location', () => {
    const location = Location.create({ address: 'Av. Principal 123' });
    expect(location.address).toBe('Av. Principal 123');
  });

  it('should throw when address is empty', () => {
    expect(() => Location.create({ address: '' })).toThrow(InvalidLocationError);
  });

  it('should throw when address is whitespace only', () => {
    expect(() => Location.create({ address: '   ' })).toThrow(InvalidLocationError);
  });
});
```

```typescript
// ✅ Good — src/modules/client/domain/policies/ClientTypePolicy.spec.ts
import { describe, expect, it } from 'vitest';
import { ClientTypePolicy } from './ClientTypePolicy';
import { InvalidClientError } from '../errors/InvalidClientError';

describe('ClientTypePolicy', () => {
  it('should throw when corporate client has no RIF', () => {
    expect(() =>
      ClientTypePolicy.validate('corporate', { rif: undefined })
    ).toThrow(InvalidClientError);
  });

  it('should pass when natural client has no RIF', () => {
    expect(() =>
      ClientTypePolicy.validate('natural', { rif: undefined })
    ).not.toThrow();
  });
});
```

---

## 2. Unit tests — Application layer (use-cases)

Use-cases are tested with plain `new` — no `Test.createTestingModule()`. Inject mock implementations of the abstract repository using `vi.fn()`.

> **CQRS note:** Use-cases are decorated with `@CommandHandler(Port)` and their `execute()` method receives a **Port instance** (the command object), not a plain DTO. Pass `new CreateOfficePort(...)` in tests, not a raw object literal.

```typescript
// ✅ Good — src/modules/office/application/use-cases/CreateOfficeUseCase.spec.ts
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { CreateOfficeUseCase } from './CreateOfficeUseCase';
import { CreateOfficePort } from '../ports/in/CreateOfficePort';
import type { OfficeRepository } from '../ports/out/OfficeRepository';
import { Office } from '../../domain/entities/Office';
import { OfficeId } from '../../domain/value-objects/OfficeId';
import { Location } from '../../domain/value-objects/Location';

describe('CreateOfficeUseCase', () => {
  let useCase: CreateOfficeUseCase;
  let officeRepository: OfficeRepository;

  beforeEach(() => {
    officeRepository = {
      create: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
      findById: vi.fn(),
      findAll: vi.fn(),
    };
    useCase = new CreateOfficeUseCase(officeRepository);
  });

  it('should call repository.create and return the new office', async () => {
    const mockOffice = Office.restore({
      id: OfficeId.create(1),
      name: 'Main Office',
      phone: '+58 212 000 0000',
      representative: 'John Doe',
      postalMail: null,
      location: Location.restore({ address: 'Av. Principal 123' }),
    });
    vi.mocked(officeRepository.create).mockResolvedValue(mockOffice);

    // Pass a Port instance — the CQRS command object — not a plain object
    const command = new CreateOfficePort(
      'Main Office',
      '+58 212 000 0000',
      'John Doe',
      { address: 'Av. Principal 123' },
    );
    const result = await useCase.execute(command);

    expect(officeRepository.create).toHaveBeenCalledOnce();
    expect(result).toBe(mockOffice);
  });
});
```

**Key rules:**
- Never instantiate real adapters in use-case tests.
- Never connect to a database in use-case tests.
- Create fresh mocks in `beforeEach` — never share mutable state between tests.
- Pass a `Port` instance to `execute()`, not a raw object literal.
- One behavior per test; name with `it('should <behavior>')`.

---

## 3. Test doubles — In-memory fakes

For complex use-cases with multiple interactions, prefer an **in-memory fake** over `vi.fn()` mocks. A fake is a real implementation of the abstract class that stores data in memory. It behaves like the real thing — just without a database.

```typescript
// ✅ Good — src/modules/office/infrastructure/memory/OfficeRepositoryFake.ts
import { OfficeRepository } from '../../application/ports/out/OfficeRepository';
import type { Office } from '../../domain/entities/Office';
import type { NewOffice } from '../../domain/entities/NewOffice';
import type { PaginatedResult } from '../../../../shared/domain/pagination';
import { OfficeId } from '../../domain/value-objects/OfficeId';

export class OfficeRepositoryFake extends OfficeRepository {
  private readonly store = new Map<number, Office>();
  private nextId = 1;

  async create(newOffice: NewOffice): Promise<Office> {
    const office = Office.restore({ id: OfficeId.create(this.nextId++), ...newOffice });
    this.store.set(office.id.value, office);
    return office;
  }

  async findById(id: number): Promise<Office | null> {
    return this.store.get(id) ?? null;
  }

  async delete(id: number): Promise<boolean> {
    return this.store.delete(id);
  }

  async findAll(page: number, perPage: number): Promise<PaginatedResult<Office>> {
    const items = Array.from(this.store.values());
    return { items, count: items.length, pageInfo: { currentPage: page, perPage, itemCount: items.length, pageCount: 1, hasPreviousPage: false, hasNextPage: false } };
  }

  async update(id: number, dto: unknown): Promise<Office | null> {
    return this.store.get(id) ?? null;
  }
}
```

---

## 4. Integration tests — NestJS wiring

Use `Test.createTestingModule()` only to verify that the NestJS DI container resolves correctly — the right providers are registered and the right tokens are bound.

> **CQRS note:** The module must import `CqrsModule` for `CommandBus`, `QueryBus`, and `@CommandHandler` decorators to resolve. When testing controller HTTP wiring, mock the `CommandBus` directly — do not dispatch real commands.

```typescript
// ✅ Good — verifying module wiring
import { Test, type TestingModule } from '@nestjs/testing';
import { CqrsModule } from '@nestjs/cqrs';
import { describe, it, expect, vi, beforeAll, afterAll } from 'vitest';
import { OfficeModule } from '../../module';
import { CreateOfficeUseCase } from '../../application/use-cases/CreateOfficeUseCase';
import { OfficeRepository } from '../../application/ports/out/OfficeRepository';
import { OfficeRepositoryFake } from '../memory/OfficeRepositoryFake';

describe('OfficeModule (wiring)', () => {
  let module: TestingModule;

  beforeAll(async () => {
    module = await Test.createTestingModule({
      imports: [CqrsModule, OfficeModule],
    })
      .overrideProvider(OfficeRepository)
      .useClass(OfficeRepositoryFake)
      .compile();
  });

  afterAll(async () => {
    await module.close();
  });

  it('should resolve CreateOfficeUseCase from the container', () => {
    const useCase = module.get(CreateOfficeUseCase);
    expect(useCase).toBeDefined();
  });
});
```

```typescript
// ✅ Good — controller test: mock CommandBus, not use-cases
import { Test, type TestingModule } from '@nestjs/testing';
import { CommandBus } from '@nestjs/cqrs';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { OfficeController } from './OfficeController';
import { Office } from '../../domain/entities/Office';

describe('OfficeController', () => {
  let controller: OfficeController;
  const commandBus = { execute: vi.fn() };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [OfficeController],
      providers: [{ provide: CommandBus, useValue: commandBus }],
    }).compile();

    controller = module.get(OfficeController);
    vi.clearAllMocks();
  });

  it('should return 201 and the mapped office on create', async () => {
    const mockOffice = Office.restore({ /* ... */ });
    commandBus.execute.mockResolvedValue(mockOffice);

    const result = await controller.create({ /* valid request dto */ });

    expect(commandBus.execute).toHaveBeenCalledOnce();
    expect(result.id).toBe(mockOffice.id.value);
  });
});
```

---

## 5. Integration tests — Repository adapters (DB)

Test the DB adapter against a real (or test-container) database. Validate that rows are correctly inserted, queried, soft-deleted, and mapped back to domain entities.

```typescript
// ✅ Good — src/modules/office/infrastructure/persistence/OfficeRepositoryAdapter.spec.ts
import { describe, expect, it, beforeEach } from 'vitest';
import { OfficeRepositoryAdapter } from './OfficeRepositoryAdapter';
import { testDb } from '../../../../test/helpers/testDb';
import { NewOffice } from '../../domain/entities/NewOffice';
import { Location } from '../../domain/value-objects/Location';

describe('OfficeRepositoryAdapter', () => {
  let repo: OfficeRepositoryAdapter;

  beforeEach(async () => {
    await testDb.reset();
    repo = new OfficeRepositoryAdapter(testDb.client);
  });

  it('should persist and retrieve an office', async () => {
    const newOffice = NewOffice.create({
      name: 'Test Office',
      phone: '+58 212 000 0000',
      representative: 'John Doe',
      postalMail: null,
      location: Location.create({ address: 'Av. Principal 123' }),
    });

    const saved = await repo.create(newOffice);
    const found = await repo.findById(saved.id.value);

    expect(found?.name).toBe('Test Office');
  });

  it('should not return soft-deleted offices', async () => {
    const newOffice = NewOffice.create({ /* ... */ });
    const office = await repo.create(newOffice);

    await repo.delete(office.id.value);
    const found = await repo.findById(office.id.value);

    expect(found).toBeNull();
  });
});
```

---

## 6. E2E tests — Full HTTP stack

E2E tests spin up the full application and make real HTTP requests via `supertest`. They use a test database and exercise guards, pipes, exception filters, and response mapping end-to-end.

```typescript
// ✅ Good — test/offices.e2e-spec.ts
import { Test, type TestingModule } from '@nestjs/testing';
import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { describe, beforeAll, afterAll, it, expect } from 'vitest';
import { AppModule } from '../src/app.module';

describe('Offices (e2e)', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const module: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = module.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  describe('POST /offices', () => {
    it('should return 201 with office data on valid input', async () => {
      const response = await request(app.getHttpServer())
        .post('/offices')
        .send({
          name: 'Main Office',
          phone: '+58 212 000 0000',
          representative: 'John Doe',
          location: { address: 'Av. Principal 123' },
        });

      expect(response.status).toBe(201);
      expect(response.body).toMatchObject({ name: 'Main Office' });
    });

    it('should return 400 on missing required fields', async () => {
      const response = await request(app.getHttpServer())
        .post('/offices')
        .send({ name: 'Incomplete' });

      expect(response.status).toBe(400);
    });
  });

  describe('GET /offices/:id', () => {
    it('should return 404 when office does not exist', async () => {
      const response = await request(app.getHttpServer()).get('/offices/99999');
      expect(response.status).toBe(404);
    });
  });
});
```

---

## What to mock vs what to test for real

| Always mock / fake | Always test for real |
|---|---|
| Repository adapters in use-case tests | Domain entities and value objects |
| External HTTP clients (Postmark, etc.) | Domain policies |
| `CommandBus` / `QueryBus` in controller tests | Repository adapters (integration test with DB) |
| Time (`vi.useFakeTimers`) and randomness | Zod schema validation |
| Auth guards in controller unit tests | Full auth flow in E2E tests |

---

## vitest configuration

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['src/**/*.spec.ts'],
    exclude: ['test/**'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov'],
      include: ['src/**/*.ts'],
      exclude: ['src/**/*.spec.ts', 'src/main.ts'],
    },
  },
});
```

---

## Anti-patterns

### ❌ Testing business logic through HTTP

```typescript
// ❌ Bad — E2E test for a pure domain rule
it('should throw when location address is empty', async () => {
  const response = await request(app.getHttpServer())
    .post('/offices')
    .send({ name: 'x', location: { address: '' } });
  expect(response.status).toBe(400);
  // This tests a domain invariant through the full HTTP stack —
  // 100x slower than a unit test and sensitive to unrelated HTTP changes
});
```

Test `Location.create({ address: '' })` directly in `Location.spec.ts`.

### ❌ Using `Test.createTestingModule` for unit tests

```typescript
// ❌ Bad — framework overhead in a pure unit test
const module = await Test.createTestingModule({
  providers: [CreateOfficeUseCase, { provide: OfficeRepository, useValue: mockRepo }],
}).compile();
// Adds hundreds of milliseconds to a test that doesn't need the DI container
const useCase = module.get(CreateOfficeUseCase);
```

Just use `new CreateOfficeUseCase(mockRepo)`.

### ❌ Shared mutable state between tests

```typescript
// ❌ Bad — fake shared across tests, test order matters
const repo = new OfficeRepositoryFake();

it('test one', async () => { await repo.create(/* ... */); });
it('test two', async () => {
  const all = await repo.findAll(1, 10);
  expect(all.count).toBe(0); // ← fails because test one already inserted
});
```

Always create a fresh fake in `beforeEach`.

### ❌ Mocking domain classes

```typescript
// ❌ Bad — mocking an entity
vi.mock('../../domain/entities/Office');
```

Domain classes are pure TypeScript — test them directly. Never mock them.
