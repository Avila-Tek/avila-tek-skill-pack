---
description: Backend Hexagonal Architecture — NestJS modules, ports & adapters, dependency direction
globs: "apps/api/src/**/*.ts"
alwaysApply: false
---

# 03 · Architecture

We use **Hexagonal Architecture** (Ports & Adapters). The goal is a NestJS application where business logic is completely isolated from infrastructure — databases, HTTP, queues, and third-party APIs. The domain must be expressible in plain TypeScript with no NestJS imports, no Drizzle imports, and no framework decorators. This makes every business rule independently testable, independently replaceable, and independently understandable.

NestJS is excellent infrastructure for this pattern. Its module system becomes the composition root, its DI container wires ports to adapters, and its decorator system cleanly marks the boundaries between zones. But the framework will not enforce these boundaries for you — that discipline is entirely up to the developer. This guide is the enforcement mechanism.

---

## The Four Zones

```
┌──────────────────────────────────────────────────────────────┐
│                    Presentation (HTTP)                        │
│   @Controller() — parses request, calls use-cases directly   │
│   or CommandBus for cross-module. Maps response.             │
│   Guards, Pipes, Interceptors live here.                     │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                   Application                          │  │
│  │   Use-cases — orchestrate domain services, manage      │  │
│  │   transactions, emit events. No HTTP, no DB imports.   │  │
│  │                                                        │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │                   Domain                         │  │  │
│  │  │   Pure business logic. Entities, value objects,  │  │  │
│  │  │   policies, domain errors. Zero external         │  │  │
│  │  │   dependencies.                                  │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  │                                                        │  │
│  │  ┌──────────────────────────────────────────────────┐  │  │
│  │  │                    Ports                         │  │  │
│  │  │   Abstract classes & interfaces.                 │  │  │
│  │  │   OfficeRepository, CreateOfficePort. The        │  │  │
│  │  │   contracts between zones.                       │  │  │
│  │  └──────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐  │
│  │                  Infrastructure                        │  │
│  │   Drizzle repositories, better-auth adapter, external  │  │
│  │   API clients. Implements ports, knows the domain,     │  │
│  │   domain does not know about infrastructure.           │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

---

## The Dependency Rule

**Dependencies always point inward.** Presentation depends on Application. Application depends on Domain and Ports. Infrastructure implements Ports. Nothing in the inner circles knows about the outer circles.

```
Presentation → Application → Domain
Infrastructure → Ports (implements) ← Application (uses)
```

Never:

```
Domain → Infrastructure     ❌ (domain importing Drizzle)
Domain → NestJS decorators  ❌ (domain importing @nestjs/*)
Application → Controllers   ❌ (use-case importing HTTP constructs)
```

---

## NestJS Component Mapping

| NestJS Construct | Hexagonal Role | Zone |
|---|---|---|
| Plain TypeScript class | Entity / Value Object / Policy | Domain |
| `@CommandHandler()` use-case | Application Use-Case | Application |
| Abstract class | Output Port | Ports |
| `Command<T>` subclass | Input Port (CQRS, cross-module only) | Ports |
| `@Controller()` | Input Adapter | Presentation |
| `@Injectable()` repository | Output Adapter | Infrastructure |
| better-auth instance | Input Adapter | Infrastructure |
| `@Module()` | Composition Root | All |

---

## Directory Mapping

```
src/modules/<feature>/
├── domain/
│   ├── entities/
│   │   ├── <Feature>.ts                    # Entity — encapsulates business invariants
│   │   └── New<Feature>.ts                 # Creation entity (without ID)
│   ├── value-objects/
│   │   └── <Feature>Id.ts                  # Typed ID to prevent primitive obsession
│   └── policies/                           # Business rule validators
│       └── <Feature>Policy.ts
├── application/
│   ├── ports/
│   │   ├── in/                             # CQRS Commands (cross-module input ports only)
│   │   │   ├── Create<Feature>Port.ts
│   │   │   ├── Update<Feature>Port.ts
│   │   │   ├── Delete<Feature>Port.ts
│   │   │   ├── Get<Feature>ByIdPort.ts
│   │   │   └── Get<Feature>sPort.ts
│   │   └── out/                            # Repository abstracts (output ports)
│   │       └── <Feature>Repository.ts
│   └── use-cases/
│       ├── Create<Feature>UseCase.ts
│       ├── Update<Feature>UseCase.ts
│       ├── Delete<Feature>UseCase.ts
│       ├── Get<Feature>ByIdUseCase.ts
│       └── Get<Feature>sUseCase.ts
├── infrastructure/
│   ├── persistence/
│   │   ├── <feature>.schema.ts             # Drizzle table definition
│   │   └── <Feature>RepositoryAdapter.ts   # Output adapter (Drizzle)
│   ├── web/
│   │   ├── <Feature>Controller.ts          # Input adapter (HTTP)
│   │   └── dto/
│   │       ├── Create<Feature>Request.ts
│   │       ├── Update<Feature>Request.ts
│   │       └── <Feature>Response.ts
│   └── services/                           # External integrations (optional)
└── module.ts                               # Composition root
```

---

## Domain Zone

The domain contains entities with business behavior, value objects with validation, and policies that enforce cross-field business rules. Zero NestJS imports. Zero Drizzle imports.

### Entity

```typescript
// ✅ Good — src/modules/office/domain/entities/Office.ts
// Pure TypeScript. No framework decorators.
export class Office {
  private constructor(private readonly props: OfficeProps) {}

  static create(props: OfficeProps): Office {
    return new Office(props);
  }

  // For restoring from DB — skips validation, trusts stored data
  static restore(props: OfficeProps): Office {
    return new Office(props);
  }

  get id(): OfficeId { return this.props.id; }
  get name(): string { return this.props.name; }
  get location(): Location { return this.props.location; }
}
```

### Value Object

```typescript
// ✅ Good — src/modules/office/domain/value-objects/Location.ts
export class Location {
  private constructor(private readonly props: LocationProps) {}

  static create(props: LocationProps): Location {
    if (!props.address || props.address.trim().length === 0) {
      throw new InvalidLocationError('Location address is required');
    }
    return new Location(props);
  }

  static restore(props: LocationProps): Location {
    return new Location(props);
  }

  equals(other: Location): boolean {
    return this.props.address === other.props.address;
  }
}
```

### Typed ID

```typescript
// ✅ Good — src/modules/office/domain/value-objects/OfficeId.ts
export class OfficeId {
  private constructor(private readonly _value: number) {}

  static create(value: number): OfficeId {
    if (!Number.isInteger(value) || value <= 0) {
      throw new Error('OfficeId must be a positive integer');
    }
    return new OfficeId(value);
  }

  get value(): number { return this._value; }
  equals(other: OfficeId): boolean { return this._value === other._value; }
}
```

### Domain Policies

Policies are standalone validator classes that enforce business rules too complex for a single entity or value object. They live in `domain/policies/`.

```typescript
// ✅ Good — src/modules/client/domain/policies/ClientTypePolicy.ts
export class ClientTypePolicy {
  static validate(clientType: string, fields: ClientFields): void {
    if (clientType === 'corporate' && !fields.rif) {
      throw new InvalidClientError('Corporate clients require a RIF');
    }
  }
}
```

Use policies when:

- Validation spans multiple fields or entities.
- The rule is complex enough to deserve its own test suite.
- The same rule applies in multiple use-cases.

### Shared Domain Types

Types used across multiple modules live in `src/shared/domain/`.

```typescript
// ✅ Good — src/shared/domain/pagination.ts
export interface PageInfo {
  currentPage: number;
  perPage: number;
  itemCount: number;
  pageCount: number;
  hasPreviousPage: boolean;
  hasNextPage: boolean;
}

export interface PaginatedResult<T> {
  items: T[];
  count: number;
  pageInfo: PageInfo;
}
```

Every list use-case and repository port returning collections must use `PaginatedResult<T>`.

**Key conventions:**

- Private constructor, static `create` (with validation) and `restore` (from DB, no validation) factories.
- `New<Feature>` companion class for creation (no ID yet).
- Value objects are immutable and implement `equals`.

---

## Ports Zone

### Output Port (Repository)

Abstract classes that define contracts for persistence. The application layer depends on these, never on concrete adapters.

```typescript
// ✅ Good — src/modules/office/application/ports/out/OfficeRepository.ts
export abstract class OfficeRepository {
  abstract create(office: NewOffice): Promise<Office>;
  abstract update(id: number, dto: UpdateOfficeBody): Promise<Office | null>;
  abstract delete(id: number): Promise<boolean>;
  abstract findById(id: number): Promise<Office | null>;
  abstract findAll(page: number, perPage: number): Promise<PaginatedResult<Office>>;
}
```

### Input Port (CQRS Command — cross-module only)

Commands extend `Command<T>` and are only needed when another module needs to trigger this module's logic. Within the same module, the controller calls the use-case directly.

```typescript
// ✅ Good — src/modules/office/application/ports/in/GetOfficeByIdPort.ts
// Only exists because other modules need to fetch office data
export class GetOfficeByIdPort extends Command<Office | null> {
  constructor(public readonly id: number) {
    super();
  }
}
```

---

## Application Zone

Use-cases coordinate domain + ports. They do not contain business rules — they sequence operations.

```typescript
// ✅ Good — src/modules/office/application/use-cases/CreateOfficeUseCase.ts
@Injectable()
export class CreateOfficeUseCase {
  constructor(private readonly officeRepository: OfficeRepository) {}

  async execute(dto: CreateOfficeDto): Promise<Office> {
    const location = Location.create({
      address: dto.location.address,
      coordinates: dto.location.coordinates,
    });

    const newOffice = NewOffice.create({
      name: dto.name,
      postalMail: dto.postalMail ?? null,
      phone: dto.phone,
      representative: dto.representative,
      location,
    });

    return this.officeRepository.create(newOffice);
  }
}
```

When a use-case needs data from **another module**, it dispatches via the bus instead of importing directly:

```typescript
// ✅ Good — use-case crossing a module boundary
@Injectable()
export class CreateAgentUseCase {
  constructor(
    private readonly agentRepository: AgentRepository,
    private readonly commandBus: CommandBus,
  ) {}

  async execute(dto: CreateAgentDto): Promise<Agent> {
    // Needs currency from the Currency module — use the bus
    const currency = await this.commandBus.execute(
      new GetCurrencyByIdPort(dto.currencyId),
    );

    const newAgent = NewAgent.create({ ...dto, currency });
    return this.agentRepository.create(newAgent);
  }
}
```

---

## Infrastructure Zone

Adapters implement ports. They know about the domain, but the domain knows nothing about them.

### Repository Adapter (DB)

```typescript
// ✅ Good — src/modules/office/infrastructure/persistence/OfficeRepositoryAdapter.ts
@Injectable()
export class OfficeRepositoryAdapter implements OfficeRepository {
  constructor(@Inject(DRIZZLE_CLIENT) private readonly db: NodePgDatabase) {}

  async create(office: NewOffice): Promise<Office> {
    const [inserted] = await this.db
      .insert(offices)
      .values({
        name: office.name,
        postalMail: office.postalMail,
        phone: office.phone,
        representative: office.representative,
        locationId: office.locationId,
      })
      .returning();

    return this.rowToOffice(inserted);
  }

  private rowToOffice(row: typeof offices.$inferSelect): Office {
    return Office.restore({
      id: OfficeId.create(row.id),
      name: row.name,
      locationId: row.locationId,
    });
  }
}
```

### Soft Deletes

All entities that support deletion use **soft deletes** via an `isActive` column. Hard deletes are not used.

```typescript
// Schema
isActive: boolean('is_active').default(true).notNull(),

// Repository adapter — always filter by isActive on reads
async findById(id: number): Promise<Office | null> {
  const row = await this.db.query.offices.findFirst({
    where: and(eq(offices.id, id), eq(offices.isActive, true)),
  });
  if (!row) return null;
  return this.rowToOffice(row);
}

// Delete = set isActive to false
async delete(id: number): Promise<boolean> {
  const [row] = await this.db
    .update(offices)
    .set({ isActive: false })
    .where(and(eq(offices.id, id), eq(offices.isActive, true)))
    .returning();
  return !!row;
}
```

Every repository adapter must include `eq(table.isActive, true)` in all read queries.

### Schema Aggregation & Cross-Domain Relations

Each module defines its own Drizzle schema in `infrastructure/persistence/<feature>.schema.ts`. However, when a schema has **relations with another domain**, the relation declaration must live in the central aggregation file:

```
src/infrastructure/database/schema.ts
```

This file imports all module schemas and defines cross-domain Drizzle relations. Individual modules must not import schemas from other modules directly.

```typescript
// ✅ Good — src/infrastructure/database/schema.ts
import { agents } from '../../modules/agent/infrastructure/persistence/agent.schema';
import { offices } from '../../modules/office/infrastructure/persistence/office.schema';

export const agentRelations = relations(agents, ({ one }) => ({
  office: one(offices, {
    fields: [agents.officeId],
    references: [offices.id],
  }),
}));
```

### Controller (HTTP)

Controllers within the same module inject use-cases directly — no bus needed.

```typescript
// ✅ Good — src/modules/office/infrastructure/web/OfficeController.ts
@Controller('offices')
export class OfficeController {
  constructor(
    private readonly createOfficeUseCase: CreateOfficeUseCase,
    private readonly getOfficesUseCase: GetOfficesUseCase,
    private readonly getOfficeByIdUseCase: GetOfficeByIdUseCase,
  ) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(@Body() dto: CreateOfficeRequest): Promise<TOffice> {
    const office = await this.createOfficeUseCase.execute(dto);
    return officeFromDomain(office);
  }

  @Get()
  async findAll(@Query() query: GetOfficesRequest): Promise<PaginatedResult<TOffice>> {
    return this.getOfficesUseCase.execute(query);
  }

  @Get(':id')
  async findOne(@Param('id') id: number): Promise<TOffice> {
    const office = await this.getOfficeByIdUseCase.execute(id);
    return officeFromDomain(office);
  }
}
```

### DTO & Response Mapping

```typescript
// Request DTO — Zod-based validation
export class CreateOfficeRequest extends createZodDto(createOfficeInput) {
  static toDto(req: TCreateOfficeInput): CreateOfficeCommand {
    return { name: req.name, phone: req.phone, /* ... */ };
  }
}

