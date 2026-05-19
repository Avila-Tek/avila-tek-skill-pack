# Module Patterns — API (NestJS + Hexagonal + CQRS)

Reference guide for implementing modules following the NestJS + PostgreSQL + Hexagonal Architecture stack.

---

## Target stack

- **NestJS** with **CQRS** (`@nestjs/cqrs`)
- **Hexagonal Architecture** (Ports & Adapters)
- **Drizzle ORM** for PostgreSQL
- **Vitest** for unit testing
- **Biome** for linting/formatting

---

## Module folder structure

```
src/modules/<moduleName>/
├── domain/
│   ├── <Entity>.ts
│   └── value-objects/
│       └── <ValueObject>.ts
├── application/
│   ├── ports/
│   │   ├── in/
│   │   │   └── <Action><Module>Port.ts   ← Command or Query
│   │   └── out/
│   │       └── <Module>Repository.ts     ← abstract class
│   └── use-cases/
│       └── <Action><Module>UseCase.ts
├── infrastructure/
│   ├── persistence/
│   │   └── <Module>RepositoryAdapter.ts  ← NO schema here
│   └── web/
│       ├── dto/
│       │   └── <Module>Response.ts
│       └── <Module>Controller.ts
└── module.ts
```

Drizzle schemas live in the **central schemas directory**, outside the module:

```
src/infrastructure/database/schemas/<moduleName>.schema.ts
```

The repository adapter imports from there. Cross-domain relations are declared in
`src/infrastructure/database/schema.ts`.

---

## Architecture rules (non-negotiable)

### 1. `@repo/schemas` — shared contract between backend and frontend

`packages/schemas` is the single source of truth for the API contract. Both the backend
and the frontend consume it.

**What goes in `@repo/schemas`:**
- Zod validation schemas for request bodies (`createXxxInput`, `updateXxxInput`)
- Response type aliases prefixed with `T` (`TXxx`, `TXxxsResponse`)
- Shared enum schemas (`z.enum([...])`) derived from domain enums

**Where `@repo/schemas` is allowed in the API:**
- `infrastructure/web/` — controllers and request/response DTOs

**Forbidden in:**
- domain, application (ports/in, ports/out, use-cases), infrastructure/persistence

```typescript
// packages/schemas/src/xxx/xxx.schema.ts
export const xxxSchema = z.object({
  id: z.number().int().positive(),
  name: z.string(),
  // ...
});
export type TXxx = z.infer<typeof xxxSchema>;

export const createXxxInput = z.object({
  name: z.string().trim().min(1, 'Name is required'),
  // ...
});
export type TCreateXxxInput = z.infer<typeof createXxxInput>;
```

```typescript
// infrastructure/web/dto/XxxResponse.ts
import type { TXxx } from '@repo/schemas';
import type { Xxx } from '../../../domain/entities/Xxx';

export function xxxFromDomain(xxx: Xxx): TXxx {
  return { id: xxx.id.value, name: xxx.name };
}
```

### 2. Domain defines its own enums

Value objects define their enums locally, **without importing** `@repo/schemas`:

```typescript
// domain/value-objects/MyValueObject.ts
export enum MyValueObjectEnum {
  VALUE_A = 'value_a',
  VALUE_B = 'value_b',
}

export class MyValueObject {
  private constructor(private readonly _value: MyValueObjectEnum) {}

  static restore(value: string): MyValueObject {
    const valid = Object.values(MyValueObjectEnum) as string[];
    if (!valid.includes(value)) {
      throw new Error(`Invalid MyValueObject: ${value}`);
    }
    return new MyValueObject(value as MyValueObjectEnum);
  }

  getValue(): MyValueObjectEnum {
    return this._value;
  }
}
```

### 3. CQRS pattern — Ports named as `XxxPort`

> **Rule:** Write operations use `Command<T>` + `@CommandHandler` (dispatched via `CommandBus`).
> Read operations use `Query<T>` + `@QueryHandler` (dispatched via `QueryBus`).

**Input port (any operation):**
```typescript
// application/ports/in/CreateXxxPort.ts
import { Command } from '@nestjs/cqrs';
import { type Xxx } from '../../../domain/Xxx';

export class CreateXxxPort extends Command<Xxx> {
  constructor(
    public readonly name: string,
    // ...fields
  ) {
    super();
  }
}

// application/ports/in/GetXxxPort.ts
export class GetXxxPort extends Query<Xxx> {
  constructor(public readonly id: number) {
    super();
  }
}

// application/ports/in/ListXxxsPort.ts
export class ListXxxsPort extends Query<PaginatedResult<Xxx>> {
  constructor(
    public readonly page: number,
    public readonly perPage: number,
  ) {
    super();
  }
}
```

