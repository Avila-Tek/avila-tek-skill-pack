---
description: Layered architecture, Router-per-feature structure, middleware registration order, dependency rules, folder layout, and step-by-step guide for adding a new feature in an Express project.
globs: ["src/**/*.ts"]
alwaysApply: false
---

# Architecture

## The Four Layers

Every feature in an Express project crosses exactly four layers. Each layer has a single responsibility and strict rules about what it may import.

```
┌─────────────────────────────────────────────────────────────┐
│  Router (express.Router)                                    │
│  • Declare route path, HTTP method, middleware chain        │
│  • Wire validate() middleware + controller methods          │
│  ✗ No business logic   ✗ No DB calls   ✗ No validation code │
├─────────────────────────────────────────────────────────────┤
│  Controller                                                 │
│  • Extract data from request (body, params, query)          │
│  • Call one service method                                  │
│  • Map result through toXxxResponse() and send response     │
│  • Never serialize errors — call next(err) on failure       │
│  ✗ No business logic   ✗ No DB calls                        │
├─────────────────────────────────────────────────────────────┤
│  Service                                                    │
│  • All business logic lives here                            │
│  • Calls repository interface methods only                  │
│  • Throws typed AppError subclasses on domain errors        │
│  ✗ No HTTP concerns    ✗ No direct ORM/Drizzle imports      │
├─────────────────────────────────────────────────────────────┤
│  Repository                                                 │
│  • All DB queries (SELECT, INSERT, UPDATE, DELETE)          │
│  • Implements IXxxRepository interface                      │
│  • Returns domain objects, never raw ORM rows               │
│  ✗ No business logic   ✗ No HTTP concerns                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Router-per-Feature Structure

Each feature exports an `express.Router()` that is mounted in the versioned router.

```typescript
// modules/users/users.router.ts
import { Router } from 'express'
import { asyncHandler } from '../../middleware/asyncHandler'
import { validate } from '../../middleware/validate.middleware'
import { createUserSchema } from './dto/create-user.dto'
import { UserController } from './users.controller'

export function createUserRouter(controller: UserController): Router {
  const router = Router()
  router.post('/', validate(createUserSchema), asyncHandler(controller.create))
  router.get('/:id', asyncHandler(controller.findById))
  router.patch('/:id', validate(updateUserSchema), asyncHandler(controller.update))
  router.delete('/:id', asyncHandler(controller.remove))
  return router
}
```

```typescript
// routes/v1.ts
import { Router } from 'express'
import { requireAuth } from '../middleware/auth.middleware'
import { createUserRouter } from '../modules/users/users.router'

export function createV1Router(): Router {
  const router = Router()
  // Apply auth to all v1 routes (or per-router as needed)
  router.use(requireAuth)
  router.use('/users', createUserRouter(new UserController(...)))
  return router
}
```

```typescript
// app.ts — middleware registration order is critical
import express from 'express'
import helmet from 'helmet'
import cors from 'cors'
import { createV1Router } from './routes/v1'
import { errorHandler } from './middleware/error.middleware'

export function buildApp() {
  const app = express()

  app.use(helmet())
  app.use(cors())
  app.use(express.json())                          // body parser — BEFORE routes
  app.use(express.urlencoded({ extended: true }))
  app.use('/api/v1', createV1Router())             // feature routes
  app.use(errorHandler)                            // error handler — MUST be last

  return app
}
```

---

## Global Middleware Registration

Middleware order in `app.ts` is execution order. Getting it wrong causes subtle bugs.

| Order | Middleware | Why |
|-------|-----------|-----|
| 1 | `helmet()` | Sets security headers before any response |
| 2 | `cors()` | Allows CORS preflight before routes |
| 3 | `express.json()` | Parses body before validation or auth can read it |
| 4 | `express.urlencoded()` | Parses form data |
| 5 | request logger | Logs after body is parsed |
| 6 | rate limiter | Before heavy route processing |
| 7 | Feature routers | Auth middleware lives inside routers |
| 8 | 404 handler | After all routes — catches unmatched |
| 9 | `errorHandler` | **MUST be last** — catches all `next(err)` calls |

---

## Dependency Direction

```
Router
  ↓ imports
