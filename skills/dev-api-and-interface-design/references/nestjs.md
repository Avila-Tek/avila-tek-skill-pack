# NestJS + Drizzle — API Standards Reference

## Architecture

Hexagonal Architecture (Ports & Adapters). NestJS is infrastructure — business logic is pure TypeScript with zero NestJS imports.

```
src/modules/<feature>/
├── domain/
│   ├── entities/
│   │   ├── <Feature>.ts              # Entity — private constructor, static create/restore
│   │   └── New<Feature>.ts           # Creation entity (no ID yet)
│   ├── value-objects/
│   │   └── <Feature>Id.ts            # Typed ID (prevents primitive obsession)
│   └── policies/                     # Cross-field business rule validators
├── application/
│   ├── ports/
│   │   ├── in/                       # CQRS Commands/Queries (cross-module only)
│   │   │   └── Create<Feature>Port.ts
│   │   └── out/                      # Abstract repositories (output ports)
│   │       └── <Feature>Repository.ts
│   └── use-cases/
│       ├── Create<Feature>UseCase.ts
│       ├── Update<Feature>UseCase.ts
│       ├── Delete<Feature>UseCase.ts
│       ├── Get<Feature>ByIdUseCase.ts
│       └── Get<Feature>sUseCase.ts
├── infrastructure/
│   ├── persistence/
│   │   ├── <feature>.schema.ts       # Drizzle table definition
│   │   └── <Feature>RepositoryAdapter.ts
│   └── web/
│       ├── <Feature>Controller.ts
│       └── dto/
│           ├── Create<Feature>Request.ts
│           ├── Update<Feature>Request.ts
│           └── <Feature>Response.ts
└── module.ts                         # Composition root
```

## Dependency Rule

```
Presentation → Application → Domain
Infrastructure → Ports (implements) ← Application (uses)
```

Never: domain importing NestJS decorators, domain importing Drizzle, use-case importing HTTP constructs.

## Domain: Entities and Value Objects

```typescript
// domain/entities/Office.ts — pure TypeScript, zero framework imports
export class Office {
  private constructor(private readonly props: OfficeProps) {}

  static create(props: OfficeProps): Office {
    return new Office(props);  // validate here if needed
  }

  static restore(props: OfficeProps): Office {
    return new Office(props);  // from DB — skip validation, trust stored data
  }

  get id(): OfficeId { return this.props.id; }
  get name(): string { return this.props.name; }
}

// domain/value-objects/OfficeId.ts
export class OfficeId {
  private constructor(private readonly _value: number) {}
  static create(value: number): OfficeId {
    if (!Number.isInteger(value) || value <= 0) throw new Error('OfficeId must be a positive integer');
    return new OfficeId(value);
  }
  get value(): number { return this._value; }
}
```

Policies enforce cross-field rules:
```typescript
export class ClientTypePolicy {
  static validate(clientType: string, fields: ClientFields): void {
    if (clientType === 'corporate' && !fields.rif) throw new InvalidClientError('Corporate clients require a RIF');
  }
}
```

## Ports: Abstract Repository (Output Port)

```typescript
// application/ports/out/OfficeRepository.ts
export abstract class OfficeRepository {
  abstract create(office: NewOffice): Promise<Office>;
  abstract update(id: number, dto: UpdateOfficeBody): Promise<Office | null>;
  abstract delete(id: number): Promise<boolean>;
  abstract findById(id: number): Promise<Office | null>;
  abstract findAll(page: number, perPage: number): Promise<PaginatedResult<Office>>;
}
```

CQRS input ports (`ports/in/`) only when **another module** needs to trigger this module's logic. Within the same module, controllers call use-cases directly.

## Application: Use Cases

```typescript
// application/use-cases/CreateOfficeUseCase.ts
@Injectable()
export class CreateOfficeUseCase {
  constructor(private readonly officeRepository: OfficeRepository) {}

  async execute(dto: CreateOfficeDto): Promise<Office> {
    const location = Location.create({ address: dto.location.address });
    const newOffice = NewOffice.create({ name: dto.name, location });
    return this.officeRepository.create(newOffice);
  }
}
```

Cross-module data via CommandBus — never direct cross-module imports:
```typescript
const currency = await this.commandBus.execute(new GetCurrencyByIdPort(dto.currencyId));
```

## Infrastructure: Repository Adapter