**Use Case (command):**
```typescript
// application/use-cases/CreateXxxUseCase.ts
@CommandHandler(CreateXxxPort)
export class CreateXxxUseCase implements ICommandHandler<CreateXxxPort> {
  constructor(private readonly repository: XxxRepository) {}

  async execute(command: CreateXxxPort): Promise<Xxx> {
    const entity = NewXxx.create({ ... });
    return this.repository.create(entity);
  }
}
```

**Use Case (query):**
```typescript
// application/use-cases/GetXxxUseCase.ts
@QueryHandler(GetXxxPort)
export class GetXxxUseCase implements IQueryHandler<GetXxxPort> {
  constructor(private readonly repository: XxxRepository) {}

  async execute(command: GetXxxPort): Promise<Xxx> {
    const entity = await this.repository.findById(command.id);
    // ✓ throw a DomainError, not NestJS NotFoundException
    if (!entity) throw new XxxNotFoundError();
    return entity;
  }
}
```

### 4. Abstract repository (output port)

```typescript
// application/ports/out/XxxRepository.ts
export abstract class XxxRepository {
  abstract create(entity: Xxx): Promise<Xxx>;
  abstract findAll(): Promise<Xxx[]>;
  abstract findPaginated(page: number, perPage: number, ...filters: unknown[]): Promise<PaginatedResult<Xxx>>;
  abstract findById(id: string): Promise<Xxx | null>;
  abstract update(id: string, entity: Xxx): Promise<Xxx>; // id always explicit
  abstract delete(id: string): Promise<Xxx>;              // soft delete, returns entity
}
```

| Method | Returns | When to use |
|---|---|---|
| `findAll()` | `Promise<Xxx[]>` | Full unbounded list; lightweight; always filters `isActive = true`; requires safe `orderBy` |
| `findPaginated(page, perPage, ...)` | `Promise<PaginatedResult<Xxx>>` | Paginated results with search/sort filters |

### 5. Soft delete and `isActive`

- Column `is_active: boolean` in the table (Drizzle field: `isActive`)
- The `DELETE` endpoint does `UPDATE SET is_active = false` and **returns the entity** (not void/204)
- `isActive` is **always internal and mandatory** — never exposed as a client query param
- In the adapter, `buildWhereClause()` hardcodes `eq(table.isActive, true)` — does not use `filters.isActive`
- Port-out filters include `isActive: boolean` for contract consistency, but the adapter ignores it (the controller always passes `true`)
- All adapter queries filter `isActive = true`: `findAll`, `findById`, `update`, `delete`

```typescript
// ✓ CORRECT — buildWhereClause hardcodes isActive
function buildWhereClause(filters: XxxFilters) {
  return and(
    eq(table.isActive, true),                         // always hardcoded
    filters.otherFilter ? eq(table.field, filters.otherFilter) : undefined,
  );
}

// ✓ CORRECT — findById also filters isActive
async findById(id: string): Promise<Xxx | null> {
  const result = await this.db.select().from(table)
    .where(and(eq(table.id, id), eq(table.isActive, true)));
  return result[0] ?? null;
}

// ✓ CORRECT — update and delete also filter isActive (race condition)
async delete(id: string): Promise<Xxx> {
  const [row] = await this.db.update(table)
    .set({ isActive: false })
    .where(and(eq(table.id, id), eq(table.isActive, true)))
    .returning();
  return row ? rowToEntity(row) : null;
}
```

### 6. Drizzle schema — inline enums

**Do not** use typed array spreads. Define values inline:

```typescript
// src/infrastructure/database/schemas/xxx.schema.ts
export const xxxKindEnum = pgEnum('xxx_kind', ['value_a', 'value_b']);
// NO: pgEnum('xxx_kind', [...myArray])  ← causes type errors
```

### 7. Registration in module.ts

> **Rule:** both the repository and **all** use cases are registered with
> `{ provide: Port, useClass: UseCase }`. Do not register use cases directly
> (without provide/useClass).

