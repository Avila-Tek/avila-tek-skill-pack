---
description: Backend TypeScript/NestJS code conventions — naming, patterns, Zod validation
globs: "apps/api/src/**/*.ts"
alwaysApply: false
---

# Code Standards — apps/api

Keep changes consistent with this repo. Prefer clarity, small diffs, and predictable patterns.

---

## File & export conventions

- **camelCase** for files and folders (e.g. `createOfficeUseCase.ts`, `officeResponse.ts`).
- **One class per file**; file name must match the class name.
- Prefer **named exports**; avoid default exports except where NestJS requires them.
- Avoid **barrel exports** (`index.ts`) — they hide boundaries and slow down tooling.
- Co-locate files by feature inside `src/modules/<feature>/`; don't move code to `shared/` speculatively.

---

## TypeScript

- **Strict**: no `any`, no `as any`, no unsafe coercion.
- Prefer **interfaces** for object shapes (`OfficeProps`, `LocationProps`); use `type` for unions/mapped types.
- Add **explicit return types** on all public methods and exported functions.
- Keep types close to usage; only promote to `shared/` when two or more modules need them.
- Validate **external data** (HTTP body, query params, env) with **Zod** at the boundary. Never trust raw request data inside use-cases or domain.
- Use **`type` imports** when importing only for type checking (`import type { Office } from ...`).

---

## NestJS patterns

- **Controllers** are thin. They parse the request, call a use-case or CommandBus, and map the response. No logic.
- **Use-cases** are `@Injectable()` classes with a single `execute()` method. They sequence operations — no business rules.
- **Domain classes** (entities, value objects, policies) have zero NestJS imports and zero Drizzle imports.
- **Repository adapters** implement the abstract repository class from `application/ports/out/`.
- Use `@CommandHandler()` + `ICommandHandler` only for cross-module CQRS handlers. Intra-module use-cases are plain `@Injectable()`.
- Never put `@Module()` logic in `app.module.ts` beyond imports; each feature owns its own `module.ts`.

---

## Async & data work

- Prefer **async/await** over `.then()`.
- Parallelize independent async work with **`Promise.all`**.
- Never `await` inside a loop for independent operations.
- Never return raw Drizzle rows to the application or presentation layer — always map to domain entities.

---

## Naming conventions

| Concept | Convention | Example |
|---|---|---|
| Entity | `PascalCase`, noun | `Office`, `NewOffice` |
| Value object | `PascalCase`, noun | `OfficeId`, `Location` |
| Domain policy | `PascalCase` + `Policy` | `ClientTypePolicy` |
| Use-case | `PascalCase` + `UseCase` | `CreateOfficeUseCase` |
| CQRS port (in) | `PascalCase` + `Port` | `CreateOfficePort` |
| Repository port (out) | `PascalCase` + `Repository` | `OfficeRepository` |
| Repository adapter | `PascalCase` + `RepositoryAdapter` | `OfficeRepositoryAdapter` |
| Controller | `PascalCase` + `Controller` | `OfficeController` |
| Request DTO | `PascalCase` + `Request` | `CreateOfficeRequest` |
| Response mapper fn | camelCase + `FromDomain` | `officeFromDomain` |
| Module file | `module.ts` (always) | `src/modules/office/module.ts` |

---

## Error handling

- Domain errors are plain TypeScript classes extending `Error`. Never throw NestJS HTTP exceptions from the domain or application layer.
- Map domain errors to HTTP exceptions **in the controller** or via a global exception filter.
- Don't add error handling "just in case"; handle expected errors explicitly.
- Never leak internal error details (stack traces, DB messages) in API responses.

---

## Swagger / OpenAPI

- Every controller method must have `@ApiOperation`, `@ApiResponse` (success + error cases), and where applicable `@ApiParam` / `@ApiQuery`.
- Use `@ZodApiBody` and `@ZodApiResponse` helpers (from `src/shared/decorators/zodSwagger`) to derive schemas from Zod — never write schemas by hand.
- Keep tags consistent with the module name via `@ApiTags`.

---

## General

- Prefer **function declarations** over arrow functions for methods and handlers.
- Prefer **composition** over inheritance in domain classes.
- Avoid comments that describe *what* the code does; write comments only when explaining *why*.
- Tests are the documentation for behavior — prefer tests over prose explanations.
