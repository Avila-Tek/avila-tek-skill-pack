---
description: Success response shape and message i18n — TransformResponseInterceptor, MESSAGES dictionary
globs: "apps/api/src/shared/interceptors/TransformResponseInterceptor.ts, apps/api/src/shared/errors/dictionary.ts"
alwaysApply: false
---

# Response Messages — Success

> Reference document for success response shape and how `message` is resolved in non-error responses.

---

## Success response shape

Every non-error, non-raw response is wrapped by `TransformResponseInterceptor`:

```json
// POST/PUT/PATCH — 201
{ "data": { ... }, "message": "Record created successfully" }

// GET by id — 200
{ "data": { ... }, "message": "Record retrieved successfully" }

// GET paginated — 200
{ "data": { "count": 10, "items": [...], "pageInfo": { ... } }, "message": "List retrieved successfully" }

// DELETE — 204
// No body returned.
```

The `message` field is always user-facing and resolved from the `Accept-Language` header.

---

## How the message is resolved

`TransformResponseInterceptor` reads `request.headers['accept-language']`, calls `parseLang()`, and passes the result to `resolveGenericMessage()`:

```typescript
// Logic inside the interceptor
if (statusCode === 201)        → resolveGenericMessage('created', lang)
if (isPaginatedShape(data))    → resolveGenericMessage('paginated', lang)
else                           → resolveGenericMessage('retrieved', lang)
```

`isPaginatedShape` checks that the response object has `{ count, items, pageInfo }`.

---

## MESSAGES dictionary

Success and generic error messages live in `apps/api/src/shared/errors/dictionary.ts` under the `MESSAGES` constant.

The generic keys (`created`, `retrieved`, `paginated`) are **fallbacks only** — used when no module-specific key is available. Every module must define its own entity-specific message keys in the same dictionary:

```typescript
// ✗ Bad — fallback generic keys, not entity-specific
created:   { en: 'Record created successfully',   es: 'Registro creado exitosamente' }
retrieved: { en: 'Record retrieved successfully', es: 'Registro obtenido exitosamente' }

// ✓ Good — entity-specific keys per module
userCreated:     { en: 'User registered successfully',   es: 'Usuario registrado exitosamente' }
officeCreated:   { en: 'Office created successfully',    es: 'Sucursal creada exitosamente' }
quoteApproved:   { en: 'Quote approved successfully',    es: 'Cotización aprobada exitosamente' }
userRetrieved:   { en: 'User retrieved successfully',    es: 'Usuario obtenido exitosamente' }
```

Generic fallback keys (defined once, used only when no entity-specific key exists):

| Key | en | es |
|---|---|---|
| `created` | Record created successfully | Registro creado exitosamente |
| `retrieved` | Record retrieved successfully | Registro obtenido exitosamente |
| `paginated` | List retrieved successfully | Lista obtenida exitosamente |
| `unexpectedError` | An unexpected error occurred | Ocurrió un error inesperado |
| `invalidJson` | Invalid request format. Please check the data sent. | Formato de solicitud inválido. Por favor verifique los datos enviados. |
| `alreadyInUse` | already in use *(prepended with field name)* | ya está en uso |
| `databaseError` | An unexpected error occurred. Please try again. | Ocurrió un error inesperado. Intente de nuevo. |

---

## i18n — Accept-Language header

```text
Accept-Language: es   →  messages in Spanish
Accept-Language: en   →  messages in English  (default when absent)
```

`parseLang` matches any value starting with `"es"` (e.g. `es`, `es-VE`, `es-419`) to Spanish. Everything else falls back to English.

---

## Opting out of the wrapper — `@RawResponse()`

Endpoints that manage their own response shape use `@RawResponse()` to bypass the interceptor entirely:

```typescript
@RawResponse()
@Controller('auth')
export class AuthController { ... }
```

These endpoints are **not** wrapped in `{ data, message }`.

---

## Confirmation endpoints pattern

Endpoints that confirm an action without returning a resource (e.g. logout, verify email) return `{ success: true }` as raw data and must be decorated with `@RawResponse()`:

```typescript
@RawResponse()
@Post('logout')
logout(): { success: true } {
  return { success: true };
}
```

Do **not** wrap confirmation responses in `{ data, message }`.

---

## Errors are thrown, never returned

Controllers never return error shapes. All error responses go through the global filters.

```typescript
// ❌ Never do this
return { error: 'Not found' };

// ✅ Always throw
throw new UserNotFoundError();
```

---

## Message quality rules

- **Messages are displayed as toasts in the frontend** — write them as user-facing notifications, not log entries.
- **Messages must be entity-specific** — name the entity that was acted on, never use generic terms like "Record" or "Registro":
  - ✗ `Record created successfully` / `Registro creado exitosamente`
  - ✓ `User registered successfully` / `Usuario registrado exitosamente`
  - ✓ `Office created successfully` / `Sucursal creada exitosamente`
- Messages must be readable by end users — no technical terms, no internal identifiers.
- Never expose implementation details (database names, field names, operation internals).
- Keep messages short and actionable when possible.
- Both `en` and `es` must always be provided — never leave one blank.

---

## Key files

| File | Role |
|---|---|
| `shared/interceptors/TransformResponseInterceptor.ts` | Wraps responses in `{ data, message }` |
| `shared/errors/dictionary.ts` | `MESSAGES` constant + `resolveGenericMessage()` + `parseLang()` |
| `shared/decorators/rawResponse.decorator.ts` | `@RawResponse()` — opt out of the interceptor |