```typescript
providers: [
  { provide: XxxRepository,   useClass: XxxRepositoryAdapter },
  { provide: CreateXxxPort,   useClass: CreateXxxUseCase },
  { provide: UpdateXxxPort,   useClass: UpdateXxxUseCase },
  { provide: DeleteXxxPort,   useClass: DeleteXxxUseCase },
  { provide: ListXxxsPort,    useClass: ListXxxsUseCase },
  { provide: GetXxxPort,      useClass: GetXxxUseCase },
],
```

### 8. Controller injects CommandBus and QueryBus

Write operations are dispatched via `CommandBus`, read operations via `QueryBus`.

```typescript
constructor(
  private readonly commandBus: CommandBus,
  private readonly queryBus: QueryBus,
) {}
```

### 9. Controller — validation with `parseOrThrow`

The global `ZodValidationPipe` **does not validate** `@Param()` or `@Body()` when the type is a
TypeScript `type` or `interface` (erased at runtime). Always use `parseOrThrow`
explicitly in the handler:

```typescript
import { parseOrThrow } from '../../../../shared/utils/parseOrThrow';

// params with UUID
async findOne(@Param() params: { id: string }): Promise<TXxx> {
  const { id } = parseOrThrow(xxxIdParamsSchema, params);
  // ...
}

// body in POST
async create(@Body() body: TCreateXxxInput): Promise<TXxx> {
  const parsed = parseOrThrow(createXxxInput, body);
  // use parsed, not body
}

// body in PATCH
async update(@Param() params: { id: string }, @Body() body: TUpdateXxxInput): Promise<TXxx> {
  const { id } = parseOrThrow(xxxIdParamsSchema, params);
  const parsed = parseOrThrow(updateXxxInput, body);
  // ...
}
```

Without this, an invalid UUID in params returns **500** instead of **400**,
and a body with `null` can reach the domain and cause a `TypeError`.

### 10. Controller — authorization

Every controller requires `@ApiBearerAuth()` at the class level. For each endpoint:

- **Protected** — add `@Permissions('<module>:<action>')`. The guard enforces that the caller holds that permission.
- **Public** — add `@Public()`. This exempts the endpoint from authentication entirely; `@Permissions` is not needed and must not be added.

See `agent_docs/backend/auth-permissions.md` for the full naming convention and seed registration.

```typescript
@ApiBearerAuth()
@ApiTags('Xxxx')        // display name in Swagger — PascalCase or Title Case
@Controller('xxxx')     // HTTP route path — lowercase kebab-case
export class XxxController {

  // Protected endpoints — require a valid token + the listed permission
  @Post()
  @Permissions('xxx:create')
  async create(...) { ... }

  @Get()
  @Permissions('xxx:read')
  async listAll(...) { ... }

  @Get('paginate')
  @Permissions('xxx:read')
  async findPaginated(...) { ... }

  @Get(':id')
  @Permissions('xxx:read')
  async findOne(...) { ... }

  @Put(':id')
  @Permissions('xxx:update')
  async update(...) { ... }

  @Delete(':id')
  @Permissions('xxx:delete')
  async delete(...) { ... }

  // Public endpoint — no token required, no @Permissions
  @Public()
  @Get('health')
  async health(...) { ... }
}
```

If a specific endpoint must be public (no auth), add `@Public()` on that method — do not remove `@ApiBearerAuth()` from the class.

See `auth-permissions.md` for full details on permission naming and seed registration.

### 11. RepositoryAdapter — database errors

#### General rule

Infrastructure errors (PG error codes) must **always be caught in the adapter**
(infrastructure layer), never in use cases (application layer).
The adapter converts them to `DomainError` subclasses before propagating.
The global `DomainErrorFilter` maps them to HTTP responses.

> Do **not** throw `NotFoundException` / `BadRequestException` from NestJS in the adapter
> or use cases — use only `DomainError` subclasses.

#### Race condition in update/delete

If another process deletes the record between the use case's `findById` and the
adapter's `UPDATE`, Drizzle returns `[]` and `rowToEntity(undefined)` crashes.
The adapter returns `null` (does not throw) when the row is not found:

```typescript
async update(id: number, data: XxxUpdateData): Promise<Xxx | null> {
  const [row] = await this.db.update(...)
    .where(and(eq(table.id, id), eq(table.isActive, true)))
    .returning();
  return row ? rowToEntity(row) : null;
}
```

The use case must verify the result and throw a `DomainError`:

```typescript
// use case — verify after update
const updated = await this.repository.update(command.id, command.body);
if (!updated) throw new XxxNotFoundError();
return updated;
```

#### FK violation (`23503`)

If the module has a FK to another table, catch the PG error in `create()`, `update()`
and in pivot table inserts:

