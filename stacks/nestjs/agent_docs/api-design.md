# API Design — NestJS + Drizzle

NestJS-specific patterns for API contracts, request validation, error handling, controllers, and cross-module communication. Apply these when the active stack is NestJS.

See also: `conventions.md` (naming), `architecture.md` (hexagonal layers), `error-handling.md` (DomainError), `auth-permissions.md` (guards).

---

## Shared Schema Layer (`@repo/schemas`)

The contract between frontend and backend lives in `packages/schemas/`. This is the single source of truth:

- **Input schemas** — Zod objects defining what the API accepts (`createOfficeInput`)
- **Response types** — TypeScript types defining what the API returns (`TOffice`)
- **Shared DTOs** — Types used by both apps (`TCreateOfficeInput`)

```
packages/schemas/src/
├── office.ts       → officeDTO, TOffice, TCreateOfficeInput
├── agent.ts        → agentDTO, TAgent, TCreateAgentInput
└── index.ts        → re-exports
```

Rules:
- Define schemas **once** in `@repo/schemas`, never duplicate in apps
- Use `z.infer<>` to derive types — never hand-write duplicate interfaces
- Backend imports schemas to create `createZodDto` request classes
- Frontend imports types for services and transforms

```typescript
// packages/schemas/src/office.ts
export const officeDTO = {
  createOfficeInput: z.object({
    name: z.string().min(1),
    phone: z.string(),
    representative: z.string(),
    location: z.object({
      address: z.string(),
      coordinates: z.string().optional(),
    }),
    postalMail: z.string().optional(),
  }),
};

export type TCreateOfficeInput = z.infer<typeof officeDTO.createOfficeInput>;
export type TOffice = { id: number; name: string; phone: string; /* ... */ };
```

---

## Request DTOs (`createZodDto`)

Backend wraps shared schemas with `createZodDto` for automatic NestJS validation (global Zod pipe validates automatically — no manual parsing in controllers):

```typescript
// apps/api/src/modules/office/infrastructure/web/dto/CreateOfficeRequest.ts
import { createZodDto } from '@anatine/zod-nestjs';
import { officeDTO } from '@repo/schemas';

export class CreateOfficeRequest extends createZodDto(officeDTO.createOfficeInput) {}
```

Use `@ZodApiBody` / `@ZodApiResponse` to derive Swagger schemas from Zod — never hand-write OpenAPI schemas.

---

## Error Handling

Domain errors are `DomainError` subclasses. The `DomainExceptionFilter` translates them to RFC 7807 automatically — controllers never catch or rethrow:

```typescript
// modules/office/domain/errors/OfficeErrors.ts
export class OfficeDuplicateNameError extends DomainError {
  readonly code = 'officeDuplicateName';  // camelCase, unique across app
  readonly status = 409;

  constructor(name: string) {
    super(`Office "${name}" already exists`);
  }
}

// Use-case throws — no try-catch needed in controller:
if (existing) throw new OfficeDuplicateNameError(dto.name);

// DomainExceptionFilter produces RFC 7807 automatically:
// { "type": "officeDuplicateName", "title": "...", "status": 409, "detail": "..." }
```

**Never use `new HttpException(...)` directly** — always use `DomainError` subclasses. See `error-handling.md` for full patterns.

---

## Controller CRUD Pattern

Standard CRUD with NestJS decorators. Controllers are thin adapters — no business logic:

```typescript
@Controller('offices')
export class OfficeController {
  constructor(
    private readonly createOfficeUseCase: CreateOfficeUseCase,
    private readonly getOfficesUseCase: GetOfficesUseCase,
    private readonly getOfficeByIdUseCase: GetOfficeByIdUseCase,
    private readonly updateOfficeUseCase: UpdateOfficeUseCase,
    private readonly deleteOfficeUseCase: DeleteOfficeUseCase,
  ) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create an office' })
  @ApiResponse({ status: 201, description: 'Office created successfully' })
  @ApiResponse({ status: 409, description: 'Office name already exists' })
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

  @Patch(':id')
  async update(@Param('id') id: number, @Body() dto: UpdateOfficeRequest): Promise<TOffice> {
    const office = await this.updateOfficeUseCase.execute(id, dto);
    return officeFromDomain(office);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async remove(@Param('id') id: number): Promise<void> {
    await this.deleteOfficeUseCase.execute(id);
  }
}
```