Controller
  ↓ imports
Service
  ↓ imports
IXxxRepository (interface)
  ↑ implemented by
Repository
  ↓ imports
ORM / Drizzle / Prisma
```

Rules:
- Controllers may import service types but never services from another module
- Services may only import `IXxxRepository` — never the concrete `XxxRepository` class
- Repositories are the only files that import from the ORM
- `shared/errors`, `shared/schemas`, `dto/` may be imported from any layer
- Middleware imports only from `shared/` — never from feature modules

---

## Folder Layout

```
src/
  app.ts                              ← buildApp() factory, no port binding
  server.ts                           ← app.listen(), graceful shutdown
  routes/
    index.ts                          ← mounts v1Router at /api/v1
    v1.ts                             ← mounts all feature routers
  modules/
    users/
      users.router.ts                 ← express.Router() with validate + asyncHandler
      users.controller.ts             ← req extraction, res.json(), next(err)
      users.service.ts                ← business logic
      users.repository.ts             ← DB queries (implements IUsersRepository)
      users.repository.interface.ts   ← IUsersRepository interface
      dto/
        create-user.dto.ts            ← createUserSchema (Zod) + CreateUserDto type
        user.response.ts              ← UserResponse type + toUserResponse()
  middleware/
    auth.middleware.ts                ← JWT verification, attaches req.user
    error.middleware.ts               ← 4-arg error handler (registered last)
    validate.middleware.ts            ← validate(schema) factory
    asyncHandler.ts                   ← catches async errors, forwards to next(err)
  shared/
    errors/
      app-error.ts                    ← AppError base class
      not-found-error.ts
      validation-error.ts
      conflict-error.ts
      unauthorized-error.ts
      forbidden-error.ts
    schemas/
      pagination.schema.ts
      id.schema.ts
  types/
    express.d.ts                      ← module augmentation for req.user
  config/
    env.schema.ts                     ← Zod schema for process.env
```

---

## Adding a New Feature — Step by Step

1. Create `src/modules/<feature>/` folder
2. Define Zod schemas in `dto/create-<feature>.dto.ts` and `dto/<feature>.response.ts`
3. Create `IXxxRepository` interface in `<feature>.repository.interface.ts`
4. Implement `XxxRepository` class in `<feature>.repository.ts`
5. Implement `XxxService` class in `<feature>.service.ts` (constructor receives `IXxxRepository`)
6. Implement `XxxController` class in `<feature>.controller.ts` (constructor receives service)
7. Write `<feature>.router.ts` — `createXxxRouter(controller)` with `validate()` + `asyncHandler()` per route
8. Mount the new router in `routes/v1.ts`

---

## Anti-Patterns

```typescript
// ❌ Business logic in a controller
export class UserController {
  async create(req: Request, res: Response) {
    const existing = await db.query.users.findFirst(...)
    if (existing) return res.status(409).json({ error: 'already exists' })
    const user = await db.insert(users).values(req.body).returning()
    res.status(201).json(user[0]) // raw DB row exposed
  }
}

// ✅ Controller only translates and delegates
export class UserController {
  constructor(private readonly service: UserService) {}

  create = asyncHandler(async (req: Request, res: Response) => {
    const user = await this.service.create(req.body as CreateUserDto)
    res.status(201).json(toUserResponse(user))
  })
}
```

```typescript
// ❌ Missing next(err) — error swallowed or res sent twice
router.post('/', async (req, res) => {
  const user = await userService.create(req.body) // throws — unhandled rejection
  res.status(201).json(user)
})

// ✅ asyncHandler catches and forwards to error middleware
router.post('/', validate(createUserSchema), asyncHandler(async (req, res) => {
  const user = await userService.create(req.body as CreateUserDto)
  res.status(201).json(toUserResponse(user))
}))
```

```typescript
// ❌ Error middleware not last — regular routes defined after it are skipped
app.use(errorHandler)
app.use('/api/v1', v1Router) // never reached after an error

// ✅ Error handler registered after all routes
app.use('/api/v1', v1Router)
app.use(errorHandler) // last
```
