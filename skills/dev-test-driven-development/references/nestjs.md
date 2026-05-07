# NestJS — Testing Reference

## Framework
Vitest (`npm test`) + Supertest for E2E. Test files co-located as `*.spec.ts` next to source. E2E tests in `test/*.e2e-spec.ts`.

## Test Pyramid

```
test/
  *.e2e-spec.ts               ← E2E: full HTTP stack (Supertest)

src/modules/<feature>/
  domain/entities/*.spec.ts   ← Unit: pure TypeScript, no framework
  application/use-cases/*.spec.ts  ← Unit: no DI container
  infrastructure/persistence/*.spec.ts  ← Integration: real DB
  infrastructure/web/*.spec.ts     ← Integration: NestJS wiring
```

**Rule:** test domain invariants with unit tests. Test HTTP wiring with integration. Never test business rules through HTTP.

## 1. Domain Unit Tests

No mocks, no `Test.createTestingModule()`. Instantiate directly:

```typescript
import { describe, expect, it } from 'vitest';
import { Location } from './Location';

describe('Location', () => {
  it('should create a valid location', () => {
    const location = Location.create({ address: 'Av. Principal 123' });
    expect(location.address).toBe('Av. Principal 123');
  });

  it('should throw when address is empty', () => {
    expect(() => Location.create({ address: '' })).toThrow(InvalidLocationError);
  });
});
```

## 2. Use-Case Unit Tests

Plain `new` + `vi.fn()` mocks. No Spring context:

```typescript
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
    const mockOffice = Office.restore({ /* ... */ });
    vi.mocked(officeRepository.create).mockResolvedValue(mockOffice);

    // CQRS: pass a Port instance — not a raw object
    const command = new CreateOfficePort('Main Office', '+58 212 000 0000', 'John Doe', { address: 'Av. Principal 123' });
    const result = await useCase.execute(command);

    expect(officeRepository.create).toHaveBeenCalledOnce();
    expect(result).toBe(mockOffice);
  });
});
```

**CQRS note:** Use-cases receive a `Port` instance (the command object), not a plain DTO. Pass `new CreateOfficePort(...)` in tests.

## 3. In-Memory Fakes

For complex use-cases, prefer an in-memory fake over `vi.fn()`:

```typescript
export class OfficeRepositoryFake extends OfficeRepository {
  private readonly store = new Map<number, Office>();
  private nextId = 1;

  async create(newOffice: NewOffice): Promise<Office> {
    const office = Office.restore({ id: OfficeId.create(this.nextId++), ...newOffice });
    this.store.set(office.id.value, office);
    return office;
  }
  async findById(id: number): Promise<Office | null> { return this.store.get(id) ?? null; }
  async delete(id: number): Promise<boolean> { return this.store.delete(id); }
  // ...
}
```

Always create a fresh fake in `beforeEach`. Never share mutable state between tests.

## 4. NestJS Wiring Integration Tests

Use `Test.createTestingModule()` only to verify DI resolves correctly. Import `CqrsModule`:

```typescript
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

  it('should resolve CreateOfficeUseCase from the container', () => {
    expect(module.get(CreateOfficeUseCase)).toBeDefined();
  });
});
```

For controller tests: mock `CommandBus`, not individual use-cases:

```typescript
const commandBus = { execute: vi.fn() };

beforeEach(async () => {
  const module = await Test.createTestingModule({
    controllers: [OfficeController],
    providers: [{ provide: CommandBus, useValue: commandBus }],
  }).compile();
  controller = module.get(OfficeController);
});
```

## 5. DB Integration Tests

Test repository adapters against a real DB via test helpers:

```typescript
describe('OfficeRepositoryAdapter', () => {
  let repo: OfficeRepositoryAdapter;

  beforeEach(async () => {
    await testDb.reset();
    repo = new OfficeRepositoryAdapter(testDb.client);
  });

  it('should not return soft-deleted offices', async () => {
    const office = await repo.create(newOffice);
    await repo.delete(office.id.value);
    expect(await repo.findById(office.id.value)).toBeNull();
  });
});
```

## 6. E2E Tests

Full HTTP stack with Supertest. Use a test database:

```typescript
describe('POST /offices', () => {
  it('should return 201 with office data on valid input', async () => {
    const response = await request(app.getHttpServer())
      .post('/offices')
      .send({ name: 'Main Office', phone: '+58 212 000 0000', representative: 'John Doe', location: { address: 'Av. Principal 123' } });
    expect(response.status).toBe(201);
  });

  it('should return 400 on missing required fields', async () => {
    const response = await request(app.getHttpServer()).post('/offices').send({ name: 'Incomplete' });
    expect(response.status).toBe(400);
  });
});
```

## What to Mock vs Test for Real

| Always mock / fake | Always test for real |
|---|---|
| Repository adapters in use-case tests | Domain entities and value objects |
| External HTTP clients | Domain policies |
| `CommandBus` / `QueryBus` in controller tests | Repository adapters (integration DB test) |
| Time (`vi.useFakeTimers`) and randomness | Zod schema validation |
| Auth guards in controller unit tests | Full auth flow in E2E tests |

## Commands

```bash
npm test                  # run all unit + integration tests
npm run test:coverage     # with coverage report
```

## Anti-Patterns

- `Test.createTestingModule()` in a unit test — adds ~hundreds of ms for no reason; use `new`
- Testing domain logic via E2E/HTTP — 100x slower and sensitive to unrelated changes
- Shared mutable fakes across tests — always create fresh in `beforeEach`
- Mocking domain classes — they're pure TypeScript, test them directly
- Raw object literal in `execute()` — pass the `Port` instance
