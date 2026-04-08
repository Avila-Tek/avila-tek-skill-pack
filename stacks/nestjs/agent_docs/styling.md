---
description: Backend code formatting — Biome config, DTO response rules, no domain objects in HTTP
globs: "apps/api/biome.json, apps/api/src/**/dto/*Response.ts"
alwaysApply: false
---

# Code Style & API Response Styling — apps/api

Conventions for code formatting and how HTTP responses are shaped and mapped from domain data.

---

## Code formatting — Biome

All formatting is handled by **Biome**. Never format code manually or configure a separate formatter (no Prettier).

```bash
# Format all files
npm run format

# Lint + auto-fix
npm run lint
```

**Active rules from `biome.json`:**

| Rule | Value |
|---|---|
| Indent style | Spaces |
| Indent width | 2 |
| Line width | 80 |
| Line ending | LF |
| Quotes | Single (`'`) |
| Semicolons | Always |
| Trailing commas | ES5 |
| Arrow parens | Always |
| Bracket spacing | `true` |
| Import organizer | On (auto-sorted on save) |

Do not override these settings per-file. If Biome flags something, fix the code — don't add ignore comments unless there is a documented reason.

---

## Rule: never expose domain objects directly

Domain entities and value objects must **never** be serialized directly into responses. Always pass through a response mapper function.

```typescript
// ❌ Bad — domain object leaking into response
async findOne(@Param('id', ParseIntPipe) id: number) {
  const office = await this.commandBus.execute(new GetOfficeByIdPort(id));
  return office; // ← exposes internal structure
}

// ✅ Good — always map through a response function
async findOne(@Param('id', ParseIntPipe) id: number): Promise<TOffice> {
  const office = await this.commandBus.execute(new GetOfficeByIdPort(id));
  return officeFromDomain(office);
}
```

---

## Response mapper functions

Mappers live in `infrastructure/web/dto/<Feature>Response.ts`. They are plain functions — no classes.

```typescript
// ✅ Good — src/modules/office/infrastructure/web/dto/OfficeResponse.ts
import type { Office } from '../../../domain/entities/Office';
import type { TOffice } from '@repo/schemas';

export function officeFromDomain(office: Office): TOffice {
  return {
    id: office.id.value,
    name: office.name,
    phone: office.phone,
    representative: office.representative,
    postalMail: office.postalMail,
    location: {
      address: office.location.address,
      coordinates: office.location.coordinates,
    },
  };
}
```

---

## Paginated responses

All list endpoints return a consistent shape using `TOfficesResponse` (or equivalent per-module type) sourced from `@repo/schemas`.

```typescript
// ✅ Good — consistent list response shape
return {
  success: true,
  data: {
    count: result.count,
    items: result.items.map(officeFromDomain),
    pageInfo: result.pageInfo,
  },
};
```

Never invent a one-off shape for list endpoints. The `PaginatedResult<T>` type and its `pageInfo` structure are shared across all modules.

---

## HTTP status codes

| Operation | Status |
|---|---|
| `POST` (create) | `201 Created` — use `@HttpCode(HttpStatus.CREATED)` |
| `GET` (read) | `200 OK` (default) |
| `PUT` / `PATCH` (update) | `200 OK` (default) |
| `DELETE` (soft delete) | `204 No Content` — use `@HttpCode(HttpStatus.NO_CONTENT)` |
| Not found | `404 Not Found` — throw `NotFoundException` in the controller |
| Validation error | `400 Bad Request` — handled by the global Zod validation pipe |

---

## Request DTOs

Request DTOs extend `createZodDto` from `@anatine/zod-nestjs` and include a static `toDto()` method that maps the raw validated input to the command structure.

```typescript
// ✅ Good — src/modules/office/infrastructure/web/dto/CreateOfficeRequest.ts
import { createZodDto } from '@anatine/zod-nestjs';
import { officeDTO } from '@repo/schemas';

export class CreateOfficeRequest extends createZodDto(officeDTO.createOfficeInput) {
  static toDto(req: CreateOfficeRequest): CreateOfficeCommand {
    return {
      name: req.name,
      phone: req.phone,
      representative: req.representative,
      location: req.location,
      postalMail: req.postalMail,
    };
  }
}
```

Zod schemas for DTOs **must live in `packages/schemas`**, not inside the API app, so the frontend and backend share the same contract.

---

## Naming conventions for response types

- Type aliases for API shapes live in `@repo/schemas` and are prefixed with `T` (e.g. `TOffice`, `TOfficesResponse`).
- Mapper functions follow the pattern `<entity>FromDomain` (e.g. `officeFromDomain`, `agentFromDomain`).
- Never create a separate "ViewModel" class — a plain function is enough.
