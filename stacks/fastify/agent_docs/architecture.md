---
description: Layered architecture, plugin-driven module structure, dependency rules, folder layout, and step-by-step guide for adding a new feature in a Fastify project.
globs: ["src/**/*.ts"]
alwaysApply: false
---

# Architecture

## The Four Layers

Every feature in a Fastify project crosses exactly four layers. Each layer has a single responsibility and strict rules about what it may import.

```
┌─────────────────────────────────────────────────────────────┐
│  Routes (Fastify plugin)                                    │
│  • Declare route path, HTTP method, schema, handler ref     │
│  • Wire controller functions as route handlers              │
│  ✗ No business logic   ✗ No DB calls   ✗ No validation code │
├─────────────────────────────────────────────────────────────┤
│  Controller                                                 │
│  • Extract data from request (body, params, query)          │
│  • Call one service method                                  │
│  • Map result through toXxxResponse() and send reply        │
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

## Plugin-Driven Module Structure

In Fastify, a feature module is a plugin. Every route registration, every feature boundary, is expressed through `fastify.register()`.

```typescript
// modules/users/users.plugin.ts
import fp from 'fastify-plugin'
import { FastifyInstance } from 'fastify'
import { userRoutes } from './users.routes'

// Feature plugins do NOT use fp() — they stay encapsulated
export async function usersPlugin(fastify: FastifyInstance) {
  fastify.register(userRoutes, { prefix: '/users' })
}

// app.ts
import { usersPlugin } from './modules/users/users.plugin'

fastify.register(usersPlugin, { prefix: '/api/v1' })
```

The route file wires schema + handler:

```typescript
// modules/users/users.routes.ts
import type { FastifyInstance } from 'fastify'
import { createUserSchema, getUserSchema } from './dto/create-user.dto'
import { UserController } from './users.controller'

export async function userRoutes(fastify: FastifyInstance) {
  const controller = new UserController(fastify)

  fastify.post('/', { schema: { body: createUserSchema } }, controller.create)
  fastify.get('/:id', { schema: { params: getUserSchema } }, controller.findById)
}
```

---

## Infrastructure Plugins

Infrastructure plugins attach shared services to the Fastify instance. They **must** use `fastify-plugin` (`fp()`) so decorations are visible to all sibling and child plugins.

```typescript
// plugins/database.ts
import fp from 'fastify-plugin'
import { FastifyInstance } from 'fastify'
import { drizzle } from 'drizzle-orm/...'

declare module 'fastify' {
  interface FastifyInstance {
    db: ReturnType<typeof drizzle>
  }
}

export default fp(async function databasePlugin(fastify: FastifyInstance) {
  const db = drizzle(fastify.config.DATABASE_URL)
  fastify.decorate('db', db)
  fastify.addHook('onClose', async () => { /* close connection */ })
})
```

```typescript
// app.ts — plugin registration order matters
import configPlugin from './plugins/config'
import databasePlugin from './plugins/database'
import authPlugin from './plugins/auth'
import { usersPlugin } from './modules/users/users.plugin'

export async function buildApp() {
  const fastify = Fastify({ logger: true })

  // 1. Config first — others depend on fastify.config
  await fastify.register(configPlugin)
  // 2. Infrastructure
  await fastify.register(databasePlugin)
  await fastify.register(authPlugin)
  // 3. Feature routes
  await fastify.register(usersPlugin, { prefix: '/api/v1' })

  // 4. Global error handler
  fastify.setErrorHandler(errorHandler)

  return fastify
}
```

---

## Dependency Direction

```
Routes
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
- Controllers may import service types but never service implementation from another module
- Services may only import `IXxxRepository` — never the concrete `XxxRepository` class
- Repositories are the only files that import from the ORM
- Cross-module communication goes through services, not direct repository imports
- `shared/errors`, `shared/schemas`, `dto/` files may be imported from any layer

---

## Folder Layout

```
src/
  app.ts                          ← buildApp() factory
  server.ts                       ← fastify.listen(), graceful shutdown
  plugins/
    config.ts                     ← fp-wrapped, decorates fastify.config
    database.ts                   ← fp-wrapped, decorates fastify.db
    auth.ts                       ← fp-wrapped, decorateRequest('user'), onRequest hook
    cors.ts                       ← fp-wrapped, @fastify/cors registration
  modules/
    users/
      users.plugin.ts             ← top-level module plugin (no fp)
      users.routes.ts             ← route declarations with schema
      users.controller.ts         ← request extraction + reply.send()
      users.service.ts            ← business logic
      users.repository.ts         ← DB queries (implements IUsersRepository)
      users.repository.interface.ts ← IUsersRepository interface
      dto/
        create-user.dto.ts        ← createUserSchema (Zod) + CreateUserDto type
        user.response.ts          ← UserResponse type + toUserResponse()
  shared/
    errors/
      app-error.ts                ← AppError base class
      not-found-error.ts
      validation-error.ts
      conflict-error.ts
      unauthorized-error.ts
      forbidden-error.ts
    schemas/
      pagination.schema.ts
      id.schema.ts
  config/
    env.schema.ts                 ← Zod schema for process.env
```

---

## Adding a New Feature — Step by Step

1. Create `src/modules/<feature>/` folder
2. Define Zod schemas in `dto/create-<feature>.dto.ts` and `dto/<feature>.response.ts`
3. Create `IXxxRepository` interface in `<feature>.repository.interface.ts`
4. Implement `XxxRepository` class in `<feature>.repository.ts`
5. Implement `XxxService` class in `<feature>.service.ts` (constructor receives `IXxxRepository`)
6. Implement `XxxController` class in `<feature>.controller.ts` (constructor receives service)
7. Write `<feature>.routes.ts` — declare routes with `schema:` options, wire controller methods
8. Write `<feature>.plugin.ts` — `async function featurePlugin(fastify)` registers routes
9. Register the module plugin in `app.ts` with the appropriate prefix

---

## Anti-Patterns

```typescript
// ❌ Business logic in a route handler
fastify.get('/users/:id', async (request, reply) => {
  const user = await db.query.users.findFirst({ where: eq(users.id, request.params.id) })
  if (!user) return reply.code(404).send({ error: 'not found' })
  reply.send(user) // also exposes raw DB row
})

// ✅ Correct — handler delegates to controller, controller to service
fastify.get('/:id', { schema: { params: getUserParamsSchema } }, controller.findById)
// controller.findById calls service.findById which calls repo.findById
```

```typescript
// ❌ Direct ORM call in a service
class UserService {
  async findById(id: string) {
    return db.query.users.findFirst({ where: eq(users.id, id) }) // wrong layer
  }
}

// ✅ Correct — service calls repository interface
class UserService {
  constructor(private readonly repo: IUsersRepository) {}
  async findById(id: string) {
    const user = await this.repo.findById(id)
    if (!user) throw new NotFoundError('User not found')
    return user
  }
}
```

```typescript
// ❌ Infrastructure plugin without fp() — decorations won't reach sibling plugins
export async function databasePlugin(fastify: FastifyInstance) {
  fastify.decorate('db', createDb()) // invisible to other plugins!
}

// ✅ Correct
export default fp(async function databasePlugin(fastify: FastifyInstance) {
  fastify.decorate('db', createDb())
})
```