```typescript
@Injectable()
export class OfficeRepositoryAdapter implements OfficeRepository {
  constructor(@Inject(DRIZZLE_CLIENT) private readonly db: NodePgDatabase) {}

  async findById(id: number): Promise<Office | null> {
    const row = await this.db.query.offices.findFirst({
      where: and(eq(offices.id, id), eq(offices.isActive, true)),  // always filter isActive
    });
    if (!row) return null;
    return Office.restore({ id: OfficeId.create(row.id), name: row.name });
  }

  async delete(id: number): Promise<boolean> {
    const [row] = await this.db.update(offices)
      .set({ isActive: false })
      .where(and(eq(offices.id, id), eq(offices.isActive, true)))
      .returning();
    if (!row) throw new NotFoundException(`Office ${id} not found`);
    return true;
  }
}
```

**Soft deletes always:** set `isActive = false`, never hard delete. Every read query must filter `eq(table.isActive, true)`.

**Guard clauses in update/delete:** if `const [row] = []`, row is `undefined` — always check:
```typescript
if (!row) throw new NotFoundException(`Office ${id} not found`);
```

**FK violations:** catch PostgreSQL error code `23503` and throw `BadRequestException`:
```typescript
const PG_FK_VIOLATION = '23503';
try {
  const [row] = await this.db.insert(offices).values({ ... }).returning();
  return rowToOffice(row);
} catch (error) {
  if (error instanceof Error && 'code' in error && error.code === PG_FK_VIOLATION) {
    throw new BadRequestException(`Referenced entity does not exist`);
  }
  throw error;
}
```

## Infrastructure: Controller

```typescript
@Controller('offices')
export class OfficeController {
  constructor(
    private readonly createOfficeUseCase: CreateOfficeUseCase,
    private readonly getOfficesUseCase: GetOfficesUseCase,
  ) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(@Body() body: TCreateOfficeInput): Promise<TOffice> {
    const parsed = parseOrThrow(createOfficeInput, body);  // always use parseOrThrow
    const office = await this.createOfficeUseCase.execute(parsed);
    return officeFromDomain(office);
  }

  @Get(':id')
  async findOne(@Param() params: { id: string }): Promise<TOffice> {
    const { id } = parseOrThrow(officeIdParamsSchema, params);
    const office = await this.getOfficeByIdUseCase.execute(Number(id));
    return officeFromDomain(office);
  }
}
```

Always use `parseOrThrow` on `@Param()` and `@Body()` — the global `ZodValidationPipe` does not validate when the type is a TypeScript `type`/`interface` (erased at runtime). Without this, an invalid param returns 500 instead of 400.

## Infrastructure: DTOs

```typescript
// Request DTO — Zod-based
export class CreateOfficeRequest extends createZodDto(createOfficeInput) {}

// Response mapper — domain → API shape (never serialize domain objects directly)
export function officeFromDomain(office: Office): TOffice {
  return { id: office.id.value, name: office.name };
}
```

**`@repo/schemas` only in `infrastructure/web/`** — forbidden in domain, application, or persistence layers.

## Zod Schema Rules

```typescript
// ✓ correct — trim before min(1)
name: z.string().trim().min(1, 'Name is required'),
// ✗ wrong — "   " passes min(1) but becomes "" after domain trimming
name: z.string().min(1, 'Name is required'),
```

Enum values inline in Drizzle schema — no typed array spreads:
```typescript
export const statusEnum = pgEnum('status', ['active', 'inactive']);  // ✓
// pgEnum('status', [...myArray])  // ✗ causes type errors
```

## Module Wiring

```typescript
@Module({
  providers: [
    { provide: OfficeRepository, useClass: OfficeRepositoryAdapter },  // bind port → adapter
    CreateOfficeUseCase,
    UpdateOfficeUseCase,
    DeleteOfficeUseCase,
    GetOfficeByIdUseCase,
    GetOfficesUseCase,
  ],
  controllers: [OfficeController],
})
export class OfficeModule {}
```

## Error Handling

Domain errors extend `DomainError` — the `DomainExceptionFilter` converts to RFC 7807:

```typescript
// domain/errors/OfficeErrors.ts
export class OfficeNotFoundError extends DomainError {
  readonly code = 'officeNotFound';
  readonly status = 404;
  constructor(id: number) { super(`Office ${id} not found`); }
}

// Add to shared/errors/dictionary.ts
404: {
  officeNotFound: { en: 'Office not found', es: 'Oficina no encontrada', severity: 'low' }
}
```

