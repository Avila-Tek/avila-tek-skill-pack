---
stack: nestjs
label: "NestJS + Drizzle"
type: backend
detection:
  package_json_deps:
    - "@nestjs/core"
---

# Stack: NestJS + Drizzle

## Summary

NestJS backend service with Drizzle ORM. Used for all Avila Tek backend services in the monorepo and standalone APIs. Zod schemas in `packages/schemas/` are the shared contract between this layer and any frontend.

## Architecture Overview

```
src/
  modules/           ← Domain modules (one per bounded context)
    <module>/
      <module>.module.ts
      <module>.controller.ts
      <module>.service.ts
      <module>.repository.ts
      dto/            ← Zod-inferred DTOs (import from packages/schemas)
  shared/            ← Cross-cutting: guards, interceptors, pipes, decorators
  config/            ← Environment validation with Zod/class-validator
  database/          ← Drizzle setup, schema definitions, migrations
```

## Key Patterns

- **Zod schemas first** — never hand-write interfaces; import from `packages/schemas/`
- **Repository layer** — all DB queries go in `.repository.ts`; services never touch Drizzle directly
- **Module isolation** — no cross-module imports; communicate through service injection or events
- **Global exception filter** — all errors map through the shared exception filter; never `throw new HttpException` ad-hoc
- **Auth via guards** — `@UseGuards(JwtAuthGuard)` + `@Roles()` decorator pattern; see `stacks/nestjs/agent_docs/auth-permissions.md`
- **Logging** — structured JSON via the shared logger (see `stacks/nestjs/agent_docs/log-standardization.md`); no `console.log`
- **DTOs validated at controller level** — `ValidationPipe` global; DTO class implements Zod schema type

## Standards Documents

Full standards live in `stacks/nestjs/agent_docs/`:

| File | Content |
|------|---------|
| `architecture.md` | Module structure, layering rules, monorepo setup |
| `auth-permissions.md` | JWT guards, role decorators, permission matrix |
| `code-standard.md` | Naming, file structure, forbidden patterns |
| `conventions.md` | Cross-cutting monorepo conventions (shared with frontend) |
| `error-handling.md` | Exception filters, error codes, response shape |
| `log-standardization.md` | Logger usage, structured fields, correlation IDs |
| `module-patterns.md` | Module, service, repository, controller templates |
| `testing.md` | Unit test patterns, mock strategies, coverage gates |
| `test.md` | Quick cheat sheet — test commands, watch/coverage/E2E scripts |
| `erp-context.md` | Domain context specific to ERP-style modules |

## Specialized Skills

When working in a NestJS project, use these skills for stack-specific tasks:

| Task | Skill | Invoke when |
|------|-------|-------------|
| Designing API endpoints, module boundaries, or contracts | `api-and-interface-design` | "design this API", "what should this endpoint look like", "define the contract", "REST endpoint design", or any time a new controller/service boundary is needed |
| Code review of a NestJS change | `code-review-and-quality` | Before merging — runs the NestJS Red Flags list as axis 6 |

The `api-and-interface-design` skill contains the full NestJS-specific patterns: Zod schemas, response mappers, error handling, Swagger annotations, and frontend API integration. It cross-references `stacks/nestjs/agent_docs/` for detailed standards.

## Testing Conventions

- Unit tests: `*.spec.ts` co-located with source
- Integration tests: `test/` at project root
- Use `@nestjs/testing` `Test.createTestingModule()` for module tests
- Mock repositories, not services — test real service logic
- Coverage gate: 80% statements minimum

## Red Flags

- `console.log` anywhere in production code
- Direct Drizzle calls in a service (bypass repository)
- `any` type without explicit comment explaining why
- Cross-module imports that are not through injected services
- Hard-coded secrets or config values (use `ConfigService`)
- Missing `@UseGuards` on authenticated endpoints

## Verification Checklist

- [ ] `pnpm build` passes with no type errors
- [ ] `pnpm test` passes, coverage ≥ 80%
- [ ] No ESLint errors (`pnpm lint`)
- [ ] New endpoints have `@UseGuards` or explicit `@Public()` decorator
- [ ] Drizzle schema changes have a migration (`pnpm db:generate`)
- [ ] No `console.log` in changed files
