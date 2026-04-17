---
description: TypeScript conventions, file naming, export rules, naming conventions table, async patterns, and forbidden patterns for Fastify projects.
globs: ["src/**/*.ts"]
alwaysApply: false
---

# Code Standard

## File Naming

- **camelCase** for all source files: `userService.ts`, `createUserSchema.ts`
- One class or one primary export per file
- File name matches the primary export: `UserService` lives in `users.service.ts`
- No barrel `index.ts` files — import directly from the source file

### Suffix Conventions

| File type | Suffix | Example |
|-----------|--------|---------|
| Fastify plugin | `.plugin.ts` | `users.plugin.ts` |
| Routes | `.routes.ts` | `users.routes.ts` |
| Controller | `.controller.ts` | `users.controller.ts` |
| Service | `.service.ts` | `users.service.ts` |
| Repository | `.repository.ts` | `users.repository.ts` |
| Repository interface | `.repository.interface.ts` | `users.repository.interface.ts` |
| DTO (input) | `.dto.ts` | `create-user.dto.ts` |
| Response | `.response.ts` | `user.response.ts` |
| Error class | `-error.ts` | `not-found-error.ts` |
| Zod schema | `*.schema.ts` (shared) | `pagination.schema.ts` |
| Test | `.spec.ts` | `users.service.spec.ts` |
| Integration test | `.integration.spec.ts` | `users.integration.spec.ts` |

---

## Exports

- **Named exports** for all files except Fastify plugin files
- **`export default fp(...)`** is required for infrastructure plugins (Fastify plugin convention)
- Feature module plugins use `export async function` (named, no `fp`)

```typescript
// ✅ Named exports for services, controllers, repositories
export class UserService { ... }
export class UserController { ... }
export function toUserResponse(user: User): UserResponse { ... }
export const createUserSchema = z.object({ ... })

// ✅ Default export required for fp-wrapped infrastructure plugins
export default fp(async function databasePlugin(fastify) { ... })

// ✅ Named export for feature plugins (no fp)
export async function usersPlugin(fastify: FastifyInstance) { ... }
```

---

## TypeScript Rules

- `"strict": true` in `tsconfig.json` — required, no exceptions
- **No `any`** — if you must use it, add a comment explaining why
- **Explicit return types** on all exported functions and public class methods
- **`z.infer<>`** for DTO types — never duplicate a Zod schema with a manual interface
- **`import type`** for type-only imports

```typescript
// ✅ Explicit return type
export async function findById(id: string): Promise<User | null> { ... }

// ✅ Type inferred from Zod — no duplicate interface
export type CreateUserDto = z.infer<typeof createUserSchema>

// ✅ Type-only import
import type { FastifyInstance } from 'fastify'
```

---

## Naming Conventions

| Concept | Convention | Example |
|---------|-----------|---------|
| Plugin (feature) | camelCase function | `usersPlugin` |
| Plugin file (infra) | camelCase + `.ts` | `database.ts` |
| Controller class | PascalCase + `Controller` | `UserController` |
| Service class | PascalCase + `Service` | `UserService` |
| Repository class | PascalCase + `Repository` | `UserRepository` |
| Repository interface | `I` + PascalCase + `Repository` | `IUsersRepository` |
| DTO (input type) | PascalCase + `Dto` | `CreateUserDto` |
| Response type | PascalCase + `Response` | `UserResponse` |
| Response mapper | `to` + PascalCase + `Response` | `toUserResponse` |
| Error class | PascalCase + `Error` | `UserNotFoundError` |
| Zod schema | camelCase + `Schema` | `createUserSchema` |
| Route handler type | `RouteHandler` (from Fastify) | — |

---

## Layer Responsibilities (Quick Reference)

| Layer | Allowed | Forbidden |
|-------|---------|-----------|
| Routes | Declare route, attach schema, call controller | Business logic, DB calls, validation code |
| Controller | Extract request data, call service, send reply | Business logic, DB calls, error formatting |
| Service | Business logic, call repository interface | HTTP concerns, direct ORM imports |
| Repository | DB queries, data mapping | Business logic, HTTP concerns |

---

## Async Conventions

```typescript
// ✅ async/await only — no .then() chains
const user = await userService.findById(id)

// ✅ Promise.all for parallel independent operations
const [user, orders] = await Promise.all([
  userService.findById(id),
  orderService.findByUserId(id),
])

// ❌ await in a loop for independent items — use Promise.all instead
for (const id of ids) {
  const user = await userService.findById(id) // sequential, slow
}

// ✅ Correct
const users = await Promise.all(ids.map(id => userService.findById(id)))
```

---

## Forbidden Patterns

```typescript
// ❌ any without comment
const data: any = request.body

// ❌ console.log in production code
console.log('user created', user) // use fastify.log

// ❌ Bare throw without AppError subclass
throw new Error('User not found') // no HTTP status, produces 500

// ❌ Direct ORM import in a service
import { db } from '../../plugins/database' // wrong layer
import { eq } from 'drizzle-orm'

// ❌ Business logic in a route handler
fastify.post('/users', async (request, reply) => {
  const existing = await db.query.users.findFirst(...)
  if (existing) return reply.code(409).send(...)
  // ...
})

// ❌ Missing schema on a route
fastify.post('/users', async (request, reply) => {
  // request.body has no validation, no type inference
})

// ❌ Barrel index.ts files
// src/modules/users/index.ts — avoid; import directly from the file
```

---

## Linting Setup (Biome)

Use Biome for fast linting and formatting:

```json
// biome.json
{
  "linter": {
    "enabled": true,
    "rules": {
      "recommended": true,
      "suspicious": { "noExplicitAny": "error" },
      "style": { "noNonNullAssertion": "warn" }
    }
  },
  "formatter": {
    "enabled": true,
    "indentStyle": "space",
    "indentWidth": 2
  }
}
```

```json
// package.json scripts
{
  "scripts": {
    "lint": "biome check src/",
    "lint:fix": "biome check --write src/",
    "build": "tsc --noEmit",
    "test": "vitest run --coverage"
  }
}
```
