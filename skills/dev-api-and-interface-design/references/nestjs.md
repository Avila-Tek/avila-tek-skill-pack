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
│   │   ├── in/                       # CQRS Commands/Queries
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
│   │   └── <Feature>RepositoryAdapter.ts   # No schema here — see below
│   └── web/
│       ├── <Feature>Controller.ts
│       └── dto/
│           ├── Create<Feature>Request.ts
│           ├── Update<Feature>Request.ts
│           └── <Feature>Response.ts
└── module.ts                         # Composition root
```

Drizzle schemas live in the **central schemas directory**, outside the module:

```
src/infrastructure/database/schemas/<feature>.schema.ts
```

Cross-domain Drizzle relations go in `src/infrastructure/database/schema.ts`.

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
  abstract findAll(): Promise<Office[]>;
  abstract findPaginated(page: number, perPage: number): Promise<PaginatedResult<Office>>;
}
```

Input ports (`ports/in/`) are needed for **every use-case** — controllers always dispatch via `CommandBus` or `QueryBus`, never injecting use-cases directly.

## CQRS: Commands and Queries

**Write operations** (POST / PUT / PATCH / DELETE) extend `Command<T>` and are dispatched via `CommandBus`:

```typescript
// application/ports/in/CreateOfficePort.ts
export class CreateOfficePort extends Command<Office> {
  constructor(
    public readonly name: string,
    public readonly phone: string,
  ) { super(); }
}
```

**Read operations** (GET) extend `Query<T>` and are dispatched via `QueryBus`:

```typescript
// application/ports/in/GetOfficeByIdPort.ts
export class GetOfficeByIdPort extends Query<Office> {
  constructor(public readonly id: number) { super(); }
}

// application/ports/in/GetOfficesPaginatedPort.ts
export class GetOfficesPaginatedPort extends Query<PaginatedResult<Office>> {
  constructor(
    public readonly page: number,
    public readonly perPage: number,
  ) { super(); }
}
```

Cross-module reads also use `QueryBus`:
```typescript
// ✓ read from another module — QueryBus
const currency = await this.queryBus.execute(new GetCurrencyByIdPort(dto.currencyId));
```

## Application: Use Cases

Write use-case — implements `ICommandHandler`:

```typescript
// application/use-cases/CreateOfficeUseCase.ts
@CommandHandler(CreateOfficePort)
export class CreateOfficeUseCase implements ICommandHandler<CreateOfficePort> {
  constructor(private readonly officeRepository: OfficeRepository) {}

  async execute(command: CreateOfficePort): Promise<Office> {
    const newOffice = NewOffice.create({ name: command.name, phone: command.phone });
    return this.officeRepository.create(newOffice);
  }
}
```

Read use-case — implements `IQueryHandler`:

```typescript
// application/use-cases/GetOfficeByIdUseCase.ts
@QueryHandler(GetOfficeByIdPort)
export class GetOfficeByIdUseCase implements IQueryHandler<GetOfficeByIdPort> {
  constructor(private readonly officeRepository: OfficeRepository) {}

  async execute(query: GetOfficeByIdPort): Promise<Office> {
    const office = await this.officeRepository.findById(query.id);
    if (!office) throw new OfficeNotFoundError();
    return office;
  }
}
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
    if (!row) return null;
    return true;
  }
}
```

**Soft deletes always:** set `isActive = false`, never hard delete. Every read query must filter `eq(table.isActive, true)`.

**Guard clauses in update/delete:** if `const [row] = []`, row is `undefined` — always check and return `null`. Adapter returns `null` — the use case checks and throws the appropriate `DomainError`.

**FK violations:** catch PostgreSQL error code `23503` and throw a `DomainError` subclass. Adapters never throw NestJS HTTP exceptions:
```typescript
const PG_FK_VIOLATION = '23503';
try {
  const [row] = await this.db.insert(offices).values({ ... }).returning();
  return rowToOffice(row);
} catch (error) {
  if (error instanceof Error && 'code' in error && error.code === PG_FK_VIOLATION) {
    throw new XxxReferencedEntityNotFoundError();
  }
  throw error;
}
```

## Infrastructure: Controller

Controllers **always** inject `CommandBus` (writes) and `QueryBus` (reads) — never use-cases directly:

```typescript
@Controller('offices')
export class OfficeController {
  constructor(
    private readonly commandBus: CommandBus,
    private readonly queryBus: QueryBus,
  ) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(@Body() body: TCreateOfficeInput): Promise<TOffice> {
    const parsed = parseOrThrow(createOfficeInput, body);
    const office = await this.commandBus.execute(new CreateOfficePort(parsed.name, parsed.phone));
    return officeFromDomain(office);
  }

  @Get()
  async findAll(): Promise<TOffice[]> {
    const offices = await this.queryBus.execute(new GetOfficesPort());
    return offices.map(officeFromDomain);
  }

  @Get('paginate')
  async findPaginated(@Query() query: TPaginateQuery): Promise<PaginatedResult<TOffice>> {
    const { page, perPage } = parseOrThrow(paginateQuerySchema, query);
    const result = await this.queryBus.execute(new GetOfficesPaginatedPort(page, perPage));
    return { ...result, data: result.data.map(officeFromDomain) };
  }

  @Get(':id')
  async findOne(@Param() params: { id: string }): Promise<TOffice> {
    const { id } = parseOrThrow(officeIdParamsSchema, params);
    const office = await this.queryBus.execute(new GetOfficeByIdPort(Number(id)));
    return officeFromDomain(office);
  }
}
```

