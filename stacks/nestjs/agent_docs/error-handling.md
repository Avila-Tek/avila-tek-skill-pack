---
description: Backend domain errors — DomainError subclasses, RFC 7807 responses, error dictionary
globs: "apps/api/src/**/domain/errors/*.ts, apps/api/src/shared/errors/*.ts, apps/api/src/shared/filters/*.ts"
alwaysApply: false
---

# Error Handling

> Reference document. Include with `@.claude/docs/error-handling.md` in prompts involving domain errors.

## Architecture

```
Domain layer         → throws DomainError (pure TypeScript, no NestJS)
Application layer    → use cases throw DomainError directly, no try-catch
Infrastructure layer → DomainExceptionFilter automatically translates to HTTP RFC 7807
```

Each module owns its own errors. There is no global registry of domain errors.

---

## 3 steps to add a new error

### 1 — Class in the module's domain

```typescript
// modules/<domain>/domain/errors/<Domain>Errors.ts
import { DomainError } from '../../../../shared/errors/domain-error';

export class QuoteAlreadyApprovedError extends DomainError {
  readonly code = 'quoteAlreadyApproved';  // camelCase, unique across the app
  readonly status = 409;

  constructor(quoteId: number) {
    super(`Quote ${quoteId} is already approved`);
  }
}
```

### 2 — Entry in the shared dictionary

```typescript
// apps/api/src/shared/errors/dictionary.ts — inside the HTTP status block:
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
  throw new QuoteAlreadyApprovedError(quote.id);
}
```

No try-catch is needed in the controller or the use case.

---

## HTTP Response (RFC 7807)

```json
{
  "type": "quoteAlreadyApproved",
  "title": "La cotización ya fue aprobada",
  "status": 409,
  "detail": "409-quoteAlreadyApproved"
}
```

The language is resolved from the `Accept-Language` header (`en` or `es`). Default: `en`.

---

## How to test errors

### Option A — curl

```bash
# 404 — resource not found
curl -s -X GET http://localhost:8080/api/v1/users/99999/roles \
  -H "Authorization: Bearer <token>" | jq

# 401 — invalid credentials
curl -s -X POST http://localhost:8080/api/v1/auth/sign-in \
  -H "Content-Type: application/json" \
  -d '{"email":"noexiste@test.com","password":"wrong"}' | jq

# With Spanish language
curl -s -X GET http://localhost:8080/api/v1/users/99999/roles \
  -H "Authorization: Bearer <token>" \
  -H "Accept-Language: es" | jq
```

### Option B — Swagger UI (`/api/docs`)

1. Authenticate with the lock icon (Bearer token)
2. Execute any endpoint with a non-existent ID or invalid data
3. View the response in the Swagger panel

### Expected responses by type

| Scenario | Status | `type` |
|-----------|--------|--------|
| Non-existent user ID | 404 | `userNotFound` |
| Email already registered | 409 | `userAlreadyExists` |
| Incorrect credentials | 401 | `invalidCredentials` |
| Unverified email | 401 | `emailNotVerified` |
| Incorrect OTP | 401 | `invalidOtp` |
| Password does not meet rules | 400 | `invalidPassword` |
| Passwords do not match | 400 | `passwordMismatch` |
| Role not found | 404 | `roleNotFound` |
| Role already exists | 409 | `roleAlreadyExists` |

### Verify that the `DomainExceptionFilter` is active

If a domain error returns the standard NestJS format instead of RFC 7807, there is a problem with the filter registration:

```json
// ❌ NestJS format (filter is NOT active)
{ "statusCode": 404, "message": "Not Found", "error": "Not Found" }

// ✅ RFC 7807 format (filter is active)
{ "type": "userNotFound", "title": "User not found", "status": 404, "detail": "404-userNotFound" }
```

Verify in `main.ts` that `DomainExceptionFilter` is registered **after** `DatabaseExceptionFilter`:
```typescript
app.useGlobalFilters(
  new DatabaseExceptionFilter(),
  new DomainExceptionFilter(),   // ← must go second
);
```

---

## Where each error belongs

```
✅ modules/<x>/domain/errors/   → module business errors
✅ shared/domain/policies/      → reusable validation errors
✅ domain/value-objects/        → may throw DomainError in static create()
❌ shared/errors/               → infrastructure only (base class, dictionary, filter)
❌ domain/entities/             → never throw errors inside entities
❌ controllers/                 → never catch or rethrow, the filter handles it
```

---

## Key files

| File | Role |
|---------|-----|
| `shared/errors/domain-error.ts` | Abstract base class |
| `shared/errors/dictionary.ts` | RFC 7807 catalog — add new entries here |
| `shared/types/result.type.ts` | `Result<T,E>`, `ok()`, `err()` |
| `shared/filters/domain-exception.filter.ts` | HTTP boundary |
| `modules/<x>/domain/errors/<X>Errors.ts` | Per-module errors |