```typescript
const PG_FK_VIOLATION = '23503';

async create(entity: NewXxx): Promise<Xxx> {
  try {
    const [row] = await this.db.insert(table).values({ ... }).returning();
    return rowToEntity(row);
  } catch (error) {
    if (error instanceof Error && 'code' in error && error.code === PG_FK_VIOLATION) {
      throw new XxxReferencedEntityNotFoundError();
    }
    throw error;
  }
}
```

> Do **not** throw `BadRequestException` from the adapter — throw a `DomainError` subclass.
> The same applies to M:N pivot table inserts (assign operations).

#### Unique violation (`23505`)

If the module has a unique constraint (single field or composite), catch the PG error
in `create()` and `update()` and convert it to a `DomainError`:

```typescript
const PG_UNIQUE_VIOLATION = '23505';

async create(entity: NewXxx): Promise<Xxx> {
  try {
    const [row] = await this.db.insert(table).values({ ... }).returning();
    return rowToEntity(row);
  } catch (error) {
    if (error instanceof Error && 'code' in error && error.code === PG_UNIQUE_VIOLATION) {
      throw new XxxAlreadyExistsError();
    }
    throw error;
  }
}
```

> **Note:** Drizzle exposes `error.code` directly on the thrown error — there is no need
> to access `error.cause`. The pattern `error instanceof Error && 'code' in error` is sufficient.

### 12. Zod schema — strings with `.trim().min(1)`

Required `string` fields must include `.trim()` before `.min(1)` to reject
whitespace-only strings (`"   "`) that would pass `.min(1)` but become empty after
domain trimming:

```typescript
// ✓ correct
name: z.string().trim().min(1, 'Name is required'),

// ✗ incorrect — "   " passes Zod but the domain saves it as ""
name: z.string().min(1, 'Name is required'),
```

### 13. Domain — null-safe `update()`

In the `update()` method use `!= null` (covers both `null` and `undefined`) instead of
`!== undefined` to avoid crashing if an unexpected `null` arrives:

```typescript
update(props: Partial<CreateXxxProps>): Xxx {
  return new Xxx({
    ...this.props,
    name: props.name != null ? props.name.trim() : this.props.name,
    // ...
  });
}
```

### 14. M:N relationships — assign/unassign

For modules with pivot tables (e.g.: `macrolines_lines`, `lines_sublines`):

- `assign` inserts into the pivot table with `.onConflictDoNothing()` and try/catch for `PG_FK_VIOLATION`
- `unassign` does DELETE on the pivot table
- Assign/unassign use cases **do not cross-module import** — if the FK fails, the adapter throws a `DomainError` subclass
- After assign/unassign, the use case calls `findByIdWithXxx()` and verifies the result with null check (not `result!`)

```typescript
// ✓ CORRECT — assign with try/catch, throws DomainError
async assignSubline(lineId: string, sublineId: string): Promise<void> {
  try {
    await this.db.insert(linesSublines).values({ lineId, sublineId }).onConflictDoNothing();
  } catch (error) {
    if (error instanceof Error && 'code' in error && error.code === PG_FK_VIOLATION) {
      throw new SublineNotFoundError();
    }
    throw error;
  }
}

// ✓ CORRECT — do not use result! in use case
const result = await this.repository.findByIdWithLines(command.macrolineId);
if (!result) throw new MacrolineNotFoundError();
return result;
```

### 15. Relational queries — filter soft-deleted in M:N relations

When using Drizzle's relational API (`db.query.X.findFirst({ with: { pivot: { with: { entity } } } })`), soft-deleted related entities are NOT filtered automatically. Filter in post-process:

```typescript
// ✓ CORRECT — filter isActive in the map
return {
  line: rowToLine(result),
  sublines: result.linesSublines
    .filter((ls) => ls.subline.isActive)
    .map((ls) => rowToSubline(ls.subline)),
};
```

### 16. Controller — GET endpoints and route ordering

Every module exposes two GET list endpoints:
- `GET /` — full list, calls `findAll()` on repository, returns `Entity[]`
- `GET /paginate` — paginated, calls use-case with page/perPage/search/sort params

**Route declaration order is critical.** In NestJS, routes are matched in declaration order. A static segment like `paginate` will be captured by a preceding `:id` param route, causing a runtime error (e.g., `ParseIntPipe` receiving the string `"paginate"`).

Always declare routes in this order:

```typescript
@Get()             // 1. static — list all
@Get('paginate')   // 2. static — paginated
@Get(':id')        // 3. dynamic — always last among GETs
```

The same rule applies to **POST** routes: declare static segments before parameterized ones.
A route like `POST /import/opening-balance` must come before `POST /:id`, otherwise NestJS
matches `/:id` with the value `"import"` and the static route is never reached.

```typescript
@Post()                          // 1. resource creation — no segment
@Post('import/opening-balance')  // 2. static action — must come before @Post(':id')
@Post(':id/post')                // 3. parameterized action — :id won't shadow multi-segment statics
@Post(':id/reverse')             // 4. parameterized action
```

### 17. In-port / out-port coupling

In-ports (`ports/in/`) must never import from out-ports (`ports/out/`). If a shared filter or options type is needed by both, declare it in a neutral file at `application/<module>.types.ts` and import it from there.

```typescript
// ✅ application/xxx.types.ts
export interface XxxFilters {
  isActive: boolean;
  search?: string;
}

// ✅ ports/in/GetXxxPaginatedPort.ts
import type { XxxFilters } from '../../xxx.types';

// ✅ ports/out/XxxRepository.ts
import type { XxxFilters } from '../../xxx.types';
```

### 18. Cross-module repository injection

When a use case in module A needs to read data owned by module B (e.g., `ImportOpeningBalanceCsvUseCase` in `journalEntry` resolving account codes from `accountingAccount`):

**1 — Source module exports its repository abstract class:**

```typescript
// modules/accountingAccount/module.ts
@Module({
  providers: [
    { provide: AccountingAccountRepository, useClass: AccountingAccountRepositoryAdapter },
  ],
  exports: [AccountingAccountRepository],  // ← export the abstract token, never the concrete adapter
})
export class AccountingAccountModule {}
```

**2 — Consumer module imports the source module:**

```typescript
// modules/journalEntry/module.ts
@Module({
  imports: [AccountingAccountModule, AccountingPeriodModule],  // ← add here
  providers: [...],
})
export class JournalEntryModule {}
```

**3 — Consumer use case injects the foreign repository:**

```typescript
constructor(
  @Inject(AccountingAccountRepository)
  private readonly accountingAccountRepo: AccountingAccountRepository,
) {}
```

Rules:
- Only export the **abstract class** token — never expose the concrete adapter directly.
- Never import a concrete `RepositoryAdapter` from another module; always inject via the abstract token.
- The consumer module must list the source module in `imports`; NestJS resolves the provider through the module graph.

### 19. File upload endpoints

When an endpoint accepts a file (CSV, image, PDF) via `multipart/form-data`, use `FileInterceptor` from `@nestjs/platform-express`:

```typescript
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiBody, ApiConsumes } from '@nestjs/swagger';
import {
  BadRequestException,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';

@Post('import/csv')
@Permissions('module:create')
@HttpCode(HttpStatus.CREATED)
@ApiConsumes('multipart/form-data')
@ApiBody({
  schema: {
    type: 'object',
    properties: { file: { type: 'string', format: 'binary' } },
  },
})
@UseInterceptors(FileInterceptor('file', { limits: { fileSize: 1024 * 1024 } }))
async importCsv(
  @UploadedFile() file: Express.Multer.File | undefined,
  @CurrentUser() user: AuthenticatedUser,
): Promise<TEntity> {
  if (!file) throw new BadRequestException('No file was uploaded');
  const content = file.buffer.toString('utf-8');
  const rows = parseCsvEntity(content, file.originalname); // utility in utils/
  const result = await this.commandBus.execute(new ImportCsvPort(rows, file.originalname, user.id));
  return entityFromDomain(result);
}
```

Rules:
- Parse the file in a dedicated utility at `infrastructure/web/utils/parse<Format><Entity>.ts` — never inline parsing in the controller.
- The utility is a plain function (no `@Injectable()`); throw `BadRequestException` for format errors.
- Limit file size via `limits.fileSize` in the interceptor options.
- `@ApiConsumes('multipart/form-data')` is required for Swagger to render the file upload UI.
- Declare this route **before** any `@Post(':id/...')` routes (see Rule 16).

---

## Database migration

Due to a WSL2 bug with the `node-postgres` driver, `drizzle-kit migrate` hangs.
**Workaround:** apply the SQL directly via Docker:

```bash
# 1. Generate the migration
npx drizzle-kit generate

# 2. Apply the SQL (replace with the generated file name)
docker exec -i <project>-postgres-1 psql -U postgres -d <dbname> \
  < apps/api/drizzle/0000_xxxx.sql
```