// Response mapper — domain → API shape
export function officeFromDomain(office: Office): TOffice {
  return {
    id: office.id.value,
    name: office.name,
    location: { address: office.location.address },
  };
}
```

---

## Module Wiring (Composition Root)

The `@Module()` is where ports are bound to adapters. This is the only place that knows about both abstractions and implementations.

```typescript
// ✅ Good — src/modules/office/module.ts
@Module({
  providers: [
    { provide: OfficeRepository, useClass: OfficeRepositoryAdapter },
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

---

## Cross-Module Communication (CQRS)

> **Note:** The current cross-module communication approach uses `@nestjs/cqrs` CommandBus/QueryBus. **This pattern is provisional and will be replaced in the future.** When it changes, this section will be updated. For now, follow this convention.

CQRS is **only required when a module needs to trigger logic or fetch data from another module**. Within a single module, controllers and use-cases inject their dependencies directly.

| Scenario | Pattern |
|---|---|
| Controller calls its own module's use-case | Direct injection |
| Use-case needs data from another module | `CommandBus` / `QueryBus` |
| Guard needs user data from UsersModule | `QueryBus` via shared query |

```typescript
// ❌ No bus needed — same module
@Controller('offices')
export class OfficeController {
  constructor(private readonly createOffice: CreateOfficeUseCase) {}
}

// ✅ Bus required — crossing module boundary
@Injectable()
export class CreateAgentUseCase {
  constructor(private readonly commandBus: CommandBus) {}

  async execute(dto: CreateAgentDto): Promise<Agent> {
    const currency = await this.commandBus.execute(
      new GetCurrencyByIdPort(dto.currencyId),
    );
    // ...
  }
}
```

Modules must **never** import each other's internal classes directly:

```typescript
// ❌ Bad — direct import across module boundary
import { CurrencyRepositoryAdapter } from '../currency/infrastructure/persistence/CurrencyRepositoryAdapter';
```

### Shared Queries

// Validate

Queries needed by multiple modules live in `src/modules/shared/queries/`. These are dispatched via the QueryBus and handled by the owning module.

```typescript
// src/modules/shared/queries/GetUserByIdQuery.ts
export class GetUserByIdQuery {
  constructor(public readonly userId: string) {}
}

// Dispatched from any module:
const user = await this.queryBus.execute(new GetUserByIdQuery(userId));
```

Keep shared queries minimal — if only one module dispatches a query, it belongs in that module, not in shared.

---

## Adding a New Feature

When adding a new feature, always follow this sequence:

1. **Start in `domain/`** — model the concept, write the entity, value objects, policies, and business rules. No infrastructure.
2. **Define ports** — add the abstract repository to `ports/out/`. Only add `ports/in/` CQRS commands if other modules will need to call into this feature.
3. **Write the use-cases** — orchestrate domain + ports in `application/use-cases/`.
4. **Implement adapters** — make the DB repository adapter and HTTP controller satisfy those contracts.
5. **Wire in the module** — bind abstract ports to concrete adapters in `module.ts`.
6. **Register the module** — import it in `app.module.ts`.
7. **Add cross-domain relations** — if the new schema relates to other domains, declare the relations in `src/infrastructure/database/schema.ts`.

This order ensures infrastructure never drives domain design.

---

## Anti-Patterns

### ❌ Business logic in the controller

```typescript
// ❌ Bad — controller contains domain decisions
@Post()
async create(@Body() dto: CreateOfficeDto) {
  if (!dto.location.address) throw new BadRequestException('Address required');
  const [office] = await this.db.insert(offices).values(dto).returning();
  return office;
}
```

Validation belongs in value objects (`Location.create`). Persistence belongs in repository adapters. The controller's only job is to translate HTTP into use-case calls.

### ❌ Domain importing NestJS or Drizzle

```typescript
// ❌ Bad — domain entity with framework coupling
import { Injectable } from '@nestjs/common';  // ← domain zone contaminated
import { offices } from '../schema';           // ← DB in domain

@Injectable()
export class OfficeService {
  constructor(@Inject(DRIZZLE_CLIENT) private readonly db: NodePgDatabase) {}
}
```

### ❌ Use-case depending on concrete adapter

```typescript
// ❌ Bad — use-case depends on concrete repository
@Injectable()
export class CreateOfficeUseCase {
  constructor(private readonly repo: OfficeRepositoryAdapter) {} // ← concrete type
  // Cannot swap for an in-memory implementation in tests
}
```

### ❌ Using the bus within the same module

```typescript
// ❌ Bad — dispatching a command to your own module's handler
@Controller('offices')
export class OfficeController {
  constructor(private readonly commandBus: CommandBus) {}

  @Post()
  async create(@Body() dto: CreateOfficeRequest) {
    return this.commandBus.execute(new CreateOfficePort(dto)); // ← unnecessary indirection
  }
}
```

Inject the use-case directly. The bus is only for crossing module boundaries.

### ❌ Direct cross-module imports

```typescript
// ❌ Bad — module A reaches into module B's internals
import { CurrencyRepositoryAdapter } from '../currency/infrastructure/persistence/CurrencyRepositoryAdapter';
```

Use the CQRS bus or shared queries instead.

### ❌ Hard deletes

```typescript
// ❌ Bad
async delete(id: number): Promise<void> {
  await this.db.delete(offices).where(eq(offices.id, id));
}
```

Always soft delete by setting `isActive` to `false`.

### ❌ Cross-domain relations in module schemas

```typescript
// ❌ Bad — agent.schema.ts declaring relations to another module's table
import { offices } from '../../office/infrastructure/persistence/office.schema';

export const agentRelations = relations(agents, ({ one }) => ({
  office: one(offices, { ... }),
}));
```

Cross-domain relations belong in `src/infrastructure/database/schema.ts`.
