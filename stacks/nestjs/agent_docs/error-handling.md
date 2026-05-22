---
description: Backend error handling — DomainError subclasses, error filters, error dictionary, i18n
globs: "apps/api/src/**/domain/errors/*.ts, apps/api/src/shared/errors/*.ts, apps/api/src/shared/filters/*.ts"
alwaysApply: false
---

# Error Handling

> Reference document. Include in prompts involving domain errors, filters, or error responses.

## Architecture

```text
Domain layer         → throws DomainError (pure TypeScript, no NestJS)
Application layer    → use cases throw DomainError directly, no try-catch
Infrastructure layer → three global filters catch and format all errors
```

Each module owns its own errors. There is no global registry of domain errors.

---

## Error response shape

All errors — regardless of origin — return this shape:

```json
{
  "error": {
    "code": "quoteAlreadyApproved",
    "path": "/api/v1/quotes/42",
    "details": "..." // only in non-production environments
  },
  "message": "La cotización ya fue aprobada"
}
```

- `code` — identifier matching the dictionary key; two conventions apply:
  - **camelCase** for domain/business errors (e.g. `userNotFound`, `paymentMethodInvalid`) — thrown by `DomainError` subclasses and resolved via `ERROR_DICTIONARY`
  - **SCREAMING\_SNAKE\_CASE** for infrastructure/system errors (e.g. `UNIQUE_VIOLATION`, `INVALID_JSON`, `INTERNAL_SERVER_ERROR`) — emitted directly by the database and catch-all filters, not resolved via the dictionary
- `path` — the request path where the error occurred
- `details` — internal stack trace or original message, **only when `NODE_ENV !== 'production'`**
- `message` — user-facing string resolved from `Accept-Language` header (`en` | `es`, default `en`)

---

## Zod validation i18n — `ZodValidationPipe`

Input validation errors from Zod schemas are also translated via `Accept-Language`.
This applies to **every DTO that uses `createZodDto()`** (i.e., every controller body decorated with a Zod-backed class).

### How it works

```text
Request body
  → ZodValidationPipe.transform()
      → schema.safeParse(value)
      → on failure: reads Accept-Language header
      → maps each issue.message through resolveValidationMessage(key, lang)
      → throws BadRequestException with the translated string
```

`resolveValidationMessage` looks up the key in `ERROR_DICTIONARY[400]`. If not found, it returns the raw key as-is — so always add a dictionary entry when using a custom key.

### Registration

`ZodValidationPipe` is registered globally as `APP_PIPE` with `Scope.REQUEST` so it can read the per-request `Accept-Language` header:

```typescript
// app.module.ts
{ provide: APP_PIPE, useClass: ZodValidationPipe, scope: Scope.REQUEST }
```

### How to add i18n messages to a Zod schema

**Step 1 — Use a string key as the Zod message** (in `packages/schemas`):

```typescript
// Required field
name: z.string({ message: 'providerNameRequired' }).min(1, 'providerNameRequired'),

// Enum validation
dniType: z.enum(['V', 'E', 'J', 'G', 'P'], { message: 'clientDniTypeInvalid' }),

// Numeric validation
commission: z.number().positive('providerCommissionInvalid'),
```

**Step 2 — Add the entry in `ERROR_DICTIONARY[400]`** (in `apps/api/src/shared/errors/dictionary.ts`):

```typescript
400: {
  // ...existing entries...
  providerNameRequired: {
    en: 'Provider name is required.',
    es: 'El nombre del proveedor es requerido.',
    severity: 'low',
  },
  clientDniTypeInvalid: {
    en: 'Document type must be one of: V, E, J, G, P.',
    es: 'El tipo de documento debe ser uno de: V, E, J, G, P.',
    severity: 'low',
  },
},
```

### Rules

- Keys must be **camelCase** and unique across the 400 block.
- Always add **both** `en` and `es` entries — never leave one empty.
- `severity` is always `low` for input validation errors.
- Do **not** expose field names or technical identifiers in the messages.
- If a Zod issue has no custom message (default Zod text), `resolveValidationMessage` returns the raw Zod string — the client sees it untranslated. Always set a custom key for user-facing fields.

### Key files

| File | Role |
|------|------|
| `apps/api/src/shared/pipes/zodValidationPipe.ts` | Pipe — reads `Accept-Language`, calls `resolveValidationMessage` |
| `apps/api/src/shared/errors/dictionary.ts` | `ERROR_DICTIONARY[400]` block + `resolveValidationMessage()` |
| `apps/api/src/shared/utils/createZodDto.ts` | Helper that attaches the schema to the DTO class |
| `packages/schemas/src/<module>/<module>.dto.ts` | Where Zod schemas with custom message keys live |

---

## Three global filters (registered in `main.ts`)

NestJS applies filters in **reverse registration order** — the last registered has highest priority.

```typescript
app.useGlobalFilters(
  new AllExceptionsFilter(),     // registered first = lowest priority
  new DatabaseExceptionFilter(),
  new DomainExceptionFilter(),   // registered last = highest priority
);
```

| Filter | Catches | Message source |
|---|---|---|
| `DomainExceptionFilter` | `DomainError` subclasses | `ERROR_DICTIONARY` via `resolveError()` |
| `DatabaseExceptionFilter` | `DrizzleQueryError`, `DrizzleError` | Hardcoded keys in `MESSAGES` via `resolveGenericMessage()` |
| `AllExceptionsFilter` | Everything else (`ZodError`, `HttpException`, `Error`) | `MESSAGES` for generic cases; Zod/NestJS messages passed through |

---

## 3 steps to add a new domain error

### 1 — Class in the module's domain