HTTP response (RFC 7807):
```json
{ "type": "officeNotFound", "title": "Office not found", "status": 404, "detail": "404-officeNotFound" }
```

No try-catch needed in controllers or use cases — the filter handles it automatically.

Filter registration order in `main.ts`:
```typescript
app.useGlobalFilters(new DatabaseExceptionFilter(), new DomainExceptionFilter()); // DomainExceptionFilter second
```

## Cross-Domain Relations

Drizzle relations between modules belong in `src/infrastructure/database/schema.ts` — never in individual module schemas:

```typescript
// ✓ src/infrastructure/database/schema.ts
export const agentRelations = relations(agents, ({ one }) => ({
  office: one(offices, { fields: [agents.officeId], references: [offices.id] }),
}));
```

## TypeScript Interface Patterns

### Discriminated Unions for Status Types

Use discriminated unions for domain states that carry different data depending on the variant. This makes invalid states unrepresentable:

```typescript
// domain/entities/task-status.ts
type TaskStatus =
  | { type: 'pending' }
  | { type: 'in_progress'; assignee: string; startedAt: Date }
  | { type: 'completed'; completedAt: Date; completedBy: string }
  | { type: 'cancelled'; reason: string; cancelledAt: Date };

// Exhaustive switch — TypeScript enforces all cases are handled
function getStatusLabel(status: TaskStatus): string {
  switch (status.type) {
    case 'pending':     return 'Pending';
    case 'in_progress': return `In progress (${status.assignee})`;
    case 'completed':   return `Done on ${status.completedAt.toISOString()}`;
    case 'cancelled':   return `Cancelled: ${status.reason}`;
  }
}
```

Prefer discriminated unions over boolean flags or string enums when variants have different associated data.

### Input/Output Type Separation

Separate what callers provide from what the system returns. Never use the same type for both:

```typescript
// Input: what the caller provides (no server-generated fields)
interface CreateTaskInput {
  title: string;
  description?: string;
}

// Output: what the system returns (includes server-generated fields)
interface Task {
  id: string;
  title: string;
  description: string | null;
  createdAt: Date;
  updatedAt: Date;
  createdBy: string;
}
```

In NestJS: `Create<Feature>Request.ts` is input; `<Feature>Response.ts` is output. Domain entities never leave the application boundary — always map through a response DTO.

### Branded Types for Domain IDs

Value Objects (see Domain section) already enforce this at the class level. When lightweight branded types are sufficient:

```typescript
type TaskId = string & { readonly __brand: 'TaskId' };
type UserId = string & { readonly __brand: 'UserId' };

// TypeScript prevents accidentally passing a UserId where a TaskId is expected
function getTask(id: TaskId): Promise<Task> { ... }
```

For NestJS, prefer the `OfficeId`-style Value Object class over branded primitives when validation logic is needed.

## Adding a New Feature (sequence)

1. `domain/` — model entity, value objects, policies (no infrastructure)
2. `ports/out/` — abstract repository
3. `application/use-cases/` — orchestrate domain + ports
4. `infrastructure/persistence/` — Drizzle schema + repository adapter
5. `infrastructure/web/` — controller + DTOs
6. `module.ts` — bind port → adapter, register use cases
7. `app.module.ts` — import the new module
8. If cross-domain relations: add to `src/infrastructure/database/schema.ts`

## Red Flags

- `console.log` in production code (use structured logger)
- Direct Drizzle calls in a service or use case (bypass repository)
- `any` type without explanatory comment
- Cross-module imports not going through CommandBus/QueryBus
- Hard-coded config values (use `ConfigService`)
- Missing `@UseGuards` on authenticated endpoints
- Hard delete instead of soft delete (`isActive = false`)
- Cross-domain Drizzle relations in module schemas

## Verification Checklist

- [ ] `npm run build` passes with no type errors
- [ ] `npm test` passes, coverage ≥ 80%
- [ ] No ESLint errors (`npm run lint`)
- [ ] New endpoints have `@UseGuards` or explicit `@Public()` decorator
- [ ] Drizzle schema changes have a migration (`npm run db:generate`)
- [ ] No `console.log` in changed files
- [ ] All read queries filter `eq(table.isActive, true)`
- [ ] `parseOrThrow` used on all `@Param()` and `@Body()` in controllers
