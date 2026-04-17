---
description: Fastify plugin system deep-dive — fastify-plugin (fp), decorate, decorateRequest, lifecycle hooks, boot order, and encapsulation rules.
globs: ["src/plugins/**/*.ts", "src/modules/**/*.plugin.ts"]
alwaysApply: false
---

# Plugins

## Plugin System Overview

Fastify builds a **tree of encapsulated scopes**. Every `fastify.register()` call creates a child scope. Hooks, decorators, and plugins registered inside a child scope are invisible to the parent and to sibling scopes — unless the plugin is wrapped with `fastify-plugin`.

```
App (root scope)
├── configPlugin (fp-wrapped → visible everywhere)
├── databasePlugin (fp-wrapped → fastify.db visible everywhere)
├── authPlugin (fp-wrapped → onRequest hook applies everywhere registered)
└── usersPlugin (NOT fp-wrapped → encapsulated)
    └── userRoutes (child of usersPlugin)
└── ordersPlugin (NOT fp-wrapped → encapsulated, cannot see usersPlugin internals)
```

**Rule of thumb:**
- Infrastructure plugins → use `fp()` (need to share state with everyone)
- Feature route plugins → do NOT use `fp()` (should be isolated)

---

## `fastify-plugin` (`fp()`)

`fp()` breaks encapsulation for a plugin, making its decorations and hooks visible to the parent scope (and therefore all siblings).

```typescript
import fp from 'fastify-plugin'
import { FastifyInstance } from 'fastify'

// ✅ Infrastructure plugin — wraps with fp()
export default fp(async function databasePlugin(fastify: FastifyInstance) {
  const db = createDrizzleClient(fastify.config.DATABASE_URL)
  fastify.decorate('db', db)

  fastify.addHook('onClose', async () => {
    await db.$disconnect?.()
  })
}, {
  name: 'database',          // Optional: gives the plugin a name for error messages
  dependencies: ['config'],  // Optional: declares required plugins
})
```

```typescript
// ❌ Feature plugin using fp() — do NOT do this
export default fp(async function usersPlugin(fastify: FastifyInstance) {
  // This breaks encapsulation — auth hooks or decorators added here leak globally
  fastify.register(userRoutes, { prefix: '/users' })
})

// ✅ Feature plugin without fp()
export async function usersPlugin(fastify: FastifyInstance) {
  fastify.register(userRoutes, { prefix: '/users' })
}
```

---

## `fastify.decorate()`

Attaches a value (service, client, config) to the Fastify instance. Must be called before any plugin tries to access it.

```typescript
// plugins/config.ts
import fp from 'fastify-plugin'
import { z } from 'zod'

const envSchema = z.object({
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  PORT: z.coerce.number().default(3000),
})

// TypeScript augmentation — required for type-safe fastify.config access
declare module 'fastify' {
  interface FastifyInstance {
    config: z.infer<typeof envSchema>
  }
}

export default fp(async function configPlugin(fastify: FastifyInstance) {
  const config = envSchema.parse(process.env)
  fastify.decorate('config', config)
})
```

```typescript
// Any route handler can now safely access fastify.config
fastify.get('/health', async (request, reply) => {
  reply.send({ port: request.server.config.PORT })
})
```

---

## `fastify.decorateRequest()` / `fastify.decorateReply()`

Extends the `Request` or `Reply` objects. **Must declare an initial value** (even `null`) — this allows Fastify to allocate the property on every request object at instantiation time for performance.

```typescript
// plugins/auth.ts
import fp from 'fastify-plugin'

interface JwtPayload {
  sub: string
  email: string
  role: string
}

// TypeScript augmentation
declare module 'fastify' {
  interface FastifyRequest {
    user: JwtPayload | null
  }
}

export default fp(async function authPlugin(fastify: FastifyInstance) {
  // Initial value MUST be provided — null for objects, '' for strings, 0 for numbers
  fastify.decorateRequest('user', null)

  fastify.addHook('onRequest', async (request, reply) => {
    const header = request.headers.authorization
    if (!header?.startsWith('Bearer ')) return // public route — user stays null
    const token = header.slice(7)
    try {
      const payload = fastify.jwt.verify<JwtPayload>(token)
      request.user = payload
    } catch {
      throw new UnauthorizedError('Invalid token')
    }
  })
})
```

```typescript
// ❌ Missing initial value — Fastify will throw at startup
fastify.decorateRequest('user') // wrong

// ✅ With initial value
fastify.decorateRequest('user', null)
```

---

## Lifecycle Hooks

Fastify exposes a rich hook system. Hooks can be registered globally on the instance or scoped to a plugin.