```typescript
// modules/<domain>/domain/errors/<Domain>Errors.ts
import { DomainError } from '../../../../shared/errors/domain-error';

export class QuoteAlreadyApprovedError extends DomainError {
  readonly code = 'quoteAlreadyApproved';  // camelCase, unique across the app
  readonly status = 409;

  constructor() {
    super('Quote is already approved');
  }
}
```

### 2 — Entry in the shared dictionary

```typescript
// apps/api/src/shared/errors/dictionary.ts — inside the correct HTTP status block:
409: {
  quoteAlreadyApproved: {
    en: 'Quote is already approved',
    es: 'La cotización ya fue aprobada',
    severity: 'low',
  },
},
```

### 3 — Throw from the use case or adapter

```typescript
if (quote.status === 'approved') {
  throw new QuoteAlreadyApprovedError();
}
```

No try-catch is needed in the controller or the use case.

---

## Dictionary message quality rules

These rules apply to every entry in `ERROR_DICTIONARY`:

- **No field names or internal identifiers** — never expose camelCase field names (`clientId`, `driverIsClient`, `DocumentId`). Use plain language: "Client ID", "document number".
- **No implementation details in 500s** — never mention "database seeds", "rollback", "role assignment", or internal operation names. Use: "The system is not properly configured. Please contact an administrator."
- **No technical jargon** — avoid "transitioned", "contiguous starting from 0", "circular reference", "slug", "referenced entity". Use plain equivalents.
- **Severity guide**:
  - `low` — user input or business rule violation (400, 404, 409, 422)
  - `medium` — authentication / authorization (401, 403)
  - `high` — unexpected state that needs attention (some 422, 500)
  - `critical` — data integrity or system config issues (500)

---

## i18n — Accept-Language header

All three filters read `request.headers['accept-language']` and call `parseLang()`:

```text
Accept-Language: es  →  messages in Spanish
Accept-Language: en  →  messages in English  (default when header is absent)
```

`parseLang` matches any value starting with `"es"` (e.g. `es`, `es-VE`, `es-419`) to Spanish. Everything else falls back to English.

---

## How to test errors

```bash
# 404 — domain error in Spanish
curl -s -X GET http://localhost:8080/api/v1/users/99999/roles \
  -H "Authorization: Bearer <token>" \
  -H "Accept-Language: es" | jq

# 401 — invalid credentials
curl -s -X POST http://localhost:8080/api/v1/auth/sign-in \
  -H "Content-Type: application/json" \
  -H "Accept-Language: es" \
  -d '{"email":"noexiste@test.com","password":"wrong"}' | jq
```

### Expected responses by scenario

| Scenario | Status | `code` |
|-----------|--------|--------|
| Non-existent user | 404 | `userNotFound` |
| Email already registered | 409 | `userAlreadyExists` |
| Incorrect credentials | 401 | `invalidCredentials` |
| Unverified email | 401 | `emailNotVerified` |
| Invalid OTP | 401 | `invalidOtp` |
| Invalid password format | 400 | `invalidPassword` |
| Passwords do not match | 400 | `passwordMismatch` |
| Role not found | 404 | `roleNotFound` |
| Role already exists | 409 | `roleAlreadyExists` |
| DB unique constraint | 409 | `UNIQUE_VIOLATION` |
| Malformed JSON body | 400 | `INVALID_JSON` |
| Unhandled exception | 500 | `INTERNAL_SERVER_ERROR` |

### Verify filters are active

```json
// ❌ NestJS default format (filters NOT registered)
{ "statusCode": 404, "message": "Not Found", "error": "Not Found" }

// ✅ Correct format (filters active)
{ "error": { "code": "userNotFound", "path": "/api/v1/users/99" }, "message": "User not found" }
```

---

## Where each error belongs

```
✅ modules/<x>/domain/errors/   → module business errors
✅ shared/domain/policies/      → reusable validation errors
✅ domain/value-objects/        → may throw DomainError in static create()
❌ shared/errors/               → infrastructure only (base class, dictionary, filters)
❌ domain/entities/             → never throw errors inside entities
❌ controllers/                 → never catch or rethrow, the filter handles it
```

---

## Key files

| File | Role |
|---------|-----|
| `shared/errors/domain-error.ts` | Abstract base class for all domain errors |
| `shared/errors/dictionary.ts` | Error catalog (`ERROR_DICTIONARY`) + `MESSAGES` + `resolveError()` + `resolveGenericMessage()` + `parseLang()` |
| `shared/filters/domain-exception.filter.ts` | Catches `DomainError` → formats with dictionary |
| `shared/filters/DatabaseExceptionFilter.ts` | Catches Drizzle errors → formats DB errors |
| `shared/filters/AllExceptionsFilter.ts` | Catch-all for Zod, HttpException, and uncaught errors |
| `modules/<x>/domain/errors/<X>Errors.ts` | Per-module error classes |

---

## Error implementation checklist

When adding a new domain error, verify all three steps are complete:

- [ ] **Class** in `modules/<domain>/domain/errors/<Domain>Errors.ts`
  - Extends `DomainError`
  - `readonly code` — camelCase, unique across the whole app
  - `readonly status` — correct HTTP status (400, 404, 409, 422…)
  - Constructor message is internal-only (plain English, not shown to end users)
- [ ] **Dictionary entry** in `shared/errors/dictionary.ts` under the matching HTTP status block
  - Both `en` and `es` messages in plain language
  - No field names, no technical jargon, no internal identifiers
  - `severity` follows the guide: `low` for user/business errors, `medium` for auth, `high`/`critical` for system issues
- [ ] **Thrown** from the use case or adapter — no try-catch in the controller
- [ ] `npx turbo typecheck` passes after adding the class