Always use `parseOrThrow` on `@Param()` and `@Body()` — the global `ZodValidationPipe` does not validate when the type is a TypeScript `type`/`interface` (erased at runtime). Without this, an invalid param returns 500 instead of 400.

Static routes (`paginate`, `active`, etc.) must be declared **before** parameterized routes (`:id`) to avoid route shadowing.

## Infrastructure: DTOs

```typescript
// Request DTO — Zod-based
export class CreateOfficeRequest extends createZodDto(createOfficeInput) {
  // Simple field mapping: static toDto() on the DTO class
  static toDto(req: CreateOfficeRequest): CreateOfficeCommand {
    return { name: req.name, phone: req.phone };
  }
}

// Response mapper — domain → API shape (never serialize domain objects directly)
export function officeFromDomain(office: Office): TOffice {
  return { id: office.id.value, name: office.name };
}
```

**Input transformation patterns:**

- **`static toDto()`** — for simple 1:1 field mapping and renaming. Lives on the request DTO class.
- **Plain utility function** — for complex parsing (CSV/XLSX, multi-step transforms). Lives in `infrastructure/web/utils/<utilityName>.ts`. No DI, throws `BadRequestException` for malformed input.

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
  imports: [CqrsModule],
  providers: [
    { provide: OfficeRepository,  useClass: OfficeRepositoryAdapter },
    { provide: CreateOfficePort,  useClass: CreateOfficeUseCase },
    { provide: UpdateOfficePort,  useClass: UpdateOfficeUseCase },
    { provide: DeleteOfficePort,  useClass: DeleteOfficeUseCase },
    { provide: GetOfficesPort,    useClass: GetOfficesUseCase },
    { provide: GetOfficeByIdPort, useClass: GetOfficeByIdUseCase },
  ],
  controllers: [OfficeController],
})
export class OfficeModule {}
```

## Error Handling

Domain errors extend `DomainError` — the `DomainExceptionFilter` converts to the project error shape:

```typescript
// domain/errors/OfficeErrors.ts
export class OfficeNotFoundError extends DomainError {
  readonly code = 'officeNotFound';
  readonly status = 404;
  constructor() { super('Office not found'); }
}

// Add to shared/errors/dictionary.ts
404: {
  officeNotFound: { en: 'Office not found', es: 'Oficina no encontrada', severity: 'low' }
}
```

HTTP response:
```json
{ "error": { "code": "officeNotFound", "path": "/api/v1/offices/42" }, "message": "Oficina no encontrada" }
```

No try-catch needed in controllers or use cases — the filter handles it automatically.

Filter registration order in `main.ts`:
```typescript
app.useGlobalFilters(
  new AllExceptionsFilter(),     // registered first = lowest priority
  new DatabaseExceptionFilter(),
  new DomainExceptionFilter(),   // registered last = highest priority
);
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
interface CreateTaskInput {
  title: string;
  description?: string;
}

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

Value Objects already enforce this at the class level. When lightweight branded types are sufficient:

```typescript
type TaskId = string & { readonly __brand: 'TaskId' };
type UserId = string & { readonly __brand: 'UserId' };
```

For NestJS, prefer the `OfficeId`-style Value Object class over branded primitives when validation logic is needed.

## Adding a New Feature (sequence)

1. `domain/` — model entity, value objects, policies (no infrastructure)
2. `ports/out/` — abstract repository
3. `ports/in/` — one `Command<T>` per write, one `Query<T>` per read
4. `application/use-cases/` — one handler per port (`@CommandHandler` / `@QueryHandler`)
5. `src/infrastructure/database/schemas/` — Drizzle schema file
6. `infrastructure/persistence/` — repository adapter
7. `infrastructure/web/` — controller + DTOs
8. `module.ts` — bind port → adapter + use cases, import `CqrsModule`
9. `app.module.ts` — import the new module
10. If cross-domain relations: add to `src/infrastructure/database/schema.ts`

## Red Flags

- `console.log` in production code (use structured logger)
- Direct Drizzle calls in a service or use case (bypass repository)
- `any` type without explanatory comment
- Use-case injected directly into a controller — all controller calls must go through `CommandBus` / `QueryBus`
- `commandBus.execute()` for a GET (read) operation — reads must use `QueryBus`
- Hard-coded config values (use `ConfigService`)
- Missing `@UseGuards` on authenticated endpoints
- Hard delete instead of soft delete (`isActive = false`)
- Cross-domain Drizzle relations in module schemas
- Drizzle schema inside the module's `infrastructure/persistence/` — schemas belong in the central `src/infrastructure/database/schemas/` directory

## Verification Checklist

- [ ] `npm run build` passes with no type errors
- [ ] `npm test` passes, coverage ≥ 80%
- [ ] No ESLint errors (`npm run lint`)
- [ ] New endpoints have `@ApiBearerAuth()` + `@Permissions()` or explicit `@Public()`
- [ ] Drizzle schema changes have a migration (`npm run db:generate`)
- [ ] No `console.log` in changed files
- [ ] All read queries filter `eq(table.isActive, true)`
- [ ] `parseOrThrow` used on all `@Param()` and `@Body()` in controllers
- [ ] Write operations use `CommandBus`, read operations use `QueryBus`
