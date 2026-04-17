---
description: TypeScript conventions, file naming, export rules, naming conventions table, async patterns, and forbidden patterns for Express projects.
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
| Router | `.router.ts` | `users.router.ts` |
| Controller | `.controller.ts` | `users.controller.ts` |
| Service | `.service.ts` | `users.service.ts` |
| Repository | `.repository.ts` | `users.repository.ts` |
| Repository interface | `.repository.interface.ts` | `users.repository.interface.ts` |
| Middleware | `.middleware.ts` | `auth.middleware.ts` |
| DTO (input) | `.dto.ts` | `create-user.dto.ts` |
| Response | `.response.ts` | `user.response.ts` |
| Error class | `-error.ts` | `not-found-error.ts` |
| Zod schema | `*.schema.ts` (shared) | `pagination.schema.ts` |
| Type augmentation | `.d.ts` | `express.d.ts` |
| Test | `.spec.ts` | `users.service.spec.ts` |
| Integration test | `.integration.spec.ts` | `users.integration.spec.ts` |

---

## Exports

- **Named exports** for all files
- No default exports except for `asyncHandler.ts` (common convention) — prefer named

```typescript
// ✅ Named exports everywhere
export class UserService { ... }
export class UserController { ... }
export function toUserResponse(user: User): UserResponse { ... }
export const createUserSchema = z.object({ ... })
export function createUserRouter(controller: UserController): Router { ... }
export function requireAuth(req, res, next) { ... }
```

---

## TypeScript Rules

- `"strict": true` in `tsconfig.json` — required, no exceptions
- **No `any`** — if you must use it, add a comment explaining why
- **Explicit return types** on all exported functions and public class methods
- **`z.infer<>`** for DTO types — never duplicate a Zod schema with a manual interface
- **`import type`** for type-only imports
- **Module augmentation** for `req.user` in `src/types/express.d.ts`

```typescript
// ✅ Explicit return type
export async function findById(id: string): Promise<User | null> { ... }

// ✅ Type inferred from Zod — no duplicate interface
export type CreateUserDto = z.infer<typeof createUserSchema>

// ✅ Type-only import
import type { Request, Response, NextFunction } from 'express'
```

---

## Naming Conventions

| Concept | Convention | Example |
|---------|-----------|---------|
| Router factory | `create` + PascalCase + `Router` | `createUserRouter` |
| Controller class | PascalCase + `Controller` | `UserController` |
| Service class | PascalCase + `Service` | `UserService` |
| Repository class | PascalCase + `Repository` | `UserRepository` |
| Repository interface | `I` + PascalCase + `Repository` | `IUsersRepository` |
| Middleware function | camelCase + purpose | `requireAuth`, `validate` |
| DTO (input type) | PascalCase + `Dto` | `CreateUserDto` |
| Response type | PascalCase + `Response` | `UserResponse` |
| Response mapper | `to` + PascalCase + `Response` | `toUserResponse` |
| Error class | PascalCase + `Error` | `UserNotFoundError` |
| Zod schema | camelCase + `Schema` | `createUserSchema` |

---

## Layer Responsibilities (Quick Reference)

| Layer | Allowed | Forbidden |
|-------|---------|-----------|
| Router | Declare route, apply middleware, call controller via asyncHandler | Business logic, DB calls, validation code |
| Controller | Extract request data, call service, send response | Business logic, DB calls, error serialization (use next(err)) |
| Service | Business logic, call repository interface | HTTP concerns, direct ORM imports |
| Repository | DB queries, data mapping | Business logic, HTTP concerns |
| Middleware | Cross-cutting concerns (auth, validation, logging) | Business logic, direct DB calls |

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
const data: any = req.body

// ❌ console.log in production code
console.log('user created', user) // use a logger (pino, winston)

// ❌ Bare throw without AppError subclass
throw new Error('User not found') // no HTTP status, produces 500

// ❌ Direct ORM import in a service
import { db } from '../../config/database' // wrong layer
import { eq } from 'drizzle-orm'

// ❌ Business logic in a controller
export class UserController {
  async create(req, res) {
    if (await this.repo.findByEmail(req.body.email)) { // repo in controller!
      return res.status(409).json({ error: 'exists' })
    }
  }
}

// ❌ Async handler without asyncHandler — unhandled rejection crashes process
router.post('/users', async (req, res) => {
  const user = await userService.create(req.body) // if throws, process crashes
  res.json(user)
})

// ❌ Error serialized in controller instead of forwarded
async create(req, res) {
  try {
    const user = await this.service.create(req.body)
    res.json(user)
  } catch (err) {
    res.status(500).json({ error: 'failed' }) // bypass errorHandler, inconsistent format
  }
}

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
