---
stack: fastify
label: "Fastify"
type: backend
detection:
  package_json_deps:
    - "fastify"
---

# Fastify

## Summary

Fastify backend service. Plugin-driven architecture with encapsulation, Zod / JSON Schema validation at the route level, lifecycle hooks for cross-cutting concerns, and a strict four-layer structure (routes → controller → service → repository). TypeScript strict mode throughout. `setErrorHandler` is the single place that serializes error responses.

---

## Architecture Overview

```
src/
  app.ts                    ← Fastify instance, plugin registration, server export
  server.ts                 ← HTTP server startup, port bind, graceful shutdown
  plugins/                  ← Infrastructure plugins (fp-wrapped, shared scope)
    config.ts               ← Env validation (Zod) decorated as fastify.config
    database.ts             ← Drizzle/Prisma client decorated as fastify.db
    auth.ts                 ← JWT verification hook, decorateRequest('user')
    cors.ts                 ← @fastify/cors
  modules/                  ← Feature modules — each is a Fastify plugin (NOT fp-wrapped)
    <feature>/
      <feature>.routes.ts   ← Route declarations: schema + handler wiring
      <feature>.controller.ts ← request/reply translation; calls service
      <feature>.service.ts  ← Business logic; calls repository interface
      <feature>.repository.ts ← All DB queries; implements IXxxRepository
      dto/
        create-<feature>.dto.ts   ← Zod schema + z.infer<> type
        <feature>.response.ts     ← Response type + toXxxResponse() mapper
  shared/
    errors/                 ← AppError base class + typed subclasses
    schemas/                ← Shared Zod schemas (pagination, ids, etc.)
    hooks/                  ← Reusable hooks (requireAuth, requireRole)
  config/                   ← Environment schema (Zod)
```

**Request lifecycle inside a module:**

```
HTTP request
  → onRequest hook (auth plugin)
  → preValidation (schema validation via fastify-type-provider-zod)
  → preHandler
  → Route handler → Controller → Service → Repository → DB
  → Reply serialization (schema speeds this up)
  ← HTTP response
  (on throw) → setErrorHandler → serialized error response
```

---

## Key Patterns

- **Plugin system**: every feature and every infrastructure concern is a Fastify plugin registered with `fastify.register()`
- **`fastify-plugin` (`fp()`)** for infrastructure plugins — breaks encapsulation so decorations (`fastify.db`, `fastify.config`) propagate to all siblings
- **Feature plugins do NOT use `fp()`** — they stay encapsulated; auth hooks are scoped to them, not global
- **Schema-first routes**: declare Zod schema on every route via `fastify-type-provider-zod`; Fastify validates before the handler runs and speeds up serialization
- **`fastify.decorate()`** to attach singleton services (db, config, logger) to the Fastify instance
- **`setErrorHandler`** as the single centralized error handler — never manually serialize errors inside handlers; always `throw new AppError()`
- **Repository pattern**: all DB queries in `.repository.ts`; services import only the `IXxxRepository` interface, never Drizzle/Prisma directly
- **Strict TypeScript**: no `any`, explicit return types, DTOs inferred from Zod schemas via `z.infer<>`

---

## Standards Documents

| File | Content |
|------|---------|
| `agent_docs/architecture.md` | Layered structure, plugin-driven modules, dependency rules, folder layout, adding a new feature |
| `agent_docs/plugins.md` | Plugin system deep-dive: `fp()`, `decorate`, lifecycle hooks, boot order |
| `agent_docs/api-design.md` | REST conventions, DTOs, response mapping, pagination, CRUD patterns, Swagger |
| `agent_docs/validation.md` | Zod + `fastify-type-provider-zod`, schema-first routes, param/query validation |
| `agent_docs/error-handling.md` | `AppError` hierarchy, `setErrorHandler`, error envelope |
| `agent_docs/auth.md` | JWT plugin, `decorateRequest`, `onRequest` hook, protected route scoping |
| `agent_docs/testing.md` | Vitest, `buildApp()` factory, `app.inject()`, unit vs integration tests |
| `agent_docs/code-standard.md` | TypeScript rules, naming conventions, async patterns, forbidden patterns |

---

## Required Reading by Task Type

| Task | Required docs |
|------|--------------|
| Any implementation | `architecture.md`, `code-standard.md` |
| New endpoint | + `api-design.md`, `error-handling.md`, `plugins.md` |
| Auth / permissions | + `auth.md`, `plugins.md` |
| Input validation | + `validation.md` |
| Writing tests | `testing.md` |
| Code review | `architecture.md`, `code-standard.md` (Red Flags below) |
| New feature module | `architecture.md`, `plugins.md` |

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
- **Integration tests**: `*.integration.spec.ts`; use `app.inject()` — no real port needed
- **Test runner**: Vitest
- **Coverage gate**: 80% minimum
- **Factory function**: always export `buildApp()` from `app.ts` for clean test setup; never share state between tests

---

## Red Flags

- Business logic inside a route handler or controller (belongs in service)
- Direct Drizzle/Prisma/ORM calls inside a service (bypasses repository)
- Infrastructure plugin (`database.ts`, `config.ts`, `auth.ts`) not wrapped with `fp()` — decorations won't propagate to sibling plugins
- Feature route plugin wrapped with `fp()` — should be encapsulated, not shared
- Error response serialized inside a handler or controller (`reply.send({ error: ... })`) instead of throwing `AppError` and delegating to `setErrorHandler`
- Route registered without a `schema:` option — misses validation, type inference, and serialization speedup
- Plugin boot order wrong: feature plugins registered before infrastructure plugins (`fastify.db` not yet available)
- `reply.send()` called after `reply.hijack()` or after async flow already ended — "reply already sent" errors
- `any` type used without an explanatory comment
- `console.log` in production code

---

## Verification Checklist

- [ ] `pnpm build` passes with no TypeScript errors
- [ ] `pnpm test` passes, coverage ≥ 80%
- [ ] `pnpm lint` reports no errors
- [ ] Every route definition includes a `schema:` option
- [ ] All infrastructure plugins (`plugins/`) use `fastify-plugin` (`fp()`)
- [ ] Feature module plugins do NOT use `fp()`
- [ ] `setErrorHandler` is registered in `app.ts`; no error serialization elsewhere
- [ ] `request.user` is typed via `fastify.decorateRequest('user', null)` + TypeScript augmentation
- [ ] Auth hooks are scoped to the plugins that need them (not registered globally unless truly needed everywhere)
- [ ] No direct ORM calls in any service file
- [ ] Plugin registration order in `app.ts`: config → database → auth/cors → feature routes
- [ ] No `console.log` in changed files
