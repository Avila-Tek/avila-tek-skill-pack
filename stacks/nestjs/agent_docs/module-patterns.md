# Migration Guide — API (NestJS + Hexagonal + CQRS)

Reference context for migrating modules from the `.old-aren` project (MongoDB/Express)
to the new stack (NestJS + PostgreSQL + Hexagonal Architecture).

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
│   │   ├── <module>.schema.ts            ← Drizzle schema
│   │   └── <Module>RepositoryAdapter.ts
│   └── web/
│       ├── dto/
│       │   └── <Module>Response.ts
│       └── <Module>Controller.ts
└── module.ts
```

---

## Architecture rules (non-negotiable)

### 1. `@repo/schemas` only in the web layer

- **Allowed:** `infrastructure/web/` (controller and DTOs)
- **Forbidden:** domain, application (ports/in, ports/out, use-cases), infrastructure/persistence

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

**Input port (Command):**
```typescript
// application/ports/in/CreateXxxPort.ts
import { Command } from '@nestjs/cqrs';
import { type Xxx } from '../../../domain/Xxx';

export interface CreateXxxBody {
  name: string;
  // ...fields
}

export class CreateXxxPort extends Command<Xxx> {
  constructor(
    public readonly name: string,
    // ...fields
  ) {
    super();
  }
}
```

**Input port (Query):**
```typescript
// application/ports/in/GetXxxPort.ts
import { Query } from '@nestjs/cqrs';
import { type Xxx } from '../../../domain/Xxx';

export interface GetXxxBody {
  id: string;
}

export class GetXxxPort extends Query<Xxx> {
  constructor(public readonly id: string) {
    super();
  }
}
```

**Use Case (Command):**
```typescript
// application/use-cases/CreateXxxUseCase.ts
@CommandHandler(CreateXxxPort)
export class CreateXxxUseCase implements ICommandHandler<CreateXxxPort> {
  constructor(private readonly repository: XxxRepository) {}

  async execute(command: CreateXxxBody): Promise<Xxx> {
    const entity = Xxx.create({ ... });
    return this.repository.create(entity);
  }
}
```

**Use Case (Query):**
```typescript
@QueryHandler(GetXxxPort)
export class GetXxxUseCase implements IQueryHandler<GetXxxPort> {
  constructor(private readonly repository: XxxRepository) {}