| Hook | When it runs | Common use case |
|------|-------------|----------------|
| `onRequest` | First — before body is read | Authentication, rate limiting, request ID |
| `preParsing` | Before body parsing | Streaming transforms, request logging |
| `preValidation` | After parsing, before schema validation | Manual pre-processing |
| `preHandler` | After validation, before route handler | Authorization, attaching derived data |
| `preSerialization` | Before response serialization | Response transformations |
| `onSend` | Before response is sent (payload available) | Compression, response logging |
| `onResponse` | After response is sent | Metrics, audit logging |
| `onError` | On error, before `setErrorHandler` | Error enrichment, structured logging |
| `onClose` | When server is shutting down | Cleanup (close DB connections, flush logs) |

```typescript
// Scoped hook — only applies to routes inside this plugin
export async function usersPlugin(fastify: FastifyInstance) {
  // This requireAdmin hook applies only to routes registered in this plugin
  fastify.addHook('preHandler', requireAdmin)
  fastify.register(userRoutes, { prefix: '/users' })
}

// Global hook — applies to all routes
fastify.addHook('onRequest', requestIdMiddleware)
```

---

## `addHook` vs `register`

| Mechanism | Scope | Use for |
|-----------|-------|---------|
| `fastify.addHook()` at root | All routes | Request IDs, global logging |
| `fastify.addHook()` inside a plugin (no fp) | Only that plugin's routes | Feature-specific auth, admin checks |
| `fastify.register(authPlugin)` with `fp()` | All routes after registration | JWT auth applied to whole API |
| `fastify.register(protectedRoutes)` with `addHook` inside | Only those routes | Mixed public/protected API |

```typescript
// Mixed public/protected routes in the same app
export async function buildApp() {
  const fastify = Fastify()

  await fastify.register(configPlugin)
  await fastify.register(databasePlugin)

  // Public routes — no auth
  fastify.register(async (publicScope) => {
    publicScope.register(authRoutes, { prefix: '/auth' })
    publicScope.register(healthRoutes, { prefix: '/health' })
  }, { prefix: '/api/v1' })

  // Protected routes — auth hook scoped here
  fastify.register(async (protectedScope) => {
    protectedScope.addHook('onRequest', verifyJwt)
    protectedScope.register(usersPlugin, { prefix: '/users' })
    protectedScope.register(ordersPlugin, { prefix: '/orders' })
  }, { prefix: '/api/v1' })

  fastify.setErrorHandler(errorHandler)
  return fastify
}
```

---

## Plugin Boot Order

Infrastructure plugins must be registered before anything that depends on them. Fastify will error at startup if a decoration is accessed before it is registered — but only at runtime, not at compile time.

```typescript
// ✅ Correct order
await fastify.register(configPlugin)     // 1. Config (no deps)
await fastify.register(databasePlugin)   // 2. DB (needs fastify.config)
await fastify.register(jwtPlugin)        // 3. JWT (needs fastify.config.JWT_SECRET)
await fastify.register(authPlugin)       // 4. Auth (needs fastify.jwt)
await fastify.register(corsPlugin)       // 5. CORS
await fastify.register(usersPlugin, { prefix: '/api/v1' })  // 6. Features (need fastify.db)

// ❌ Wrong order — fastify.config not yet available when databasePlugin runs
await fastify.register(databasePlugin)
await fastify.register(configPlugin)
```

---

## Anti-Patterns

```typescript
// ❌ Forgetting fp() on an infrastructure plugin
export async function databasePlugin(fastify: FastifyInstance) {
  fastify.decorate('db', createDb())
  // fastify.db is only visible inside this plugin's scope — usersPlugin can't see it!
}

// ✅ Wrap with fp()
export default fp(async function databasePlugin(fastify) {
  fastify.decorate('db', createDb())
})
```

```typescript
// ❌ Using fp() on a feature plugin — leaks hooks/decorations globally
export default fp(async function usersPlugin(fastify) {
  fastify.addHook('preHandler', requireAdminRole) // now applies to ALL routes!
  fastify.register(userRoutes)
})

// ✅ Feature plugins stay encapsulated (no fp)
export async function usersPlugin(fastify: FastifyInstance) {
  fastify.addHook('preHandler', requireAdminRole) // only applies to user routes
  fastify.register(userRoutes)
}
```

```typescript
// ❌ decorateRequest without initial value
fastify.decorateRequest('user') // Fastify throws: "Must have a default value"

// ✅ Always provide initial value
fastify.decorateRequest('user', null)
```

```typescript
// ❌ Accessing fastify.db before database plugin is registered
fastify.register(usersPlugin) // usersPlugin accesses fastify.db in constructor
fastify.register(databasePlugin) // too late

// ✅ Register infrastructure first, features after
fastify.register(databasePlugin)
fastify.register(usersPlugin) // fastify.db is available now
```