The `apps/api/drizzle/` folder is in `.gitignore` (regenerate with `npx drizzle-kit generate`).

---

## Testing pattern (Vitest)

File at: `src/test/<moduleName>/<moduleName>.test.ts`

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { NotFoundException } from '@nestjs/common';
import { CreateXxxUseCase } from '../../modules/xxx/application/use-cases/CreateXxxUseCase';

function mockXxx(overrides: Record<string, unknown> = {}) {
  return {
    id: { getValue: () => 'id1' },
    name: 'Test',
    isActive: true,
    update: vi.fn().mockReturnThis(),
    ...overrides,
  };
}

describe('CreateXxxUseCase', () => {
  let repository: { create: ReturnType<typeof vi.fn> };
  let useCase: CreateXxxUseCase;

  beforeEach(() => {
    repository = { create: vi.fn() };
    useCase = new CreateXxxUseCase(repository as any);
  });

  it('Create: saves and returns the new entity', async () => {
    const entity = mockXxx();
    repository.create.mockResolvedValue(entity);

    const result = await useCase.execute({ name: 'Test', ... });

    expect(repository.create).toHaveBeenCalledTimes(1);
    expect(result).toBe(entity);
  });
});
```

**Minimum scenarios to cover per use case:**

| Use Case | Scenarios |
|---|---|
| Create | Happy path (creates and returns) |
| GetAll | Returns list |
| GetOne | Finds by id / `XxxNotFoundError` if not found |
| Update | Updates and returns / `XxxNotFoundError` if not found |
| Delete | Soft-delete returns the deactivated entity / `XxxNotFoundError` if not found |

**Note:** use valid values according to domain enums in mocks
(e.g.: `'individual_policy_summary'`, not `'pdf'`).

---

## Implementation checklist

- [ ] Create `domain/<Entity>.ts` with `create()`, `restore()`, `update()`
- [ ] Create necessary value objects with local enums
- [ ] Create 5 input ports (`Create`, `Update`, `Delete`, `GetOne`, `GetAll`)
- [ ] Create abstract output repository
- [ ] Create 5 use cases: write ports use `Command<T>` + `@CommandHandler`, read ports use `Query<T>` + `@QueryHandler`
- [ ] Create Drizzle schema in `src/infrastructure/database/schemas/<moduleName>.schema.ts` (inline enums, `is_active` column) and export it from `src/infrastructure/database/schema.ts`
- [ ] Add `TXxx`, `TXxxsResponse`, `createXxxInput`, `updateXxxInput` to `packages/schemas/src/<moduleName>/`
- [ ] Create `RepositoryAdapter` with soft delete in `delete()`
- [ ] Adapter returns `null` from `update()` when row is not found (does not throw); use case checks and throws `XxxNotFoundError`
- [ ] If unique constraint: catch `23505` in adapter's `create()` / `update()` → `XxxAlreadyExistsError` (DomainError)
- [ ] If FK: catch `23503` in adapter's `create()` / `update()` → `XxxReferencedEntityNotFoundError` (DomainError)
- [ ] Add schema to `drizzle.config.ts` if applicable
- [ ] Create response DTO and Controller (inject both `CommandBus` and `QueryBus`)
- [ ] Use `parseOrThrow` in params and body of all controller handlers
- [ ] Register in `module.ts` with `{ provide: Port, useClass: UseCase }` for ALL use cases and `app.module.ts`
- [ ] Add `@ApiBearerAuth()` at class level and `@Permissions('<module>:<action>')` on every endpoint (see Rule 10)
- [ ] Declare `GET /` before `GET /paginate` before `GET /:id` in the controller
- [ ] Register in `module.ts` and in `app.module.ts`
- [ ] Generate and apply DB migration
- [ ] Write unit tests (minimum 8 tests)
- [ ] `npx turbo typecheck` without errors
- [ ] `npm run format-and-lint:fix` without configuration errors

---

## Reference module

See full implementation in:
- `apps/api/src/modules/bankAccount/` — reference for rules 7, 8, 11: `{ provide: Port, useClass: UseCase }` for all use cases, `CommandBus` + `QueryBus` controller, PG errors caught in the adapter as `DomainError`
- `apps/api/src/modules/currency/` — reference for pagination, soft delete, and value objects
- `apps/api/src/modules/line/` — reference for M:N relationships (assign/unassign)
