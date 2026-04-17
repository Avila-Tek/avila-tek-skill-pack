---
description: JWT authentication in Fastify — auth plugin, decorateRequest, onRequest hook, and protected route scoping.
globs: ["src/plugins/auth.ts", "src/modules/**/*.ts"]
alwaysApply: false
---

# Authentication

## JWT Pattern

```
Client → Authorization: Bearer <token>
  → onRequest hook (auth plugin)
    → verify JWT signature
    → extract claims
    → attach to request.user
      → route handler accesses request.user
```

Token payload shape:

```typescript
export interface JwtPayload {
  sub: string     // user ID
  email: string
  role: 'admin' | 'member'
  iat: number
  exp: number
}
```

---

## Setup: `@fastify/jwt`

```bash
pnpm add @fastify/jwt
```

Register in the plugin chain before `authPlugin`:

```typescript
// plugins/jwt.ts
import fp from 'fastify-plugin'
import jwt from '@fastify/jwt'

export default fp(async function jwtPlugin(fastify) {
  fastify.register(jwt, {
    secret: fastify.config.JWT_SECRET,
    sign: { expiresIn: '15m' },
  })
})
```

---

## Auth Plugin

```typescript
// plugins/auth.ts
import fp from 'fastify-plugin'
import { FastifyInstance, FastifyRequest, FastifyReply } from 'fastify'
import { UnauthorizedError } from '../shared/errors/unauthorized-error'
import type { JwtPayload } from '../shared/types/jwt-payload'

// TypeScript augmentation — required for type-safe request.user
declare module 'fastify' {
  interface FastifyRequest {
    user: JwtPayload | null
  }
}

export default fp(async function authPlugin(fastify: FastifyInstance) {
  // Initial value required — must match the type declared above
  fastify.decorateRequest('user', null)
})

// Reusable hook — attach to a plugin scope to protect that scope's routes
export async function verifyJwt(request: FastifyRequest, reply: FastifyReply) {
  const header = request.headers.authorization
  if (!header?.startsWith('Bearer ')) {
    throw new UnauthorizedError('Missing Bearer token')
  }
  try {
    const payload = await request.jwtVerify<JwtPayload>()
    request.user = payload
  } catch {
    throw new UnauthorizedError('Invalid or expired token')
  }
}

// Role guard factory
export function requireRole(role: JwtPayload['role']) {
  return async (request: FastifyRequest, reply: FastifyReply) => {
    if (!request.user) throw new UnauthorizedError()
    if (request.user.role !== role) throw new ForbiddenError()
  }
}
```

---

## Scoping Auth to Protected Routes

Fastify's plugin encapsulation lets you apply the auth hook only to the routes that need it — without a global middleware.

```typescript
// app.ts
export async function buildApp() {
  const fastify = Fastify({ logger: true })

  await fastify.register(configPlugin)
  await fastify.register(databasePlugin)
  await fastify.register(jwtPlugin)
  await fastify.register(authPlugin)  // decorates request.user

  // Public routes — no auth hook
  fastify.register(async (publicScope) => {
    publicScope.register(authRoutes, { prefix: '/auth' })
    publicScope.register(healthRoutes, { prefix: '/health' })
  }, { prefix: '/api/v1' })

  // Protected routes — verifyJwt hook scoped here
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

## Per-Route Role Guard

```typescript
// users.routes.ts
export async function userRoutes(fastify: FastifyInstance) {
  const controller = new UserController(...)

  // Any authenticated user
  fastify.get('/:id', { schema: { params: userParamsSchema } }, controller.findById)

  // Admin only — add requireRole in the preHandler option
  fastify.delete('/:id', {
    schema: { params: userParamsSchema },
    preHandler: [requireRole('admin')],
  }, controller.remove)
}
```

---

## Token Issuance (Login Route)

```typescript
// modules/auth/auth.controller.ts
export class AuthController {
  login: RouteHandler = async (request, reply) => {
    const { email, password } = request.body as LoginDto
    const user = await this.authService.validateCredentials(email, password)
    // request.server gives access to fastify.jwt from inside a handler
    const token = await request.server.jwt.sign({
      sub: user.id,
      email: user.email,
      role: user.role,
    })
    reply.send({ accessToken: token })
  }
}
```

---

## Accessing `request.user` in Controllers

```typescript
export class UserController {
  findById: RouteHandler = async (request, reply) => {
    // request.user is JwtPayload | null
    // In a protected scope, it is always set (verifyJwt hook ran before this)
    const currentUser = request.user!
    const user = await this.service.findById(request.params.id, currentUser)
    reply.send(toUserResponse(user))
  }
}
```

---

## Anti-Patterns

```typescript
// ❌ Global auth hook applied to ALL routes (including public ones)
fastify.addHook('onRequest', verifyJwt) // /auth/login now requires a token!

// ✅ Scope the hook to a protected plugin
fastify.register(async (protectedScope) => {
  protectedScope.addHook('onRequest', verifyJwt)
  protectedScope.register(usersPlugin)
})
```

```typescript
// ❌ Not using decorateRequest — runtime error when accessing request.user
fastify.addHook('onRequest', async (request) => {
  request.user = await getPayload(request) // Error: property not defined on request
})

// ✅ Declare with decorateRequest first (in authPlugin)
fastify.decorateRequest('user', null)
```

```typescript
// ❌ Hardcoding JWT_SECRET
const secret = 'my-secret-123' // never hardcode

// ✅ From validated config
fastify.register(jwt, { secret: fastify.config.JWT_SECRET })
```
