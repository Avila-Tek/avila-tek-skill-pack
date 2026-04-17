---
description: REST conventions, request DTOs, response mapping, pagination, CRUD patterns, and Swagger setup for Fastify.
globs: ["src/modules/**/*.ts"]
alwaysApply: false
---

# API Design

## REST Conventions

### URL Naming

- Resources are **plural nouns**: `/users`, `/orders`, `/products`
- Nested resources for ownership: `/users/:userId/orders`
- Actions that don't map to CRUD use verbs: `/auth/login`, `/auth/logout`
- All lowercase, hyphen-separated: `/product-categories`

### HTTP Verbs and Status Codes

| Operation | Method | Success status | Notes |
|-----------|--------|---------------|-------|
| Create | POST | 201 | Body contains created resource |
| Read one | GET | 200 | 404 if not found |
| Read list | GET | 200 | Never 204 for lists |
| Update (partial) | PATCH | 200 | Body contains updated resource |
| Update (full) | PUT | 200 | Idempotent |
| Delete | DELETE | 204 | No body |
| Login / token | POST | 200 | |
| Validation error | — | 400 | `code: 'VALIDATION_ERROR'` |
| Unauthenticated | — | 401 | `code: 'UNAUTHORIZED'` |
| Forbidden | — | 403 | `code: 'FORBIDDEN'` |
| Not found | — | 404 | `code: 'NOT_FOUND'` |
| Conflict | — | 409 | `code: 'CONFLICT'` |
| Internal error | — | 500 | Never expose stack traces |

---

## Request DTOs

Define a Zod schema and infer the TypeScript type from it. Never write a duplicate interface.

```typescript
// modules/users/dto/create-user.dto.ts
import { z } from 'zod'

export const createUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(2).max(100),
  role: z.enum(['admin', 'member']).default('member'),
})

export type CreateUserDto = z.infer<typeof createUserSchema>

// Params schema
export const getUserParamsSchema = z.object({
  id: z.string().uuid(),
})

export type GetUserParams = z.infer<typeof getUserParamsSchema>
```

Attach schemas to routes so Fastify validates and provides type inference:

```typescript
import { zodToJsonSchema } from 'zod-to-json-schema'

fastify.post('/', {
  schema: {
    body: zodToJsonSchema(createUserSchema),
    response: {
      201: zodToJsonSchema(userResponseSchema),
    },
  },
}, controller.create)
```

With `fastify-type-provider-zod`, schemas can be passed directly as Zod objects (no manual conversion):

```typescript
import { serializerCompiler, validatorCompiler } from 'fastify-type-provider-zod'
// in app.ts:
fastify.setValidatorCompiler(validatorCompiler)
fastify.setSerializerCompiler(serializerCompiler)

// in routes:
fastify.post('/', {
  schema: { body: createUserSchema, response: { 201: userResponseSchema } },
}, controller.create)
// request.body is now typed as CreateUserDto automatically
```

---

## Response Mapping

Never expose raw ORM rows or domain objects. Always map through a response function.

```typescript
// modules/users/dto/user.response.ts
import { z } from 'zod'

export const userResponseSchema = z.object({
  id: z.string().uuid(),
  email: z.string(),
  name: z.string(),
  role: z.string(),
  createdAt: z.string().datetime(),
})

export type UserResponse = z.infer<typeof userResponseSchema>

export function toUserResponse(user: { id: string; email: string; name: string; role: string; createdAt: Date }): UserResponse {
  return {
    id: user.id,
    email: user.email,
    name: user.name,
    role: user.role,
    createdAt: user.createdAt.toISOString(),
  }
}
```

```typescript
// ❌ Exposing raw DB row
reply.send(userFromDb) // may include passwordHash, internalFields

// ✅ Always map
reply.code(201).send(toUserResponse(userFromDb))
```

---

## Pagination

Standard query params: `?page=1&limit=20` (1-indexed pages).

```typescript
// shared/schemas/pagination.schema.ts
import { z } from 'zod'

export const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
})

export type PaginationQuery = z.infer<typeof paginationSchema>
```

Response shape for paginated lists:

```typescript
export interface PaginatedResponse<T> {
  data: T[]
  meta: {
    page: number
    limit: number
    total: number
    totalPages: number
  }
}

export function toPaginatedResponse<T>(
  items: T[],
  total: number,
  page: number,
  limit: number,
): PaginatedResponse<T> {
  return {
    data: items,
    meta: { page, limit, total, totalPages: Math.ceil(total / limit) },
  }
}
```

---

## CRUD Pattern Walkthrough

```typescript
// users.routes.ts
export async function userRoutes(fastify: FastifyInstance) {
  const controller = new UserController(new UserService(new UserRepository(fastify.db)))

  fastify.post('/', {
    schema: { body: createUserSchema, response: { 201: userResponseSchema } },
  }, controller.create)

  fastify.get('/', {
    schema: { querystring: paginationSchema, response: { 200: paginatedUserResponseSchema } },
  }, controller.findAll)

  fastify.get('/:id', {
    schema: { params: getUserParamsSchema, response: { 200: userResponseSchema } },
  }, controller.findById)

  fastify.patch('/:id', {
    schema: { params: getUserParamsSchema, body: updateUserSchema, response: { 200: userResponseSchema } },
  }, controller.update)

  fastify.delete('/:id', {
    schema: { params: getUserParamsSchema, response: { 204: z.null() } },
  }, controller.remove)
}
```

```typescript
// users.controller.ts
export class UserController {
  constructor(private readonly service: UserService) {}

  create: RouteHandler = async (request, reply) => {
    const user = await this.service.create(request.body as CreateUserDto)
    reply.code(201).send(toUserResponse(user))
  }

  findById: RouteHandler = async (request, reply) => {
    const { id } = request.params as GetUserParams
    const user = await this.service.findById(id)
    reply.send(toUserResponse(user))
  }

  remove: RouteHandler = async (request, reply) => {
    const { id } = request.params as GetUserParams
    await this.service.remove(id)
    reply.code(204).send()
  }
}
```

---

## API Versioning

All routes are prefixed with `/api/v1`. Register modules under this prefix in `app.ts`:

```typescript
fastify.register(usersPlugin, { prefix: '/api/v1' })
fastify.register(ordersPlugin, { prefix: '/api/v1' })
```

---

## Swagger / OpenAPI

Use `@fastify/swagger` and `@fastify/swagger-ui`:

```typescript
// plugins/swagger.ts
import fp from 'fastify-plugin'
import swagger from '@fastify/swagger'
import swaggerUi from '@fastify/swagger-ui'

export default fp(async function swaggerPlugin(fastify) {
  await fastify.register(swagger, {
    openapi: {
      info: { title: 'API', version: '1.0.0' },
      components: {
        securitySchemes: {
          bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
        },
      },
    },
  })
  await fastify.register(swaggerUi, { routePrefix: '/docs' })
})
```

Routes with `schema.body` and `schema.response` automatically appear in the Swagger UI.