  async execute(query: GetXxxBody): Promise<Xxx> {
    const entity = await this.repository.findById(query.id);
    if (!entity) throw new NotFoundException(`Xxx ${query.id} not found`);
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
  abstract findById(id: string): Promise<Xxx | null>;
  abstract update(id: string, entity: Xxx): Promise<Xxx>; // id always explicit
  abstract delete(id: string): Promise<Xxx>;              // soft delete, returns entity
}
```

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
  if (!row) throw new NotFoundException(`Xxx ${id} not found`);
  return rowToEntity(row);
}
```

### 6. Drizzle schema — inline enums

**Do not** use typed array spreads. Define values inline:

```typescript
// infrastructure/persistence/xxx.schema.ts
export const xxxKindEnum = pgEnum('xxx_kind', ['value_a', 'value_b']);
// NO: pgEnum('xxx_kind', [...myArray])  ← causes type errors
```

### 7. Registration in module.ts

```typescript
providers: [
  { provide: XxxRepository, useClass: XxxRepositoryAdapter }, // output port
  CreateXxxUseCase,    // registered directly, without provide/useClass
  UpdateXxxUseCase,
  DeleteXxxUseCase,
  GetXxxsUseCase,
  GetXxxUseCase,
],
```

### 8. Controller only uses CommandBus / QueryBus

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

### 10. Controller — authorization (TODO)

Create, Update and Delete must be private routes (admin only). The correct mechanism
in NestJS is a **Guard**, not middleware. Since `JwtAuthGuard` and
`RolesGuard` do not yet exist, leave the following comment on each protected endpoint:

```typescript
// TODO: protect with @UseGuards(JwtAuthGuard, RolesGuard) @Roles('admin') once auth guards are implemented
@Post()
async create(...) { ... }
```

`GET` endpoints are left public (no comment).

### 11. RepositoryAdapter — guard clauses and FK violations

**Race condition in update/delete:** if another process deletes the record between the
use case's `findById` and the adapter's `UPDATE`, Drizzle returns `[]` and
`const [row] = []` assigns `undefined`, crashing in `rowToEntity`. Always add:

```typescript
async update(id: string, entity: Xxx): Promise<Xxx> {
  const [row] = await this.db.update(...).returning();
  if (!row) throw new NotFoundException(`Xxx ${id} not found`);
  return rowToEntity(row);
}

async delete(id: string): Promise<Xxx> {
  const [row] = await this.db.update(...).set({ isActive: false }).returning();
  if (!row) throw new NotFoundException(`Xxx ${id} not found`);
  return rowToEntity(row);
}
```

**FK violation:** if the module has a FK to another table, catch the PostgreSQL error in `create()`, `update()` **and in pivot table inserts** (assign) to return a 400 instead of a 500:

```typescript
// TODO: move to shared/infrastructure/pgErrors.ts once more modules need it
const PG_FK_VIOLATION = '23503';

async create(entity: Xxx): Promise<Xxx> {
  try {
    const [row] = await this.db.insert(...).returning();
    return rowToEntity(row);
  } catch (error) {
    if (error instanceof Error && 'code' in error && error.code === PG_FK_VIOLATION) {
      throw new BadRequestException(`ReferencedEntity ${entity.referencedId} does not exist`);
    }
    throw error;
  }
}
```

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

---

## Database migration

Due to a WSL2 bug with the `node-postgres` driver, `drizzle-kit migrate` hangs.
**Workaround:** apply the SQL directly via Docker:

```bash
# 1. Generate the migration
npx drizzle-kit generate

# 2. Apply the SQL (replace with the generated file name)
docker exec -i continental-postgres-1 psql -U postgres -d continental \
  < ~/continental/apps/api/drizzle/0000_xxxx.sql
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
| GetOne | Finds by id / `NotFoundException` if not found |
| Update | Updates and returns / `NotFoundException` if not found |
| Delete | Soft-delete and returns with `isActive: false` / `NotFoundException` if not found |

**Note:** use valid values according to domain enums in mocks
(e.g.: `'individual_policy_summary'`, not `'pdf'`).

### 14. M:N relationships — assign/unassign

For modules with pivot tables (e.g.: `macrolines_lines`, `lines_sublines`):

- `assign` inserts into the pivot table with `.onConflictDoNothing()` and try/catch for `PG_FK_VIOLATION`
- `unassign` does DELETE on the pivot table
- Assign/unassign use cases **do not cross-module import** — if the FK fails, the adapter returns 400
- After assign/unassign, the use case calls `findByIdWithXxx()` and verifies the result with null check (not `result!`)

```typescript
// ✓ CORRECT — assign with try/catch
async assignSubline(lineId: string, sublineId: string): Promise<void> {
  try {
    await this.db.insert(linesSublines).values({ lineId, sublineId }).onConflictDoNothing();
  } catch (error) {
    if (error instanceof Error && 'code' in error && error.code === PG_FK_VIOLATION) {
      throw new BadRequestException(`Subline ${sublineId} does not exist`);
    }
    throw error;
  }
}

// ✓ CORRECT — do not use result! in use case
const result = await this.repository.findByIdWithLines(command.macrolineId);
if (!result) throw new NotFoundException(`Macroline ${command.macrolineId} not found`);
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

---

## Migration checklist

- [ ] Read the model in `.old-aren/models/<Model>.js`
- [ ] Create `domain/<Entity>.ts` with `create()`, `restore()`, `update()`
- [ ] Create necessary value objects with local enums
- [ ] Create 5 input ports (`Create`, `Update`, `Delete`, `GetOne`, `GetAll`)
- [ ] Create abstract output repository
- [ ] Create 5 use cases with `@CommandHandler` / `@QueryHandler`
- [ ] Create Drizzle schema (inline enums, `is_active` column)
- [ ] Create `RepositoryAdapter` with soft delete in `delete()`
- [ ] Add guard clauses (`if (!row) throw NotFoundException`) in adapter's `update()` and `delete()`
- [ ] If FK: catch error `23503` in adapter's `create()` and `update()` → `BadRequestException`
- [ ] Add schema to `drizzle.config.ts` if applicable
- [ ] Create response DTO and Controller
- [ ] Use `parseOrThrow` in params and body of all controller handlers
- [ ] Add auth guard TODO on `POST`, `PATCH` and `DELETE`
- [ ] Register in `module.ts` and in `app.module.ts`
- [ ] Generate and apply DB migration
- [ ] Write unit tests (minimum 8 tests)
- [ ] `npx turbo typecheck` without errors
- [ ] `npm run format-and-lint:fix` without configuration errors

---

## Reference module

See full implementation in:
- `apps/api/src/modules/line/` — most recent module, includes **all** correct patterns (rules 9–13)
- `apps/api/src/modules/documentTemplate/` — reference for value objects and enums
