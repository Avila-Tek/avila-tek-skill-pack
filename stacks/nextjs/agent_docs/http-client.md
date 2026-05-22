---
description: HTTP client conventions — API envelope format, schema usage (Camp A), buildSafeResponseSchema role, message propagation
globs: "packages/services/src/**/*.ts, packages/schemas/src/**/*.dto.ts, packages/schemas/src/**/*.schema.ts"
alwaysApply: false
---

# HTTP Client

## Utility reference

| Utility | Package | What it is |
|---|---|---|
| `SafeFetchClient` | `@repo/services` | HTTP client implementation that wraps `fetch`. Handles auth headers, base URL, and always returns `Safe<T>` — never throws. Unwraps the `{ data, message }` envelope automatically before returning. |
| `buildSafeResponseSchema(schema)` | `@repo/schemas` | Wraps a raw Zod schema into `{ data: schema, message: z.string() }` — the full HTTP response shape. **Swagger/OpenAPI documentation only. Never pass this to the HTTP client.** |
| `buildPaginationSchemaForModel(schema)` | `@repo/schemas` | Builds `{ count, pageInfo, items: schema[] }` — the inner paginated data shape. **Pass this to the HTTP client** for paginated endpoints. |
| `buildPaginatedResponseSchema(schema)` | `@repo/schemas` | Shorthand for `buildSafeResponseSchema(buildPaginationSchemaForModel(schema))` — full paginated HTTP response. **Swagger only.** |

---

## API envelope contract (wire format)

Every backend response follows this shape:

```
// Success
{ "data": T, "message": "string" }

// Error
{ "error": { "code": "string", "details"?: [], "path"?: "string" }, "message": "string" }

// Confirmation-only (send-otp, forgot-password, etc.)
{ "data": { "success": true }, "message": "string" }
```

The `message` field is always present and is the text to show in toasts.
`SafeFetchClient` detects the envelope automatically and returns `Safe<T>`.

---

## Camp A: schemas describe raw data, not the envelope

When passing a schema to the HTTP client, the schema must describe the **inner `T`** — the
object inside `data`, not the full `{ data: T, message }` shape.

```typescript
// ✅ Correct — schema describes the raw data
httpClient.get('/regions', params, options, regionsPaginatedSchema)
//                                           ↑ = buildPaginationSchemaForModel(regionSchema)
//                                             describes { count, items, pageInfo }

// ❌ Wrong — schema describes the full HTTP envelope
httpClient.get('/regions', params, options, regionDTO.regionsResponseSchema)
//                                           ↑ = buildSafeResponseSchema(regionsPaginatedSchema)
//                                             describes { data: { count... }, message }
//                                             → parse fails: client already unwrapped data
```

**Why:** `SafeFetchClient.parseWithSchema()` always unwraps the `{ data, message }` envelope
before calling `schema.safeParse()`. The schema receives the inner `T` directly.

---

## `buildSafeResponseSchema` — Swagger only, never in the HTTP client

```
buildSafeResponseSchema(rawSchema)
       │
       ├── @ZodApiResponse(200, responseSchema, "...")
       │     └─→ Swagger UI shows the actual HTTP response shape
       │         { data: { ... }, message: string }
       │
       └── ❌ httpClient.get(path, ..., responseSchema)
               — Do NOT pass response schemas to the HTTP client
```

Response schemas (`*ResponseSchema`, `buildSafeResponseSchema(T)`) exist exclusively for
OpenAPI documentation. Pass the raw data schema to the HTTP client instead.

---

## When to use a schema

| Use schema? | When | Example |
|-------------|------|---------|
| **Yes** | Data is structured, domain-critical | `paginatedUsersSchema`, `signInDataSchema` |
| **No** | Simple mutation with no meaningful return | `DELETE /users/:id` |
| **No** | Response is `void` or `{ success: true }` confirmation | `forgotPassword`, `sendOtp` |

```typescript
// With schema — validates and types the response
async getUsers(): Promise<Safe<TUsersPaginated>> {
  return this.httpClient.get('/v1/users', params, options, paginatedUsersSchema);
}

// Without schema — envelope is unwrapped automatically, no validation
async deleteUser(id: number): Promise<Safe<unknown>> {
  return this.httpClient.delete(`/v1/users/${id}`);
}
```

---

## Available schema builders

```typescript
// packages/schemas/src/utils.ts
buildSafeResponseSchema(schema)       // { data: schema, message: z.string() } — Swagger only
buildPaginatedResponseSchema(schema)  // buildSafeResponseSchema(buildPaginationSchemaForModel(schema))

// packages/schemas/src/pagination/index.ts
buildPaginationSchemaForModel(schema) // { count, pageInfo, items: schema[] } — use in HTTP client
```

For paginated endpoints, pass `buildPaginationSchemaForModel(itemSchema)` to the HTTP client,
not `buildPaginatedResponseSchema(itemSchema)`.

---

## Exporting raw data schemas from DTOs

Every DTO that has a response schema must also export the raw inner schema and its type,
so both the backend controller and the frontend HTTP client can reference it.

```typescript
// ✅ Pattern in packages/schemas/src/auth/auth.dto.ts
export const signInDataSchema = z.object({ ... });       // raw — use in HTTP client + controller
export type TSignInData = z.output<typeof signInDataSchema>;

const signInResponse = buildSafeResponseSchema(signInDataSchema); // Swagger only
export type TSignInResponse = z.infer<typeof signInResponse>;
```

---

## Message propagation

`Safe<T>` carries `message?: string` from the backend. Use it in toasts with a fallback:

```typescript
const result = await authService.signIn(input);
if (!result.success) {
  showToast({ type: 'error', title: result.error });
  return;
}
showToast({ type: 'success', title: result.message ?? 'Inicio de sesión exitoso' });
```

The fallback is needed because `Safe` is also constructed internally (e.g. by `safe()`) where
there is no backend message.

---

## Anti-patterns

- **Passing `*ResponseSchema` to the HTTP client** — these describe `{ data: T, message }`, but the client already unwrapped the envelope. The schema parse will fail. Pass the raw schema instead.
- **Hardcoding toast text when the backend provides a message** — always prefer `result.message` with a fallback string.
- **Defining response schemas inline in service files** — schemas belong in `@repo/schemas`. Services import and use them; they do not define them.
- **Using `InferEnvelopeData`** — this utility is deprecated. Use the exported raw type directly (e.g. `TSignInData` instead of `InferEnvelopeData<typeof authDTO.signInResponse>`).