**HTTP status codes by operation:**

| Operation | Status | Decorator |
|-----------|--------|-----------|
| POST (create) | 201 Created | `@HttpCode(HttpStatus.CREATED)` |
| GET (read) | 200 OK | default |
| PATCH (update) | 200 OK | default |
| DELETE (soft) | 204 No Content | `@HttpCode(HttpStatus.NO_CONTENT)` |

Every controller method **must** have `@ApiOperation` and at least one `@ApiResponse`. See `code-standard.md`.

---

## Response Mappers

Never expose domain objects directly in API responses. Always map through a response function:

```typescript
// infrastructure/web/dto/OfficeResponse.ts
import type { Office } from '../../../domain/entities/Office';
import type { TOffice } from '@repo/schemas';

export function officeFromDomain(office: Office): TOffice {
  return {
    id: office.id.value,
    name: office.name,
    phone: office.phone,
    representative: office.representative,
    postalMail: office.postalMail,
    location: { address: office.location.address },
  };
}
```

---

## Pagination

Always paginate list endpoints using `PaginatedResult<T>`:

```typescript
// Request
GET /api/offices?page=1&pageSize=20&sortBy=createdAt&sortOrder=desc

// Response shape
{
  "data": [...],
  "pagination": { "page": 1, "pageSize": 20, "totalItems": 142, "totalPages": 8 }
}
```

---

## Cross-Module Communication

Modules communicate via CQRS bus — never import directly across module boundaries:

```typescript
// Within same module: inject use-case directly
constructor(private readonly getOfficeUseCase: GetOfficeByIdUseCase) {}

// Across modules: use CommandBus / QueryBus
constructor(private readonly commandBus: CommandBus) {}

async execute(dto: CreateAgentDto): Promise<Agent> {
  const office = await this.commandBus.execute(new GetOfficeByIdPort(dto.officeId));
  // ...
}
```

---

## Soft Deletes

Always use soft deletes with an `isActive` column — never hard delete:

```typescript
// Schema
isActive: boolean('is_active').default(true).notNull(),

// Repository reads always filter by isActive
where: and(eq(offices.id, id), eq(offices.isActive, true)),

// Delete = set isActive to false
await this.db.update(offices).set({ isActive: false }).where(eq(offices.id, id));
```

---

## Typed IDs

Use typed IDs to prevent primitive obsession:

```typescript
export class OfficeId {
  private constructor(private readonly _value: number) {}

  static create(value: number): OfficeId {
    if (!Number.isInteger(value) || value <= 0) throw new Error('OfficeId must be a positive integer');
    return new OfficeId(value);
  }

  get value(): number { return this._value; }
  equals(other: OfficeId): boolean { return this._value === other._value; }
}
```

---

## Naming Conventions

See `code-standard.md` for full conventions. API-specific names:

| Artifact | Convention | Example |
|----------|-----------|---------|
| Controller | PascalCase + `Controller` | `OfficeController` |
| Request DTO | PascalCase + `Request` | `CreateOfficeRequest` |
| Response mapper fn | camelCase + `FromDomain` | `officeFromDomain` |
| Response type (from schemas) | `T` + PascalCase | `TOffice`, `TOfficesResponse` |
| Domain error | PascalCase + `Error` | `OfficeDuplicateNameError` |

---

## Verification Checklist

Before completing any API endpoint:

- [ ] Schema defined in `@repo/schemas` with Zod — types inferred, not duplicated
- [ ] Request DTO uses `createZodDto` (not a manual interface)
- [ ] Controller is a thin adapter — no business logic, no try-catch
- [ ] Error handling uses `DomainError` subclass — no `new HttpException(...)`
- [ ] `@ApiOperation` and `@ApiResponse` decorators present
- [ ] Auth guard applied (`@UseGuards(JwtAuthGuard)` or `@Public()`) — see `auth-permissions.md`
- [ ] Response goes through mapper function (`entityFromDomain()`) — no raw domain object exposed
- [ ] List endpoints use `PaginatedResult<T>`
- [ ] Cross-module access goes through CQRS bus — no direct module imports
- [ ] Delete operations use soft delete (`isActive = false`), not hard delete
