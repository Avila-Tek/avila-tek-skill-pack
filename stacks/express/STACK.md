---
stack: express
label: "Express"
type: backend
detection:
  package_json_deps:
    - "express"
  exclude_if_present:
    - "@nestjs/core"
    - "@angular/core"
    - "react-native"
---

# Express

## Summary

Express backend service. Middleware-chain architecture, four-layer structure (router → controller → service → repository), Zod for request validation, and centralized error handling via the 4-argument error middleware. TypeScript strict mode throughout. All errors are passed via `next(err)` — never serialized inline.

---

## Architecture Overview

```
src/
  app.ts                    ← Express app creation, global middleware, router mounting
  server.ts                 ← HTTP server startup, port bind, graceful shutdown
  routes/                   ← Versioned router mounting
    index.ts                ← app.use('/api/v1', v1Router)
    v1.ts                   ← all v1 feature routers mounted here
  modules/                  ← Feature modules
    <feature>/
      <feature>.router.ts   ← express.Router(); mounts validate + controller methods
      <feature>.controller.ts ← Parses req, calls service, sends res
      <feature>.service.ts  ← Business logic; calls repository interface
      <feature>.repository.ts ← All DB queries; implements IXxxRepository
      dto/
        create-<feature>.dto.ts   ← Zod schema + z.infer<> type
        <feature>.response.ts     ← Response type + toXxxResponse() mapper
  middleware/               ← Global and shared middleware
    auth.middleware.ts       ← JWT verification; attaches req.user
    error.middleware.ts      ← 4-arg error handler (registered last)
    validate.middleware.ts   ← validate(schema) factory
    asyncHandler.ts          ← Wraps async route handlers to catch rejections
  shared/
    errors/                 ← AppError base class + typed subclasses
    schemas/                ← Shared Zod schemas (pagination, ids, etc.)
  types/
    express.d.ts            ← Module augmentation for req.user
  config/                   ← Environment schema (Zod)
```

**Middleware registration order in `app.ts`:**

```
app.use(helmet())
app.use(cors())
app.use(express.json())
app.use(express.urlencoded({ extended: true }))
app.use(requestLogger)
app.use(rateLimit(...))
app.use('/api/v1', v1Router)          ← routes (auth middleware inside routers)
app.use(notFoundHandler)
app.use(errorHandler)                 ← MUST be last
```

---

## Key Patterns

- **Middleware chain**: all cross-cutting concerns (auth, logging, rate limiting) registered with `app.use()` in explicit order in `app.ts`
- **4-argument error middleware**: `(err, req, res, next)` in `error.middleware.ts` is the single place that serializes error responses — must be registered last
- **Router per feature**: `express.Router()` exported from `.router.ts`, mounted via `app.use('/api/v1/feature', featureRouter)`
- **`validate(schema)` middleware factory**: calls `schema.safeParse(req.body)`, calls `next(new ValidationError(issues))` on failure
- **Repository pattern**: all DB queries in `.repository.ts`; services import only the `IXxxRepository` interface, never Drizzle/Prisma directly
- **`req.user` convention**: auth middleware attaches decoded JWT claims to `req.user`, typed via module augmentation in `src/types/express.d.ts`
- **`asyncHandler` wrapper**: wraps every async route handler to catch rejected promises and forward to `next(err)` — never omit this
- **Strict TypeScript**: no `any`, explicit return types, DTOs inferred from Zod schemas via `z.infer<>`

---

## Standards Documents

| File | Content |
|------|---------|
| `agent_docs/architecture.md` | Layered structure, Router-per-feature, middleware order, dependency rules, folder layout |
| `agent_docs/api-design.md` | REST conventions, DTOs, response mapping, pagination, CRUD patterns, controller signatures |
| `agent_docs/validation.md` | Zod, `validate()` middleware factory, body/params/query validation |
| `agent_docs/error-handling.md` | `AppError` hierarchy, 4-arg error middleware, `asyncHandler`, error envelope |
| `agent_docs/auth.md` | JWT middleware, `requireAuth`, `requireRole`, TypeScript module augmentation |
| `agent_docs/testing.md` | Vitest, `buildApp()` factory, supertest, unit vs integration tests |
| `agent_docs/code-standard.md` | TypeScript rules, naming conventions, async patterns, forbidden patterns |

---

## Required Reading by Task Type

| Task | Required docs |
|------|--------------|
| Any implementation | `architecture.md`, `code-standard.md` |
| New endpoint | + `api-design.md`, `error-handling.md` |
| Auth / permissions | + `auth.md` |
| Input validation | + `validation.md` |
| Writing tests | `testing.md` |
| Code review | `architecture.md`, `code-standard.md` (Red Flags below) |
| New feature module | `architecture.md` |

---

## Specialized Skills

| Skill | When to use |
|-------|-------------|
| `dev-api-and-interface-design` | Designing a new REST resource or contract |
| `dev-code-review-and-quality` | Reviewing a PR against these standards |
| `dev-security-and-hardening` | Auth, input validation, secret handling |
| `dev-test-driven-development` | Writing tests before implementation |

---

## Testing Conventions

- **Unit tests**: `*.spec.ts` co-located with source; test services with mock repositories (`vi.fn()`), repositories with a real test DB or in-memory SQLite
- **Integration tests**: `*.integration.spec.ts`; use `supertest(app)` — no real port needed
- **Test runner**: Vitest
- **Coverage gate**: 80% minimum
- **Factory function**: always export `buildApp()` from `app.ts` for clean test setup; never share state between tests

---

## Red Flags

- Business logic inside a controller or router handler (belongs in service)
- Direct Drizzle/Prisma/ORM calls inside a service (bypasses repository)
- Missing `next(err)` — error serialized inline with `res.status().json(...)`, bypassing the error middleware
- Async route handler without `asyncHandler` wrapper or explicit try/catch that calls `next(err)` — unhandled promise rejection
- `errorHandler` middleware not registered as the last `app.use()` in `app.ts`
- `express.json()` not registered — `req.body` is always `undefined`
- `req.user` accessed without TypeScript module augmentation in `express.d.ts` — implicit `any`
- Route handler calling `res.send()` after `next()` has already been called — double response crash
- `any` type used without an explanatory comment
- `console.log` in production code

---

## Verification Checklist

- [ ] `pnpm build` passes with no TypeScript errors
- [ ] `pnpm test` passes, coverage ≥ 80%
- [ ] `pnpm lint` reports no errors
- [ ] `express.json()` registered before any route handlers in `app.ts`
- [ ] `errorHandler` is the last `app.use()` call in `app.ts`
- [ ] All async route handlers are wrapped with `asyncHandler` (or have explicit try/catch + `next(err)`)
- [ ] All errors forwarded via `next(err)`, not serialized inside handlers or controllers
- [ ] `req.user` typed via module augmentation in `src/types/express.d.ts`
- [ ] Auth middleware applied to all protected routers
- [ ] No direct ORM calls in any service file
- [ ] Zod validation applied to all POST/PUT/PATCH request bodies
- [ ] No `console.log` in changed files
