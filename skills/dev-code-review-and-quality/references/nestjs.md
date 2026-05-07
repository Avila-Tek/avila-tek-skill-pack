# NestJS — Code Review Reference

## Naming Conventions

| Concept | Convention | Example |
|---|---|---|
| Entity | PascalCase noun | `Office`, `NewOffice` |
| Value object | PascalCase noun | `OfficeId`, `Location` |
| Domain policy | PascalCase + `Policy` | `ClientTypePolicy` |
| Use-case | PascalCase + `UseCase` | `CreateOfficeUseCase` |
| CQRS port (in) | PascalCase + `Port` | `CreateOfficePort` |
| Repository port (out) | PascalCase + `Repository` | `OfficeRepository` |
| Repository adapter | PascalCase + `RepositoryAdapter` | `OfficeRepositoryAdapter` |
| Controller | PascalCase + `Controller` | `OfficeController` |
| Request DTO | PascalCase + `Request` | `CreateOfficeRequest` |
| Response mapper fn | camelCase + `FromDomain` | `officeFromDomain` |
| Module file | always `module.ts` | `src/modules/office/module.ts` |

Files: camelCase. One class per file. No barrel `index.ts` exports.

## Architecture Red Flags

These are blocking findings in a code review:

- `@Entity` or `@Table` annotation inside `domain/` package — JPA annotations belong in `infrastructure/persistence/` only
- Direct Drizzle imports (`db.select()`, `db.insert()`, etc.) inside a use-case or domain class — all DB access goes through repository adapters
- Cross-module imports not going through `CommandBus`/`QueryBus` — modules must be independent
- Cross-domain Drizzle relations defined inside a feature module schema — they belong in `src/infrastructure/database/schema.ts`
- Hard delete (`db.delete(...)`) where soft delete (`isActive = false`) should be used — all deletes must be soft
- Every read query must filter `eq(table.isActive, true)` — soft-deleted records must be excluded

## Code Standards

**TypeScript:**
- No `any`, no `as any`, no unsafe coercions
- Explicit return types on all public methods and exported functions
- `import type` for type-only imports
- Prefer `interface` for object shapes; `type` for unions/mapped types

**NestJS patterns:**
- Controllers are thin: parse request → call use-case → map response. No business logic.
- Use-cases: single `execute()` method, orchestrate only, no business rules
- Domain classes have zero NestJS and zero Drizzle imports
- No `@Autowired`-style field injection — constructor injection only

**Async:**
- Prefer `async/await` over `.then()`
- Parallelize independent async work with `Promise.all`
- Never `await` inside a loop for independent operations
- Never return raw Drizzle rows to application or presentation layers

## Validation

`parseOrThrow` must be used on all `@Param()` and `@Body()`. Without it, a TypeScript `type`/`interface` (erased at runtime) won't be validated, returning 500 instead of 400:

```typescript
// ✅
const parsed = parseOrThrow(createOfficeInput, body);

// ❌ Missing — invalid input may reach domain code
const result = await useCase.execute(body as TCreateOfficeInput);
```

Zod schemas must use `.trim().min(1)` — not `.min(1)` alone (whitespace-only strings pass `.min(1)` before trimming).

## Error Handling

- Domain errors extend `DomainError` — never throw NestJS HTTP exceptions from domain or application layers
- Exception mapping happens in the `DomainExceptionFilter` — no ad-hoc `try/catch` in controllers
- Never leak stack traces, DB messages, or internal error details in API responses

## Swagger

Every controller method must have:
- `@ApiOperation` with a clear `summary`
- `@ApiResponse` for success + common error cases (400, 401, 403, 404)
- `@ApiParam` / `@ApiQuery` where applicable
- `@ZodApiBody` / `@ZodApiResponse` to derive schemas from Zod — never write schemas by hand

## Verification Checklist

- [ ] `npm run build` — no type errors
- [ ] `npm test` — all tests pass, coverage ≥ 80%
- [ ] `npm run lint` — no ESLint errors
- [ ] `npm run db:generate` — run if any Drizzle schema changed
- [ ] No `@Entity`/`@Table` in `domain/` packages
- [ ] No direct Drizzle in use-cases or domain
- [ ] All read queries filter `eq(table.isActive, true)`
- [ ] No hard deletes — soft delete everywhere
- [ ] `parseOrThrow` on all `@Param()` and `@Body()`
- [ ] New endpoints have `@UseGuards` + `@Permissions()` or explicit `@Public()`
- [ ] No `console.log` in changed files
